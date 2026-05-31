defmodule Mob.Routing.QUIC do
  @moduledoc """
  QUIC transport adapter for MeshX (built on the optional `:quicer` NIF).

  QUIC gives MeshX three things over plain UDP:

    * **Built-in TLS 1.3** — handshake yields keys for application data
      without a separate Noise round-trip (the runtime can still layer Noise
      for end-to-end secrecy across relays).
    * **Stream multiplexing** — frames travel on one bidirectional stream
      per peer; head-of-line blocking is contained to that stream.
    * **Connection migration** — clients that change network paths (4G ↔
      WiFi) keep the same QUIC connection ID, surviving NAT rebinds without
      a fresh handshake.

  The adapter exposes the same surface as `Mob.Routing.TCP`:
  `start_link/1`, `connect/4`, `disconnect/2`, `listen_port/1`,
  `send_frame/4`, `broadcast_frame/3`, `peers/1`. Each peer connection owns
  exactly one bidirectional stream that carries length-prefixed MeshX
  frames; the in-band handshake exchanges peer ids and metadata using the
  same tagged-term scheme as the TCP transport.

  ## Loading

  `:quicer` is an *optional* dependency (and a NIF). To enable it:

      # mix.exs
      defp deps do
        [
          {:quicer, "~> 0.2"}
        ]
      end

  When `:quicer` is unavailable, calling any function on this module returns
  `{:error, :quic_not_available}`.

  ## Certificates

  QUIC mandates TLS. For local testing pass a self-signed cert via
  `:certfile` / `:keyfile`. For production use cert material trusted by
  every peer (or pinned via Noise-style application-layer auth).
  """

  @behaviour Mob.Routing

  use GenServer

  alias Mob.Routing.{Event, Peer}

  @transport :quic
  @hello_tag :mob_quic_hello_v1
  @frame_tag :mob_quic_frame_v1
  @alpn ["mob/1"]
  @default_handshake_timeout_ms 5_000

  @type host :: :inet.ip_address() | charlist() | String.t()

  @spec available?() :: boolean()
  def available?, do: Code.ensure_loaded?(:quicer)

  @spec start_link(keyword()) :: GenServer.on_start() | {:error, :quic_not_available}
  def start_link(opts \\ []) do
    if available?() do
      opts = Keyword.put_new(opts, :event_target, self())
      GenServer.start_link(__MODULE__, opts)
    else
      {:error, :quic_not_available}
    end
  end

  @spec listen_port(pid()) :: :inet.port_number()
  def listen_port(transport), do: GenServer.call(transport, :listen_port)

  @spec connect(pid(), host(), :inet.port_number(), keyword()) :: :ok | {:error, term()}
  def connect(transport, host, port, opts \\ []) do
    GenServer.call(
      transport,
      {:connect, host, port, opts},
      Keyword.get(opts, :call_timeout_ms, 15_000)
    )
  end

  @spec disconnect(pid(), term()) :: :ok | {:error, :peer_not_found}
  def disconnect(transport, peer_id), do: GenServer.call(transport, {:disconnect, peer_id})

  @impl Mob.Routing
  def send_frame(transport, peer_id, frame, opts \\ []) do
    GenServer.call(transport, {:send_frame, peer_id, frame, opts})
  end

  @impl Mob.Routing
  def broadcast_frame(transport, frame, opts \\ []) do
    GenServer.call(transport, {:broadcast_frame, frame, opts})
  end

  @impl Mob.Routing
  def peers(transport), do: GenServer.call(transport, :peers)

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    metadata = Keyword.get(opts, :metadata, %{})
    event_target = Keyword.fetch!(opts, :event_target)
    certfile = Keyword.get(opts, :certfile)
    keyfile = Keyword.get(opts, :keyfile)
    listen_port = Keyword.get(opts, :listen_port, 0)

    listen_opts = [
      cert: certfile,
      key: keyfile,
      alpn: @alpn,
      verify: :none,
      idle_timeout_ms: Keyword.get(opts, :idle_timeout_ms, 30_000),
      peer_bidi_stream_count: 8
    ]

    state = %{
      id: id,
      metadata: metadata,
      event_target: event_target,
      certfile: certfile,
      keyfile: keyfile,
      listener: nil,
      listen_port: nil,
      acceptor: nil,
      # peer_id => %{conn: handle, stream: handle, peer: %Peer{}}
      peers: %{},
      streams: %{}
    }

    case open_listener(listen_port, listen_opts, state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, {:quic_listen_failed, reason}}
    end
  end

  @impl true
  def handle_call(:listen_port, _from, state), do: {:reply, state.listen_port, state}

  # Internal hello-fetch used by the acceptor loop.
  def handle_call(:__local_hello, _from, state) do
    {:reply, {:ok, %{id: state.id, metadata: state.metadata}}, state}
  end

  def handle_call({:connect, host, port, opts}, _from, state) do
    timeout = Keyword.get(opts, :handshake_timeout_ms, @default_handshake_timeout_ms)

    conn_opts = [
      alpn: @alpn,
      verify: :none,
      idle_timeout_ms: 30_000,
      peer_bidi_stream_count: 8
    ]

    case quicer_connect(normalize_host(host), port, conn_opts, timeout) do
      {:ok, conn} ->
        case start_stream_and_handshake(conn, state) do
          {:ok, peer_id, peer_metadata, stream} ->
            {:reply, :ok, add_peer(peer_id, peer_metadata, conn, stream, state)}

          {:error, reason} ->
            quicer_close(conn)
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:disconnect, peer_id}, _from, state) do
    case Map.get(state.peers, peer_id) do
      nil ->
        {:reply, {:error, :peer_not_found}, state}

      %{conn: conn, stream: stream} ->
        _ = quicer_close_stream(stream)
        _ = quicer_close(conn)
        {:reply, :ok, drop_peer(peer_id, state)}
    end
  end

  def handle_call({:send_frame, peer_id, frame, _opts}, _from, state) do
    case Map.get(state.peers, peer_id) do
      nil -> {:reply, {:error, :peer_not_found}, state}
      %{stream: stream} -> {:reply, quicer_send(stream, encode_frame(frame)), state}
    end
  end

  def handle_call({:broadcast_frame, frame, _opts}, _from, state) do
    payload = encode_frame(frame)

    results =
      state.peers
      |> Map.values()
      |> Enum.map(fn %{stream: stream} -> quicer_send(stream, payload) end)

    result = if Enum.all?(results, &(&1 == :ok)), do: :ok, else: {:error, results}
    {:reply, result, state}
  end

  def handle_call(:peers, _from, state) do
    {:reply, state.peers |> Map.values() |> Enum.map(& &1.peer), state}
  end

  @impl true
  def handle_cast({:accepted, peer_id, peer_metadata, conn, stream}, state) do
    {:noreply, add_peer(peer_id, peer_metadata, conn, stream, state)}
  end

  @impl true
  def handle_info({:quic, :data, stream, data}, state) do
    {:noreply, handle_stream_data(stream, data, state)}
  end

  def handle_info({:quic, :stream_closed, stream, _flags}, state) do
    {:noreply, drop_stream(stream, state)}
  end

  def handle_info({:quic, :closed, conn, _flags}, state) do
    {:noreply, drop_conn(conn, state)}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if state.listener, do: quicer_close_listener(state.listener)
    Enum.each(state.peers, fn {_id, %{conn: conn}} -> quicer_close(conn) end)
    :ok
  end

  # ---- listener / acceptor ----

  defp open_listener(port, opts, state) do
    case quicer_listen(port, opts) do
      {:ok, listener} ->
        {:ok, bound_port} = quicer_listen_port(listener)
        acceptor = spawn_link(fn -> accept_loop(listener, self()) end)
        {:ok, %{state | listener: listener, listen_port: bound_port, acceptor: acceptor}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp accept_loop(listener, server) do
    case quicer_accept(listener, []) do
      {:ok, conn} ->
        case quicer_handshake(conn, @default_handshake_timeout_ms) do
          {:ok, _} ->
            handle_inbound_conn(conn, server)
            accept_loop(listener, server)

          {:error, _} ->
            quicer_close(conn)
            accept_loop(listener, server)
        end

      {:error, :listener_closed} ->
        :ok

      {:error, _} ->
        accept_loop(listener, server)
    end
  end

  defp handle_inbound_conn(conn, server) do
    with {:ok, stream} <- quicer_accept_stream(conn, @default_handshake_timeout_ms),
         {:ok, peer_id, peer_metadata} <- recv_hello(stream),
         {:ok, %{id: local_id, metadata: local_meta}} <- GenServer.call(server, :__local_hello),
         :ok <- quicer_send(stream, encode_hello(local_id, local_meta)) do
      GenServer.cast(server, {:accepted, peer_id, peer_metadata, conn, stream})
    else
      _ -> quicer_close(conn)
    end
  end

  # ---- helpers ----

  defp start_stream_and_handshake(conn, state) do
    with {:ok, stream} <- quicer_start_stream(conn, []),
         :ok <- quicer_send(stream, encode_hello(state.id, state.metadata)),
         {:ok, peer_id, peer_metadata} <- recv_hello(stream) do
      {:ok, peer_id, peer_metadata, stream}
    end
  end

  defp recv_hello(stream) do
    case quicer_recv(stream, @default_handshake_timeout_ms) do
      {:ok, payload} ->
        case safe_term(payload) do
          {:ok, {@hello_tag, id, metadata}} when is_map(metadata) -> {:ok, id, metadata}
          _ -> {:error, :invalid_hello}
        end

      error ->
        error
    end
  end

  defp add_peer(peer_id, peer_metadata, conn, stream, state) do
    peer = Peer.new(peer_id, @transport, address: peer_id, metadata: peer_metadata)
    send(state.event_target, Event.peer_up(@transport, peer))

    %{
      state
      | peers: Map.put(state.peers, peer_id, %{conn: conn, stream: stream, peer: peer}),
        streams: Map.put(state.streams, stream, peer_id)
    }
  end

  defp drop_peer(peer_id, state) do
    case Map.pop(state.peers, peer_id) do
      {nil, _} ->
        state

      {%{stream: stream}, rest} ->
        send(state.event_target, Event.peer_down(@transport, peer_id))
        %{state | peers: rest, streams: Map.delete(state.streams, stream)}
    end
  end

  defp drop_stream(stream, state) do
    case Map.get(state.streams, stream) do
      nil -> state
      peer_id -> drop_peer(peer_id, state)
    end
  end

  defp drop_conn(conn, state) do
    state.peers
    |> Enum.filter(fn {_id, %{conn: c}} -> c == conn end)
    |> Enum.reduce(state, fn {id, _}, acc -> drop_peer(id, acc) end)
  end

  defp handle_stream_data(stream, data, state) do
    case Map.get(state.streams, stream) do
      nil ->
        state

      peer_id ->
        case decode_frame(data) do
          {:ok, frame} ->
            send(state.event_target, Event.frame(@transport, peer_id, frame))
            state

          :error ->
            drop_peer(peer_id, state)
        end
    end
  end

  defp encode_hello(id, metadata), do: :erlang.term_to_binary({@hello_tag, id, metadata})
  defp encode_frame(frame) when is_binary(frame), do: :erlang.term_to_binary({@frame_tag, frame})

  defp decode_frame(data) do
    case safe_term(data) do
      {:ok, {@frame_tag, frame}} when is_binary(frame) -> {:ok, frame}
      _ -> :error
    end
  end

  defp safe_term(bin) do
    {:ok, :erlang.binary_to_term(bin, [:safe])}
  rescue
    _ -> :error
  end

  defp normalize_host(host) when is_binary(host), do: String.to_charlist(host)
  defp normalize_host(host), do: host

  # ---- :quicer indirection so the module compiles even when the NIF is absent ----

  defp quicer_listen(port, opts), do: apply_quicer(:listen, [port, opts])
  defp quicer_listen_port(listener), do: apply_quicer(:listen_port, [listener])
  defp quicer_accept(listener, opts), do: apply_quicer(:accept, [listener, opts])
  defp quicer_handshake(conn, timeout), do: apply_quicer(:handshake, [conn, timeout])
  defp quicer_accept_stream(conn, timeout), do: apply_quicer(:accept_stream, [conn, timeout])

  defp quicer_connect(host, port, opts, timeout),
    do: apply_quicer(:connect, [host, port, opts, timeout])

  defp quicer_start_stream(conn, opts), do: apply_quicer(:start_stream, [conn, opts])
  defp quicer_send(stream, data), do: apply_quicer(:send, [stream, data])
  defp quicer_recv(stream, timeout), do: apply_quicer(:recv, [stream, timeout])
  defp quicer_close(conn), do: apply_quicer(:close_connection, [conn])
  defp quicer_close_stream(stream), do: apply_quicer(:close_stream, [stream])
  defp quicer_close_listener(listener), do: apply_quicer(:close_listener, [listener])

  defp apply_quicer(fun, args) do
    if available?() do
      apply(:quicer, fun, args)
    else
      {:error, :quic_not_available}
    end
  end
end
