defmodule MeshxMobileApp.BleSelfTest do
  @moduledoc """
  Headless on-device BLE bring-up probe.

  Started by `MeshxMobileApp.App.on_start/0` only when the
  `MESHX_BLE_SELFTEST` env var is set (the Android launcher derives it
  from the `meshx_ble_selftest` intent extra). It exercises the real
  `mob_ble_nif` path end to end without any UI:

    1. `:mob_ble_nif.start_scan/1` + `:mob_ble_nif.start_advertising/2`
       with this process as the owner pid.
    2. Receives `{MeshxMobileApp.NativeBridge, :bridge_event, json}` and
       `{Mob.Ble.MobileBridge, :bridge_event, json}` messages (the shape
       emitted by the current NIF for any owner), plus the decoded
       `{:ble_peer_up, ...}` / `{:ble_frame, ...}` tuples from the
       `mob_ble` path (`Mob.Ble.MobileBridge` + `MeshxTransportBLE`).
       Normalizes via `BLE.Adapter.event_message/1` (or direct mapping)
       and logs under the `MeshxBleSelfTest` tag.

  Two devices each running this probe should log each other's
  advertisements — that is the on-device two-node BLE mesh check.
  """

  use GenServer

  require Logger

  alias MeshxMobileApp.BLE.Adapter

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @heartbeat_ms 5_000
  # Re-dispatch a MeshX message on this interval. BleDispatcher only
  # advertises for a 5s window per send, so a one-shot send-on-discovery
  # easily misses the peer's scan window — a steady cadence keeps a
  # dispatch advertisement on the air for the peer to catch.
  @send_interval_ms 7_000

  @impl true
  def init(opts) do
    local_name = Keyword.get(opts, :local_name, default_local_name())

    state = %{
      local_name: local_name,
      discovered: MapSet.new(),
      event_count: 0,
      meshx_peers: MapSet.new(),
      # Dispatch counters and received-side dedup. `beacon_callbacks` is
      # the raw count of received_message_beacon events from the scanner —
      # with ScanSettings.CALLBACK_TYPE_ALL_MATCHES a single 5s advertise
      # window typically fires 15-50 callbacks for the *same* beacon, so
      # the count inflates well past actual delivery. `distinct_messages`
      # dedups by {sender_peer_id_hash, message_id_hash}: that's the real
      # cardinality of MeshX messages received across the BLE radio.
      sent: 0,
      beacon_callbacks: 0,
      full_envelopes_received: 0,
      native?: Keyword.get(opts, :native?, true),
      send_enabled: selftest_send_enabled?(),
      seen_messages: MapSet.new(),
      first_seen_at: %{}
    }

    {:ok, state, {:continue, :start_ble}}
  end

  @impl true
  def handle_continue(:start_ble, %{native?: false} = state) do
    Logger.info("BleSelfTest: native disabled — passive event-forward mode")
    Process.send_after(self(), :heartbeat, @heartbeat_ms)

    if state.send_enabled do
      Process.send_after(self(), :send_message, @send_interval_ms)
    end

    {:noreply, state}
  end

  def handle_continue(:start_ble, state) do
    nif = :mob_ble_nif

    Logger.info("BleSelfTest: starting scan + advertising as #{state.local_name}")

    scan = safe_call(fn -> nif.start_scan(self()) end)
    adv = safe_call(fn -> nif.start_advertising(self(), state.local_name) end)

    Logger.info("BleSelfTest: start_scan=#{inspect(scan)} start_advertising=#{inspect(adv)}")
    Process.send_after(self(), :heartbeat, @heartbeat_ms)

    if state.send_enabled do
      Process.send_after(self(), :send_message, @send_interval_ms)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:send_message, %{send_enabled: false} = state) do
    {:noreply, state}
  end

  def handle_info(:send_message, %{native?: false} = state) do
    # Passive mode under default mob_ble path: no direct NIF ownership or
    # send; the transport owns the radio. Send scheduling is harmless but
    # this guard prevents contention or no-op nif calls.
    {:noreply, state}
  end

  def handle_info(:send_message, state) do
    # Broadcast a real MeshX message on a steady cadence. recipient is
    # "broadcast" — any MeshX scanner in range ingests it. send_ping/3
    # routes through mob_ble_nif -> MobBleNative -> BleDispatcher,
    # which builds a v1 MobMessageEnvelope and advertises it.
    payload = "hello-from-#{state.local_name}-#{System.system_time(:second)}"
    result = safe_call(fn -> :mob_ble_nif.send_ping(self(), "broadcast", payload) end)

    Logger.info(
      "BleSelfTest: MESH MESSAGE SENT payload=#{inspect(payload)} result=#{inspect(result)}"
    )

    Process.send_after(self(), :send_message, @send_interval_ms)
    {:noreply, %{state | sent: state.sent + 1}}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    # Periodic proof-of-life: distinguishes "pipeline working, just no
    # MeshX peer correlated yet" from "no BLE events reaching the BEAM".
    Logger.info(
      "BleSelfTest: HEARTBEAT events=#{state.event_count} " <>
        "devices=#{MapSet.size(state.discovered)} " <>
        "meshx_peers=#{MapSet.size(state.meshx_peers)} " <>
        "sent=#{state.sent} " <>
        "send_enabled=#{state.send_enabled} " <>
        "distinct_msgs=#{MapSet.size(state.seen_messages)} " <>
        "beacon_callbacks=#{state.beacon_callbacks} " <>
        "envelopes=#{state.full_envelopes_received}"
    )

    Process.send_after(self(), :heartbeat, @heartbeat_ms)
    {:noreply, state}
  end

  def handle_info({source, :bridge_event, raw}, state)
      when source in [MeshxMobileApp.NativeBridge, Mob.Ble.MobileBridge, __MODULE__] do
    state = %{state | event_count: state.event_count + 1}
    decoded = Adapter.event_message(raw)

    # Fork the canonical event to the in-process observability surface.
    # No-op (returns :ok) when the Observability server isn't running.
    case decoded do
      {Adapter, :event, event} -> MeshxMobileApp.BLE.Observability.record(event)
      _ -> :ok
    end

    state =
      case decoded do
        {Adapter, :event, %MeshxMobileApp.BLE.Events.DeviceDiscovered{} = e} ->
          maybe_log_meshx_peer(e.device_id, e.rssi, e.advertisement, state)

        {Adapter, :event, %MeshxMobileApp.BLE.Events.AdvertisementReceived{} = e} ->
          maybe_log_meshx_peer(e.device_id, e.rssi, e.advertisement, state)

        {Adapter, :event, %MeshxMobileApp.BLE.Events.ReceivedMessage{} = e} ->
          key = {e.envelope.sender_peer_id, e.message_id}
          state = %{state | full_envelopes_received: state.full_envelopes_received + 1}

          state =
            record_distinct_message(state, key, :envelope, e.sender_peer_id, e.received_device_id)

          # High-visibility marker for the production MB-legacy + GATT path on
          # older devices (T390/API 28). Appears under BleSelfTest tag when the
          # envelope arrived via fetch (triggered by MB cue). Makes positive
          # evidence obvious in focused log captures without broad filters.
          if gatt_fetch_metadata?(e.raw_transport_metadata) do
            Logger.info(
              "BleSelfTest: GATT_FETCH_RECEIVED messageId=#{inspect(e.message_id)} " <>
                "sender=#{e.sender_peer_id} device=#{e.received_device_id} rssi=#{e.rssi}"
            )
          end

          state

        {Adapter, :event, %MeshxMobileApp.BLE.Events.ReceivedMessageBeacon{} = e} ->
          # CALLBACK_TYPE_ALL_MATCHES fires per advertising-event, not per
          # message — the *same* 22-byte beacon is reported many times
          # across its 5s advertise window. Dedup by the (sender_hash,
          # msg_id_hash) pair so the distinct count is a defensible
          # delivery metric independent of scan duty cycle.
          key = {e.sender_peer_id_hash, e.message_id_hash}
          state = %{state | beacon_callbacks: state.beacon_callbacks + 1}

          state =
            record_distinct_message(
              state,
              key,
              :beacon,
              "sender_hash=#{Base.encode16(e.sender_peer_id_hash, case: :lower)}",
              e.received_device_id
            )

          state

        {Adapter, :event, %MeshxMobileApp.BLE.Events.Error{} = e} ->
          Logger.warning("BleSelfTest: bridge error #{e.kind}: #{e.detail}")
          state

        {Adapter, :event, _event} ->
          state
      end

    {:noreply, state}
  end

  # New `mob_ble` default path support (Mob.Ble.MobileBridge + its
  # Internal.BridgeProtocol -> MeshxTransportBLE). When the legacy
  # self-test is the bridge event_target (or receives tuples in test/
  # passive-forward setups), we receive the decoded low-level shapes
  # instead of (or in addition to) the raw :bridge_event json. Map the
  # common ones to our counters and meshx-peer logging so the heavy
  # app-specific evidence paths continue to produce numbers.
  def handle_info({:ble_peer_up, device_id, metadata}, state) do
    state = %{state | event_count: state.event_count + 1}

    rssi = (is_map(metadata) && (metadata[:rssi] || metadata["rssi"])) || 0
    advert = (is_map(metadata) && (metadata[:advertisement] || metadata["advertisement"])) || <<>>

    state = maybe_log_meshx_peer(device_id, rssi, advert, state)

    # Beacon-style peer_up carries the hashes in metadata (see
    # Mob.Ble.Internal.BridgeProtocol.decode_v1 for received_message_beacon).
    # Normalize Base64 wire values (as emitted by internal protocol) to the
    # canonical 8-byte binaries that BridgeProtocol produces on the json path.
    # This makes distinct_msgs keys and DISTINCT logs identical across paths.
    state =
      if is_map(metadata) and
           (metadata[:message_id_hash] || metadata["message_id_hash"]) and
           (metadata[:sender_peer_id_hash] || metadata["sender_peer_id_hash"]) do
        mid_h = normalize_b64_hash(metadata[:message_id_hash] || metadata["message_id_hash"])

        sid_h =
          normalize_b64_hash(metadata[:sender_peer_id_hash] || metadata["sender_peer_id_hash"])

        key = {sid_h, mid_h}
        state = %{state | beacon_callbacks: state.beacon_callbacks + 1}

        record_distinct_message(
          state,
          key,
          :beacon,
          "sender_hash=#{Base.encode16(sid_h, case: :lower)}",
          device_id
        )
      else
        state
      end

    {:noreply, state}
  end

  def handle_info({:ble_peer_down, _device_id}, state) do
    {:noreply, state}
  end

  def handle_info({:ble_frame, peer_id, frame}, state) do
    state = %{
      state
      | event_count: state.event_count + 1,
        full_envelopes_received: state.full_envelopes_received + 1
    }

    # Best-effort for tuple path (frames carry envelope bytes post-internal decode).
    # Use {peer, size} proxy key so distinct_msgs and DISTINCT logs move;
    # full message_id-based dedup + GATT only possible on the rich json+Adapter path.
    key = {to_string(peer_id), byte_size(frame)}
    state = record_distinct_message(state, key, :frame, peer_id, peer_id)
    {:noreply, state}
  end

  def handle_info(other, state) do
    Logger.debug("BleSelfTest: unexpected #{inspect(other)}")
    {:noreply, state}
  end

  # Record the first sight of a distinct message and log it; subsequent
  # sightings of the same key are silently absorbed into beacon_callbacks
  # so the per-message log line maps 1:1 to actual delivered messages.
  defp record_distinct_message(state, key, kind, sender_label, device_id) do
    if MapSet.member?(state.seen_messages, key) do
      state
    else
      now = System.monotonic_time(:millisecond)

      Logger.info(
        "BleSelfTest: DISTINCT MESH MESSAGE kind=#{kind} " <>
          "key=#{format_key(key)} from=#{sender_label} " <>
          "device_id=#{device_id} " <>
          "first_seen_after=#{state.beacon_callbacks + state.full_envelopes_received}_callbacks"
      )

      %{
        state
        | seen_messages: MapSet.put(state.seen_messages, key),
          first_seen_at: Map.put(state.first_seen_at, key, now)
      }
    end
  end

  defp format_key({sender, msg_id}) when is_binary(sender) and is_binary(msg_id) do
    Base.encode16(sender, case: :lower) <> ":" <> Base.encode16(msg_id, case: :lower)
  end

  defp format_key(other), do: inspect(other)

  # A MeshX peer tablet advertises its adapter name ("meshx-<suffix>");
  # that ASCII lands in the raw advertisement bytes. Log the first sight
  # of each MeshX peer distinctly — that line is the two-device mesh
  # proof: this BEAM, over the real mob_ble_nif path, saw the other
  # BEAM's BLE advertisement.
  defp maybe_log_meshx_peer(device_id, rssi, advertisement, state) do
    # The canonical event's `advertisement` field arrives base64-encoded
    # on the Android JSON-wire path (BleEvent.toJsonObject does .toBase64()
    # and BridgeProtocol keeps it as the wire string). Decode to raw bytes
    # before scanning for the peer's "meshx-*" manufacturer-data tag.
    bytes = advertisement_bytes(advertisement)

    state = %{state | discovered: MapSet.put(state.discovered, device_id)}

    if is_binary(bytes) and meshx_advertisement?(bytes) and
         not MapSet.member?(state.meshx_peers, device_id) do
      Logger.info(
        "BleSelfTest: MESHX PEER device_id=#{device_id} rssi=#{rssi} " <>
          "name=#{extract_name(bytes)}"
      )

      Map.update!(state, :meshx_peers, &MapSet.put(&1, device_id))
    else
      state
    end
  end

  # `advertisement` may be raw bytes (atom-keyed map path) or a base64
  # string (Android JSON-wire path). Normalize to raw bytes.
  defp advertisement_bytes(advertisement) when is_binary(advertisement) do
    case Base.decode64(advertisement) do
      {:ok, decoded} -> decoded
      :error -> advertisement
    end
  end

  defp advertisement_bytes(_), do: <<>>

  defp meshx_advertisement?(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> printable_runs()
    |> Enum.any?(&String.contains?(&1, "meshx"))
  end

  defp extract_name(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> printable_runs()
    |> Enum.find("?", &String.contains?(&1, "meshx"))
  end

  defp gatt_fetch_metadata?(metadata) when is_map(metadata) do
    metadata_value(metadata, :transport) == "ble_android_gatt_fetch" or
      metadata_value(metadata, :source_event) == "gatt_fetch_response"
  end

  defp gatt_fetch_metadata?(_), do: false

  defp metadata_value(metadata, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  # Split a byte list into runs of >=4 printable ASCII chars.
  defp printable_runs(bytes) do
    bytes
    |> Enum.chunk_by(&(&1 in 32..126))
    |> Enum.filter(fn run -> hd(run) in 32..126 and length(run) >= 4 end)
    |> Enum.map(&List.to_string/1)
  end

  defp safe_call(fun) do
    fun.()
  rescue
    error -> {:error, error}
  end

  defp default_local_name do
    suffix = System.get_env("MOB_NODE_SUFFIX") || "dev"
    "meshx-#{suffix}"
  end

  defp selftest_send_enabled? do
    System.get_env("MESHX_BLE_SELFTEST_SEND", "1") not in [
      "0",
      "false",
      "FALSE",
      "no",
      "NO",
      "off",
      "OFF"
    ]
  end

  # Normalize a wire hash (Base64 string from Internal.BridgeProtocol or
  # raw 8-byte binary from app BridgeProtocol) to the canonical 8-byte
  # binary form used for distinct_msgs keys and format_key. Fallback keeps
  # already-decoded or non-b64 values intact.
  defp normalize_b64_hash(h) when is_binary(h) do
    case Base.decode64(h) do
      {:ok, bin} when byte_size(bin) == 8 -> bin
      _ -> h
    end
  end

  defp normalize_b64_hash(h), do: h
end
