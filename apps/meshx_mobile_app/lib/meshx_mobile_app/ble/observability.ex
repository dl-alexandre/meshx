defmodule MeshxMobileApp.BLE.Observability do
  @moduledoc """
  Single-point in-process observability for the mobile BLE transport.

  Subscribers (`BleSelfTest`, `Session`, future telemetry exporters)
  call `record/1` with a canonical `MeshxMobileApp.BLE.Events.*` struct
  after they've decoded it from the bridge protocol. The Observability
  GenServer folds each event into a small aggregate model so the rest of
  the system can ask "what is the BLE transport doing right now?" with
  one `snapshot/0` call — without re-reading logcat or holding its own
  parallel state.

  The model is intentionally lossy:

    * `peers` — one row per BLE device id seen, with `first_seen_at_ms`,
      `last_seen_at_ms`, `rssi` (last observed), `beacon_callbacks` (raw
      scan-callback count), `distinct_messages` (dedup by
      `{sender_peer_id_hash, message_id_hash}` or `{sender, message_id}`
      on the full-envelope path — the only honest delivery cardinality
      per the FAILURE_DOMAINS BLE section).
    * `dispatch_outcomes` — counters keyed by the attempt-outcome kind
      string reported by `BleDispatcher`
      (`dispatched`, `failed`, `skipped`, `invalid_attempt`,
      `would_dispatch`). Lets you watch the dispatch path's health
      independently of receive.
    * `error_kinds` — counters keyed by canonical
      `MeshxMobileApp.BLE.Error.kind`. The Kotlin bridge surfaces every
      failure path through these (commit 8e437a9 hardening).
    * `started_at_ms` — when the observer began aggregating.

  Lossy on purpose — this is a *what's happening right now* surface, not
  a stream archive. A subscriber that needs the raw event stream should
  add its own monitor; this is the one-call snapshot for UI, mix tasks,
  and reliability assertions.
  """

  use GenServer

  alias MeshxMobileApp.BLE.Events

  @type peer_state :: %{
          device_id: binary(),
          first_seen_at_ms: integer(),
          last_seen_at_ms: integer(),
          rssi: integer(),
          beacon_callbacks: non_neg_integer(),
          distinct_messages: non_neg_integer()
        }

  @type snapshot :: %{
          started_at_ms: integer(),
          peers: %{binary() => peer_state()},
          dispatch_outcomes: %{binary() => non_neg_integer()},
          error_kinds: %{atom() => non_neg_integer()},
          distinct_message_keys: non_neg_integer(),
          total_events: non_neg_integer()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: name(opts))
  end

  @doc """
  Record one canonical BLE event. Returns `:ok` even when the server
  isn't running — observability is a best-effort instrument, never a
  hard dependency of the bridge.
  """
  @spec record(GenServer.server(), Events.t()) :: :ok
  def record(server \\ __MODULE__, event) do
    case GenServer.whereis(server) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:record, event})
    end
  end

  @spec snapshot(GenServer.server()) :: snapshot()
  def snapshot(server \\ __MODULE__) do
    GenServer.call(server, :snapshot)
  end

  @doc """
  Reset all counters and peer state. Useful between test runs and for
  the in-app "clear stats" affordance.
  """
  @spec reset(GenServer.server()) :: :ok
  def reset(server \\ __MODULE__) do
    GenServer.call(server, :reset)
  end

  # ── server ────────────────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, fresh_state()}
  end

  @impl true
  def handle_cast({:record, event}, state) do
    {:noreply, fold(state, event)}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    snap = %{
      started_at_ms: state.started_at_ms,
      peers: state.peers,
      dispatch_outcomes: state.dispatch_outcomes,
      error_kinds: state.error_kinds,
      distinct_message_keys: MapSet.size(state.seen_messages),
      total_events: state.total_events
    }

    {:reply, snap, state}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, fresh_state()}
  end

  # ── folding ───────────────────────────────────────────────────────────────

  defp fold(state, %Events.DeviceDiscovered{} = e) do
    state
    |> bump_total()
    |> touch_peer(e.device_id, e.rssi, beacon_inc: 0)
  end

  defp fold(state, %Events.AdvertisementReceived{} = e) do
    state
    |> bump_total()
    |> touch_peer(e.device_id, e.rssi, beacon_inc: 0)
  end

  defp fold(state, %Events.ReceivedMessageBeacon{} = e) do
    key = {e.sender_peer_id_hash, e.message_id_hash}

    state
    |> bump_total()
    |> touch_peer(e.received_device_id, e.rssi, beacon_inc: 1)
    |> record_distinct(key, e.received_device_id)
  end

  defp fold(state, %Events.ReceivedMessage{} = e) do
    key = {e.envelope.sender_peer_id, e.message_id}

    state
    |> bump_total()
    |> touch_peer(e.received_device_id, e.rssi, beacon_inc: 1)
    |> record_distinct(key, e.received_device_id)
  end

  defp fold(state, %Events.Error{} = e) do
    # BleDispatcher routes its attempt_outcome JSON through an
    # Error(kind: :unknown) so the v1 wire path stays single-channel.
    # When the detail starts with `{"v":1,"event":"attempt_outcome"`,
    # decode the dispatch kind and increment the dispatch counter
    # rather than the error counter — otherwise dispatches and real
    # errors get conflated.
    case classify_error(e) do
      {:dispatch_outcome, kind} ->
        state
        |> bump_total()
        |> Map.update!(:dispatch_outcomes, &Map.update(&1, kind, 1, fn n -> n + 1 end))

      :error ->
        state
        |> bump_total()
        |> Map.update!(:error_kinds, &Map.update(&1, e.kind, 1, fn n -> n + 1 end))
    end
  end

  defp fold(state, _other), do: bump_total(state)

  defp bump_total(state), do: %{state | total_events: state.total_events + 1}

  defp touch_peer(state, device_id, rssi, beacon_inc: bcount) do
    now = System.monotonic_time(:millisecond)

    peers =
      Map.update(
        state.peers,
        device_id,
        %{
          device_id: device_id,
          first_seen_at_ms: now,
          last_seen_at_ms: now,
          rssi: rssi,
          beacon_callbacks: bcount,
          distinct_messages: 0
        },
        fn p ->
          %{
            p
            | last_seen_at_ms: now,
              rssi: rssi,
              beacon_callbacks: p.beacon_callbacks + bcount
          }
        end
      )

    %{state | peers: peers}
  end

  defp record_distinct(state, key, device_id) do
    if MapSet.member?(state.seen_messages, key) do
      state
    else
      state = %{state | seen_messages: MapSet.put(state.seen_messages, key)}

      peers =
        Map.update(state.peers, device_id, nil, fn
          nil -> nil
          p -> %{p | distinct_messages: p.distinct_messages + 1}
        end)
        |> Map.reject(fn {_k, v} -> is_nil(v) end)

      %{state | peers: peers}
    end
  end

  # BleDispatcher feeds attempt_outcome JSON to the sink as a
  # BleEvent.Error with kind :unknown — see BleDispatcher.kt mapReasonKind.
  defp classify_error(%Events.Error{kind: :unknown, detail: detail}) when is_binary(detail) do
    if String.contains?(detail, ~s("event":"attempt_outcome")) do
      case Regex.run(~r/"kind":"([a-z_]+)"/, detail) do
        [_, kind] -> {:dispatch_outcome, kind}
        _ -> :error
      end
    else
      :error
    end
  end

  defp classify_error(_), do: :error

  defp fresh_state do
    %{
      started_at_ms: System.monotonic_time(:millisecond),
      peers: %{},
      dispatch_outcomes: %{},
      error_kinds: %{},
      seen_messages: MapSet.new(),
      total_events: 0
    }
  end

  defp name(opts), do: Keyword.get(opts, :name, __MODULE__)
end
