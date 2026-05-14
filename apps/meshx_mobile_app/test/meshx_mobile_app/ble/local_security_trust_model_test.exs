defmodule MeshxMobileApp.BLE.LocalSecurityTrustModelTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalSecurityTrustModel, MessageEnvelope}
  alias MeshxMobileApp.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

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

  defp full_event do
    env = envelope()

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 10,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
      sender_peer_id_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
      received_device_id: "AA:02",
      received_at: 10,
      rssi: -70,
      raw_transport_metadata: %{}
    }
  end

  test "snapshot records the future trust boundary without enabling current trust" do
    snapshot = LocalSecurityTrustModel.snapshot()

    assert snapshot.model_version == 1
    assert snapshot.boundary == :future_authenticated_local_ble_trust
    assert :trusted in snapshot.peer_states
    refute snapshot.current_observations_trusted?
    refute snapshot.delivery_claims_allowed?
    assert :trusted_message in snapshot.blocked_claims
  end

  test "current full messages remain untrusted without required proof" do
    result = LocalSecurityTrustModel.evaluate(%{item_state: :full_message})

    refute result.trusted_message?
    refute result.delivery_claim_allowed?
    assert :authenticated_peer_identity in result.missing_evidence
    assert :message_authorship in result.missing_evidence
    assert :replay_protection in result.missing_evidence
    assert :trusted_peer_state in result.missing_evidence
  end

  test "hash-only beacon refs require full envelope resolution before trust" do
    result = LocalSecurityTrustModel.evaluate(%{item_state: :unresolved_ref})

    refute result.trusted_message?
    assert :full_envelope_resolution in result.missing_evidence
    assert :hash_sender_binding in result.missing_evidence
    assert :hash_reference_not_authorship in result.reasons
  end

  test "blocked or revoked peer state prevents trust even with supplied proofs" do
    proof = [
      authenticated_peer_identity?: true,
      message_authorship?: true,
      replay_protection?: true,
      peer_trust_state: :revoked
    ]

    result = LocalSecurityTrustModel.evaluate(%{item_state: :full_message}, proof)

    refute result.trusted_message?
    assert result.peer_trust_state == :revoked
    assert :peer_revoked in result.reasons
    assert :trusted_message in result.blocked_claims
  end

  test "synthetic complete full-message proof is the only trusted path" do
    proof = [
      authenticated_peer_identity?: true,
      message_authorship?: true,
      replay_protection?: true,
      peer_trust_state: :trusted
    ]

    result = LocalSecurityTrustModel.evaluate(%{item_state: :full_message}, proof)

    assert result.trusted_message?
    assert result.delivery_claim_allowed?
    assert result.missing_evidence == []
    assert result.blocked_claims == []
  end

  test "local inbox snapshot exposes the trust model next to current untrusted policy" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.snapshot()

    assert snapshot.security_trust_model.boundary == :future_authenticated_local_ble_trust
    refute snapshot.security_trust_model.current_observations_trusted?
    refute snapshot.trust_policy.delivery_claims_allowed?
  end

  test "json snapshot is machine readable" do
    snapshot = LocalSecurityTrustModel.json_snapshot()

    assert snapshot["model_version"] == 1
    assert snapshot["current_observations_trusted?"] == false
    assert "trusted_message" in snapshot["blocked_claims"]
  end
end
