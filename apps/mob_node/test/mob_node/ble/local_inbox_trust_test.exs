defmodule Mob.Node.BLE.LocalInboxTrustTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalInbox, LocalInboxTrust, LocalInboxView, MessageEnvelope}
  alias Mob.Node.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  defp envelope do
    {:ok, envelope} =
      MessageEnvelope.build(
        message_id: <<1::128>>,
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: "meshx-beta",
        created_at: 1_700_000_000_000,
        ttl: 1,
        payload_type: "TX",
        payload: "hello",
        capability_requirements: 0
      )

    envelope
  end

  defp full_event(received_at \\ 10) do
    env = envelope()

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: received_at,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event(opts \\ []) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: Keyword.get(opts, :message_id_hash, <<1, 2, 3, 4, 5, 6, 7, 8>>),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_id_hash, <<8, 7, 6, 5, 4, 3, 2, 1>>),
      received_device_id: "AA:02",
      received_at: Keyword.get(opts, :received_at, 10),
      rssi: -70,
      raw_transport_metadata: Keyword.get(opts, :raw_transport_metadata, %{})
    }
  end

  test "classifies full advert messages as unsigned observations" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.snapshot()

    assert [%LocalInboxTrust.Evidence{} = evidence] = snapshot.trust_evidence
    assert evidence.item_state == :full_message
    assert evidence.trust_state == :unsigned_observation
    assert evidence.authorship == :unverified
    assert evidence.integrity == :canonical_envelope_validated
    assert evidence.replay_protection == :none
    assert evidence.resolution_state == :full_envelope_present
    assert :no_signature in evidence.reasons
    assert :no_authenticated_peer_identity in evidence.reasons
  end

  test "classifies beacon refs as untrusted unresolved references" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.snapshot()

    assert [%LocalInboxTrust.Evidence{} = evidence] = snapshot.trust_evidence
    assert evidence.item_state == :unresolved_ref
    assert evidence.trust_state == :untrusted_reference
    assert evidence.authorship == :unverified
    assert evidence.integrity == :hash_reference_only
    assert evidence.resolution_state == :needs_resolution
    assert :full_envelope_absent in evidence.reasons
  end

  test "classifies stale refs distinctly without claiming stronger trust" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(received_at: 1))
      |> LocalInbox.snapshot()

    assert [%LocalInboxView.Item{state: :stale_ref} = stale_item] =
             LocalInboxView.nearby_messages(snapshot, now: 100, stale_after_ms: 10)

    evidence = LocalInboxTrust.classify(stale_item)
    assert evidence.trust_state == :untrusted_reference
    assert evidence.resolution_state == :stale_reference
    assert :stale_observation in evidence.reasons
  end

  test "gossiped refs remain untrusted hash references" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(
        beacon_event(raw_transport_metadata: %{transport: :advert_gossip_simulation})
      )
      |> LocalInbox.snapshot()

    assert [%LocalInboxTrust.Evidence{} = evidence] = snapshot.trust_evidence
    assert evidence.item_state == :gossiped_ref
    assert evidence.trust_state == :untrusted_reference
    assert evidence.integrity == :hash_reference_only
    assert evidence.authorship == :unverified
  end
end
