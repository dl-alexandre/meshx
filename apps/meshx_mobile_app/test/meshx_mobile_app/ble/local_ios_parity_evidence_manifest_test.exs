defmodule MeshxMobileApp.BLE.LocalIOSParityEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalIOSParityEvidenceManifest

  test "snapshot packages contract-only iOS evidence while keeping parity claims blocked" do
    manifest = LocalIOSParityEvidenceManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.boundary == :local_ios_parity_evidence_manifest
    assert manifest.current_ios_mode == :contract_only
    assert manifest.native_foreground_legacy_beacon_observe_present?
    assert manifest.ios_legacy_beacon_observe_hardware_validated?
    refute manifest.ios_participation_claim_allowed?
    refute manifest.ios_hardware_claim_allowed?
    refute manifest.ios_parity_claim_allowed?
    refute manifest.ios_legacy_beacon_observe_claim_allowed?
    refute manifest.ios_legacy_beacon_gossip_claim_allowed?
    refute manifest.ios_full_envelope_advert_claim_allowed?
    refute manifest.ios_background_ble_claim_allowed?

    assert manifest.contract_only_scope.current_mode == :contract_only

    assert :foreground_legacy_beacon_manufacturer_data_observe in manifest.contract_only_scope.hardware_validated_behavior

    assert :foreground_legacy_beacon_manufacturer_data_emit in manifest.contract_only_scope.implemented_unvalidated_behavior
    assert :ios_legacy_beacon_gossip_emit in manifest.contract_only_scope.not_selected_behavior
    assert :ios_full_mx_direct_advert_receive in manifest.contract_only_scope.not_evidence_of
  end

  test "manifest embeds policy, contract, acceptance, hardware plan, and negative validation" do
    manifest = LocalIOSParityEvidenceManifest.snapshot()

    assert manifest.policy.platform == :ios
    assert manifest.policy.ios_participation_claims_allowed? == false
    assert manifest.acceptance.boundary == :current_ios_contract_only_mode
    assert manifest.advert_carrier_decision.boundary == :ios_advert_only_carrier_decision
    assert manifest.advert_carrier_decision.current_ios_emit_carrier ==
             :manufacturer_data_legacy_beacon_emit

    assert manifest.advert_carrier_decision.ios_legacy_beacon_emit_implemented?
    refute manifest.advert_carrier_decision.ios_legacy_beacon_emit_cross_radio_validated?
    refute manifest.advert_carrier_decision.ios_legacy_beacon_gossip_claim_allowed?

    assert manifest.ios_parity_decision_scenario_plan.boundary ==
             :local_ios_parity_decision_scenario_plan

    assert length(manifest.ios_parity_decision_scenario_plan.decision_scenarios) == 2
    assert manifest.contract.open_requirement_count == manifest.proof_plan.open_gate_count
    assert manifest.native_source_inventory.boundary == :ios_native_source_inventory
    assert manifest.native_source_inventory.foreground_observe_source_present?
    refute manifest.native_source_inventory.ios_parity_claim_allowed?
    assert Enum.any?(
             manifest.implementation_evidence,
             &(&1.id == :ios_foreground_legacy_beacon_scan_decode)
           )

    assert Enum.any?(
             manifest.implementation_evidence,
             &(&1.id == :ios_direct_full_mx_aux_scan_response_probe and
                 &1.status == :negative_hardware_evidence and
                 Enum.any?(
                   &1.hardware_evidence,
                   fn path -> String.contains?(path, "android-aux-full-mx-ios-observe-rerun") end
                 ))
           )

    assert Enum.any?(
             manifest.implementation_evidence,
             &(&1.id == :ios_foreground_legacy_beacon_emit and
                 &1.status == :implemented_unvalidated)
           )

    assert manifest.hardware_validation_plan.boundary ==
             :ios_advert_only_hardware_validation_plan

    assert manifest.operator_capture_plan.boundary == :local_ios_parity_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 8

    assert manifest.negative_validation.boundary == :current_ios_contract_only_mode
    assert manifest.acceptance_blocked_count == 5
    assert manifest.hardware_blocked_gate_count == 8
    assert manifest.open_hardware_gate_count == 8
  end

  test "manifest lists missing iOS-specific hardware evidence" do
    manifest = LocalIOSParityEvidenceManifest.snapshot()
    gate_ids = Enum.map(manifest.missing_ios_evidence, & &1.gate_id)

    assert :target_ios_device_matrix in gate_ids
    assert :canonical_ingress_fixture in gate_ids
    assert :legacy_beacon_observe_hardware in gate_ids
    assert :legacy_beacon_gossip_hardware in gate_ids
    assert :full_envelope_capability_probe in gate_ids
    assert :hardware_replay_fixture in gate_ids
    assert :ios_background_ble_boundary in gate_ids
    assert :negative_claim_review in gate_ids
  end

  test "manifest includes hardware review command and artifact" do
    manifest = LocalIOSParityEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_ios_parity.hardware_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_ios_parity.hardware_review --input")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ios_parity_hardware_evidence_template)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ios_parity_operator_capture_plan)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ios_parity_decision_scenario_plan)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ios_parity_hardware_evidence_review)
           )
  end

  test "manifest requires direct iOS parity evidence command gates" do
    required_commands = LocalIOSParityEvidenceManifest.snapshot().required_commands

    required_test_paths = [
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_advert_carrier_decision_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_acceptance_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_contract_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_decision_scenario_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_evidence_manifest_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_hardware_evidence_review_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_hardware_validation_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_negative_validation_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_operator_capture_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_native_source_inventory_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_policy_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_proof_plan_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_ios_parity_evidence_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_ios_parity_hardware_review_test.exs"
    ]

    for path <- required_test_paths do
      assert "mix test #{path}" in required_commands
    end

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_ios_parity.hardware_review --template")
           )
  end

  test "JSON snapshot preserves blocked iOS parity claims" do
    manifest = LocalIOSParityEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_ios_parity_evidence_manifest"
    assert manifest["ios_participation_claim_allowed?"] == false
    assert manifest["ios_hardware_claim_allowed?"] == false
    assert manifest["ios_parity_claim_allowed?"] == false
    assert manifest["ios_background_ble_claim_allowed?"] == false
    assert manifest["native_foreground_legacy_beacon_observe_present?"] == true
    assert manifest["ios_legacy_beacon_observe_hardware_validated?"] == true
    assert manifest["contract_only_scope"]["current_mode"] == "contract_only"

    assert "foreground_legacy_beacon_manufacturer_data_observe" in manifest[
             "contract_only_scope"
           ][
             "hardware_validated_behavior"
           ]

    assert "foreground_legacy_beacon_manufacturer_data_emit" in manifest[
             "contract_only_scope"
           ][
             "implemented_unvalidated_behavior"
           ]

    assert "ios_background_ble_advertise" in manifest["contract_only_scope"][
             "not_selected_behavior"
           ]

    assert "ios_parity_claim" in manifest["contract_only_scope"]["not_evidence_of"]
    assert manifest["advert_carrier_decision"]["current_ios_emit_carrier"] ==
             "manufacturer_data_legacy_beacon_emit"

    assert manifest["advert_carrier_decision"][
             "ios_legacy_beacon_emit_cross_radio_validated?"
           ] == false

    assert Enum.any?(
             manifest["implementation_evidence"],
             &(&1["id"] == "ios_direct_full_mx_aux_scan_response_probe" and
                 &1["status"] == "negative_hardware_evidence" and
                 Enum.any?(
                   &1["hardware_evidence"],
                   fn path -> String.contains?(path, "android-aux-full-mx-ios-observe-rerun") end
                 ))
           )

    assert Enum.any?(
             manifest["implementation_evidence"],
             &(&1["id"] == "ios_foreground_legacy_beacon_emit" and
                 &1["status"] == "implemented_unvalidated")
           )

    assert manifest["ios_parity_decision_scenario_plan"]["boundary"] ==
             "local_ios_parity_decision_scenario_plan"

    assert length(manifest["ios_parity_decision_scenario_plan"]["decision_scenarios"]) == 2

    assert manifest["operator_capture_plan"]["boundary"] ==
             "local_ios_parity_operator_capture_plan"

    assert length(manifest["operator_capture_plan"]["capture_sections"]) == 8
    assert "ios_parity_claim" in manifest["blocked_claims"]
  end
end
