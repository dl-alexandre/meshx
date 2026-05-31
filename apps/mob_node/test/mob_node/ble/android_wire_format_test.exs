defmodule Mob.Node.BLE.AndroidWireFormatTest do
  @moduledoc """
  Contract proof: Kotlin emits the same v1 wire format that
  `Mob.Node.BLE.BridgeProtocol.decode/1` understands.

  Fixtures under `test/fixtures/android_wire_v1/` mirror the exact JSON
  shape produced by `dev.mob.mob.ble.BleEvent.toJsonObject()`. JSON
  serializes binary fields as base64 (raw bytes don't survive JSON);
  this test decodes the JSON, base64-decodes the `advertisement` field
  if present, and then runs the result through `BridgeProtocol.decode/1`.

  When BEAM-on-Android lands, the NIF path will deliver the same maps
  with raw binaries (no base64 hop) and the existing `decode/1` path
  takes over verbatim — that's why the bridge protocol is the same on
  both transports.
  """

  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{BridgeProtocol, Events}

  @fixture_dir Path.expand("../../fixtures/android_wire_v1", __DIR__)

  defp load(name) do
    @fixture_dir
    |> Path.join(name)
    |> File.read!()
    |> :json.decode()
    |> json_transport_to_native()
  end

  # JSON carries binaries as base64 strings. The NIF transport carries
  # them as raw binaries. Both decode through `BridgeProtocol.decode/1`,
  # so the JSON-side test just performs the base64 → binary step before
  # handing off — that step is the transport adapter, not the contract.
  defp json_transport_to_native(map) do
    map
    |> Map.replace_lazy("advertisement", fn s when is_binary(s) -> Base.decode64!(s) end)
    |> Map.replace_lazy("message_id", fn s when is_binary(s) -> Base.decode64!(s) end)
    |> Map.replace_lazy("envelope", fn s when is_binary(s) -> Base.decode64!(s) end)
    |> decode_raw_transport_metadata()
  end

  defp decode_raw_transport_metadata(%{"raw_transport_metadata" => %{} = metadata} = map) do
    decoded =
      Enum.reduce(["advertisement", "message_payload", "manufacturer_data"], metadata, fn key,
                                                                                          acc ->
        case Map.get(acc, key) do
          s when is_binary(s) -> Map.put(acc, key, Base.decode64!(s))
          _ -> acc
        end
      end)

    Map.put(map, "raw_transport_metadata", decoded)
  end

  defp decode_raw_transport_metadata(map), do: map

  test "device_discovered fixture decodes to canonical event" do
    msg = load("device_discovered.json")

    assert {:ok, %Events.DeviceDiscovered{} = e} = BridgeProtocol.decode(msg)
    assert e.device_id == "AA:BB:CC:DD:EE:01"
    assert e.transport == :ble
    assert e.rssi == -55
    assert e.advertisement == <<0x02, 0x01, 0x06>>
    assert e.observed_at_ms == 12345
  end

  test "advertisement_received fixture decodes to canonical event" do
    msg = load("advertisement_received.json")

    assert {:ok, %Events.AdvertisementReceived{} = e} = BridgeProtocol.decode(msg)
    assert e.device_id == "AA:BB:CC:DD:EE:02"
    assert e.rssi == -70
    assert e.advertisement == <<>>
    assert e.observed_at_ms == 99
  end

  test "error fixture decodes to canonical Error with closed-taxonomy kind" do
    msg =
      "error_scan_failed.json"
      |> then(&Path.join(@fixture_dir, &1))
      |> File.read!()
      |> :json.decode()

    assert {:ok, %Events.Error{kind: :scan_failed, detail: "scan failed (code=3)"}} =
             BridgeProtocol.decode(msg)
  end

  test "received_message fixture decodes to canonical ReceivedMessage" do
    msg = load("received_message.json")

    assert {:ok, %Events.ReceivedMessage{} = e} = BridgeProtocol.decode(msg)
    assert e.message_id == <<1::128>>
    assert e.sender_peer_id == "meshx-alpha"
    assert e.recipient_peer_id == "meshx-beta"
    assert e.received_device_id == "AA:BB:CC:DD:EE:01"
    assert e.received_at == 12345
    assert e.rssi == -61
    assert e.envelope.payload == "hi"
    assert e.raw_transport_metadata.advertisement != <<>>
    assert e.raw_transport_metadata.manufacturer_data != <<>>

    assert e.raw_transport_metadata.message_payload ==
             Mob.Node.BLE.MessageEnvelope.encode(e.envelope)

    assert e.raw_transport_metadata.manufacturer_data ==
             <<0xFF, 0xFF, e.raw_transport_metadata.message_payload::binary>>

    assert e.raw_transport_metadata.company_identifier == 65_535
    assert e.raw_transport_metadata.ad_type == 255
  end
end
