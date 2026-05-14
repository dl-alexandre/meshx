defmodule MeshxMobileApp.BLE.LocalSecurityAcceptanceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalSecurityAcceptance, MessageEnvelope}
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

  defp inbox_snapshot do
    LocalInbox.new()
    |> LocalInbox.ingest(full_event())
    |> LocalInbox.ingest(beacon_event())
    |> LocalInbox.snapshot()
  end

  test "snapshot records current satisfied claim gates and blocked future security gates" do
    acceptance = LocalSecurityAcceptance.snapshot(inbox_snapshot())

    assert acceptance.boundary == :current_unsigned_local_ble_security
    assert acceptance.satisfied_count == 20
    assert acceptance.blocked_count == 4
    refute acceptance.authenticated_peer_identity_claim_allowed?
    refute acceptance.trusted_message_claim_allowed?
    refute acceptance.trusted_delivery_claim_allowed?
    refute acceptance.replay_protection_claim_allowed?

    assert [
             %{id: :current_trust_policy, status: :satisfied},
             %{id: :future_security_contract, status: :satisfied},
             %{id: :trust_transition_model, status: :satisfied},
             %{id: :negative_security_validation, status: :satisfied},
             %{id: :crypto_negative_validation_boundary, status: :satisfied},
             %{id: :security_identity_validation_plan, status: :satisfied},
             %{id: :security_fixture_audit, status: :satisfied},
             %{id: :peer_enrollment_boundary, status: :satisfied},
             %{id: :authorship_verifier_boundary, status: :satisfied},
             %{id: :peer_identity_binding_boundary, status: :satisfied},
             %{id: :replay_guard_boundary, status: :satisfied},
             %{id: :replay_lifecycle_policy_boundary, status: :satisfied},
             %{id: :replay_lifecycle_validation_boundary, status: :satisfied},
             %{id: :trusted_message_decision_boundary, status: :satisfied},
             %{id: :canonical_replay_decision_boundary, status: :satisfied},
             %{id: :operator_trust_policy_boundary, status: :satisfied},
             %{id: :trust_lifecycle_plan_boundary, status: :satisfied},
             %{id: :trust_lifecycle_validation_boundary, status: :satisfied},
             %{id: :security_release_evidence_review_boundary, status: :satisfied},
             %{id: :beacon_authentication_boundary, status: :satisfied},
             %{id: :authenticated_peer_identity, status: :blocked},
             %{id: :message_authorship, status: :blocked},
             %{id: :replay_protection, status: :blocked},
             %{id: :beacon_ref_authentication, status: :blocked}
           ] = acceptance.gates
  end

  test "blocked security gates carry concrete missing evidence" do
    acceptance = LocalSecurityAcceptance.snapshot(inbox_snapshot())

    identity = Enum.find(acceptance.gates, &(&1.id == :authenticated_peer_identity))
    authorship = Enum.find(acceptance.gates, &(&1.id == :message_authorship))
    replay = Enum.find(acceptance.gates, &(&1.id == :replay_protection))
    beacon = Enum.find(acceptance.gates, &(&1.id == :beacon_ref_authentication))

    assert Enum.any?(identity.missing, &String.contains?(&1, "cryptographic key material"))
    assert Enum.any?(authorship.missing, &String.contains?(&1, "authorship proof"))
    assert Enum.any?(replay.missing, &String.contains?(&1, "stale or replayed signed envelopes"))
    assert Enum.any?(beacon.missing, &String.contains?(&1, "hash-only beacon"))
  end

  test "local inbox snapshot exposes security acceptance without promoting trust" do
    snapshot = inbox_snapshot()

    assert %{security_acceptance: acceptance} = snapshot
    assert acceptance.satisfied_count == 20
    assert acceptance.blocked_count == 4
    refute acceptance.trusted_delivery_claim_allowed?
  end

  test "JSON snapshot preserves blocked trusted claims" do
    snapshot = LocalSecurityAcceptance.json_snapshot(inbox_snapshot())

    assert snapshot["boundary"] == "current_unsigned_local_ble_security"
    assert snapshot["trusted_message_claim_allowed?"] == false
    assert snapshot["trusted_delivery_claim_allowed?"] == false
    assert "trusted_message" in snapshot["blocked_claims"]

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "message_authorship" and &1["status"] == "blocked")
           )
  end
end
