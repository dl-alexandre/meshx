defmodule MeshxMobileApp.BLE.LocalSecurityIdentityProofPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalSecurityIdentityProofPlan

  test "snapshot maps every open security requirement to planned proof gates" do
    snapshot = LocalSecurityIdentityProofPlan.snapshot()
    ids = Enum.map(snapshot.gates, & &1.requirement_id)

    assert snapshot.plan_version == 1
    assert snapshot.proof_boundary == :future_authenticated_local_ble_messages
    assert snapshot.open_gate_count == 5
    refute snapshot.trusted_delivery_claims_allowed?

    assert :authenticated_peer_identity in ids
    assert :message_authorship in ids
    assert :replay_protection in ids
    assert :trust_policy in ids
    assert :beacon_ref_authentication in ids
  end

  test "message authorship gate binds envelope fields before trusted delivery" do
    assert {:ok, gate} = LocalSecurityIdentityProofPlan.get(:message_authorship)

    assert gate.status == :planned
    assert :signature_or_equivalent_authorship_proof in gate.implementation_gates
    assert :message_id_binding in gate.implementation_gates
    assert :payload_binding in gate.implementation_gates
    assert :authenticated_message in gate.blocked_claims

    assert Enum.any?(
             gate.validation_evidence,
             &String.contains?(&1, "payload_kind, payload, and envelope_version tampering")
           )
  end

  test "replay protection gate requires bounded duplicate and expiry evidence" do
    assert {:ok, gate} = LocalSecurityIdentityProofPlan.get(:replay_protection)

    assert :bounded_replay_window in gate.implementation_gates
    assert :seen_proof_cache in gate.implementation_gates
    assert :fresh_message in gate.blocked_claims

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "duplicate signed envelope"))
    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "expired signed envelope"))
  end

  test "beacon ref authentication cannot skip full envelope proof" do
    assert {:ok, gate} = LocalSecurityIdentityProofPlan.get(:beacon_ref_authentication)

    assert :authenticated_beacon_pointer_or_resolution in gate.implementation_gates
    assert :resolved_envelope_authorship_check in gate.implementation_gates
    assert :trusted_beacon_ref in gate.blocked_claims

    assert Enum.any?(
             gate.validation_evidence,
             &String.contains?(&1, "hash-only beacon is never promoted")
           )
  end

  test "json snapshot is machine readable" do
    snapshot = LocalSecurityIdentityProofPlan.json_snapshot()

    assert snapshot["plan_version"] == 1
    assert snapshot["open_gate_count"] == 5
    assert snapshot["trusted_delivery_claims_allowed?"] == false
    assert Enum.any?(snapshot["gates"], &(&1["requirement_id"] == "message_authorship"))
  end

  test "trust policy gate points to the local trust model while staying planned" do
    assert {:ok, gate} = LocalSecurityIdentityProofPlan.get(:trust_policy)

    assert :local_security_trust_model in gate.implementation_gates
    assert :trust_transition_rules in gate.implementation_gates
    assert :trusted_peer in gate.blocked_claims
  end
end
