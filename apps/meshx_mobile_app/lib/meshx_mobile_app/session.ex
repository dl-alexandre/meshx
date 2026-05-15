defmodule MeshxMobileApp.Session do
  @moduledoc """
  Mob-facing MeshX mobile session state.

  Owns the UI-visible state and delegates platform BLE work to a
  `MeshxMobileApp.BLE.Adapter` implementation. Consumes only canonical
  events from `MeshxMobileApp.BLE.Events.*` — never raw NIF tuples or
  platform-specific shapes.
  """

  use GenServer

  alias MeshxMobileApp.BLE.Adapter
  alias MeshxMobileApp.BLE.Events
  alias MeshxMobileApp.BLE.LocalInbox
  alias MeshxMobileApp.BLE.LocalInboxStore
  alias MeshxMobileApp.BLE.PeerTable

  @max_events 50

  @type mode :: :scan | :advertise

  @type event :: %{
          at: DateTime.t(),
          title: String.t(),
          detail: String.t()
        }

  @type snapshot :: %{
          mode: mode(),
          status: String.t(),
          peer_id: String.t() | nil,
          local_inbox: map(),
          local_inbox_persistence: map(),
          restored_local_inbox: map() | nil,
          events: [event()]
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server, pid \\ self()) do
    GenServer.call(server, {:subscribe, pid})
  end

  @spec snapshot(GenServer.server()) :: snapshot()
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @spec set_mode(GenServer.server(), mode()) :: snapshot()
  def set_mode(server, mode), do: GenServer.call(server, {:set_mode, mode})

  @spec start(GenServer.server()) :: snapshot()
  def start(server), do: GenServer.call(server, :start)

  @spec stop(GenServer.server()) :: snapshot()
  def stop(server), do: GenServer.call(server, :stop)

  @spec send_ping(GenServer.server()) :: snapshot()
  def send_ping(server), do: GenServer.call(server, :send_ping)

  @impl true
  def init(opts) do
    bridge = Keyword.get(opts, :bridge, Adapter.configured())

    persistence = persistence_config(opts)
    {restored_local_inbox, persistence} = maybe_restore_local_inbox(persistence)

    state = %{
      bridge: bridge,
      mode: :scan,
      status: "Waiting for Bluetooth",
      peer_id: nil,
      subscribers: MapSet.new(),
      events: [event("Mob app ready", "MeshX is running inside the device BEAM.")],
      peers: PeerTable.new(),
      local_inbox: LocalInbox.new(),
      local_inbox_persistence: persistence,
      restored_local_inbox: restored_local_inbox
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_call(:snapshot, _from, state), do: {:reply, to_snapshot(state), state}

  def handle_call({:set_mode, mode}, _from, state) when mode in [:scan, :advertise] do
    state =
      state
      |> Map.put(:mode, mode)
      |> Map.put(:peer_id, nil)
      |> record("Mode changed", Atom.to_string(mode))

    broadcast(state)
    {:reply, to_snapshot(state), state}
  end

  def handle_call(:start, _from, %{mode: :scan, bridge: bridge} = state) do
    state = %{state | status: "Scanning", peer_id: nil}
    result = bridge.start_scan(self())
    state = record_result(state, "Scan started", "Looking for MeshX BLE peers.", result)
    broadcast(state)
    {:reply, to_snapshot(state), state}
  end

  def handle_call(:start, _from, %{mode: :advertise, bridge: bridge} = state) do
    state = %{state | status: "Advertising", peer_id: nil}
    result = bridge.start_advertising(self(), "meshx-mob")
    state = record_result(state, "Advertising started", "Waiting for a MeshX central.", result)
    broadcast(state)
    {:reply, to_snapshot(state), state}
  end

  def handle_call(:stop, _from, %{bridge: bridge} = state) do
    result = bridge.stop(self())

    state =
      state
      |> Map.put(:status, "Stopped")
      |> record_result("Stopped", "BLE activity paused.", result)
      |> maybe_persist_local_inbox()

    broadcast(state)
    {:reply, to_snapshot(state), state}
  end

  def handle_call(:send_ping, _from, %{peer_id: nil} = state) do
    state = record(state, "Send skipped", "No secure peer is connected.")
    broadcast(state)
    {:reply, to_snapshot(state), state}
  end

  def handle_call(:send_ping, _from, %{bridge: bridge, peer_id: peer_id} = state) do
    result = bridge.send_to_peer(self(), peer_id, "mob-harness-ping")
    state = record_result(state, "Ping sent", peer_id, result)
    broadcast(state)
    {:reply, to_snapshot(state), state}
  end

  # ── Canonical BLE events ────────────────────────────────────────────────────
  #
  # Every event handler folds the event into the passive peer table
  # first via `track/2`. The table is derived state — replaying the
  # same event stream from scratch produces the same table.

  @impl true
  def handle_info({Adapter, :event, %Events.ConnectionStateChanged{state: :connected} = e}, s) do
    s =
      s
      |> track(e)
      |> Map.put(:status, "Device connected")
      |> Map.put(:peer_id, e.device_id)
      |> record("Connected", e.device_id)

    broadcast(s)
    {:noreply, s}
  end

  def handle_info(
        {Adapter, :event, %Events.ConnectionStateChanged{state: :disconnected} = e},
        s
      ) do
    s =
      s
      |> track(e)
      |> Map.merge(%{status: "Disconnected", peer_id: nil})
      |> record("Disconnected", e.device_id)

    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.ConnectionStateChanged{} = e}, s) do
    s = s |> track(e) |> record("Connection state", "#{e.device_id}: #{e.state}")
    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.PeerAuthenticated{} = e}, s) do
    s =
      s
      |> track(e)
      |> Map.put(:status, "Secure peer connected")
      |> Map.put(:peer_id, e.peer_id)
      |> record("Peer authenticated", e.peer_id)

    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.MessageReceived{} = e}, s) do
    detail = "#{e.peer_id}: #{byte_size(e.payload)} bytes"
    s = s |> track(e) |> record("Frame received", detail)
    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.ReceivedMessage{} = e}, s) do
    detail =
      "#{e.sender_peer_id} -> #{e.recipient_peer_id || "broadcast"}: " <>
        "#{byte_size(e.envelope.payload)} bytes"

    s =
      s
      |> track(e)
      |> inbox(e)
      |> maybe_persist_local_inbox()
      |> record("Message received", detail)

    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.ReceivedMessageBeacon{} = e}, s) do
    detail =
      "ref #{Base.encode16(e.message_id_hash, case: :lower)} " <>
        "from #{Base.encode16(e.sender_peer_id_hash, case: :lower)}"

    s =
      s
      |> track(e)
      |> inbox(e)
      |> maybe_persist_local_inbox()
      |> record("Message beacon", detail)

    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.DeviceDiscovered{} = e}, s) do
    s = s |> track(e) |> record("Device discovered", "#{e.device_id} (rssi #{e.rssi})")
    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.DeviceLost{} = e}, s) do
    s = s |> track(e) |> record("Device lost", e.device_id)
    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.AdvertisementReceived{} = e}, s) do
    s = s |> track(e) |> record("Advertisement", "#{e.device_id} (rssi #{e.rssi})")
    broadcast(s)
    {:noreply, s}
  end

  def handle_info({Adapter, :event, %Events.Error{} = e}, s) do
    s = s |> track(e) |> record("Bridge error", "#{e.kind}: #{e.detail}")
    broadcast(s)
    {:noreply, s}
  end

  def handle_info({MeshxMobileApp.NativeBridge, :bridge_event, event}, s) do
    handle_info(Adapter.event_message(event), s)
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, s) do
    {:noreply, %{s | subscribers: MapSet.delete(s.subscribers, pid)}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp record_result(state, title, detail, :ok), do: record(state, title, detail)

  defp record_result(state, _title, _detail, {:error, reason}) do
    record(state, "Bridge error", inspect(reason))
  end

  defp record(state, title, detail) do
    events = [event(title, detail) | state.events] |> Enum.take(@max_events)
    %{state | events: events}
  end

  defp event(title, detail) do
    %{at: DateTime.utc_now(), title: title, detail: detail}
  end

  defp to_snapshot(state) do
    state
    |> Map.take([:mode, :status, :peer_id, :events, :peers])
    |> Map.put(:local_inbox, LocalInbox.snapshot(state.local_inbox))
    |> Map.put(:local_inbox_persistence, persistence_snapshot(state.local_inbox_persistence))
    |> Map.put(:restored_local_inbox, state.restored_local_inbox)
  end

  defp track(state, event) do
    # Forks every canonical BLE event to the in-process observability
    # surface so `MeshxMobileApp.BLE.Observability.snapshot/0` reflects
    # production session traffic, not just the self-test probe. The call
    # is best-effort — `record/2` returns `:ok` when the Observability
    # server isn't running, so it never blocks the session pipeline.
    MeshxMobileApp.BLE.Observability.record(event)
    %{state | peers: PeerTable.update(state.peers, event)}
  end

  defp inbox(state, event) do
    %{state | local_inbox: LocalInbox.ingest(state.local_inbox, event)}
  end

  defp persistence_config(opts) do
    %{
      enabled?: Keyword.get(opts, :persist_local_inbox?, false),
      restore?: Keyword.get(opts, :restore_local_inbox?, false),
      snapshot_id: Keyword.get(opts, :local_inbox_snapshot_id, :default),
      persisted_at_fun:
        Keyword.get(opts, :persisted_at_fun, fn -> System.system_time(:millisecond) end),
      last_saved_at: nil,
      last_error: nil,
      restored?: false,
      restore_error: nil
    }
  end

  defp maybe_restore_local_inbox(%{restore?: true, snapshot_id: snapshot_id} = persistence) do
    case LocalInboxStore.load_read_model(snapshot_id) do
      {:ok, read_model} ->
        {read_model, %{persistence | restored?: true, restore_error: nil}}

      {:error, reason} ->
        {nil, %{persistence | restored?: false, restore_error: reason}}
    end
  end

  defp maybe_restore_local_inbox(persistence), do: {nil, persistence}

  defp maybe_persist_local_inbox(
         %{local_inbox_persistence: %{enabled?: true} = persistence} = state
       ) do
    persisted_at = persistence.persisted_at_fun.()
    snapshot = LocalInbox.snapshot(state.local_inbox)

    case LocalInboxStore.save(snapshot,
           snapshot_id: persistence.snapshot_id,
           persisted_at: persisted_at
         ) do
      {:ok, durable} ->
        %{
          state
          | local_inbox_persistence: %{
              persistence
              | last_saved_at: durable.persisted_at,
                last_error: nil
            }
        }

      {:error, reason} ->
        %{state | local_inbox_persistence: %{persistence | last_error: reason}}
    end
  end

  defp maybe_persist_local_inbox(state), do: state

  defp persistence_snapshot(persistence) do
    persistence
    |> Map.take([
      :enabled?,
      :restore?,
      :snapshot_id,
      :last_saved_at,
      :last_error,
      :restored?,
      :restore_error
    ])
  end

  defp broadcast(state) do
    snapshot = to_snapshot(state)
    Enum.each(state.subscribers, &send(&1, {__MODULE__, :updated, snapshot}))
  end
end
