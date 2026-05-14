defmodule MeshxMobileApp.BLE.LocalRoutingDecisionScenarioPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalRoutingDecisionScenarioPlan

  test "snapshot exposes routing decision scenarios without enabling routing claims" do
    plan = LocalRoutingDecisionScenarioPlan.snapshot()

    assert plan.boundary == :local_routing_decision_scenario_plan
    assert plan.status == :open
    assert plan.selected_decision_outcome == :keep_advert_only_non_routing
    refute plan.route_table_claim_allowed?
    refute plan.route_selection_claim_allowed?
    refute plan.forwarding_claim_allowed?
    refute plan.routed_delivery_claim_allowed?
    refute plan.guaranteed_delivery_claim_allowed?
    refute plan.multi_hop_hardware_claim_allowed?
  end

  test "decision scenarios cover non-routing and production routing outcomes" do
    plan = LocalRoutingDecisionScenarioPlan.snapshot()
    outcomes = Enum.map(plan.decision_scenarios, & &1.decision_outcome)

    assert [:keep_advert_only_non_routing, :enable_production_routing] -- outcomes == []

    assert plan.allowed_decision_outcomes == [
             :keep_advert_only_non_routing,
             :enable_production_routing
           ]

    non_routing = Enum.find(plan.decision_scenarios, &(&1.id == :keep_advert_only_non_routing))
    production = Enum.find(plan.decision_scenarios, &(&1.id == :enable_production_routing))

    assert non_routing.status == :selected_for_current_validated_mode
    assert non_routing.routing_mode_after_decision == :advert_only_non_routing
    refute non_routing.production_routing_enabled?
    refute non_routing.route_selection_enabled?
    refute non_routing.forwarding_service_enabled?
    refute non_routing.routed_delivery_enabled?

    assert production.status == :blocked
    assert production.routing_mode_after_decision == :production_routing
    refute production.production_routing_enabled?
    refute production.route_selection_enabled?
    refute production.forwarding_service_enabled?
    refute production.routed_delivery_enabled?
  end

  test "production routing scenario names every routing validation gate" do
    plan = LocalRoutingDecisionScenarioPlan.snapshot()
    production = Enum.find(plan.decision_scenarios, &(&1.id == :enable_production_routing))

    assert [
             :route_table_state_model,
             :deterministic_route_selection,
             :forwarding_service_boundary,
             :delivery_semantics_policy,
             :multi_hop_hardware_rig,
             :ttl_loop_and_suppression_evidence,
             :release_artifact_evidence,
             :negative_claim_review
           ] -- production.required_gates == []

    assert production.missing_evidence != []
    assert :route_selection_available in production.blocked_claims_called_out
    assert :live_forwarding_service in production.blocked_claims_called_out
    assert :routed_delivery in production.blocked_claims_called_out
    assert :multi_hop_hardware_routing in production.blocked_claims_called_out
  end

  test "non-routing scenario preserves release wording blockers" do
    plan = LocalRoutingDecisionScenarioPlan.snapshot()
    non_routing = Enum.find(plan.decision_scenarios, &(&1.id == :keep_advert_only_non_routing))

    assert Enum.any?(
             non_routing.required_operator_evidence,
             &String.contains?(&1, "advert-only non-routing wording")
           )

    assert :route_selection_available in non_routing.blocked_claims_called_out
    assert :live_forwarding_service in non_routing.blocked_claims_called_out
    assert :routed_delivery in non_routing.blocked_claims_called_out
    assert :guaranteed_delivery in non_routing.blocked_claims_called_out
  end

  test "JSON snapshot is archiveable" do
    plan = LocalRoutingDecisionScenarioPlan.json_snapshot()

    assert plan["boundary"] == "local_routing_decision_scenario_plan"
    assert plan["selected_decision_outcome"] == "keep_advert_only_non_routing"
    assert length(plan["decision_scenarios"]) == 2
    assert plan["route_selection_claim_allowed?"] == false
    assert plan["forwarding_claim_allowed?"] == false
    assert plan["routed_delivery_claim_allowed?"] == false
  end
end
