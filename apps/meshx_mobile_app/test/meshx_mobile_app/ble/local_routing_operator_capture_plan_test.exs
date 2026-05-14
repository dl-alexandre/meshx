defmodule MeshxMobileApp.BLE.LocalRoutingOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalRoutingOperatorCapturePlan

  test "snapshot exposes routing capture plan without enabling routing claims" do
    plan = LocalRoutingOperatorCapturePlan.snapshot()

    assert plan.boundary == :local_routing_operator_capture_plan
    assert plan.status == :open
    assert plan.current_mode == :advert_only_non_routing
    assert plan.current_routing_decision.decision_outcome == :keep_advert_only_non_routing
    refute plan.route_table_claim_allowed?
    refute plan.route_selection_claim_allowed?
    refute plan.forwarding_claim_allowed?
    refute plan.routed_delivery_claim_allowed?
    refute plan.guaranteed_delivery_claim_allowed?
    refute plan.multi_hop_hardware_claim_allowed?
  end

  test "capture sections cover every production routing gate" do
    plan = LocalRoutingOperatorCapturePlan.snapshot()
    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert [
             :route_table_state_model,
             :deterministic_route_selection,
             :forwarding_service_boundary,
             :delivery_semantics_policy,
             :multi_hop_hardware_rig,
             :ttl_loop_and_suppression_evidence,
             :release_artifact_evidence,
             :negative_claim_review
           ] -- section_ids == []

    assert plan.required_gates -- section_ids == []
    assert length(plan.capture_sections) == 8
  end

  test "each section has review fields evidence type and blocked claims" do
    plan = LocalRoutingOperatorCapturePlan.snapshot()

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

  test "multi-hop and delivery sections preserve hardware and delivery boundaries" do
    plan = LocalRoutingOperatorCapturePlan.snapshot()
    delivery = Enum.find(plan.capture_sections, &(&1.id == :delivery_semantics_policy))
    multi_hop = Enum.find(plan.capture_sections, &(&1.id == :multi_hop_hardware_rig))

    assert delivery.evidence_type == :delivery_semantics_policy
    assert multi_hop.evidence_type == :multi_hop_hardware_rig
    assert Enum.any?(delivery.notes, &String.contains?(&1, "ACK"))
    assert Enum.any?(multi_hop.notes, &String.contains?(&1, "origin, relay, and observer"))
  end

  test "JSON snapshot is archiveable" do
    plan = LocalRoutingOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "local_routing_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 8
    assert plan["routed_delivery_claim_allowed?"] == false
  end
end
