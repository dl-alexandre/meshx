defmodule Mob.Node.BLE.BeaconResolverTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.Events.ReceivedMessageBeacon
  alias Mob.Node.BLE.{BeaconRef, BeaconResolver, MessageEnvelope}

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

  defp beacon_event(envelope, opts \\ []) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: envelope.envelope_version,
      payload_kind: envelope.payload_type,
      message_id_hash: BeaconRef.message_id_hash(envelope),
      sender_peer_id_hash: BeaconRef.sender_peer_hash(envelope),
      received_device_id: Keyword.get(opts, :received_device_id, "AA:BB:CC"),
      received_at: Keyword.get(opts, :received_at, 12_345),
      rssi: Keyword.get(opts, :rssi, -58),
      raw_transport_metadata: %{}
    }
  end

  test "known beacon resolves to an already cached envelope" do
    envelope = envelope()
    assert {:ok, ref} = BeaconRef.from_event(beacon_event(envelope))

    assert {:already_known, ^envelope} = BeaconResolver.resolve(ref, [envelope])
  end

  test "unknown beacon returns a fetch request without claiming delivery" do
    envelope = envelope()
    assert {:ok, ref} = BeaconRef.from_event(beacon_event(envelope))

    assert {:needs_fetch, request} = BeaconResolver.resolve(ref, [])
    assert request.message_id_hash == ref.message_id_hash
    assert request.sender_peer_hash == ref.sender_peer_hash
    assert request.observed_at == 12_345
    assert request.received_device_id == "AA:BB:CC"
    assert request.rssi == -58
  end

  test "malformed beacon refs are unresolvable" do
    assert {:unresolvable, {:invalid_beacon_ref, :invalid_message_id_hash}} =
             BeaconResolver.resolve(
               BeaconRef.new(
                 envelope_version: 1,
                 payload_kind: "TX",
                 message_id_hash: <<1, 2>>,
                 sender_peer_hash: <<0::64>>,
                 observed_at: 1,
                 received_device_id: "AA",
                 rssi: -50
               ),
               []
             )
  end

  test "matching message hash with mismatched sender hash is unresolvable" do
    envelope = envelope()
    assert {:ok, ref} = BeaconRef.from_event(beacon_event(envelope))
    mismatched = %{ref | sender_peer_hash: <<255::64>>}

    assert {:unresolvable, :hash_mismatch} =
             BeaconResolver.resolve(mismatched, %{envelopes: [envelope]})
  end
end
