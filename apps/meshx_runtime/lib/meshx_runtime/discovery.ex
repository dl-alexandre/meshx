defmodule MeshxRuntime.Discovery do
  @moduledoc """
  Local UDP and mDNS peer discovery.

  Discovery is LAN-scoped and opt-in. It broadcasts a compact MeshX
  announcement and can also advertise `_meshx._udp.local` through mDNS/DNS-SD.
  Received announcements are forwarded to `MeshxRuntime.Router` as discovered
  peers.
  """

  use GenServer

  alias MeshxRuntime.Telemetry
  alias MeshxRuntime.MDNS
  alias MeshxStore.Identity
  alias MeshxTransport.Peer

  @tag :meshx_discovery_v1
  @default_port 45_862
  @default_mdns_port 5_353
  @default_mdns_multicast {224, 0, 0, 251}
  @default_interval_ms :timer.seconds(5)
  @default_broadcast {255, 255, 255, 255}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Broadcasts one discovery announcement immediately."
  @spec announce(pid() | atom()) :: :ok | {:error, term()}
  def announce(pid \\ __MODULE__) do
    GenServer.call(pid, :announce)
  end

  @doc "Returns the UDP listen port, or `nil` when disabled."
  @spec listen_port(pid() | atom()) :: :inet.port_number() | nil
  def listen_port(pid \\ __MODULE__) do
    GenServer.call(pid, :listen_port)
  end

  @doc "Returns the mDNS UDP port, or `nil` when mDNS is disabled."
  @spec mdns_port(pid() | atom()) :: :inet.port_number() | nil
  def mdns_port(pid \\ __MODULE__) do
    GenServer.call(pid, :mdns_port)
  end

  @doc false
  @spec encode_announcement(term(), atom(), term(), map()) :: binary()
  def encode_announcement(node_id, transport, address, metadata) when is_map(metadata) do
    :erlang.term_to_binary({@tag, node_id, transport, address, metadata})
  end

  @impl true
  def init(opts) do
    if Keyword.get(opts, :enabled?, false) do
      init_enabled(opts)
    else
      {:ok, %{enabled?: false, socket: nil, listen_port: nil, mdns_socket: nil, mdns_port: nil}}
    end
  end

  @impl true
  def handle_call(:announce, _from, %{enabled?: false} = state) do
    {:reply, {:error, :disabled}, state}
  end

  def handle_call(:announce, _from, state) do
    {:reply, send_announcement(state), state}
  end

  def handle_call(:listen_port, _from, state) do
    {:reply, state.listen_port, state}
  end

  def handle_call(:mdns_port, _from, state) do
    {:reply, state.mdns_port, state}
  end

  @impl true
  def handle_info(:announce, %{enabled?: true, interval_ms: interval} = state) do
    send_announcement(state)
    schedule(interval)
    {:noreply, state}
  end

  def handle_info({:udp, socket, ip, port, payload}, %{mdns_socket: socket} = state)
      when not is_nil(socket) do
    {:noreply, handle_mdns_payload(ip, port, payload, state)}
  end

  def handle_info({:udp, _socket, ip, port, payload}, state) do
    {:noreply, handle_payload(ip, port, payload, state)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp init_enabled(opts) do
    listen_port = Keyword.get(opts, :listen_port, @default_port)
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)

    with {:ok, socket} <- :gen_udp.open(listen_port, socket_opts()),
         {:ok, {_ip, bound_port}} <- :inet.sockname(socket),
         {:ok, mdns_socket, mdns_port} <- open_mdns_socket(opts),
         {:ok, node_id} <- local_node_id(opts) do
      state = %{
        enabled?: true,
        socket: socket,
        listen_port: bound_port,
        mdns_socket: mdns_socket,
        mdns_port: mdns_port,
        mdns_multicast: Keyword.get(opts, :mdns_multicast, @default_mdns_multicast),
        target_port: target_port(opts, bound_port),
        broadcast_ip: Keyword.get(opts, :broadcast_ip, @default_broadcast),
        interval_ms: interval,
        node_id: node_id,
        transport: Keyword.get(opts, :transport, :tcp),
        address: Keyword.get(opts, :address),
        metadata: Keyword.get(opts, :metadata, %{}),
        router: Keyword.get(opts, :router, MeshxRuntime.Router)
      }

      if Keyword.get(opts, :auto_start?, true), do: schedule(interval)
      {:ok, state}
    end
  end

  defp local_node_id(opts) do
    case Keyword.fetch(opts, :id) do
      {:ok, id} -> {:ok, id}
      :error -> Identity.local_peer_id()
    end
  end

  defp target_port(opts, bound_port) do
    case Keyword.get(opts, :target_port, @default_port) do
      :self -> bound_port
      port -> port
    end
  end

  defp send_announcement(state) do
    payload =
      encode_announcement(
        state.node_id,
        state.transport,
        state.address,
        state.metadata
      )

    result = :gen_udp.send(state.socket, state.broadcast_ip, state.target_port, payload)
    mdns_result = send_mdns_announcement(state)

    Telemetry.execute([:discovery, :announce], %{bytes: byte_size(payload)}, %{
      node_id: state.node_id,
      transport: state.transport,
      result: result,
      mdns_result: mdns_result
    })

    combine_results(result, mdns_result)
  end

  defp handle_payload(ip, port, payload, state) do
    case decode_announcement(payload) do
      {:ok, %{node_id: node_id}} when node_id == state.node_id ->
        state

      {:ok, announcement} ->
        peer =
          Peer.new(announcement.node_id, announcement.transport,
            address: announcement.address || {ip, port},
            metadata: announcement.metadata
          )

        send(state.router, {:meshx_discovery, {:peer_up, peer}})

        Telemetry.execute([:discovery, :peer, :up], %{count: 1}, %{
          peer_id: peer.id,
          transport: peer.transport
        })

        state

      {:error, reason} ->
        Telemetry.execute([:discovery, :decode_error], %{count: 1}, %{reason: reason})
        state
    end
  end

  defp handle_mdns_payload(_ip, _port, payload, state) do
    case MDNS.decode_packet(payload) do
      :query ->
        send_mdns_announcement(state)
        state

      {:announcements, announcements} ->
        Enum.reduce(announcements, state, fn
          %{node_id: node_id}, acc when node_id == acc.node_id ->
            acc

          announcement, acc ->
            peer =
              Peer.new(announcement.node_id, announcement.transport,
                address: announcement.address,
                metadata: announcement.metadata
              )

            send(acc.router, {:meshx_discovery, {:peer_up, peer}})

            Telemetry.execute([:discovery, :peer, :up], %{count: 1}, %{
              peer_id: peer.id,
              transport: peer.transport,
              source: :mdns
            })

            acc
        end)

      :ignore ->
        state

      {:error, reason} ->
        Telemetry.execute([:discovery, :decode_error], %{count: 1}, %{
          reason: reason,
          source: :mdns
        })

        state
    end
  end

  defp decode_announcement(payload) do
    case safe_binary_to_term(payload) do
      {:ok, {@tag, node_id, transport, address, metadata}}
      when is_atom(transport) and is_map(metadata) ->
        {:ok, %{node_id: node_id, transport: transport, address: address, metadata: metadata}}

      {:ok, _other} ->
        {:error, :invalid_announcement}

      error ->
        error
    end
  end

  defp safe_binary_to_term(payload) do
    {:ok, :erlang.binary_to_term(payload, [:safe])}
  rescue
    _error -> {:error, :invalid_payload}
  end

  defp schedule(interval) do
    Process.send_after(self(), :announce, interval)
  end

  defp socket_opts do
    [:binary, active: true, broadcast: true, reuseaddr: true]
  end

  defp open_mdns_socket(opts) do
    if Keyword.get(opts, :mdns?, false) do
      mdns_port = Keyword.get(opts, :mdns_port, @default_mdns_port)

      with {:ok, socket} <- :gen_udp.open(mdns_port, mdns_socket_opts(opts)),
           {:ok, {_ip, bound_port}} <- :inet.sockname(socket) do
        {:ok, socket, bound_port}
      end
    else
      {:ok, nil, nil}
    end
  end

  defp mdns_socket_opts(opts) do
    base = [:binary, active: true, reuseaddr: true, multicast_ttl: 1, multicast_loop: true]

    if Keyword.get(opts, :mdns_join?, true) do
      [
        {:add_membership,
         {Keyword.get(opts, :mdns_multicast, @default_mdns_multicast), {0, 0, 0, 0}}}
        | base
      ]
    else
      base
    end
  end

  defp send_mdns_announcement(%{mdns_socket: nil}), do: :ok

  defp send_mdns_announcement(state) do
    payload =
      MDNS.encode_announcement(state.node_id, state.transport, state.address, state.metadata)

    :gen_udp.send(state.mdns_socket, state.mdns_multicast, @default_mdns_port, payload)
  end

  defp combine_results(:ok, :ok), do: :ok
  defp combine_results(result, mdns_result), do: {:error, %{beacon: result, mdns: mdns_result}}
end
