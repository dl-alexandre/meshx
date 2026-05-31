defmodule Mob.Node.BLE.LocalSecurityTrustLifecyclePlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalSecurityTrustLifecyclePlan

  test "snapshot records persistent trust lifecycle gates as planned" do
    snapshot = LocalSecurityTrustLifecyclePlan.snapshot()
    ids = Enum.map(snapshot.gates, & &1.id)

    assert snapshot.plan_version == 1
    assert snapshot.boundary == :future_persistent_local_security_trust_lifecycle
    assert snapshot.open_gate_count == 6
    assert snapshot.validation_case_count == 6
    assert snapshot.validation_passed_count == 6
    assert snapshot.validation.all_cases_passed?
    assert snapshot.replay_lifecycle_case_count == 5
    assert snapshot.replay_lifecycle_passed_count == 5
    assert snapshot.replay_lifecycle.all_cases_passed?
    refute snapshot.persistent_trust_store_complete?
    refute snapshot.key_rotation_complete?
    refute snapshot.revocation_lifecycle_complete?
    refute snapshot.trusted_delivery_claim_allowed?

    assert :key_enrollment in ids
    assert :persistent_key_store in ids
    assert :key_rotation in ids
    assert :revocation_lifecycle in ids
    assert :replay_state_lifecycle in ids
    assert :release_audit_export in ids
  end

  test "key enrollment requires explicit operator input and blocks passive discovery" do
    assert {:ok, gate} = LocalSecurityTrustLifecyclePlan.get(:key_enrollment)

    assert gate.status == :planned
    assert :automatic_key_discovery in gate.blocked_claims

    assert Enum.any?(
             gate.required_artifacts,
             &String.contains?(&1, "Operator-visible enrollment action")
           )

    assert Enum.any?(
             gate.validation_evidence,
             &String.contains?(&1, "unknown peer/key remains untrusted")
           )
  end

  test "persistent key store stays separate from supplied in-memory policy" do
    assert {:ok, gate} = LocalSecurityTrustLifecyclePlan.get(:persistent_key_store)

    assert :persistent_trust_store in gate.blocked_claims

    assert Enum.any?(
             gate.required_artifacts,
             &String.contains?(&1, "platform-protected key/trust store policy")
           )

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "fail closed"))
  end

  test "key rotation does not transfer trust across key ids implicitly" do
    assert {:ok, gate} = LocalSecurityTrustLifecyclePlan.get(:key_rotation)

    assert :key_rotation in gate.blocked_claims

    assert Enum.any?(
             gate.required_artifacts,
             &String.contains?(&1, "new key_id starts unknown")
           )

    assert Enum.any?(
             gate.validation_evidence,
             &String.contains?(&1, "old and new key ids distinct")
           )
  end

  test "revocation lifecycle requires audit evidence and future replay blocking" do
    assert {:ok, gate} = LocalSecurityTrustLifecyclePlan.get(:revocation_lifecycle)

    assert :revocation_sync in gate.blocked_claims

    assert Enum.any?(
             gate.required_artifacts,
             &String.contains?(&1, "Operator-visible block/revoke action")
           )

    assert Enum.any?(
             gate.validation_evidence,
             &String.contains?(&1, "Post-revocation replay fixture")
           )
  end

  test "json snapshot is machine readable" do
    snapshot = LocalSecurityTrustLifecyclePlan.json_snapshot()

    assert snapshot["plan_version"] == 1
    assert snapshot["persistent_trust_store_complete?"] == false
    assert snapshot["trusted_delivery_claim_allowed?"] == false
    assert Enum.any?(snapshot["gates"], &(&1["id"] == "key_rotation"))
  end
end
