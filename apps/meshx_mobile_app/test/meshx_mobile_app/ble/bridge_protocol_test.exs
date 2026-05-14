defmodule MeshxMobileApp.BLE.BridgeProtocolTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{BridgeProtocol, Capabilities, MessageEnvelope}
  alias MeshxMobileApp.BLE.Events

  defp envelope(opts \\ []) do
    {:ok, envelope} =
      MessageEnvelope.build(
        Keyword.merge(
          [
            message_id: <<1::128>>,
            sender_peer_id: "meshx-alpha",
            recipient_peer_id: "meshx-beta",
            created_at: 1_700_000_000_000,
            ttl: 1,
            payload_type: "TX",
            payload: "hi",
            capability_requirements: 0
          ],
          opts
        )
      )

    envelope
  end

  defp message_advertisement(envelope) do
    payload = MessageEnvelope.encode(envelope)
    <<2, 0x01, 0x06, byte_size(payload) + 3, 0xFF, 0xFF, 0xFF, payload::binary>>
  end

  describe "event contracts" do
    test "ReceivedMessage enforces every M24 canonical field" do
      envelope = envelope()

      attrs = %{
        message_id: envelope.message_id,
        sender_peer_id: envelope.sender_peer_id,
        recipient_peer_id: envelope.recipient_peer_id,
        received_device_id: "AA:BB",
        received_at: 500,
        rssi: -50,
        envelope: envelope,
        raw_transport_metadata: %{}
      }

      assert %Events.ReceivedMessage{} = struct!(Events.ReceivedMessage, attrs)

      for key <- Map.keys(attrs) do
        assert_raise ArgumentError, ~r/the following keys must also be given/, fn ->
          struct!(Events.ReceivedMessage, Map.delete(attrs, key))
        end
      end
    end
  end

  describe "v1 wire format decode" do
    test "device_discovered" do
      msg = %{
        v: 1,
        event: "device_discovered",
        device_id: "dev-1",
        rssi: -60,
        advertisement: <<1, 2, 3>>,
        observed_at_ms: 1000
      }

      assert {:ok, %Events.DeviceDiscovered{} = e} = BridgeProtocol.decode(msg)
      assert e.device_id == "dev-1"
      assert e.transport == :ble
      assert e.rssi == -60
      assert e.advertisement == <<1, 2, 3>>
    end

    test "device_lost" do
      assert {:ok, %Events.DeviceLost{device_id: "dev-1", transport: :ble}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "device_lost",
                 device_id: "dev-1",
                 observed_at_ms: 2
               })
    end

    test "advertisement_received" do
      assert {:ok, %Events.AdvertisementReceived{device_id: "d", rssi: -70}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "advertisement_received",
                 device_id: "d",
                 rssi: -70,
                 advertisement: <<>>,
                 observed_at_ms: 3
               })
    end

    test "connection_state_changed with valid state" do
      assert {:ok, %Events.ConnectionStateChanged{state: :connected, device_id: "d"}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "connection_state_changed",
                 device_id: "d",
                 state: "connected"
               })
    end

    test "connection_state_changed with unknown state errors" do
      assert {:error, {:unknown_connection_state, "bogus"}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "connection_state_changed",
                 device_id: "d",
                 state: "bogus"
               })
    end

    test "peer_authenticated carries both ids and capabilities" do
      msg = %{
        v: 1,
        event: "peer_authenticated",
        peer_id: "peer-x",
        device_id: "dev-1",
        capabilities: %{version: 1, roles: ["central", "peripheral"], features: []}
      }

      assert {:ok, %Events.PeerAuthenticated{} = e} = BridgeProtocol.decode(msg)
      assert e.peer_id == "peer-x"
      assert e.device_id == "dev-1"
      assert Capabilities.has_role?(e.capabilities, :central)
      assert Capabilities.has_role?(e.capabilities, :peripheral)
    end

    test "message_received uses peer_id, not device_id" do
      assert {:ok, %Events.MessageReceived{peer_id: "p", payload: <<7, 8>>}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "message_received",
                 peer_id: "p",
                 payload: <<7, 8>>,
                 received_at_ms: 0
               })
    end

    test "advertisement_received carrying an M14 envelope becomes ReceivedMessage" do
      envelope = envelope()

      assert {:ok, %Events.ReceivedMessage{} = e} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "advertisement_received",
                 device_id: "AA:BB:CC:DD:EE:01",
                 rssi: -61,
                 advertisement: message_advertisement(envelope),
                 observed_at_ms: 12_345
               })

      assert e.message_id == envelope.message_id
      assert e.sender_peer_id == "meshx-alpha"
      assert e.recipient_peer_id == "meshx-beta"
      assert e.received_device_id == "AA:BB:CC:DD:EE:01"
      assert e.received_at == 12_345
      assert e.envelope == envelope
    end

    test "malformed MeshX message advertisement becomes tagged Error event" do
      bad = <<2, 0x01, 0x06, 9, 0xFF, 0xFF, 0xFF, "MX", 1, 0, 1, 2, 3>>

      assert {:ok, %Events.Error{} = e} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "advertisement_received",
                 device_id: "AA:BB",
                 rssi: -70,
                 advertisement: bad,
                 observed_at_ms: 0
               })

      assert e.device_id == "AA:BB"
      assert e.kind == :unknown
      assert e.detail =~ "message_advertisement_decode_error"
      assert e.detail =~ "truncated_envelope"
    end

    test "received_message rejects top-level fields that disagree with envelope" do
      envelope = envelope()

      base = %{
        v: 1,
        event: "received_message",
        message_id: envelope.message_id,
        sender_peer_id: envelope.sender_peer_id,
        recipient_peer_id: envelope.recipient_peer_id,
        received_device_id: "AA:BB",
        received_at: 500,
        rssi: -50,
        envelope: MessageEnvelope.encode(envelope),
        raw_transport_metadata: %{}
      }

      for {key, value} <- [
            message_id: <<2::128>>,
            sender_peer_id: "meshx-wrong",
            recipient_peer_id: nil
          ] do
        assert {:error,
                {:received_message_decode_error, {:received_message_field_mismatch, ^key}}} =
                 base
                 |> Map.put(key, value)
                 |> BridgeProtocol.decode()
      end
    end

    test "received_message requires every M24 wire field" do
      envelope = envelope()

      base = %{
        v: 1,
        event: "received_message",
        message_id: envelope.message_id,
        sender_peer_id: envelope.sender_peer_id,
        recipient_peer_id: envelope.recipient_peer_id,
        received_device_id: "AA:BB",
        received_at: 500,
        rssi: -50,
        envelope: MessageEnvelope.encode(envelope),
        raw_transport_metadata: %{}
      }

      for key <- [
            :message_id,
            :sender_peer_id,
            :recipient_peer_id,
            :received_device_id,
            :received_at,
            :rssi,
            :envelope,
            :raw_transport_metadata
          ] do
        assert {:error, {:received_message_decode_error, {:received_message_missing_field, ^key}}} =
                 base
                 |> Map.delete(key)
                 |> BridgeProtocol.decode()
      end
    end

    test "received_message rejects non-map raw transport metadata" do
      envelope = envelope()

      assert {:error, {:received_message_decode_error, :invalid_raw_transport_metadata}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "received_message",
                 message_id: envelope.message_id,
                 sender_peer_id: envelope.sender_peer_id,
                 recipient_peer_id: envelope.recipient_peer_id,
                 received_device_id: "AA:BB",
                 received_at: 500,
                 rssi: -50,
                 envelope: MessageEnvelope.encode(envelope),
                 raw_transport_metadata: "not metadata"
               })
    end

    test "received_message rejects invalid M24 wire field types" do
      envelope = envelope()

      base = %{
        v: 1,
        event: "received_message",
        message_id: envelope.message_id,
        sender_peer_id: envelope.sender_peer_id,
        recipient_peer_id: envelope.recipient_peer_id,
        received_device_id: "AA:BB",
        received_at: 500,
        rssi: -50,
        envelope: MessageEnvelope.encode(envelope),
        raw_transport_metadata: %{}
      }

      for {key, value} <- [
            message_id: "not sixteen bytes",
            sender_peer_id: 123,
            recipient_peer_id: 123,
            received_device_id: 123,
            received_at: "500",
            rssi: "-50",
            envelope: 123
          ] do
        assert {:error, {:received_message_decode_error, {:received_message_invalid_field, ^key}}} =
                 base
                 |> Map.put(key, value)
                 |> BridgeProtocol.decode()
      end
    end

    test "error coerces unknown kind strings to :unknown" do
      assert {:ok, %Events.Error{kind: :unknown, detail: "boom"}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "error",
                 kind: "definitely_not_a_real_kind",
                 detail: "boom"
               })
    end

    test "advert_gossip_outcome decodes canonical Android gossip execution evidence" do
      assert {:ok, %Events.AdvertGossipOutcome{} = event} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "advert_gossip_outcome",
                 gossip_intent_id: "gossip-0",
                 message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
                 sender_peer_id_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
                 advertise_as: "legacy_beacon_advert",
                 kind: "gossiped",
                 reason: nil,
                 adapter: "ble_android",
                 outcome_at_ms: 123
               })

      assert event.kind == :gossiped
      assert event.advertise_as == :legacy_beacon_advert
      assert event.adapter == :ble_android
    end

    test "error preserves known kind atoms" do
      assert {:ok, %Events.Error{kind: :bluetooth_off}} =
               BridgeProtocol.decode(%{
                 v: 1,
                 event: "error",
                 kind: "bluetooth_off",
                 detail: ""
               })
    end

    test "unknown event tag errors" do
      assert {:error, {:unknown_event_tag, "nope"}} =
               BridgeProtocol.decode(%{v: 1, event: "nope"})
    end

    test "unsupported wire version errors" do
      assert {:error, {:unsupported_wire_version, 99}} =
               BridgeProtocol.decode(%{v: 99, event: "device_discovered"})
    end

    test "string-keyed wire maps are accepted" do
      assert {:ok, %Events.DeviceDiscovered{device_id: "d"}} =
               BridgeProtocol.decode(%{
                 "v" => 1,
                 "event" => "device_discovered",
                 "device_id" => "d",
                 "rssi" => -50,
                 "advertisement" => <<>>,
                 "observed_at_ms" => 0
               })
    end
  end

  describe "legacy NIF tuples (TODO: remove when NIF emits v1)" do
    test "{:connected, device_id} → ConnectionStateChanged" do
      assert {:ok, %Events.ConnectionStateChanged{state: :connected, device_id: "x"}} =
               BridgeProtocol.decode({:connected, "x"})
    end

    test "{:disconnected, device_id} → ConnectionStateChanged" do
      assert {:ok, %Events.ConnectionStateChanged{state: :disconnected, device_id: "x"}} =
               BridgeProtocol.decode({:disconnected, "x"})
    end

    test "{:received, peer_id, packet} → MessageReceived (payload size only)" do
      assert {:ok, %Events.MessageReceived{peer_id: "p"}} =
               BridgeProtocol.decode({:received, "p", %{type: :data, msg_id: 1, bytes: 4}})
    end

    test "{:error, atom} → canonical Error" do
      assert {:ok, %Events.Error{kind: :bluetooth_off}} =
               BridgeProtocol.decode({:error, :bluetooth_off})
    end

    test "{:status, _} is no longer in the contract" do
      assert {:error, :status_not_in_contract} =
               BridgeProtocol.decode({:status, "anything"})
    end
  end

  describe "encode round-trip" do
    test "DeviceDiscovered survives encode → decode" do
      e = %Events.DeviceDiscovered{
        device_id: "d",
        transport: :ble,
        rssi: -60,
        advertisement: <<1>>,
        observed_at_ms: 5
      }

      assert {:ok, ^e} = e |> BridgeProtocol.encode() |> BridgeProtocol.decode()
    end

    test "ConnectionStateChanged survives encode → decode" do
      e = %Events.ConnectionStateChanged{
        device_id: "d",
        transport: :ble,
        state: :disconnected,
        reason: nil
      }

      assert {:ok, ^e} = e |> BridgeProtocol.encode() |> BridgeProtocol.decode()
    end

    test "ReceivedMessage survives encode → decode" do
      envelope = envelope()
      message_payload = MessageEnvelope.encode(envelope)

      e = %Events.ReceivedMessage{
        message_id: envelope.message_id,
        sender_peer_id: envelope.sender_peer_id,
        recipient_peer_id: envelope.recipient_peer_id,
        received_device_id: "AA:BB",
        received_at: 500,
        rssi: -50,
        envelope: envelope,
        raw_transport_metadata: %{
          transport: :ble_advertisement,
          source_event: :advertisement_received,
          received_device_id: "AA:BB",
          advertisement:
            <<2, 0x01, 0x06, byte_size(message_payload) + 3, 0xFF, 0xFF, 0xFF,
              message_payload::binary>>,
          message_payload: message_payload,
          manufacturer_data: <<0xFF, 0xFF, message_payload::binary>>,
          company_identifier: 65_535,
          ad_type: 255
        }
      }

      assert {:ok, ^e} = e |> BridgeProtocol.encode() |> BridgeProtocol.decode()
    end

    test "AdvertGossipOutcome survives encode → decode" do
      e = %Events.AdvertGossipOutcome{
        gossip_intent_id: "gossip-0",
        message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
        sender_peer_id_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
        advertise_as: :legacy_beacon_advert,
        kind: :gossiped,
        reason: nil,
        adapter: :ble_android,
        outcome_at_ms: 123
      }

      assert {:ok, ^e} = e |> BridgeProtocol.encode() |> BridgeProtocol.decode()
    end
  end

  test "wire_version is exposed for native parity" do
    assert BridgeProtocol.wire_version() == 1
  end
end
