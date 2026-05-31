defmodule Mob.Node.BLE.MessageAdvertisementTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.Events.{AdvertisementReceived, ReceivedMessage}
  alias Mob.Node.BLE.{MessageAdvertisement, MessageEnvelope}

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

  defp scan_record(message_payload) do
    manufacturer_len = byte_size(message_payload) + 3
    <<2, 0x01, 0x06, manufacturer_len, 0xFF, 0xFF, 0xFF, message_payload::binary>>
  end

  defp manufacturer_structure(message_payload) do
    manufacturer_len = byte_size(message_payload) + 3
    <<manufacturer_len, 0xFF, 0xFF, 0xFF, message_payload::binary>>
  end

  test "extracts and parses an M14 envelope from manufacturer data" do
    envelope = envelope()
    advertisement = scan_record(MessageEnvelope.encode(envelope))

    event = %AdvertisementReceived{
      device_id: "AA:BB:CC:DD:EE:01",
      rssi: -61,
      advertisement: advertisement,
      observed_at_ms: 12_345
    }

    assert {:ok, %ReceivedMessage{} = received} = MessageAdvertisement.decode(event)
    assert received.message_id == envelope.message_id
    assert received.sender_peer_id == "meshx-alpha"
    assert received.recipient_peer_id == "meshx-beta"
    assert received.received_device_id == "AA:BB:CC:DD:EE:01"
    assert received.received_at == 12_345
    assert received.rssi == -61
    assert received.envelope == envelope
    assert received.raw_transport_metadata.advertisement == advertisement
    assert received.raw_transport_metadata.message_payload == MessageEnvelope.encode(envelope)
  end

  test "ordinary advertisements are ignored" do
    event = %AdvertisementReceived{
      device_id: "AA:BB",
      rssi: -70,
      advertisement: <<2, 0x01, 0x06>>,
      observed_at_ms: 0
    }

    assert :not_message_advertisement = MessageAdvertisement.decode(event)
  end

  test "malformed MeshX message advertisements return tagged decode errors" do
    event = %AdvertisementReceived{
      device_id: "AA:BB",
      rssi: -70,
      advertisement: scan_record(<<"MX", 1, 0, 1, 2, 3>>),
      observed_at_ms: 0
    }

    assert {:error, {:message_advertisement_decode_error, :truncated_envelope}} =
             MessageAdvertisement.decode(event)
  end

  test "truncated MeshX advertisement structures return tagged decode errors" do
    advertisement = scan_record(<<"MX", 1, 0, 1, 2, 3>>) |> binary_part(0, 12)

    event = %AdvertisementReceived{
      device_id: "AA:BB",
      rssi: -70,
      advertisement: advertisement,
      observed_at_ms: 0
    }

    assert {:error, {:message_advertisement_decode_error, :truncated_ad_structure}} =
             MessageAdvertisement.decode(event)
  end

  test "first valid MeshX message structure wins over a later truncated MeshX structure" do
    envelope = envelope()
    valid = manufacturer_structure(MessageEnvelope.encode(envelope))
    truncated = manufacturer_structure(<<"MX", 1, 0, 1, 2, 3>>) |> binary_part(0, 8)
    advertisement = <<2, 0x01, 0x06, valid::binary, truncated::binary>>

    event = %AdvertisementReceived{
      device_id: "AA:BB:CC:DD:EE:01",
      rssi: -61,
      advertisement: advertisement,
      observed_at_ms: 12_345
    }

    assert {:ok, %ReceivedMessage{} = received} = MessageAdvertisement.decode(event)
    assert received.envelope == envelope
    assert received.raw_transport_metadata.advertisement == advertisement
  end
end
