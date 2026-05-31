defmodule Mob.Node.BLE.LocalInboxUxDecisionScenarioPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxUxDecisionScenarioPlan

  test "snapshot exposes UX decision scenarios without enabling production claims" do
    plan = LocalInboxUxDecisionScenarioPlan.snapshot()

    assert plan.boundary == :nearby_messages_ux_decision_scenario_plan
    assert plan.status == :open
    assert plan.selected_decision_outcome == :keep_pure_surface_evidence_only
    refute plan.production_ux_claim_allowed?
    refute plan.delivery_claim_allowed?
    refute plan.trusted_delivery_claim_allowed?
    refute plan.routing_claim_allowed?
    refute plan.background_operation_claim_allowed?
  end

  test "decision scenarios cover pure surface and production UX outcomes" do
    plan = LocalInboxUxDecisionScenarioPlan.snapshot()
    outcomes = Enum.map(plan.decision_scenarios, & &1.decision_outcome)

    assert [:keep_pure_surface_evidence_only, :promote_nearby_messages_production_ux] --
             outcomes == []

    assert plan.allowed_decision_outcomes == [
             :keep_pure_surface_evidence_only,
             :promote_nearby_messages_production_ux
           ]

    pure = Enum.find(plan.decision_scenarios, &(&1.id == :keep_pure_surface_evidence_only))

    production =
      Enum.find(plan.decision_scenarios, &(&1.id == :promote_nearby_messages_production_ux))

    assert pure.status == :selected_for_current_validated_mode
    assert pure.ux_mode_after_decision == :pure_surface_evidence_only
    refute pure.production_ux_enabled?
    refute pure.production_ux_claim_allowed?

    assert production.status == :blocked
    assert production.ux_mode_after_decision == :production_nearby_messages_ux
    refute production.production_ux_enabled?
    refute production.production_ux_claim_allowed?
  end

  test "production UX scenario names every validation gate and target-device scenario dimension" do
    plan = LocalInboxUxDecisionScenarioPlan.snapshot()

    production =
      Enum.find(plan.decision_scenarios, &(&1.id == :promote_nearby_messages_production_ux))

    assert [
             :target_device_matrix,
             :state_coverage_screenshots,
             :interaction_coverage,
             :blocked_claim_copy_review,
             :visual_density_review
           ] -- production.required_gates == []

    assert [:full_message, :unresolved_ref, :gossiped_ref, :stale_ref] --
             production.required_states == []

    assert [:filter_change, :sort_change, :row_selection, :detail_panel] --
             production.required_interactions == []

    assert [
             :recent_first,
             :state_then_recent,
             :strongest_rssi,
             :payload_kind_then_recent,
             :oldest_first
           ] --
             production.required_sorts == []

    assert production.missing_evidence != []
    assert :production_nearby_messages_ux in production.blocked_claims_called_out
    assert :delivery in production.blocked_claims_called_out
    assert :trusted_delivery in production.blocked_claims_called_out
    assert :routing in production.blocked_claims_called_out
    assert :background_operation in production.blocked_claims_called_out
  end

  test "pure surface scenario preserves release wording blockers" do
    plan = LocalInboxUxDecisionScenarioPlan.snapshot()
    pure = Enum.find(plan.decision_scenarios, &(&1.id == :keep_pure_surface_evidence_only))

    assert Enum.any?(
             pure.required_operator_evidence,
             &String.contains?(&1, "pure-surface wording")
           )

    assert :production_nearby_messages_ux in pure.blocked_claims_called_out
    assert :delivery in pure.blocked_claims_called_out
    assert :trusted_delivery in pure.blocked_claims_called_out
    assert :routing in pure.blocked_claims_called_out
    assert :background_operation in pure.blocked_claims_called_out
  end

  test "JSON snapshot is archiveable" do
    plan = LocalInboxUxDecisionScenarioPlan.json_snapshot()

    assert plan["boundary"] == "nearby_messages_ux_decision_scenario_plan"
    assert plan["selected_decision_outcome"] == "keep_pure_surface_evidence_only"
    assert length(plan["decision_scenarios"]) == 2
    assert plan["production_ux_claim_allowed?"] == false
    assert plan["delivery_claim_allowed?"] == false
    assert plan["trusted_delivery_claim_allowed?"] == false
  end
end
