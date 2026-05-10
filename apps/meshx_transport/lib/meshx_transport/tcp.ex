defmodule MeshxTransport.TCP do
  @moduledoc """
  TCP transport adapter for real node-to-node MeshX links.

  The adapter listens on a local TCP port and can also connect to another TCP
  endpoint. Each connection starts with a small transport handshake that
  exchanges peer IDs and metadata, then carries MeshX protocol frames as
  length-prefixed TCP messages.
  """

  @behaviour MeshxTransport

  use GenServer

  alias MeshxTransport.{Event, Peer}

  @transport :tcp
  @hello_tag :meshx_tcp_hello_v1
  @frame_tag :meshx_tcp_frame_v1
  @default_connect_timeout_ms 5_000
  @default_handshake_timeout_ms 5_000

  @type host :: :inet.ip_address() | charlist() | String.t()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :event_target, self())
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Connects this endpoint to another `MeshxTransport.TCP` endpoint.
  """
  @spec connect(pid(), host(), :inet.port_number(), keyword()) :: :ok | {:error, term()}
  def connect(transport, host, port, opts \\ []) do
    GenServer.call(
      transport,
      {:connect, host, port, opts},
      Keyword.get(opts, :call_timeout_ms, 10_000)
    )
  end

  @doc "Returns the bound TCP listen port."
  @spec listen_port(pid()) :: :inet.port_number()
  def listen_port(transport) do
    GenServer.call(transport, :listen_port)
  end

  @doc "Closes a peer connection if it exists."
  @spec disconnect(pid(), term()) :: :ok | {:error, :peer_not_found}
  def disconnect(transport, peer_id) do
    GenServer.call(transport, {:disconnect, peer_id})
  end

  @impl MeshxTransport
  def send_frame(transport, peer_id, frame, opts \\ []) do
    GenServer.call(transport, {:send_frame, peer_id, frame, opts})
  end

  @impl MeshxTransport
  def broadcast_frame(transport, frame, opts \\ []) do
    GenServer.call(transport, {:broadcast_frame, frame, opts})
  end

  @impl MeshxTransport
  def peers(transport) do
    GenServer.call(transport, :peers)
  end

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    metadata = Keyword.get(opts, :metadata, %{})
    event_target = Keyword.fetch!(opts, :event_target)
    listen_ip = Keyword.get(opts, :listen_ip, {127, 0, 0, 1})
    listen_port = Keyword.get(opts, :listen_port, 0)

    with {:ok, listener} <- :gen_tcp.listen(listen_port, listen_opts(listen_ip)),
         {:ok, bound_port} <- bound_port(listener),
         {:ok, acceptor} <- start_acceptor(listener, self()) do
      {:ok,
       %{
         id: id,
         metadata: metadata,
         event_target: event_target,
         listener: listener,
         acceptor: acceptor,
         listen_port: bound_port,
         peers: %{},
         sockets: %{}
       }}
    end
  end

  @impl true
  def handle_call(:listen_port, _from, state) do
    {:reply, state.listen_port, state}
  end

  def handle_call(:local_hello, _from, state) do
    {:reply, {:ok, state.id, state.metadata}, state}
  end

  def handle_call({:connect, host, port, opts}, _from, state) do
    timeout = Keyword.get(opts, :connect_timeout_ms, @default_connect_timeout_ms)

    case open_connection(host, port, state, timeout) do
      {:ok, socket, peer_id, peer_metadata} ->
        state = add_peer(socket, peer_id, peer_metadata, state)
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:disconnect, peer_id}, _from, state) do
    case Map.get(state.peers, peer_id) do
      nil ->
        {:reply, {:error, :peer_not_found}, state}

      %{socket: socket} ->
        :gen_tcp.close(socket)
        {:reply, :ok, remove_peer(socket, state)}
    end
  end

  def handle_call({:send_frame, peer_id, frame, _opts}, _from, state) do
    result =
      case Map.get(state.peers, peer_id) do
        nil -> {:error, :peer_not_found}
        %{socket: socket} -> send_payload(socket, encode_frame(frame))
      end

    {:reply, result, state}
  end

  def handle_call({:broadcast_frame, frame, _opts}, _from, state) do
    payload = encode_frame(frame)

    results =
      state.peers
      |> Map.values()
      |> Enum.map(fn %{socket: socket} -> send_payload(socket, payload) end)

    result = if Enum.all?(results, &(&1 == :ok)), do: :ok, else: {:error, results}
    {:reply, result, state}
  end

  def handle_call(:peers, _from, state) do
    peers = state.peers |> Map.values() |> Enum.map(& &1.peer)
    {:reply, peers, state}
  end

  @impl true
  def handle_cast({:accepted, socket, peer_id, metadata}, state) do
    {:noreply, add_peer(socket, peer_id, metadata, state)}
  end

  @impl true
  def handle_info({:tcp, socket, payload}, state) do
    state = handle_socket_payload(socket, payload, state)
    set_active_once(socket)
    {:noreply, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    {:noreply, remove_peer(socket, state)}
  end

  def handle_info({:tcp_error, socket, _reason}, state) do
    {:noreply, remove_peer(socket, state)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp open_connection(host, port, state, timeout) do
    with {:ok, socket} <-
           :gen_tcp.connect(normalize_host(host), port, socket_opts(active: false), timeout),
         :ok <- send_payload(socket, encode_hello(state.id, state.metadata)),
         {:ok, payload} <- :gen_tcp.recv(socket, 0, @default_handshake_timeout_ms),
         {:ok, peer_id, peer_metadata} <- decode_hello(payload),
         :ok <- set_active_once(socket) do
      {:ok, socket, peer_id, peer_metadata}
    else
      {:error, _reason} = error ->
        error

      other ->
        {:error, other}
    end
  end

  defp accept_loop(listener, server) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        handle_accepted_socket(socket, server)
        accept_loop(listener, server)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        accept_loop(listener, server)
    end
  end

  defp handle_accepted_socket(socket, server) do
    with {:ok, payload} <- :gen_tcp.recv(socket, 0, @default_handshake_timeout_ms),
         {:ok, peer_id, metadata} <- decode_hello(payload),
         {:ok, local_id, local_metadata} <- GenServer.call(server, :local_hello),
         :ok <- send_payload(socket, encode_hello(local_id, local_metadata)),
         :ok <- :gen_tcp.controlling_process(socket, server) do
      GenServer.cast(server, {:accepted, socket, peer_id, metadata})
    else
      _error -> :gen_tcp.close(socket)
    end
  end

  defp add_peer(socket, peer_id, metadata, state) do
    state = close_existing_peer(peer_id, socket, state)
    set_active_once(socket)
    peer = Peer.new(peer_id, @transport, address: peer_id, metadata: metadata)
    send(state.event_target, Event.peer_up(@transport, peer))

    %{
      state
      | peers: Map.put(state.peers, peer_id, %{socket: socket, peer: peer}),
        sockets: Map.put(state.sockets, socket, peer_id)
    }
  end

  defp close_existing_peer(peer_id, socket, state) do
    case Map.get(state.peers, peer_id) do
      %{socket: ^socket} ->
        state

      %{socket: existing_socket} ->
        :gen_tcp.close(existing_socket)
        remove_peer(existing_socket, state)

      nil ->
        state
    end
  end

  defp remove_peer(socket, state) do
    case Map.pop(state.sockets, socket) do
      {nil, _sockets} ->
        state

      {peer_id, sockets} ->
        :gen_tcp.close(socket)
        send(state.event_target, Event.peer_down(@transport, peer_id))
        %{state | peers: Map.delete(state.peers, peer_id), sockets: sockets}
    end
  end

  defp handle_socket_payload(socket, payload, state) do
    peer_id = Map.get(state.sockets, socket)

    case decode_frame(payload) do
      {:ok, frame} when not is_nil(peer_id) ->
        send(state.event_target, Event.frame(@transport, peer_id, frame))
        state

      _error ->
        remove_peer(socket, state)
    end
  end

  defp encode_hello(id, metadata) do
    :erlang.term_to_binary({@hello_tag, id, metadata})
  end

  defp decode_hello(payload) do
    case safe_binary_to_term(payload) do
      {:ok, {@hello_tag, id, metadata}} when is_map(metadata) -> {:ok, id, metadata}
      {:ok, _other} -> {:error, :invalid_hello}
      {:error, reason} -> {:error, reason}
    end
  end

  defp encode_frame(frame) when is_binary(frame) do
    :erlang.term_to_binary({@frame_tag, frame})
  end

  defp decode_frame(payload) do
    case safe_binary_to_term(payload) do
      {:ok, {@frame_tag, frame}} when is_binary(frame) -> {:ok, frame}
      {:ok, _other} -> {:error, :invalid_frame}
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_binary_to_term(payload) do
    {:ok, :erlang.binary_to_term(payload, [:safe])}
  rescue
    _error -> {:error, :invalid_payload}
  end

  defp send_payload(socket, payload) do
    case :gen_tcp.send(socket, payload) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp start_acceptor(listener, server) do
    Task.start(fn -> accept_loop(listener, server) end)
  end

  defp bound_port(listener) do
    with {:ok, {_ip, port}} <- :inet.sockname(listener), do: {:ok, port}
  end

  defp set_active_once(socket) do
    case :inet.setopts(socket, active: :once) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp listen_opts(listen_ip) do
    socket_opts(ip: listen_ip, active: false) ++ [reuseaddr: true]
  end

  defp socket_opts(extra) do
    [:binary, packet: 4] ++ extra
  end

  defp normalize_host(host) when is_binary(host), do: String.to_charlist(host)
  defp normalize_host(host), do: host
end
