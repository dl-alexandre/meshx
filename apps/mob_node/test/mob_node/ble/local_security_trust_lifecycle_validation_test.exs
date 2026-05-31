defmodule Mob.Node.BLE.LocalSecurityTrustLifecycleValidationTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalSecurityTrustLifecycleValidation

  test "snapshot runs every required trust lifecycle validation case" do
    snapshot = LocalSecurityTrustLifecycleValidation.snapshot()

    assert snapshot.boundary == :local_security_trust_lifecycle_validation
    assert snapshot.case_count == 6
    assert snapshot.passed_count == 6
    assert snapshot.failed_count == 0
    assert snapshot.missing_case_ids == []
    assert snapshot.all_required_cases_present?
    assert snapshot.all_cases_passed?
    refute snapshot.persistent_trust_store_complete?
    refute snapshot.key_rotation_complete?
    refute snapshot.revocation_lifecycle_complete?
    refute snapshot.trusted_delivery_claim_allowed?
  end

  test "new keys do not inherit trust from an old trusted key" do
    snapshot = LocalSecurityTrustLifecycleValidation.snapshot()

    new_key = case_result(snapshot, :new_key_starts_unknown)
    assert new_key.expected_state == :unknown
    assert new_key.actual_state == :unknown
    refute new_key.trusted_peer_state?

    rotation = case_result(snapshot, :old_key_trust_does_not_transfer)
    assert rotation.expected_state == :unknown
    assert rotation.actual_state == :unknown
    refute rotation.trusted_peer_state?
  end

  test "successor trust requires explicit operator policy" do
    snapshot = LocalSecurityTrustLifecycleValidation.snapshot()

    successor = case_result(snapshot, :explicit_successor_key_can_be_trusted)
    assert successor.expected_state == :trusted
    assert successor.actual_state == :trusted
    assert successor.trusted_peer_state?
    assert :trusted_delivery in successor.blocked_claims
  end

  test "blocked and revoked states fail closed" do
    snapshot = LocalSecurityTrustLifecycleValidation.snapshot()

    blocked = case_result(snapshot, :blocked_key_fails_closed)
    assert blocked.expected_state == :blocked
    assert blocked.actual_state == :blocked
    refute blocked.trusted_peer_state?

    revoked = case_result(snapshot, :revoked_key_fails_closed)
    assert revoked.expected_state == :revoked
    assert revoked.actual_state == :revoked
    refute revoked.trusted_peer_state?
  end

  test "passive observations cannot rotate or enroll keys" do
    snapshot = LocalSecurityTrustLifecycleValidation.snapshot()

    passive = case_result(snapshot, :passive_observation_cannot_rotate_key)
    assert passive.expected_state == :passive_observation_not_enrollment
    assert passive.actual_state == :passive_observation_not_enrollment
    refute passive.trusted_peer_state?
  end

  test "JSON snapshot preserves blocked delivery claims" do
    snapshot = LocalSecurityTrustLifecycleValidation.json_snapshot()

    assert snapshot["boundary"] == "local_security_trust_lifecycle_validation"
    assert snapshot["all_cases_passed?"] == true
    assert snapshot["trusted_delivery_claim_allowed?"] == false
    assert "trusted_delivery" in snapshot["blocked_claims"]
  end

  defp case_result(snapshot, id), do: Enum.find(snapshot.cases, &(&1.id == id))
end
