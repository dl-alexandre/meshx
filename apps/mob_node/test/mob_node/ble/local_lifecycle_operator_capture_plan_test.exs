defmodule Mob.Node.BLE.LocalLifecycleOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalLifecycleOperatorCapturePlan

  test "snapshot exposes lifecycle capture plan without enabling background claims" do
    plan = LocalLifecycleOperatorCapturePlan.snapshot()

    assert plan.boundary == :local_lifecycle_operator_capture_plan
    assert plan.status == :open
    assert plan.current_mode == :foreground_manual
    assert plan.current_lifecycle_decision.decision_outcome == :keep_foreground_manual
    refute plan.android_foreground_service_claim_allowed?
    refute plan.android_background_ble_claim_allowed?
    refute plan.ios_background_claim_allowed?
    refute plan.background_ble_claim_allowed?
    refute plan.restart_claim_allowed?
    refute plan.scheduled_retry_claim_allowed?
    refute plan.background_gossip_claim_allowed?
    refute plan.delivery_claim_allowed?
  end

  test "capture sections cover every lifecycle hardware gate" do
    plan = LocalLifecycleOperatorCapturePlan.snapshot()
    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert [
             :target_device_matrix,
             :android_foreground_service_backgrounding,
             :android_background_ble_policy,
             :ios_background_ble_policy,
             :restart_and_cancellation,
             :scheduled_retry_bounds,
             :background_gossip_limits,
             :negative_claim_review
           ] -- section_ids == []

    assert plan.required_gates -- section_ids == []
    assert length(plan.capture_sections) == 8
  end

  test "each section has review fields evidence type and blocked claims" do
    plan = LocalLifecycleOperatorCapturePlan.snapshot()

    for section <- plan.capture_sections do
      assert :artifact_path in section.required_entries
      assert :summary in section.required_entries
      assert :test_command in section.required_entries
      assert :evidence_type in section.required_entries
      assert :blocked_claims_called_out in section.required_entries
      assert section.evidence_type == Map.fetch!(plan.required_evidence_types, section.id)
      assert plan.required_blocked_claims -- section.blocked_claims_called_out == []
      assert section.gate_specific_blocked_claims_called_out != []
    end
  end

  test "restart retry and background gossip sections preserve lifecycle boundaries" do
    plan = LocalLifecycleOperatorCapturePlan.snapshot()
    restart = Enum.find(plan.capture_sections, &(&1.id == :restart_and_cancellation))
    retry = Enum.find(plan.capture_sections, &(&1.id == :scheduled_retry_bounds))
    gossip = Enum.find(plan.capture_sections, &(&1.id == :background_gossip_limits))

    assert restart.evidence_type == :restart_cancellation_fixture
    assert retry.evidence_type == :scheduled_retry_fixture
    assert gossip.evidence_type == :background_gossip_limits_fixture
    assert Enum.any?(restart.notes, &String.contains?(&1, "denied-permission"))
    assert Enum.any?(retry.notes, &String.contains?(&1, "no-guaranteed-delivery"))
    assert Enum.any?(gossip.notes, &String.contains?(&1, "rate limits"))
  end

  test "JSON snapshot is archiveable" do
    plan = LocalLifecycleOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "local_lifecycle_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 8
    assert plan["background_ble_claim_allowed?"] == false
  end
end
