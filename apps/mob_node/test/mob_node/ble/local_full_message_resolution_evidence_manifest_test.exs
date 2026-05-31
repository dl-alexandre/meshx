defmodule Mob.Node.BLE.LocalFullMessageResolutionEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalFullMessageResolutionEvidenceManifest

  test "snapshot packages resolver and fetch evidence while keeping real resolution blocked" do
    manifest = LocalFullMessageResolutionEvidenceManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.boundary == :local_full_message_resolution_evidence_manifest
    assert manifest.current_mode == :beacon_refs_unresolved_without_real_transport
    assert manifest.beacon_ref_contract_present?
    assert manifest.resolver_contract_present?
    assert manifest.fetch_request_contract_present?
    assert manifest.fetch_planning_pipeline_present?
    assert manifest.fake_offline_fetch_present?
    refute manifest.real_fetch_transport_validated?
    refute manifest.gatt_fetch_enabled_by_default?
    refute manifest.full_message_resolution_claim_allowed?
    refute manifest.message_delivery_claim_allowed?
    refute manifest.trusted_message_claim_allowed?
  end

  test "manifest embeds transport validation plan and contract coverage" do
    manifest = LocalFullMessageResolutionEvidenceManifest.snapshot()

    assert manifest.transport_validation_plan.boundary ==
             :full_message_resolution_transport_validation_plan

    assert manifest.transport_validation_plan.current_validated_fetch_transport == :none
    assert manifest.satisfied_transport_gate_count == 1
    assert manifest.blocked_transport_gate_count == 6
    assert manifest.contract_coverage.beacon_ref.status == :present

    assert manifest.contract_coverage.resolver.outcomes == [
             :already_known,
             :needs_fetch,
             :unresolvable
           ]

    assert manifest.contract_coverage.offline_fetch.status == :present

    assert manifest.transport_evidence_review.boundary ==
             :full_message_resolution_transport_evidence_review

    assert manifest.known_good_transport_review.boundary ==
             :known_good_transport_evidence_review
  end

  test "manifest lists missing real transport evidence" do
    manifest = LocalFullMessageResolutionEvidenceManifest.snapshot()
    gate_ids = Enum.map(manifest.open_transport_evidence, & &1.gate_id)

    assert :candidate_transport_decision in gate_ids
    assert :standalone_interop_matrix in gate_ids
    assert :constrained_fetch_exchange in gate_ids
    assert :canonical_replay_resolution in gate_ids
    assert :negative_failure_matrix in gate_ids
    assert :release_artifact_linkage in gate_ids
  end

  test "manifest includes transport review command and artifact" do
    manifest = LocalFullMessageResolutionEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_full_resolution.transport_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_full_resolution.transport_review --input")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :full_resolution_transport_evidence_template)
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_known_good_transport.review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_known_good_transport.review --input")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :known_good_transport_evidence_template)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :full_resolution_release_review)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :known_good_transport_logs)
           )
  end

  test "manifest requires direct full-resolution evidence command gates" do
    required_commands = LocalFullMessageResolutionEvidenceManifest.snapshot().required_commands

    required_test_paths = [
      "apps/mob_node/test/mob_node/ble/beacon_resolver_test.exs",
      "apps/mob_node/test/mob_node/ble/beacon_fetch_request_test.exs",
      "apps/mob_node/test/mob_node/ble/beacon_fetch_pipeline_test.exs",
      "apps/mob_node/test/mob_node/ble/beacon_fetch_transport_test.exs",
      "apps/mob_node/test/mob_node/ble/local_fetch_transport_validation_plan_test.exs",
      "apps/mob_node/test/mob_node/ble/local_full_message_resolution_evidence_manifest_test.exs",
      "apps/mob_node/test/mob_node/ble/local_full_message_resolution_evidence_review_test.exs",
      "apps/mob_node/test/mob_node/ble/local_known_good_transport_evidence_review_test.exs",
      "apps/mob_node/test/mix/tasks/mob_node_local_full_resolution_evidence_test.exs",
      "apps/mob_node/test/mix/tasks/mob_node_local_full_resolution_transport_review_test.exs",
      "apps/mob_node/test/mix/tasks/mob_node_local_known_good_transport_review_test.exs"
    ]

    for path <- required_test_paths do
      assert "mix test #{path}" in required_commands
    end

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_full_resolution.transport_review --template")
           )

    assert Enum.any?(
             required_commands,
             &String.contains?(&1, "local_known_good_transport.review --template")
           )
  end

  test "JSON snapshot preserves blocked full resolution claims" do
    manifest = LocalFullMessageResolutionEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_full_message_resolution_evidence_manifest"
    assert manifest["real_fetch_transport_validated?"] == false
    assert manifest["gatt_fetch_enabled_by_default?"] == false
    assert manifest["full_message_resolution_claim_allowed?"] == false
    assert manifest["message_delivery_claim_allowed?"] == false
    assert "full_message_resolution" in manifest["blocked_claims"]
  end
end
