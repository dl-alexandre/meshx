defmodule MeshxMobileApp.BLE.BridgeProtocol do
  @moduledoc """
  Tagged, versioned wire protocol between native bridges and Elixir.

  Swift (iOS) and Kotlin (Android) MUST emit messages in the shape

      %{v: 1, event: "device_discovered", ...}

  This module is the single normalization point that converts wire-format
  maps into canonical `MeshxMobileApp.BLE.Event` structs. Bridges do no
  translation themselves.

  Until the iOS NIF is rewritten to emit v1 maps, legacy tuple shapes
  emitted by the current NIF are accepted by `decode/1` and translated
  here. Those clauses are marked `# TODO: remove once NIF emits v1`.

  ## Security

  The event tag is decoded against a fixed allowlist — never via
  `String.to_atom/1` — to prevent atom-table exhaustion from a
  compromised or malformed NIF.
  """

  alias MeshxMobileApp.BLE.{Capabilities, Error, MessageAdvertisement, MessageEnvelope}

  alias MeshxMobileApp.BLE.Events.{
    DeviceDiscovered,
    DeviceLost,
    AdvertisementReceived,
    ConnectionStateChanged,
    PeerAuthenticated,
    MessageReceived,
    ReceivedMessage,
    ReceivedMessageBeacon,
    AdvertGossipOutcome
  }

  @wire_version 1

  @event_tags %{
    "device_discovered" => DeviceDiscovered,
    "device_lost" => DeviceLost,
    "advertisement_received" => AdvertisementReceived,
    "connection_state_changed" => ConnectionStateChanged,
    "peer_authenticated" => PeerAuthenticated,
    "message_received" => MessageReceived,
    "received_message" => ReceivedMessage,
    "received_message_beacon" => ReceivedMessageBeacon,
    "advert_gossip_outcome" => AdvertGossipOutcome,
    "error" => MeshxMobileApp.BLE.Events.Error
  }

  @conn_states %{
    "connecting" => :connecting,
    "connected" => :connected,
    "disconnecting" => :disconnecting,
    "disconnected" => :disconnected
  }

  @spec wire_version() :: pos_integer()
  def wire_version, do: @wire_version

  @doc """
  Normalizes a bridge payload into a canonical event struct.

  Accepts either a v1 wire-format map or a legacy NIF tuple. Returns
  `{:error, reason}` for anything else — bridges that fail to conform
  fail visibly rather than silently dropping events.
  """
  @spec decode(term()) :: {:ok, MeshxMobileApp.BLE.Event.t()} | {:error, term()}
  def decode(%{v: @wire_version, event: tag} = msg) when is_binary(tag) do
    decode_v1(tag, msg)
  end

  def decode(%{"v" => @wire_version, "event" => tag} = msg) when is_binary(tag) do
    msg
    |> atomize_top_level()
    |> decode()
  end

  def decode(%{v: v}), do: {:error, {:unsupported_wire_version, v}}
  def decode(%{"v" => v}), do: {:error, {:unsupported_wire_version, v}}

  # TODO: remove once the iOS NIF emits v1 wire format. The current
  # statically-linked NIF still sends these legacy shapes; translating
  # them here keeps the canonical pipeline honest without blocking on
  # native rework.
  def decode({:connected, device_id}) when is_binary(device_id) do
    {:ok,
     %ConnectionStateChanged{
       device_id: device_id,
       transport: :ble,
       state: :connected,
       reason: nil
     }}
  end

  def decode({:disconnected, device_id}) when is_binary(device_id) do
    {:ok,
     %ConnectionStateChanged{
       device_id: device_id,
       transport: :ble,
       state: :disconnected,
       reason: nil
     }}
  end

  def decode({:received, peer_id, %{type: _type, msg_id: _id, bytes: bytes}})
      when is_binary(peer_id) and is_integer(bytes) do
    {:ok,
     %MessageReceived{
       peer_id: peer_id,
       transport: :ble,
       # Legacy NIF only reports the size, not the payload itself; carry
       # an empty binary so size is recoverable via byte_size/1 once the
       # real payload starts flowing through v1.
       payload: <<>>,
       received_at_ms: System.monotonic_time(:millisecond)
     }}
  end

  def decode({:error, reason}) do
    {:ok,
     %MeshxMobileApp.BLE.Events.Error{
       kind: Error.coerce(extract_kind(reason)),
       detail: inspect(reason),
       device_id: nil
     }}
  end

  # The legacy `{:status, _}` tuple has no canonical analogue — status
  # text is a UI concern derived by Session from lifecycle + events, not
  # a transport event. Drop with an explicit error so callers see the
  # contract change instead of relying on free-form strings.
  def decode({:status, _}), do: {:error, :status_not_in_contract}

  # The Android NIF (c_src/meshx_ble_nif.c) delivers events as the v1
  # wire-format JSON string produced by `BleEvent.toJsonObject()` — the
  # JNI boundary carries a string far more cheaply than a built Erlang
  # term. Decode to a string-keyed map and re-enter the pipeline.
  def decode(json) when is_binary(json) do
    case JSON.decode(json) do
      {:ok, %{"v" => _} = msg} -> decode(msg)
      {:ok, other} -> {:error, {:unrecognized_bridge_payload, other}}
      {:error, reason} -> {:error, {:invalid_bridge_json, reason}}
    end
  end

  def decode(other), do: {:error, {:unrecognized_bridge_payload, other}}

  @doc """
  Encodes a canonical event struct into the v1 wire format. Used by
  test bridges and by the future Kotlin/Swift parity tests.
  """
  @spec encode(MeshxMobileApp.BLE.Event.t()) :: map()
  def encode(%DeviceDiscovered{} = e) do
    %{
      v: @wire_version,
      event: "device_discovered",
      device_id: e.device_id,
      rssi: e.rssi,
      advertisement: e.advertisement,
      observed_at_ms: e.observed_at_ms
    }
  end

  def encode(%DeviceLost{} = e) do
    %{
      v: @wire_version,
      event: "device_lost",
      device_id: e.device_id,
      observed_at_ms: e.observed_at_ms
    }
  end

  def encode(%AdvertisementReceived{} = e) do
    %{
      v: @wire_version,
      event: "advertisement_received",
      device_id: e.device_id,
      rssi: e.rssi,
      advertisement: e.advertisement,
      observed_at_ms: e.observed_at_ms
    }
  end

  def encode(%ConnectionStateChanged{} = e) do
    %{
      v: @wire_version,
      event: "connection_state_changed",
      device_id: e.device_id,
      state: Atom.to_string(e.state),
      reason: if(e.reason, do: Atom.to_string(e.reason))
    }
  end

  def encode(%PeerAuthenticated{capabilities: %Capabilities{} = caps} = e) do
    %{
      v: @wire_version,
      event: "peer_authenticated",
      peer_id: e.peer_id,
      device_id: e.device_id,
      capabilities: %{
        version: caps.version,
        roles: caps.roles |> MapSet.to_list() |> Enum.map(&Atom.to_string/1),
        features: caps.features |> MapSet.to_list() |> Enum.map(&Atom.to_string/1)
      }
    }
  end

  def encode(%MessageReceived{} = e) do
    %{
      v: @wire_version,
      event: "message_received",
      peer_id: e.peer_id,
      payload: e.payload,
      received_at_ms: e.received_at_ms
    }
  end

  def encode(%ReceivedMessage{} = e) do
    %{
      v: @wire_version,
      event: "received_message",
      message_id: e.message_id,
      sender_peer_id: e.sender_peer_id,
      recipient_peer_id: e.recipient_peer_id,
      received_device_id: e.received_device_id,
      received_at: e.received_at,
      rssi: e.rssi,
      envelope: MessageEnvelope.encode(e.envelope),
      raw_transport_metadata: e.raw_transport_metadata
    }
  end

  def encode(%ReceivedMessageBeacon{} = e) do
    %{
      v: @wire_version,
      event: "received_message_beacon",
      beacon_version: e.beacon_version,
      envelope_version: e.envelope_version,
      payload_kind: e.payload_kind,
      message_id_hash: e.message_id_hash,
      sender_peer_id_hash: e.sender_peer_id_hash,
      received_device_id: e.received_device_id,
      received_at: e.received_at,
      rssi: e.rssi,
      raw_transport_metadata: e.raw_transport_metadata
    }
  end

  def encode(%AdvertGossipOutcome{} = e) do
    %{
      v: @wire_version,
      event: "advert_gossip_outcome",
      gossip_intent_id: e.gossip_intent_id,
      message_id_hash: e.message_id_hash,
      sender_peer_id_hash: e.sender_peer_id_hash,
      advertise_as: Atom.to_string(e.advertise_as),
      kind: Atom.to_string(e.kind),
      reason: encode_optional_reason(e.reason),
      adapter: Atom.to_string(e.adapter),
      outcome_at_ms: e.outcome_at_ms
    }
  end

  def encode(%MeshxMobileApp.BLE.Events.Error{} = e) do
    %{
      v: @wire_version,
      event: "error",
      kind: Atom.to_string(e.kind),
      detail: e.detail,
      device_id: e.device_id
    }
  end

  # ── v1 decode helpers ──────────────────────────────────────────────────────

  defp decode_v1(tag, msg) do
    case Map.fetch(@event_tags, tag) do
      {:ok, MeshxMobileApp.BLE.Events.Error} -> decode_error(msg)
      {:ok, mod} -> decode_struct(mod, msg)
      :error -> {:error, {:unknown_event_tag, tag}}
    end
  end

  defp decode_struct(DeviceDiscovered, msg) do
    %DeviceDiscovered{
      device_id: msg[:device_id],
      transport: :ble,
      rssi: msg[:rssi] || 0,
      advertisement: msg[:advertisement] || <<>>,
      observed_at_ms: msg[:observed_at_ms] || 0
    }
    |> decode_advertisement_event()
  end

  defp decode_struct(DeviceLost, msg) do
    {:ok,
     %DeviceLost{
       device_id: msg[:device_id],
       transport: :ble,
       observed_at_ms: msg[:observed_at_ms] || 0
     }}
  end

  defp decode_struct(AdvertisementReceived, msg) do
    %AdvertisementReceived{
      device_id: msg[:device_id],
      rssi: msg[:rssi] || 0,
      advertisement: msg[:advertisement] || <<>>,
      observed_at_ms: msg[:observed_at_ms] || 0
    }
    |> decode_advertisement_event()
  end

  defp decode_struct(ConnectionStateChanged, msg) do
    with {:ok, state} <- Map.fetch(@conn_states, msg[:state] || "") do
      {:ok,
       %ConnectionStateChanged{
         device_id: msg[:device_id],
         transport: :ble,
         state: state,
         reason: decode_optional_error_kind(msg[:reason])
       }}
    else
      :error -> {:error, {:unknown_connection_state, msg[:state]}}
    end
  end

  defp decode_struct(PeerAuthenticated, msg) do
    caps = decode_capabilities(msg[:capabilities] || %{})

    {:ok,
     %PeerAuthenticated{
       peer_id: msg[:peer_id],
       device_id: msg[:device_id],
       transport: :ble,
       capabilities: caps
     }}
  end

  defp decode_struct(MessageReceived, msg) do
    {:ok,
     %MessageReceived{
       peer_id: msg[:peer_id],
       transport: :ble,
       payload: msg[:payload] || <<>>,
       received_at_ms: msg[:received_at_ms] || 0
     }}
  end

  defp decode_struct(ReceivedMessage, msg) do
    with :ok <- require_received_message_fields(msg),
         {:ok, envelope} <- decode_envelope(msg[:envelope]),
         :ok <- validate_received_message_fields(msg, envelope) do
      {:ok,
       %ReceivedMessage{
         message_id: received_message_field(msg, :message_id, envelope.message_id),
         sender_peer_id: received_message_field(msg, :sender_peer_id, envelope.sender_peer_id),
         recipient_peer_id:
           received_message_field(msg, :recipient_peer_id, envelope.recipient_peer_id),
         received_device_id: Map.fetch!(msg, :received_device_id),
         received_at: Map.fetch!(msg, :received_at),
         rssi: Map.fetch!(msg, :rssi),
         envelope: envelope,
         raw_transport_metadata:
           normalize_raw_transport_metadata(Map.fetch!(msg, :raw_transport_metadata))
       }}
    else
      {:error, reason} -> {:error, {:received_message_decode_error, reason}}
    end
  end

  defp decode_struct(ReceivedMessageBeacon, msg) do
    with :ok <- require_received_message_beacon_fields(msg),
         :ok <- validate_received_message_beacon_fields(msg) do
      {:ok,
       %ReceivedMessageBeacon{
         beacon_version: Map.fetch!(msg, :beacon_version),
         envelope_version: Map.fetch!(msg, :envelope_version),
         payload_kind: Map.fetch!(msg, :payload_kind),
         message_id_hash: Map.fetch!(msg, :message_id_hash),
         sender_peer_id_hash: Map.fetch!(msg, :sender_peer_id_hash),
         received_device_id: Map.fetch!(msg, :received_device_id),
         received_at: Map.fetch!(msg, :received_at),
         rssi: Map.fetch!(msg, :rssi),
         raw_transport_metadata:
           normalize_raw_transport_metadata(Map.fetch!(msg, :raw_transport_metadata))
       }}
    else
      {:error, reason} -> {:error, {:received_message_beacon_decode_error, reason}}
    end
  end

  defp decode_struct(AdvertGossipOutcome, msg) do
    with :ok <- require_advert_gossip_outcome_fields(msg),
         {:ok, advertise_as} <- decode_advertise_as(msg[:advertise_as]),
         {:ok, kind} <- decode_advert_gossip_kind(msg[:kind]),
         {:ok, adapter} <- decode_advert_gossip_adapter(msg[:adapter]),
         :ok <- validate_advert_gossip_outcome_fields(msg) do
      {:ok,
       %AdvertGossipOutcome{
         gossip_intent_id: Map.fetch!(msg, :gossip_intent_id),
         message_id_hash: Map.fetch!(msg, :message_id_hash),
         sender_peer_id_hash: Map.fetch!(msg, :sender_peer_id_hash),
         advertise_as: advertise_as,
         kind: kind,
         reason: decode_optional_reason(msg[:reason]),
         adapter: adapter,
         outcome_at_ms: Map.fetch!(msg, :outcome_at_ms)
       }}
    else
      {:error, reason} -> {:error, {:advert_gossip_outcome_decode_error, reason}}
    end
  end

  defp require_advert_gossip_outcome_fields(msg) do
    required = [
      :gossip_intent_id,
      :message_id_hash,
      :sender_peer_id_hash,
      :advertise_as,
      :kind,
      :adapter,
      :outcome_at_ms
    ]

    case Enum.find(required, &(not Map.has_key?(msg, &1))) do
      nil -> :ok
      key -> {:error, {:advert_gossip_outcome_missing_field, key}}
    end
  end

  defp validate_advert_gossip_outcome_fields(msg) do
    cond do
      not is_binary(msg[:gossip_intent_id]) ->
        {:error, {:advert_gossip_outcome_invalid_field, :gossip_intent_id}}

      not (is_binary(msg[:message_id_hash]) and byte_size(msg[:message_id_hash]) == 8) ->
        {:error, {:advert_gossip_outcome_invalid_field, :message_id_hash}}

      not (is_binary(msg[:sender_peer_id_hash]) and byte_size(msg[:sender_peer_id_hash]) == 8) ->
        {:error, {:advert_gossip_outcome_invalid_field, :sender_peer_id_hash}}

      not (is_binary(msg[:reason]) or is_nil(msg[:reason])) ->
        {:error, {:advert_gossip_outcome_invalid_field, :reason}}

      not is_integer(msg[:outcome_at_ms]) ->
        {:error, {:advert_gossip_outcome_invalid_field, :outcome_at_ms}}

      true ->
        :ok
    end
  end

  defp decode_advertise_as(value) when is_atom(value) do
    if value in [:legacy_beacon_advert, :full_envelope_advert] do
      {:ok, value}
    else
      {:error, {:unknown_advertise_as, value}}
    end
  end

  defp decode_advertise_as(value) when is_binary(value) do
    case value do
      "legacy_beacon_advert" -> {:ok, :legacy_beacon_advert}
      "full_envelope_advert" -> {:ok, :full_envelope_advert}
      _ -> {:error, {:unknown_advertise_as, value}}
    end
  end

  defp decode_advertise_as(value), do: {:error, {:unknown_advertise_as, value}}

  defp decode_advert_gossip_kind(value) when is_atom(value) do
    if value in [:gossiped, :failed, :skipped, :invalid_intent, :would_gossip] do
      {:ok, value}
    else
      {:error, {:unknown_advert_gossip_kind, value}}
    end
  end

  defp decode_advert_gossip_kind(value) when is_binary(value) do
    case value do
      "gossiped" -> {:ok, :gossiped}
      "failed" -> {:ok, :failed}
      "skipped" -> {:ok, :skipped}
      "invalid_intent" -> {:ok, :invalid_intent}
      "would_gossip" -> {:ok, :would_gossip}
      _ -> {:error, {:unknown_advert_gossip_kind, value}}
    end
  end

  defp decode_advert_gossip_kind(value), do: {:error, {:unknown_advert_gossip_kind, value}}

  defp decode_advert_gossip_adapter(value) when is_atom(value) do
    if value in [:ble_android, :advert_gossip_dry_run] do
      {:ok, value}
    else
      {:error, {:unknown_advert_gossip_adapter, value}}
    end
  end

  defp decode_advert_gossip_adapter(value) when is_binary(value) do
    case value do
      "ble_android" -> {:ok, :ble_android}
      "advert_gossip_dry_run" -> {:ok, :advert_gossip_dry_run}
      _ -> {:error, {:unknown_advert_gossip_adapter, value}}
    end
  end

  defp decode_advert_gossip_adapter(value),
    do: {:error, {:unknown_advert_gossip_adapter, value}}

  defp decode_optional_reason(nil), do: nil
  defp decode_optional_reason(reason) when is_atom(reason), do: reason
  defp decode_optional_reason(reason) when is_binary(reason), do: reason

  defp encode_optional_reason(nil), do: nil
  defp encode_optional_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp encode_optional_reason(reason) when is_binary(reason), do: reason

  defp require_received_message_beacon_fields(msg) do
    required = [
      :beacon_version,
      :envelope_version,
      :payload_kind,
      :message_id_hash,
      :sender_peer_id_hash,
      :received_device_id,
      :received_at,
      :rssi,
      :raw_transport_metadata
    ]

    case Enum.find(required, &(not Map.has_key?(msg, &1))) do
      nil -> :ok
      key -> {:error, {:received_message_beacon_missing_field, key}}
    end
  end

  defp validate_received_message_beacon_fields(msg) do
    cond do
      not is_integer(msg[:beacon_version]) ->
        {:error, {:received_message_beacon_invalid_field, :beacon_version}}

      not is_integer(msg[:envelope_version]) ->
        {:error, {:received_message_beacon_invalid_field, :envelope_version}}

      not is_binary(msg[:payload_kind]) ->
        {:error, {:received_message_beacon_invalid_field, :payload_kind}}

      not (is_binary(msg[:message_id_hash]) and byte_size(msg[:message_id_hash]) == 8) ->
        {:error, {:received_message_beacon_invalid_field, :message_id_hash}}

      not (is_binary(msg[:sender_peer_id_hash]) and byte_size(msg[:sender_peer_id_hash]) == 8) ->
        {:error, {:received_message_beacon_invalid_field, :sender_peer_id_hash}}

      not is_binary(msg[:received_device_id]) ->
        {:error, {:received_message_beacon_invalid_field, :received_device_id}}

      not is_integer(msg[:received_at]) ->
        {:error, {:received_message_beacon_invalid_field, :received_at}}

      not is_integer(msg[:rssi]) ->
        {:error, {:received_message_beacon_invalid_field, :rssi}}

      not is_map(msg[:raw_transport_metadata]) ->
        {:error, :invalid_raw_transport_metadata}

      true ->
        :ok
    end
  end

  defp validate_received_message_fields(msg, envelope) do
    with :ok <- validate_received_message_wire_types(msg),
         :ok <- validate_raw_transport_metadata(msg[:raw_transport_metadata]),
         :ok <- validate_received_message_field(msg, :message_id, envelope.message_id),
         :ok <- validate_received_message_field(msg, :sender_peer_id, envelope.sender_peer_id),
         :ok <-
           validate_received_message_field(msg, :recipient_peer_id, envelope.recipient_peer_id) do
      :ok
    end
  end

  defp require_received_message_fields(msg) do
    required = [
      :message_id,
      :sender_peer_id,
      :recipient_peer_id,
      :received_device_id,
      :received_at,
      :rssi,
      :envelope,
      :raw_transport_metadata
    ]

    case Enum.find(required, &(not Map.has_key?(msg, &1))) do
      nil -> :ok
      key -> {:error, {:received_message_missing_field, key}}
    end
  end

  defp validate_raw_transport_metadata(%{}), do: :ok
  defp validate_raw_transport_metadata(_), do: {:error, :invalid_raw_transport_metadata}

  defp validate_received_message_wire_types(msg) do
    cond do
      not (is_binary(msg[:message_id]) and byte_size(msg[:message_id]) == 16) ->
        {:error, {:received_message_invalid_field, :message_id}}

      not is_binary(msg[:sender_peer_id]) ->
        {:error, {:received_message_invalid_field, :sender_peer_id}}

      not (is_binary(msg[:recipient_peer_id]) or is_nil(msg[:recipient_peer_id])) ->
        {:error, {:received_message_invalid_field, :recipient_peer_id}}

      not is_binary(msg[:received_device_id]) ->
        {:error, {:received_message_invalid_field, :received_device_id}}

      not is_integer(msg[:received_at]) ->
        {:error, {:received_message_invalid_field, :received_at}}

      not is_integer(msg[:rssi]) ->
        {:error, {:received_message_invalid_field, :rssi}}

      true ->
        :ok
    end
  end

  defp validate_received_message_field(msg, key, expected) do
    if Map.has_key?(msg, key) and Map.fetch!(msg, key) != expected do
      {:error, {:received_message_field_mismatch, key}}
    else
      :ok
    end
  end

  defp received_message_field(msg, key, default) do
    if Map.has_key?(msg, key), do: Map.fetch!(msg, key), else: default
  end

  defp decode_advertisement_event(event) do
    case MessageAdvertisement.decode(event) do
      {:ok, %ReceivedMessage{} = received} ->
        {:ok, received}

      {:ok, %ReceivedMessageBeacon{} = beacon} ->
        {:ok, beacon}

      :not_message_advertisement ->
        {:ok, event}

      {:error, {:message_advertisement_decode_error, _} = reason} ->
        {:ok,
         %MeshxMobileApp.BLE.Events.Error{
           kind: :unknown,
           detail: inspect(reason),
           device_id: event.device_id
         }}
    end
  end

  defp decode_envelope(%MessageEnvelope{} = envelope), do: {:ok, envelope}
  defp decode_envelope(bytes) when is_binary(bytes), do: MessageEnvelope.parse(bytes)
  defp decode_envelope(_), do: {:error, {:received_message_invalid_field, :envelope}}

  defp decode_error(msg) do
    {:ok,
     %MeshxMobileApp.BLE.Events.Error{
       kind: Error.coerce(decode_optional_error_kind(msg[:kind])),
       detail: msg[:detail] || "",
       device_id: msg[:device_id]
     }}
  end

  defp decode_optional_error_kind(nil), do: nil

  defp decode_optional_error_kind(kind) when is_atom(kind) do
    Error.coerce(kind)
  end

  defp decode_optional_error_kind(kind) when is_binary(kind) do
    # Allowlist lookup against the closed taxonomy — never String.to_atom/1.
    kind_atom =
      Enum.find(Error.kinds(), :unknown, fn k -> Atom.to_string(k) == kind end)

    kind_atom
  end

  defp decode_capabilities(%{} = map) do
    Capabilities.new(
      version: map[:version] || Capabilities.current_version(),
      roles: decode_role_list(map[:roles] || []),
      features: decode_feature_list(map[:features] || [])
    )
  end

  @known_roles [:central, :peripheral]

  defp decode_role_list(roles) when is_list(roles) do
    Enum.flat_map(roles, fn
      role when role in @known_roles ->
        [role]

      role when is_binary(role) ->
        case Enum.find(@known_roles, fn r -> Atom.to_string(r) == role end) do
          nil -> []
          r -> [r]
        end

      _ ->
        []
    end)
  end

  # Features are advertised by capability — unknown ones are silently
  # dropped so the older side never crashes on a newer feature flag.
  defp decode_feature_list(features) when is_list(features) do
    Enum.flat_map(features, fn
      f when is_atom(f) -> [f]
      _ -> []
    end)
  end

  defp extract_kind(reason) when is_atom(reason), do: reason
  defp extract_kind({kind, _}) when is_atom(kind), do: kind
  defp extract_kind(_), do: :unknown

  # Binary fields carried base64-encoded on the JSON wire path
  # (BleEvent.toJsonObject does .toBase64()). The atom-keyed NIF path
  # delivers them as raw binaries already and never reaches this code.
  @b64_top_level_fields ~w(advertisement message_id message_id_hash sender_peer_id_hash envelope)a
  @b64_metadata_fields ~w(advertisement message_payload beacon_payload manufacturer_data)a

  defp atomize_top_level(map) do
    Enum.reduce(map, %{}, fn
      {"v", v}, acc ->
        Map.put(acc, :v, v)

      {"event", v}, acc ->
        Map.put(acc, :event, v)

      {"raw_transport_metadata", v}, acc when is_map(v) ->
        Map.put(acc, :raw_transport_metadata, atomize_metadata(v))

      {k, v}, acc when is_binary(k) ->
        key = safe_key(k)
        Map.put(acc, key, maybe_base64_decode(key, @b64_top_level_fields, v))

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end

  # The JSON wire path nests raw_transport_metadata as a string-keyed map
  # with base64 binary values. Atomize its keys and decode its binaries
  # here so the shared normalize_raw_transport_metadata/1 (also used by
  # the raw NIF path) just passes an already-canonical map through.
  defp atomize_metadata(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc ->
      key = normalize_metadata_key(k)
      Map.put(acc, key, maybe_base64_decode(key, @b64_metadata_fields, v))
    end)
  end

  defp maybe_base64_decode(key, binary_keys, value) when is_binary(value) do
    if key in binary_keys do
      case Base.decode64(value) do
        {:ok, decoded} -> decoded
        :error -> value
      end
    else
      value
    end
  end

  defp maybe_base64_decode(_key, _binary_keys, value), do: value

  defp normalize_raw_transport_metadata(%{} = metadata) do
    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      Map.put(acc, normalize_metadata_key(key), value)
    end)
  end

  defp normalize_raw_transport_metadata(_), do: %{}

  defp normalize_metadata_key(key) when is_atom(key), do: key

  defp normalize_metadata_key(key) when is_binary(key) do
    case key do
      "transport" -> :transport
      "source_event" -> :source_event
      "received_device_id" -> :received_device_id
      "advertisement" -> :advertisement
      "message_payload" -> :message_payload
      "beacon_payload" -> :beacon_payload
      "manufacturer_data" -> :manufacturer_data
      "company_identifier" -> :company_identifier
      "ad_type" -> :ad_type
      _ -> key
    end
  end

  # Closed allowlist for field keys — anything else falls back to a
  # binary key so the decode site can ignore it without minting atoms.
  @field_keys [
    :device_id,
    :peer_id,
    :transport,
    :rssi,
    :advertisement,
    :observed_at_ms,
    :received_at_ms,
    :message_id,
    :sender_peer_id,
    :recipient_peer_id,
    :received_device_id,
    :received_at,
    :state,
    :reason,
    :capabilities,
    :payload,
    :envelope,
    :raw_transport_metadata,
    :beacon_version,
    :envelope_version,
    :payload_kind,
    :message_id_hash,
    :sender_peer_id_hash,
    :beacon_payload,
    :gossip_intent_id,
    :advertise_as,
    :adapter,
    :outcome_at_ms,
    :kind,
    :detail,
    :version,
    :roles,
    :features
  ]

  defp safe_key(k) when is_binary(k) do
    Enum.find(@field_keys, k, fn a -> Atom.to_string(a) == k end)
  end
end
