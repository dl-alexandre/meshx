defmodule Mob.Node.BLE.LocalSecurityReplayLifecycleValidationTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalSecurityReplayLifecycleValidation

  test "snapshot runs every memory-only replay lifecycle case" do
    snapshot = LocalSecurityReplayLifecycleValidation.snapshot()

    assert snapshot.boundary == :memory_only_replay_lifecycle_validation
    assert snapshot.case_count == 5
    assert snapshot.passed_count == 5
    assert snapshot.failed_count == 0
    assert snapshot.missing_case_ids == []
    assert snapshot.all_required_cases_present?
    assert snapshot.all_cases_passed?
    refute snapshot.durable_replay_state_allowed?
    refute snapshot.restart_surviving_replay_protection_claim_allowed?
    refute snapshot.trusted_delivery_claim_allowed?
  end

  test "duplicates are rejected only inside one in-memory state" do
    snapshot = LocalSecurityReplayLifecycleValidation.snapshot()

    duplicate = case_result(snapshot, :duplicate_rejected_in_memory)
    assert duplicate.expected == :duplicate_proof
    assert duplicate.actual == :duplicate_proof
    refute duplicate.durable_replay_state?
  end

  test "restart behavior is explicit clearing of replay state" do
    snapshot = LocalSecurityReplayLifecycleValidation.snapshot()

    restart = case_result(snapshot, :restart_clears_replay_state)
    assert restart.expected == :empty_seen
    assert restart.actual == []
    refute restart.durable_replay_state?
  end

  test "expired envelopes and beacon refs do not become replay-protected delivery" do
    snapshot = LocalSecurityReplayLifecycleValidation.snapshot()

    expired = case_result(snapshot, :expired_envelope_rejected)
    assert expired.actual == :expired_envelope
    refute expired.trusted_delivery_claim_allowed?

    beacon = case_result(snapshot, :beacon_ref_outside_replay_guard)
    assert beacon.actual == :invalid_envelope
    refute beacon.trusted_delivery_claim_allowed?
  end

  test "JSON snapshot preserves blocked replay lifecycle claims" do
    snapshot = LocalSecurityReplayLifecycleValidation.json_snapshot()

    assert snapshot["boundary"] == "memory_only_replay_lifecycle_validation"
    assert snapshot["all_cases_passed?"] == true
    assert snapshot["durable_replay_state_allowed?"] == false
    assert "restart_surviving_replay_protection" in snapshot["blocked_claims"]
  end

  defp case_result(snapshot, id), do: Enum.find(snapshot.cases, &(&1.id == id))
end
