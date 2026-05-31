defmodule Mob.Node.BLE.Observability do
  @moduledoc """
  Single-point in-process observability for the mobile BLE transport.

  Subscribers (`BleSelfTest`, `Session`, future telemetry exporters)
  call `record/1` with a canonical `Mob.Node.BLE.Events.*` struct
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
      `Mob.Node.BLE.Error.kind`. The Kotlin bridge surfaces every
      failure path through these (commit 8e437a9 hardening).
    * `started_at_ms` — when the observer began aggregating.

  Lossy on purpose — this is a *what's happening right now* surface, not
  a stream archive. A subscriber that needs the raw event stream should
  add its own monitor; this is the one-call snapshot for UI, mix tasks,
  and reliability assertions.
  """

  use GenServer

  require Logger

  alias Mob.Node.BLE.Events

  @default_timeline_limit 500
  @log_marker "MobAppEvent: "

  @type peer_state :: %{
          device_id: binary(),
          first_seen_at_ms: integer(),
          last_seen_at_ms: integer(),
          rssi: integer(),
          beacon_callbacks: non_neg_integer(),
          distinct_messages: non_neg_integer()
        }

  @type timeline_entry :: %{
          schema: binary(),
          run_id: binary(),
          at_unix_ms: integer(),
          at_monotonic_ms: integer(),
          source: atom(),
          phase: atom(),
          event: atom(),
          metadata: map()
        }

  @type snapshot :: %{
          run_id: binary(),
          started_at_ms: integer(),
          last_event_at_ms: integer() | nil,
          peers: %{binary() => peer_state()},
          dispatch_outcomes: %{binary() => non_neg_integer()},
          error_kinds: %{atom() => non_neg_integer()},
          distinct_message_keys: non_neg_integer(),
          total_events: non_neg_integer(),
          phase_counts: %{atom() => non_neg_integer()},
          timeline: [timeline_entry()]
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

  @doc """
  Record an app-level reliability probe.

  Probes are structured timeline entries that are not canonical BLE
  bridge events: app startup, scan/advertise requests, store writes,
  self-test heartbeats, and UI-visible state transitions. They are the
  RT-01 debug breadcrumbs that separate "radio never woke" from
  "MeshX routed it but persistence/UI did not update".
  """
  @spec probe(atom(), atom()) :: :ok
  @spec probe(atom(), atom(), map()) :: :ok
  def probe(phase, event, metadata \\ %{}) when is_atom(phase) and is_atom(event) do
    probe(__MODULE__, phase, event, metadata)
  end

  @spec probe(GenServer.server(), atom(), atom(), map()) :: :ok
  def probe(server, phase, event, metadata)
      when is_atom(phase) and is_atom(event) and is_map(metadata) do
    case GenServer.whereis(server) do
      nil -> :ok
      pid -> GenServer.cast(pid, {:probe, phase, event, metadata})
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
  def init(opts) do
    {:ok, fresh_state(opts)}
  end

  @impl true
  def handle_cast({:record, event}, state) do
    {:noreply, fold(state, event)}
  end

  def handle_cast({:probe, phase, event, metadata}, state) do
    {:noreply, append_timeline(state, :probe, phase, event, metadata)}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    snap = %{
      run_id: state.run_id,
      started_at_ms: state.started_at_ms,
      last_event_at_ms: state.last_event_at_ms,
      peers: state.peers,
      dispatch_outcomes: state.dispatch_outcomes,
      error_kinds: state.error_kinds,
      distinct_message_keys: MapSet.size(state.seen_messages),
      total_events: state.total_events,
      phase_counts: state.phase_counts,
      timeline: state.timeline
    }

    {:reply, snap, state}
  end

  def handle_call(:reset, _from, state) do
    opts = [
      run_id: state.run_id,
      timeline_limit: state.timeline_limit,
      log_events?: state.log_events?
    ]

    {:reply, :ok, fresh_state(opts)}
  end

  # ── folding ───────────────────────────────────────────────────────────────

  defp fold(state, %Events.DeviceDiscovered{} = e) do
    state
    |> bump_total()
    |> observe_ble_event(e)
    |> touch_peer(e.device_id, e.rssi, beacon_inc: 0)
  end

  defp fold(state, %Events.AdvertisementReceived{} = e) do
    state
    |> bump_total()
    |> observe_ble_event(e)
    |> touch_peer(e.device_id, e.rssi, beacon_inc: 0)
  end

  defp fold(state, %Events.ReceivedMessageBeacon{} = e) do
    key = {e.sender_peer_id_hash, e.message_id_hash}

    state
    |> bump_total()
    |> observe_ble_event(e)
    |> touch_peer(e.received_device_id, e.rssi, beacon_inc: 1)
    |> record_distinct(key, e.received_device_id)
  end

  defp fold(state, %Events.ReceivedMessage{} = e) do
    key = {e.envelope.sender_peer_id, e.message_id}

    state
    |> bump_total()
    |> observe_ble_event(e)
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
        |> observe_ble_event(e)
        |> Map.update!(:dispatch_outcomes, &Map.update(&1, kind, 1, fn n -> n + 1 end))

      :error ->
        state
        |> bump_total()
        |> observe_ble_event(e)
        |> Map.update!(:error_kinds, &Map.update(&1, e.kind, 1, fn n -> n + 1 end))
    end
  end

  defp fold(state, event) do
    state
    |> bump_total()
    |> observe_ble_event(event)
  end

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

  defp observe_ble_event(state, event) do
    {phase, name, metadata} = event_summary(event)
    append_timeline(state, :ble_event, phase, name, metadata)
  end

  defp append_timeline(state, source, phase, event, metadata) do
    now = System.monotonic_time(:millisecond)

    entry = %{
      schema: "mob_rt_event.v1",
      run_id: state.run_id,
      at_unix_ms: System.system_time(:millisecond),
      at_monotonic_ms: now,
      source: source,
      phase: phase,
      event: event,
      metadata: normalize_metadata(metadata)
    }

    maybe_log_timeline(state, entry)

    %{
      state
      | last_event_at_ms: now,
        phase_counts: Map.update(state.phase_counts, phase, 1, fn n -> n + 1 end),
        timeline: [entry | state.timeline] |> Enum.take(state.timeline_limit)
    }
  end

  defp event_summary(%Events.DeviceDiscovered{} = e) do
    {:scan, :device_discovered,
     %{device_id: e.device_id, rssi: e.rssi, observed_at_ms: e.observed_at_ms}}
  end

  defp event_summary(%Events.AdvertisementReceived{} = e) do
    {:scan, :advertisement_received,
     %{device_id: e.device_id, rssi: e.rssi, observed_at_ms: e.observed_at_ms}}
  end

  defp event_summary(%Events.ConnectionStateChanged{} = e) do
    {:connection, :connection_state_changed,
     %{device_id: e.device_id, state: e.state, reason: e.reason}}
  end

  defp event_summary(%Events.PeerAuthenticated{} = e) do
    {:auth, :peer_authenticated, %{peer_id: e.peer_id, device_id: e.device_id}}
  end

  defp event_summary(%Events.MessageReceived{} = e) do
    {:receive, :authenticated_payload_received,
     %{peer_id: e.peer_id, payload_bytes: byte_size(e.payload), received_at_ms: e.received_at_ms}}
  end

  defp event_summary(%Events.ReceivedMessage{} = e) do
    {:receive, :mesh_message_received,
     %{
       message_id: encode_binary(e.message_id),
       sender_peer_id: e.sender_peer_id,
       recipient_peer_id: e.recipient_peer_id || "broadcast",
       received_device_id: e.received_device_id,
       received_at: e.received_at,
       rssi: e.rssi,
       payload_bytes: payload_size(e.envelope)
     }}
  end

  defp event_summary(%Events.ReceivedMessageBeacon{} = e) do
    {:receive, :mesh_message_beacon_received,
     %{
       message_id_hash: encode_binary(e.message_id_hash),
       sender_peer_id_hash: encode_binary(e.sender_peer_id_hash),
       received_device_id: e.received_device_id,
       received_at: e.received_at,
       rssi: e.rssi
     }}
  end

  defp event_summary(%Events.AdvertGossipOutcome{} = e) do
    {:advertise, :advert_gossip_outcome,
     %{
       gossip_intent_id: e.gossip_intent_id,
       message_id_hash: encode_binary(e.message_id_hash),
       sender_peer_id_hash: encode_binary(e.sender_peer_id_hash),
       advertise_as: e.advertise_as,
       kind: e.kind,
       reason: e.reason,
       adapter: e.adapter,
       outcome_at_ms: e.outcome_at_ms
     }}
  end

  defp event_summary(%Events.Error{} = e) do
    case classify_error(e) do
      {:dispatch_outcome, kind} ->
        {:dispatch, :attempt_outcome, %{kind: kind, detail: e.detail, device_id: e.device_id}}

      :error ->
        {:error, :bridge_error, %{kind: e.kind, detail: e.detail, device_id: e.device_id}}
    end
  end

  defp event_summary(event) do
    {:ble, :unknown_event, %{module: inspect(event.__struct__)}}
  rescue
    _ -> {:ble, :unknown_event, %{value: inspect(event)}}
  end

  defp payload_size(%{payload: payload}) when is_binary(payload), do: byte_size(payload)
  defp payload_size(_), do: 0

  defp normalize_metadata(metadata) do
    metadata
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {normalize_key(key), normalize_value(value)} end)
  end

  defp normalize_key(key) when is_atom(key), do: Atom.to_string(key)
  defp normalize_key(key) when is_binary(key), do: key
  defp normalize_key(key), do: inspect(key)

  defp normalize_value(value) when is_binary(value), do: encode_binary(value)
  defp normalize_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_value(value) when is_integer(value), do: value
  defp normalize_value(value) when is_float(value), do: value
  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_list(value), do: Enum.map(value, &normalize_value/1)

  defp normalize_value(value) when is_map(value) do
    value
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {normalize_key(key), normalize_value(value)} end)
  end

  defp normalize_value(value), do: inspect(value)

  defp encode_binary(value) do
    if String.valid?(value) do
      value
    else
      Base.encode16(value, case: :lower)
    end
  end

  defp maybe_log_timeline(%{log_events?: true}, entry) do
    Logger.info([@log_marker, :json.encode(entry)])
  rescue
    error -> Logger.warning("MobAppEvent encode failed: #{inspect(error)}")
  end

  defp maybe_log_timeline(_state, _entry), do: :ok

  defp fresh_state(opts) do
    %{
      run_id: run_id(opts),
      started_at_ms: System.monotonic_time(:millisecond),
      last_event_at_ms: nil,
      peers: %{},
      dispatch_outcomes: %{},
      error_kinds: %{},
      seen_messages: MapSet.new(),
      total_events: 0,
      phase_counts: %{},
      timeline: [],
      timeline_limit: Keyword.get(opts, :timeline_limit, @default_timeline_limit),
      log_events?: Keyword.get(opts, :log_events?, env_truthy?("MESHX_RT_EVENT_LOG"))
    }
  end

  defp run_id(opts) do
    Keyword.get(opts, :run_id) ||
      System.get_env("MESHX_RT_RUN_ID") ||
      "local-#{System.system_time(:second)}"
  end

  defp env_truthy?(name) do
    System.get_env(name) in ["1", "true", "TRUE", "yes", "YES", "on", "ON"]
  end

  defp name(opts), do: Keyword.get(opts, :name, __MODULE__)
end
