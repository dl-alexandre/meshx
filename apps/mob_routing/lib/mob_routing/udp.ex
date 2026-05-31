defmodule Mob.Routing.UDP do
  @moduledoc """
  UDP transport adapter for MeshX.

  Connectionless cousin of `Mob.Routing.TCP`. Each datagram is a tagged
  Erlang term, so frames and "hello" exchanges share one socket. NAT
  friendliness comes from periodic keepalives that keep the upstream NAT's
  port mapping warm; a peer that goes silent for `:peer_idle_timeout_ms` is
  reported as down.

  Wire forms:

      {:mob_udp_hello_v1, peer_id, metadata}
      {:mob_udp_keepalive_v1, peer_id}
      {:mob_udp_frame_v1, peer_id, frame}

  Datagram payload is capped at `:max_datagram_bytes` (default 1200 to stay
  under typical Internet MTU). Larger frames must be fragmented at the
  protocol layer first (`Mob.Runtime.Router` already does this when an MTU
  is advertised in peer capabilities).
  """

  @behaviour Mob.Routing

  use GenServer

  alias Mob.Routing.{Event, Peer}

  @transport :udp
  @hello_tag :mob_udp_hello_v1
  @keepalive_tag :mob_udp_keepalive_v1
  @frame_tag :mob_udp_frame_v1

  @default_keepalive_ms 15_000
  @default_idle_timeout_ms 60_000
  @default_max_datagram 1_200
  @default_hello_attempts 5

  @type host :: :inet.ip_address() | charlist() | String.t()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :event_target, self())
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Returns the bound UDP port."
  @spec listen_port(pid()) :: :inet.port_number()
  def listen_port(transport), do: GenServer.call(transport, :listen_port)

  @doc """
  Initiates a hello exchange with a remote UDP endpoint. Returns once the
  remote peer acknowledges with its own hello, or `{:error, :timeout}`.
  """
  @spec connect(pid(), host(), :inet.port_number(), keyword()) :: :ok | {:error, term()}
  def connect(transport, host, port, opts \\ []) do
    timeout = Keyword.get(opts, :call_timeout_ms, 10_000)
    GenServer.call(transport, {:connect, host, port, opts}, timeout)
  end

  @doc "Removes the peer locally and stops sending it traffic."
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
    listen_ip = Keyword.get(opts, :listen_ip, {127, 0, 0, 1})
    listen_port = Keyword.get(opts, :listen_port, 0)
    keepalive_ms = Keyword.get(opts, :keepalive_ms, @default_keepalive_ms)
    idle_timeout_ms = Keyword.get(opts, :peer_idle_timeout_ms, @default_idle_timeout_ms)
    max_datagram = Keyword.get(opts, :max_datagram_bytes, @default_max_datagram)

    case :gen_udp.open(listen_port, [:binary, ip: listen_ip, active: true]) do
      {:ok, socket} ->
        {:ok, port} = :inet.port(socket)
        schedule_keepalive(keepalive_ms)
        schedule_reaper(idle_timeout_ms)

        {:ok,
         %{
           id: id,
           metadata: metadata,
           event_target: event_target,
           socket: socket,
           listen_port: port,
           keepalive_ms: keepalive_ms,
           idle_timeout_ms: idle_timeout_ms,
           max_datagram: max_datagram,
           # peer_id => %{addr: {ip, port}, peer: %Peer{}, last_seen_ms: ms}
           peers: %{},
           # {ip, port} => peer_id (reverse lookup for inbound datagrams)
           addrs: %{}
         }}

      {:error, reason} ->
        {:stop, {:udp_open_failed, reason}}
    end
  end

  @impl true
  def handle_call(:listen_port, _from, state), do: {:reply, state.listen_port, state}

  def handle_call({:connect, host, port, opts}, from, state) do
    addr = {normalize_host(host), port}
    attempts = Keyword.get(opts, :hello_attempts, @default_hello_attempts)
    interval = Keyword.get(opts, :hello_interval_ms, 200)

    # Fire first hello immediately, then schedule retries until the peer
    # answers (or attempts run out). We reply asynchronously from the inbound
    # handler in `peer_added/4`.
    :ok = send_hello(state.socket, addr, state.id, state.metadata)

    timer =
      if attempts > 1 do
        Process.send_after(self(), {:retry_connect, addr, attempts - 1, interval, from}, interval)
      else
        Process.send_after(self(), {:connect_timeout, addr, from}, interval * attempts)
      end

    pending = Map.put(Map.get(state, :pending, %{}), addr, %{from: from, timer: timer})
    {:noreply, Map.put(state, :pending, pending)}
  end

  def handle_call({:disconnect, peer_id}, _from, state) do
    case Map.get(state.peers, peer_id) do
      nil -> {:reply, {:error, :peer_not_found}, state}
      _ -> {:reply, :ok, drop_peer(peer_id, state)}
    end
  end

  def handle_call({:send_frame, peer_id, frame, _opts}, _from, state) do
    {:reply, do_send_frame(peer_id, frame, state), state}
  end

  def handle_call({:broadcast_frame, frame, _opts}, _from, state) do
    results =
      state.peers
      |> Map.keys()
      |> Enum.map(&do_send_frame(&1, frame, state))

    result = if Enum.all?(results, &(&1 == :ok)), do: :ok, else: {:error, results}
    {:reply, result, state}
  end

  def handle_call(:peers, _from, state) do
    {:reply, state.peers |> Map.values() |> Enum.map(& &1.peer), state}
  end

  @impl true
  def handle_info({:udp, socket, ip, port, datagram}, %{socket: socket} = state) do
    {:noreply, handle_datagram({ip, port}, datagram, state)}
  end

  def handle_info({:retry_connect, addr, remaining, interval, from}, state) do
    if Map.has_key?(state.addrs, addr) do
      # Peer already came up; nothing to do.
      {:noreply, clear_pending(addr, state)}
    else
      :ok = send_hello(state.socket, addr, state.id, state.metadata)

      if remaining > 1 do
        timer =
          Process.send_after(
            self(),
            {:retry_connect, addr, remaining - 1, interval, from},
            interval
          )

        {:noreply, update_pending(addr, %{from: from, timer: timer}, state)}
      else
        timer = Process.send_after(self(), {:connect_timeout, addr, from}, interval)
        {:noreply, update_pending(addr, %{from: from, timer: timer}, state)}
      end
    end
  end

  def handle_info({:connect_timeout, addr, from}, state) do
    if Map.has_key?(state.addrs, addr) do
      {:noreply, clear_pending(addr, state)}
    else
      GenServer.reply(from, {:error, :timeout})
      {:noreply, clear_pending(addr, state)}
    end
  end

  def handle_info(:keepalive_tick, state) do
    Enum.each(state.peers, fn {_id, %{addr: addr}} ->
      send_keepalive(state.socket, addr, state.id)
    end)

    schedule_keepalive(state.keepalive_ms)
    {:noreply, state}
  end

  def handle_info(:reaper_tick, state) do
    now = System.monotonic_time(:millisecond)

    state =
      state.peers
      |> Enum.filter(fn {_id, %{last_seen_ms: ts}} -> now - ts > state.idle_timeout_ms end)
      |> Enum.reduce(state, fn {id, _}, acc -> drop_peer(id, acc) end)

    schedule_reaper(state.idle_timeout_ms)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if state[:socket], do: :gen_udp.close(state.socket)
    :ok
  end

  # --- Internal ---

  defp do_send_frame(peer_id, frame, state) do
    with %{addr: addr} <- Map.get(state.peers, peer_id),
         payload = encode_frame(state.id, frame),
         true <- byte_size(payload) <= state.max_datagram,
         :ok <- :gen_udp.send(state.socket, elem(addr, 0), elem(addr, 1), payload) do
      :ok
    else
      nil -> {:error, :peer_not_found}
      false -> {:error, :datagram_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_datagram(addr, datagram, state) do
    case decode_datagram(datagram) do
      {:hello, peer_id, metadata} ->
        was_new? = not Map.has_key?(state.peers, peer_id)
        state = ensure_peer(peer_id, addr, metadata, state)
        # Reply with our own hello ONLY for the first hello from this peer,
        # otherwise both sides loop forever and idle-reaping never triggers.
        if was_new?, do: send_hello(state.socket, addr, state.id, state.metadata)
        state

      {:keepalive, peer_id} ->
        touch_peer(peer_id, addr, state)

      {:frame, _origin_id, frame} ->
        case Map.get(state.addrs, addr) do
          nil ->
            # Frame from someone we haven't shaken hands with — drop.
            state

          peer_id ->
            send(state.event_target, Event.frame(@transport, peer_id, frame))
            touch_peer(peer_id, addr, state)
        end

      :unknown ->
        state
    end
  end

  defp ensure_peer(peer_id, addr, metadata, state) do
    case Map.get(state.peers, peer_id) do
      nil ->
        peer = Peer.new(peer_id, @transport, address: addr, metadata: metadata)
        send(state.event_target, Event.peer_up(@transport, peer))

        state =
          state
          |> Map.update!(
            :peers,
            &Map.put(&1, peer_id, %{
              addr: addr,
              peer: peer,
              last_seen_ms: System.monotonic_time(:millisecond)
            })
          )
          |> Map.update!(:addrs, &Map.put(&1, addr, peer_id))

        clear_pending(addr, state)

      %{addr: ^addr} = entry ->
        %{
          state
          | peers:
              Map.put(state.peers, peer_id, %{
                entry
                | last_seen_ms: System.monotonic_time(:millisecond)
              })
        }

      %{addr: old_addr} = entry ->
        # Peer's address changed (NAT rebind); update the reverse lookup.
        new_entry = %{entry | addr: addr, last_seen_ms: System.monotonic_time(:millisecond)}

        %{
          state
          | peers: Map.put(state.peers, peer_id, new_entry),
            addrs: state.addrs |> Map.delete(old_addr) |> Map.put(addr, peer_id)
        }
    end
  end

  defp touch_peer(peer_id, addr, state) do
    case Map.get(state.peers, peer_id) do
      nil ->
        state

      %{addr: old_addr} = entry ->
        entry = %{entry | addr: addr, last_seen_ms: System.monotonic_time(:millisecond)}
        addrs = state.addrs |> Map.delete(old_addr) |> Map.put(addr, peer_id)
        %{state | peers: Map.put(state.peers, peer_id, entry), addrs: addrs}
    end
  end

  defp drop_peer(peer_id, state) do
    case Map.pop(state.peers, peer_id) do
      {nil, _} ->
        state

      {%{addr: addr}, peers} ->
        send(state.event_target, Event.peer_down(@transport, peer_id))
        %{state | peers: peers, addrs: Map.delete(state.addrs, addr)}
    end
  end

  defp clear_pending(addr, state) do
    pending = Map.get(state, :pending, %{})

    case Map.pop(pending, addr) do
      {nil, _} ->
        state

      {%{from: from, timer: timer}, rest} ->
        Process.cancel_timer(timer)
        # If the connect call is still waiting, reply success now.
        try do
          GenServer.reply(from, :ok)
        catch
          _, _ -> :ok
        end

        Map.put(state, :pending, rest)
    end
  end

  defp update_pending(addr, entry, state) do
    pending = Map.get(state, :pending, %{}) |> Map.put(addr, entry)
    Map.put(state, :pending, pending)
  end

  defp send_hello(socket, {ip, port}, id, metadata) do
    :gen_udp.send(socket, ip, port, :erlang.term_to_binary({@hello_tag, id, metadata}))
  end

  defp send_keepalive(socket, {ip, port}, id) do
    :gen_udp.send(socket, ip, port, :erlang.term_to_binary({@keepalive_tag, id}))
  end

  defp encode_frame(local_id, frame) when is_binary(frame) do
    :erlang.term_to_binary({@frame_tag, local_id, frame})
  end

  defp decode_datagram(datagram) do
    {:ok, term} = safe_term(datagram)

    case term do
      {@hello_tag, id, metadata} when is_map(metadata) -> {:hello, id, metadata}
      {@keepalive_tag, id} -> {:keepalive, id}
      {@frame_tag, id, frame} when is_binary(frame) -> {:frame, id, frame}
      _ -> :unknown
    end
  rescue
    _ -> :unknown
  end

  defp safe_term(bin) do
    {:ok, :erlang.binary_to_term(bin, [:safe])}
  rescue
    _ -> {:ok, :unknown}
  end

  defp normalize_host(host) when is_binary(host),
    do: host |> String.to_charlist() |> normalize_host()

  defp normalize_host(host) when is_list(host) do
    case :inet.parse_address(host) do
      {:ok, addr} -> addr
      _ -> host
    end
  end

  defp normalize_host(host), do: host

  defp schedule_keepalive(ms), do: Process.send_after(self(), :keepalive_tick, ms)
  defp schedule_reaper(ms), do: Process.send_after(self(), :reaper_tick, max(div(ms, 2), 1_000))
end
