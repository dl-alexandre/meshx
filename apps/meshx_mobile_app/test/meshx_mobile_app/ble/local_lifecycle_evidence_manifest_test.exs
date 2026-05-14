defmodule MeshxMobileApp.BLE.LocalLifecycleEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalLifecycleEvidenceManifest

  test "snapshot packages foreground/manual lifecycle evidence while keeping background claims blocked" do
    manifest = LocalLifecycleEvidenceManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.boundary == :local_lifecycle_evidence_manifest
    assert manifest.current_mode == :foreground_manual
    assert manifest.current_lifecycle_decision.decision_outcome == :keep_foreground_manual

    assert manifest.current_lifecycle_decision.decision_status ==
             :selected_for_current_validated_mode

    assert manifest.lifecycle_decision_scenario_plan.boundary ==
             :local_lifecycle_decision_scenario_plan

    assert length(manifest.lifecycle_decision_scenario_plan.decision_scenarios) == 2

    refute manifest.current_lifecycle_decision.android_foreground_service_enabled?
    refute manifest.android_foreground_service_claim_allowed?
    refute manifest.android_background_ble_claim_allowed?
    refute manifest.ios_background_claim_allowed?
    refute manifest.background_ble_claim_allowed?
    refute manifest.restart_claim_allowed?
    refute manifest.scheduled_retry_claim_allowed?
    refute manifest.background_gossip_claim_allowed?
    refute manifest.delivery_claim_allowed?

    assert manifest.foreground_manual_scope.current_mode == :foreground_manual
    assert :operator_started_scan in manifest.foreground_manual_scope.allowed_current_behavior

    assert :android_background_scan in manifest.foreground_manual_scope.disallowed_current_behavior

    assert :background_ble_operation in manifest.foreground_manual_scope.not_evidence_of
  end

  test "manifest embeds lifecycle profile, policy, acceptance, hardware plan, and negative validation" do
    manifest = LocalLifecycleEvidenceManifest.snapshot()

    assert manifest.profile.name == :foreground_manual_ble
    assert :foreground_scan in manifest.profile.supports
    assert :android_foreground_service in manifest.profile.does_not_support

    assert manifest.manual_session_evidence.boundary ==
             :foreground_manual_lifecycle_session_snapshot

    assert manifest.foreground_manual_complete_session_count == 1
    assert manifest.policy.background_claims_allowed? == false
    assert manifest.policy.decision_outcome == :keep_foreground_manual
    refute manifest.policy.foreground_service_claim_allowed?
    assert manifest.acceptance.boundary == :current_foreground_manual_lifecycle

    assert manifest.background_contract.open_requirement_count ==
             manifest.proof_plan.open_gate_count

    assert manifest.hardware_validation_plan.boundary ==
             :mobile_ble_lifecycle_hardware_validation_plan

    assert manifest.operator_capture_plan.boundary == :local_lifecycle_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 8

    assert manifest.hardware_evidence_review.boundary ==
             :mobile_ble_lifecycle_hardware_evidence_review

    assert manifest.hardware_evidence_review.status == :open
    assert manifest.negative_validation.boundary == :current_foreground_manual_lifecycle

    assert Enum.any?(
             manifest.negative_validation.cases,
             &(&1.id == :fetch_request_intent_as_scheduled_retry and
                 &1.expected_decision == :fetch_intent_only)
           )

    assert manifest.acceptance_blocked_count == 6
    assert manifest.hardware_blocked_gate_count == 8
    assert manifest.open_hardware_gate_count == 8
  end

  test "manifest lists missing background lifecycle hardware evidence" do
    manifest = LocalLifecycleEvidenceManifest.snapshot()
    gate_ids = Enum.map(manifest.missing_lifecycle_evidence, & &1.gate_id)

    assert :target_device_matrix in gate_ids
    assert :android_foreground_service_backgrounding in gate_ids
    assert :android_background_ble_policy in gate_ids
    assert :ios_background_ble_policy in gate_ids
    assert :restart_and_cancellation in gate_ids
    assert :scheduled_retry_bounds in gate_ids
    assert :background_gossip_limits in gate_ids
    assert :negative_claim_review in gate_ids
  end

  test "JSON snapshot preserves blocked lifecycle and delivery claims" do
    manifest = LocalLifecycleEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_lifecycle_evidence_manifest"
    assert manifest["current_lifecycle_decision"]["decision_outcome"] == "keep_foreground_manual"

    assert manifest["lifecycle_decision_scenario_plan"]["boundary"] ==
             "local_lifecycle_decision_scenario_plan"

    assert length(manifest["lifecycle_decision_scenario_plan"]["decision_scenarios"]) == 2
    assert manifest["background_ble_claim_allowed?"] == false
    assert manifest["restart_claim_allowed?"] == false
    assert manifest["scheduled_retry_claim_allowed?"] == false
    assert manifest["background_gossip_claim_allowed?"] == false
    assert manifest["delivery_claim_allowed?"] == false
    assert manifest["foreground_manual_scope"]["current_mode"] == "foreground_manual"

    assert "operator_started_advertise" in manifest["foreground_manual_scope"][
             "allowed_current_behavior"
           ]

    assert "ios_background_advertise" in manifest["foreground_manual_scope"][
             "disallowed_current_behavior"
           ]

    assert "scheduled_retry_execution" in manifest["foreground_manual_scope"]["not_evidence_of"]
    assert "background_delivery" in manifest["blocked_claims"]
    assert manifest["hardware_evidence_review"]["background_ble_claim_allowed?"] == false

    assert manifest["operator_capture_plan"]["boundary"] ==
             "local_lifecycle_operator_capture_plan"

    assert length(manifest["operator_capture_plan"]["capture_sections"]) == 8

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_lifecycle.validation_plan")
           )

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_lifecycle.hardware_review --template")
           )

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_lifecycle.hardware_review --input")
           )
  end

  test "manifest requires direct lifecycle evidence command gates" do
    required_commands = LocalLifecycleEvidenceManifest.snapshot().required_commands

    required_test_paths = [
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_background_lifecycle_contract_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_acceptance_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_decision_scenario_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_evidence_manifest_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_hardware_evidence_review_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_hardware_validation_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_manual_session_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_negative_validation_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_operator_capture_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_policy_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_lifecycle_proof_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_transport_lifecycle_profile_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_lifecycle_validation_plan_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_lifecycle_evidence_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_lifecycle_hardware_review_test.exs"
    ]

    for path <- required_test_paths do
      assert "mix test #{path}" in required_commands
    end

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_lifecycle.validation_plan")
           )

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_lifecycle.hardware_review --template")
           )

    assert Enum.any?(
             LocalLifecycleEvidenceManifest.snapshot().required_artifacts,
             &(&1.id == :lifecycle_operator_capture_plan)
           )
  end
end
