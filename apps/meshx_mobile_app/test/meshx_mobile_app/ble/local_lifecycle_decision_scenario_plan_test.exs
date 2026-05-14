defmodule MeshxMobileApp.BLE.LocalLifecycleDecisionScenarioPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalLifecycleDecisionScenarioPlan

  test "snapshot exposes lifecycle decision scenarios without enabling background claims" do
    plan = LocalLifecycleDecisionScenarioPlan.snapshot()

    assert plan.boundary == :local_lifecycle_decision_scenario_plan
    assert plan.status == :open
    assert plan.selected_decision_outcome == :keep_foreground_manual
    refute plan.android_foreground_service_claim_allowed?
    refute plan.android_background_ble_claim_allowed?
    refute plan.ios_background_ble_claim_allowed?
    refute plan.background_ble_claim_allowed?
    refute plan.restart_claim_allowed?
    refute plan.scheduled_retry_claim_allowed?
    refute plan.background_gossip_claim_allowed?
    refute plan.background_delivery_claim_allowed?
  end

  test "decision scenarios cover foreground/manual and background lifecycle outcomes" do
    plan = LocalLifecycleDecisionScenarioPlan.snapshot()
    outcomes = Enum.map(plan.decision_scenarios, & &1.decision_outcome)

    assert [:keep_foreground_manual, :enable_background_lifecycle] -- outcomes == []

    assert plan.allowed_decision_outcomes == [
             :keep_foreground_manual,
             :enable_background_lifecycle
           ]

    foreground = Enum.find(plan.decision_scenarios, &(&1.id == :keep_foreground_manual))
    background = Enum.find(plan.decision_scenarios, &(&1.id == :enable_background_lifecycle))

    assert foreground.status == :selected_for_current_validated_mode
    assert foreground.lifecycle_mode_after_decision == :foreground_manual
    refute foreground.android_foreground_service_enabled?
    refute foreground.android_background_ble_enabled?
    refute foreground.ios_background_ble_enabled?
    refute foreground.automatic_restart_enabled?
    refute foreground.scheduled_retry_enabled?
    refute foreground.background_gossip_enabled?

    assert background.status == :blocked
    assert background.lifecycle_mode_after_decision == :background_lifecycle
    refute background.android_foreground_service_enabled?
    refute background.android_background_ble_enabled?
    refute background.ios_background_ble_enabled?
    refute background.automatic_restart_enabled?
    refute background.scheduled_retry_enabled?
    refute background.background_gossip_enabled?
  end

  test "background lifecycle scenario names every lifecycle validation gate" do
    plan = LocalLifecycleDecisionScenarioPlan.snapshot()
    background = Enum.find(plan.decision_scenarios, &(&1.id == :enable_background_lifecycle))

    assert [
             :target_device_matrix,
             :android_foreground_service_backgrounding,
             :android_background_ble_policy,
             :ios_background_ble_policy,
             :restart_and_cancellation,
             :scheduled_retry_bounds,
             :background_gossip_limits,
             :negative_claim_review
           ] -- background.required_gates == []

    assert background.missing_evidence != []
    assert :android_foreground_service_ble in background.blocked_claims_called_out
    assert :android_background_scan in background.blocked_claims_called_out
    assert :ios_background_scan in background.blocked_claims_called_out
    assert :automatic_ble_restart in background.blocked_claims_called_out
    assert :background_delivery in background.blocked_claims_called_out
  end

  test "foreground/manual scenario preserves release wording blockers" do
    plan = LocalLifecycleDecisionScenarioPlan.snapshot()
    foreground = Enum.find(plan.decision_scenarios, &(&1.id == :keep_foreground_manual))

    assert Enum.any?(
             foreground.required_operator_evidence,
             &String.contains?(&1, "foreground/manual lifecycle wording")
           )

    assert :android_foreground_service_ble in foreground.blocked_claims_called_out
    assert :android_background_scan in foreground.blocked_claims_called_out
    assert :ios_background_scan in foreground.blocked_claims_called_out
    assert :background_delivery in foreground.blocked_claims_called_out
  end

  test "JSON snapshot is archiveable" do
    plan = LocalLifecycleDecisionScenarioPlan.json_snapshot()

    assert plan["boundary"] == "local_lifecycle_decision_scenario_plan"
    assert plan["selected_decision_outcome"] == "keep_foreground_manual"
    assert length(plan["decision_scenarios"]) == 2
    assert plan["background_ble_claim_allowed?"] == false
    assert plan["restart_claim_allowed?"] == false
    assert plan["background_delivery_claim_allowed?"] == false
  end
end
