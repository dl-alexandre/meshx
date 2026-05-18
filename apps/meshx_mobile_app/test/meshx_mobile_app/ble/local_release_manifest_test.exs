defmodule MeshxMobileApp.BLE.LocalReleaseManifestTest do
  use ExUnit.Case, async: true

  @moduletag :hardware_artifact

  alias MeshxMobileApp.BLE.LocalReleaseManifest

  test "snapshot ties advert-only release criteria to open project readiness" do
    manifest = LocalReleaseManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.mode == :advertisement_only_local_mesh
    assert manifest.release_boundary == :validated_advert_only_local_mode
    refute manifest.whole_project_complete?
    assert manifest.releasable_with_limitations?

    assert manifest.release_criteria.satisfied_count == 5
    assert manifest.release_criteria.limited_count == 2
    assert manifest.release_criteria.blocked_count == 0

    assert manifest.project_readiness.open_item_count == 10
    assert manifest.project_readiness.blocked_item_count == 3
    assert manifest.project_readiness.partial_item_count == 7
    assert manifest.completion_audit.open_item_count == 10
    assert manifest.completion_audit.blocked_item_count == 3
    assert length(manifest.completion_audit.deliverables) == 10
    assert length(manifest.completion_audit.prompt_artifact_checklist) == 10
    refute manifest.completion_audit.completion_claim_allowed?
    assert Enum.any?(manifest.completion_audit.items, &(&1.objective_id == :ios_parity))

    assert manifest.full_resolution_evidence.boundary ==
             :local_full_message_resolution_evidence_manifest

    refute manifest.full_resolution_evidence.real_fetch_transport_validated?
    refute manifest.full_resolution_evidence.full_message_resolution_claim_allowed?
    assert manifest.ux_evidence.boundary == :nearby_messages_ux_evidence_manifest

    assert manifest.ux_evidence.ux_decision_scenario_plan.boundary ==
             :nearby_messages_ux_decision_scenario_plan

    refute manifest.ux_evidence.production_ux_claim_allowed?
    assert manifest.ios_parity_evidence.boundary == :local_ios_parity_evidence_manifest

    assert manifest.ios_parity_evidence.ios_parity_decision_scenario_plan.boundary ==
             :local_ios_parity_decision_scenario_plan

    assert manifest.ios_parity_evidence.operator_capture_plan.boundary ==
             :local_ios_parity_operator_capture_plan

    refute manifest.ios_parity_evidence.ios_parity_claim_allowed?
    refute manifest.ios_parity_evidence.ios_participation_claim_allowed?
    assert manifest.lifecycle_evidence.boundary == :local_lifecycle_evidence_manifest

    assert manifest.lifecycle_evidence.lifecycle_decision_scenario_plan.boundary ==
             :local_lifecycle_decision_scenario_plan

    refute manifest.lifecycle_evidence.background_ble_claim_allowed?
    refute manifest.lifecycle_evidence.restart_claim_allowed?

    assert manifest.multi_hop_hardware_evidence.boundary ==
             :local_multi_hop_hardware_evidence_manifest

    refute manifest.multi_hop_hardware_evidence.multi_hop_physical_proof_present?
    refute manifest.multi_hop_hardware_evidence.multi_hop_hardware_gossip_claim_allowed?
    assert manifest.persistence_evidence.boundary == :local_persistence_evidence_manifest
    assert manifest.persistence_evidence.current_default_mode == :memory_only
    refute manifest.persistence_evidence.production_default_persistence_allowed?
    assert manifest.routing_evidence.boundary == :local_routing_evidence_manifest

    assert manifest.routing_evidence.routing_decision_scenario_plan.boundary ==
             :local_routing_decision_scenario_plan

    refute manifest.routing_evidence.routed_delivery_claim_allowed?
    assert manifest.hardware_evidence.open_count == 4
    refute manifest.hardware_evidence.release_candidate_complete?
    assert manifest.security_evidence.boundary == :local_security_evidence_manifest
    refute manifest.security_evidence.security_evidence_complete?

    assert manifest.security_evidence.security_decision_scenario_plan.boundary ==
             :local_security_decision_scenario_plan

    assert manifest.security_evidence.operator_capture_plan.boundary ==
             :local_security_operator_capture_plan

    assert manifest.operator_capture_plan.boundary == :local_release_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 5

    manifest_paths =
      Enum.find(manifest.operator_capture_plan.capture_sections, &(&1.id == :manifest_paths))

    assert :completion_audit_plain_text_path in manifest_paths.required_entries
    assert :focused_remaining_items_audit_path in manifest_paths.required_entries
    assert :focused_remaining_items_plain_text_path in manifest_paths.required_entries
    assert :direct_full_mx_aux_validation_checklist_path in manifest_paths.required_entries
    assert :upstream_patch_maintainer_handoff_path in manifest_paths.required_entries
    assert :recent_evidence_inventory_path in manifest_paths.required_entries
    refute manifest.operator_capture_plan.release_candidate_complete?
    assert manifest.artifact_bundle.artifact_count == 54
    assert manifest.artifact_bundle.open_artifact_count == 19
    refute manifest.artifact_bundle.release_candidate_complete?

    recent_evidence =
      Enum.find(manifest.artifact_bundle.artifacts, &(&1.id == :recent_evidence_inventory))

    assert String.contains?(recent_evidence.purpose, "closure artifact pointers")
    assert :direct_full_mx_aux_complete in recent_evidence.blocked_claims
    assert :upstream_patch_migration_complete in recent_evidence.blocked_claims

    upstream_progress =
      Enum.find(
        manifest.artifact_bundle.artifacts,
        &(&1.id == :upstream_patch_migration_progress)
      )

    assert upstream_progress.path ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"

    assert :upstream_patch_migration_complete in upstream_progress.blocked_claims

    assert Enum.any?(
             recent_evidence.acceptance_criteria,
             &String.contains?(&1, "direct full-MX AUX validation checklist")
           )

    assert Enum.any?(
             recent_evidence.acceptance_criteria,
             &String.contains?(&1, "upstream maintainer handoff")
           )
  end

  test "manifest records policy gates that block overclaiming" do
    manifest = LocalReleaseManifest.snapshot()

    refute manifest.policy_gates.routing.routing_claims_allowed?
    refute manifest.policy_gates.lifecycle.background_claims_allowed?
    refute manifest.policy_gates.lifecycle.restart_claims_allowed?
    refute manifest.policy_gates.ios_parity.ios_participation_claims_allowed?
    refute manifest.policy_gates.trust.delivery_claims_allowed?
  end

  test "blocked release wording stays aligned with policy gates" do
    manifest = LocalReleaseManifest.snapshot()
    blocked = manifest.release_wording.blocked

    refute manifest.policy_gates.trust.delivery_claims_allowed?
    assert "Guaranteed delivery." in blocked
    assert "Trusted/authenticated message delivery." in blocked

    refute manifest.policy_gates.routing.routing_claims_allowed?
    assert "Routed or multi-hop hardware delivery." in blocked

    refute manifest.policy_gates.lifecycle.background_claims_allowed?
    assert "Background mobile operation." in blocked

    refute manifest.policy_gates.ios_parity.ios_participation_claims_allowed?
    assert "iOS advert-only participation." in blocked
  end

  test "manifest completion claim stays aligned with embedded completion audit" do
    manifest = LocalReleaseManifest.snapshot()

    assert manifest.whole_project_complete? == manifest.completion_audit.whole_project_complete?
    refute manifest.whole_project_complete?
    refute manifest.completion_audit.completion_claim_allowed?
    assert manifest.releasable_with_limitations?
  end

  test "manifest lists required release commands and artifacts" do
    manifest = LocalReleaseManifest.snapshot()

    assert "mix test" in manifest.required_commands

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "meshx.mobile.advert_gossip.audit")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_completion.blocker_matrix")
           )

    assert "mix meshx.mobile.remaining_items.audit --json --out <path>" in manifest.required_commands
    assert "mix meshx.mobile.remaining_items.audit | tee <path>" in manifest.required_commands

    assert Enum.any?(manifest.required_artifacts, &(&1.id == :readiness_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :completion_audit_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :completion_audit_standalone))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :completion_audit_plain_text_review))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :completion_blocker_matrix))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :focused_remaining_items_audit))

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :focused_remaining_items_plain_text_review)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :direct_full_mx_aux_validation_checklist)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :upstream_patch_maintainer_handoff)
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_completion.audit")
           )

    assert "mix meshx.mobile.local_completion.audit --allow-open" in manifest.required_commands

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local-completion-audit.txt")
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :full_message_resolution_evidence_manifest)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :full_resolution_transport_evidence_review)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :known_good_transport_evidence_review)
           )

    assert Enum.any?(manifest.required_artifacts, &(&1.id == :ux_validation_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :ux_evidence_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :ux_decision_scenario_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :ux_target_device_scenario_plan))

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ux_evidence_manifest and
                 String.contains?(&1.purpose, "control summaries") and
                 String.contains?(&1.purpose, "blocked-claim copy"))
           )

    assert Enum.any?(manifest.required_artifacts, &(&1.id == :ios_parity_evidence_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :ios_parity_decision_scenario_plan))

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ios_parity_operator_capture_plan)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :ios_parity_hardware_evidence_review)
           )

    assert Enum.any?(manifest.required_artifacts, &(&1.id == :lifecycle_validation_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :lifecycle_evidence_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :lifecycle_decision_scenario_plan))

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :multi_hop_hardware_evidence_manifest)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :multi_hop_hardware_evidence_review)
           )

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :production_persistence_lifecycle_plan)
           )

    assert Enum.any?(manifest.required_artifacts, &(&1.id == :persistence_evidence_manifest))

    assert Enum.any?(
             manifest.required_artifacts,
             &(&1.id == :production_persistence_default_decision_scenario_plan)
           )

    assert Enum.any?(manifest.required_artifacts, &(&1.id == :routing_validation_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :routing_evidence_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :routing_decision_scenario_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :release_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :hardware_evidence_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :artifact_bundle_checklist))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :recent_evidence_inventory))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :release_operator_capture_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :release_candidate_evidence_review))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :security_validation_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :security_evidence_manifest))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :security_decision_scenario_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :security_operator_capture_plan))
    assert Enum.any?(manifest.required_artifacts, &(&1.id == :security_release_evidence_review))

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security.validation_plan")
           )

    assert Enum.any?(manifest.required_commands, &String.contains?(&1, "local_security.evidence"))

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security.release_review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_security.release_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_release.recent_evidence")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_full_resolution.evidence")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_full_resolution.transport_review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_full_resolution.transport_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_known_good_transport.review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_known_good_transport.review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_persistence.lifecycle_plan")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_persistence.production_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_routing.validation_plan")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_routing.production_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_inbox.ux_validation_plan")
           )

    assert Enum.any?(manifest.required_commands, &String.contains?(&1, "local_inbox.ux_evidence"))

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_inbox.ux_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_ios_parity.evidence")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_ios_parity.hardware_review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_ios_parity.hardware_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_lifecycle.validation_plan")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_lifecycle.evidence")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_lifecycle.hardware_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_multi_hop_hardware.evidence")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_multi_hop_hardware.review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_multi_hop_hardware.review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_persistence.evidence")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_release.artifact_bundle")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_release.candidate_review")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_release.candidate_review --template")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_routing.evidence")
           )
  end

  test "required artifact commands are covered by required command gates" do
    manifest = LocalReleaseManifest.snapshot()

    artifact_commands =
      manifest.required_artifacts
      |> Enum.map(& &1.command)
      |> Enum.filter(&String.starts_with?(&1, "mix "))
      |> Enum.uniq()
      |> Enum.sort()

    required_commands = Enum.sort(manifest.required_commands)

    for command <- artifact_commands do
      assert command in required_commands
    end
  end

  test "artifact-producing required command gates are represented by required artifacts" do
    manifest = LocalReleaseManifest.snapshot()

    artifact_commands =
      manifest.required_artifacts
      |> Enum.map(& &1.command)
      |> Enum.uniq()
      |> Enum.sort()

    artifact_producing_commands =
      manifest.required_commands
      |> Enum.filter(&artifact_producing_command?/1)
      |> Enum.uniq()
      |> Enum.sort()

    for command <- artifact_producing_commands do
      assert command in artifact_commands
    end
  end

  defp artifact_producing_command?("mix meshx.mobile.advert_gossip.audit " <> _rest), do: true
  defp artifact_producing_command?(command), do: String.contains?(command, "--out <path>")

  test "json snapshot is machine readable and keeps completion false" do
    manifest = LocalReleaseManifest.json_snapshot()

    assert manifest["manifest_version"] == 1
    assert manifest["whole_project_complete?"] == false
    assert manifest["releasable_with_limitations?"] == true
    assert manifest["project_readiness"]["open_item_count"] == 10
    assert manifest["completion_audit"]["completion_claim_allowed?"] == false

    assert manifest["completion_audit"]["blocker_matrix"]["boundary"] ==
             "whole_project_completion_blocker_matrix"

    assert length(manifest["completion_audit"]["prompt_artifact_checklist"]) == 10
    assert manifest["full_resolution_evidence"]["real_fetch_transport_validated?"] == false
    assert manifest["ux_evidence"]["production_ux_claim_allowed?"] == false
    assert manifest["ios_parity_evidence"]["ios_parity_claim_allowed?"] == false

    assert manifest["ios_parity_evidence"]["operator_capture_plan"]["boundary"] ==
             "local_ios_parity_operator_capture_plan"

    assert manifest["ios_parity_evidence"]["ios_parity_decision_scenario_plan"]["boundary"] ==
             "local_ios_parity_decision_scenario_plan"

    assert manifest["lifecycle_evidence"]["background_ble_claim_allowed?"] == false

    assert manifest["lifecycle_evidence"]["lifecycle_decision_scenario_plan"]["boundary"] ==
             "local_lifecycle_decision_scenario_plan"

    assert manifest["lifecycle_evidence"]["restart_claim_allowed?"] == false
    assert manifest["persistence_evidence"]["current_default_mode"] == "memory_only"
    assert manifest["persistence_evidence"]["production_default_persistence_allowed?"] == false
    assert manifest["routing_evidence"]["routed_delivery_claim_allowed?"] == false

    assert manifest["routing_evidence"]["routing_decision_scenario_plan"]["boundary"] ==
             "local_routing_decision_scenario_plan"

    assert manifest["hardware_evidence"]["open_count"] == 4
    assert manifest["security_evidence"]["security_evidence_complete?"] == false
    assert manifest["security_evidence"]["trusted_delivery_claim_allowed?"] == false

    assert manifest["security_evidence"]["security_decision_scenario_plan"]["boundary"] ==
             "local_security_decision_scenario_plan"

    assert manifest["security_evidence"]["operator_capture_plan"]["boundary"] ==
             "local_security_operator_capture_plan"

    assert manifest["operator_capture_plan"]["boundary"] == "local_release_operator_capture_plan"
    assert length(manifest["operator_capture_plan"]["capture_sections"]) == 5

    manifest_paths =
      Enum.find(
        manifest["operator_capture_plan"]["capture_sections"],
        &(&1["id"] == "manifest_paths")
      )

    assert "completion_audit_plain_text_path" in manifest_paths["required_entries"]
    assert "focused_remaining_items_audit_path" in manifest_paths["required_entries"]
    assert "focused_remaining_items_plain_text_path" in manifest_paths["required_entries"]
    assert "direct_full_mx_aux_validation_checklist_path" in manifest_paths["required_entries"]
    assert "upstream_patch_maintainer_handoff_path" in manifest_paths["required_entries"]
    assert "recent_evidence_inventory_path" in manifest_paths["required_entries"]
    assert manifest["artifact_bundle"]["artifact_count"] == 54
    assert manifest["artifact_bundle"]["open_artifact_count"] == 19

    recent_evidence =
      Enum.find(
        manifest["artifact_bundle"]["artifacts"],
        &(&1["id"] == "recent_evidence_inventory")
      )

    assert String.contains?(recent_evidence["purpose"], "closure artifact pointers")
    assert "direct_full_mx_aux_complete" in recent_evidence["blocked_claims"]
    assert "upstream_patch_migration_complete" in recent_evidence["blocked_claims"]

    upstream_progress =
      Enum.find(
        manifest["artifact_bundle"]["artifacts"],
        &(&1["id"] == "upstream_patch_migration_progress")
      )

    assert upstream_progress["path"] ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"

    assert "upstream_patch_migration_complete" in upstream_progress["blocked_claims"]
    assert manifest["policy_gates"]["routing"]["routing_claims_allowed?"] == false
  end
end
