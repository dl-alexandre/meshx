defmodule MeshxMobileApp.BLE.LocalRoutingEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalRoutingEvidenceManifest

  test "snapshot packages route-candidate evidence while keeping routing claims blocked" do
    manifest = LocalRoutingEvidenceManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.boundary == :local_routing_evidence_manifest
    assert manifest.current_mode == :advert_only_non_routing
    assert manifest.current_routing_decision.decision_outcome == :keep_advert_only_non_routing

    assert manifest.current_routing_decision.decision_status ==
             :selected_for_current_validated_mode

    assert manifest.routing_decision_scenario_plan.boundary ==
             :local_routing_decision_scenario_plan

    assert length(manifest.routing_decision_scenario_plan.decision_scenarios) == 2

    refute manifest.current_routing_decision.production_routing_enabled?
    refute manifest.route_table_claim_allowed?
    refute manifest.route_selection_claim_allowed?
    refute manifest.forwarding_claim_allowed?
    refute manifest.routed_delivery_claim_allowed?
    refute manifest.guaranteed_delivery_claim_allowed?
    refute manifest.multi_hop_hardware_claim_allowed?

    assert manifest.non_routing_scope.current_mode == :advert_only_non_routing
    assert :route_candidate_read_model in manifest.non_routing_scope.allowed_current_behavior
    assert :live_forwarding_service in manifest.non_routing_scope.disallowed_current_behavior
    assert :message_delivery in manifest.non_routing_scope.not_evidence_of
  end

  test "manifest embeds policy, candidate table, acceptance, hardware plan, and negative validation" do
    manifest = LocalRoutingEvidenceManifest.snapshot()

    assert manifest.policy.routing_claims_allowed? == false
    assert manifest.policy.decision_outcome == :keep_advert_only_non_routing
    assert manifest.route_candidate_table.boundary == :local_observation_route_candidates
    assert manifest.route_dry_run.boundary == :local_routing_dry_run_snapshot
    assert manifest.acceptance.boundary == :current_advert_only_non_routing_mode
    assert manifest.contract.open_requirement_count == manifest.proof_plan.open_gate_count

    assert manifest.hardware_validation_plan.boundary ==
             :production_routing_hardware_validation_plan

    assert manifest.operator_capture_plan.boundary == :local_routing_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 8

    assert manifest.production_evidence_review.boundary == :production_routing_evidence_review
    assert manifest.production_evidence_review.status == :open
    assert manifest.negative_validation.boundary == :current_advert_only_non_routing_mode

    assert Enum.any?(
             manifest.negative_validation.cases,
             &(&1.id == :beacon_fetch_planning_as_routing and
                 &1.expected_decision == :fetch_intent_only)
           )

    assert manifest.candidate_count == 2
    assert manifest.forwardable_candidate_count == 1
    assert manifest.dry_run_would_select_candidate_count == 1
    assert manifest.acceptance_blocked_count == 5
    assert manifest.hardware_blocked_gate_count == 8
  end

  test "manifest lists missing production routing hardware evidence" do
    manifest = LocalRoutingEvidenceManifest.snapshot()
    gate_ids = Enum.map(manifest.missing_routing_evidence, & &1.gate_id)

    assert :route_table_state_model in gate_ids
    assert :deterministic_route_selection in gate_ids
    assert :forwarding_service_boundary in gate_ids
    assert :delivery_semantics_policy in gate_ids
    assert :multi_hop_hardware_rig in gate_ids
    assert :ttl_loop_and_suppression_evidence in gate_ids
    assert :release_artifact_evidence in gate_ids
    assert :negative_claim_review in gate_ids
  end

  test "JSON snapshot preserves blocked routing and delivery claims" do
    manifest = LocalRoutingEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_routing_evidence_manifest"

    assert manifest["current_routing_decision"]["decision_outcome"] ==
             "keep_advert_only_non_routing"

    assert manifest["route_selection_claim_allowed?"] == false
    assert manifest["forwarding_claim_allowed?"] == false
    assert manifest["routed_delivery_claim_allowed?"] == false
    assert manifest["non_routing_scope"]["current_mode"] == "advert_only_non_routing"

    assert "production_route_selection" in manifest["non_routing_scope"][
             "disallowed_current_behavior"
           ]

    assert "physical_multi_hop_propagation" in manifest["non_routing_scope"]["not_evidence_of"]
    assert "routed_delivery" in manifest["blocked_claims"]
    assert manifest["production_evidence_review"]["routed_delivery_claim_allowed?"] == false
    assert manifest["operator_capture_plan"]["boundary"] == "local_routing_operator_capture_plan"
    assert length(manifest["operator_capture_plan"]["capture_sections"]) == 8

    assert manifest["routing_decision_scenario_plan"]["boundary"] ==
             "local_routing_decision_scenario_plan"

    assert length(manifest["routing_decision_scenario_plan"]["decision_scenarios"]) == 2

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_routing.validation_plan")
           )

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_routing.production_review --template")
           )

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_routing.production_review --input")
           )
  end

  test "manifest requires direct routing evidence command gates" do
    required_commands = LocalRoutingEvidenceManifest.snapshot().required_commands

    required_test_paths = [
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_acceptance_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_contract_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_decision_scenario_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_evidence_manifest_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_hardware_validation_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_negative_validation_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_operator_capture_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_policy_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_production_evidence_review_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_proof_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_table_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_routing_dry_run_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_routing_evidence_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_routing_production_review_test.exs"
    ]

    for path <- required_test_paths do
      assert "mix test #{path}" in required_commands
    end

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_routing.validation_plan")
           )

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_routing.production_review --template")
           )

    assert Enum.any?(
             LocalRoutingEvidenceManifest.snapshot().required_artifacts,
             &(&1.id == :routing_decision_scenario_plan)
           )

    assert Enum.any?(
             LocalRoutingEvidenceManifest.snapshot().required_artifacts,
             &(&1.id == :production_routing_operator_capture_plan)
           )
  end
end
