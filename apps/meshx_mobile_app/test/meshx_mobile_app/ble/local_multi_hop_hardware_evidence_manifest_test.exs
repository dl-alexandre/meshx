defmodule MeshxMobileApp.BLE.LocalMultiHopHardwareEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalMultiHopHardwareEvidenceManifest

  test "snapshot packages replay evidence while keeping physical multi-hop blocked" do
    manifest = LocalMultiHopHardwareEvidenceManifest.snapshot()

    assert manifest.boundary == :local_multi_hop_hardware_evidence_manifest
    assert manifest.current_hardware_scope == :one_hop_legacy_beacon_gossip_only
    assert manifest.replay_policy_evidence_present?
    assert manifest.one_hop_hardware_evidence_present?
    refute manifest.multi_hop_physical_proof_present?
    refute manifest.multi_hop_hardware_gossip_claim_allowed?
    refute manifest.routed_delivery_claim_allowed?
    refute manifest.guaranteed_delivery_claim_allowed?
    refute manifest.background_operation_claim_allowed?
    assert manifest.blocked_gate_count == 6

    assert manifest.validation_plan.boundary == :advert_gossip_multi_hop_hardware_validation_plan
    assert manifest.hardware_evidence_review.boundary == :multi_hop_hardware_evidence_review
  end

  test "manifest distinguishes replay fixtures from physical hardware proof" do
    manifest = LocalMultiHopHardwareEvidenceManifest.snapshot()

    assert manifest.replay_evidence.scenarios == [
             :line_three_nodes,
             :partitioned_four_nodes,
             :triangle_duplicate_seen
           ]

    assert :physical_multi_hop_hardware_claim in manifest.replay_evidence.does_not_support
    assert manifest.current_hardware_evidence.participants_required_for_current_scope == 2
    assert manifest.current_hardware_evidence.participants_required_for_multi_hop_scope == 3

    gate_ids = Enum.map(manifest.open_hardware_evidence, & &1.gate_id)
    assert :three_role_device_matrix in gate_ids
    assert :origin_relay_observer_capture in gate_ids
    assert :replay_normalized_fixture in gate_ids
    assert :ttl_and_suppression_evidence in gate_ids
    assert :one_hop_negative_review in gate_ids
    assert :release_artifact_linkage in gate_ids
  end

  test "manifest includes hardware review command and artifact" do
    manifest = LocalMultiHopHardwareEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_multi_hop_hardware.review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_multi_hop_hardware.review --input")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :multi_hop_hardware_evidence_template)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :multi_hop_release_review)
           )
  end

  test "manifest requires direct multi-hop evidence command gates" do
    required_commands = LocalMultiHopHardwareEvidenceManifest.snapshot().required_commands

    required_test_paths = [
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_advert_gossip_hardware_validation_plan_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_hardware_validation_gates_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_multi_hop_hardware_evidence_manifest_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_multi_hop_hardware_evidence_review_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_multi_hop_hardware_evidence_test.exs",
      "apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_multi_hop_hardware_review_test.exs",
      "apps/meshx_mobile_app/test/meshx_mobile_app/ble/advert_gossip_scenario_test.exs"
    ]

    for path <- required_test_paths do
      assert "mix test #{path}" in required_commands
    end

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_multi_hop_hardware.review --template")
           )
  end

  test "JSON snapshot preserves blocked multi-hop claims and required artifacts" do
    manifest = LocalMultiHopHardwareEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_multi_hop_hardware_evidence_manifest"
    assert manifest["multi_hop_physical_proof_present?"] == false
    assert manifest["blocked_gate_count"] == 6

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "multi_hop_hardware_evidence_manifest")
           )

    assert Enum.any?(
             manifest["blocked_claims"],
             &(&1 == "multi_hop_hardware_gossip")
           )
  end
end
