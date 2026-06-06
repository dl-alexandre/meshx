defmodule Mix.Tasks.Mob.NodeReleaseCITest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../../../../.github/workflows/ci.yml", __DIR__)
  @release_doc Path.expand("../../../../../docs/RELEASE.md", __DIR__)
  @artifact_bundle_doc Path.expand(
                         "../../../../../docs/local_ble_release_artifact_bundle.md",
                         __DIR__
                       )

  test "CI generates local mobile release manifests" do
    workflow = File.read!(@workflow)

    assert workflow =~
             "mix mob.node.local_readiness.audit --allow-open --out tmp/ci-local-readiness.json"

    assert workflow =~
             "mix mob.node.local_completion.blocker_matrix --json --out tmp/ci-local-completion-blocker-matrix.json"

    assert workflow =~
             "mix mob.node.local_completion.audit --allow-open | tee tmp/ci-local-completion-audit.txt"

    assert workflow =~
             "mix mob.node.local_completion.audit --allow-open --json --out tmp/ci-local-completion-audit.json"

    assert workflow =~
             "mix mob.node.remaining_items.audit --json --out tmp/ci-focused-remaining-items-audit.json"

    assert workflow =~
             "mix mob.node.local_release.artifact_bundle --json --out tmp/ci-local-release-artifact-bundle.json"

    assert workflow =~
             "mix mob.node.local_release.recent_evidence --json --out tmp/ci-local-release-recent-evidence.json"

    assert workflow =~
             "mix mob.node.local_release.manifest --json --out tmp/ci-local-release.json"

    assert workflow =~ ~s(blocker_matrix["completion_claim_allowed?"] == false)
    assert workflow =~ ~s(completion_audit["completion_claim_allowed?"] == false)
    assert workflow =~ ~s(focused_remaining_items["complete"] == false)

    assert workflow =~
             ~s(focused_remaining_items["completion_decision"]["update_goal_allowed"] == false)

    assert workflow =~
             ~s("extended_advertising_interop_aux_scan_response" in focused_remaining_items["incomplete_rows"])

    assert workflow =~
             ~s("upstreaming_mob_dev_mob_patches" in focused_remaining_items["completed_rows"])

    assert workflow =~
             "plain_completion_audit = File.read!(\"tmp/ci-local-completion-audit.txt\")"

    assert workflow =~ "String.contains?(plain_completion_audit, \"OPEN_ITEMS 10\")"

    assert workflow =~
             "String.contains?(plain_completion_audit, \"OPEN_ITEM objective=full_message_resolution status=blocked\")"

    assert workflow =~
             "String.contains?(plain_completion_audit, \"OPEN_ITEM objective=release_hardening status=partial\")"

    assert workflow =~ ~s(artifact_bundle["release_candidate_complete?"] == false)
    assert workflow =~ ~s(artifact_bundle["required_commands"])
    assert workflow =~ ~s("direct_full_mx_aux_complete" in recent_artifact["blocked_claims"])

    assert workflow =~
             ~s("upstream_patch_migration_complete" in recent_artifact["blocked_claims"])

    assert workflow =~ ~s(recent_evidence["item_count"] == 9)
    assert workflow =~ ~s("direct_full_mx_aux_validation_checklist" in recent_ids)
    assert workflow =~ ~s("upstream_patch_maintainer_handoff" in recent_ids)
    assert workflow =~ ~s("upstream_patch_migration_progress" in recent_ids)
    assert workflow =~ ~s(local_release.manifest)
    assert workflow =~ ~s(local-completion-audit.txt)
    assert workflow =~ ~s(release["whole_project_complete?"] == false)
    assert workflow =~ ~s(release["policy_gates"]["routing"]["routing_claims_allowed?"] == false)

    assert workflow =~ "MobNode mesh and chat wiring guardrails"
    assert workflow =~ "apps/mob_node/test/mob_node/production_wiring_test.exs"
    assert workflow =~ "apps/mob_node/test/mob_node/mesh_status_test.exs"
    assert workflow =~ "apps/mob_node/test/mob_node/chat/"
    assert workflow =~ "apps/mob_node/test/mob_node/mob_ble_transport_wiring_test.exs"
    assert workflow =~ "apps/mob_node/test/mob_node/ble/adapter_test.exs"
  end

  test "device deploy runs guardrails before install" do
    source = File.read!("lib/mix/tasks/mob.node.deploy_device.ex")
    assert source =~ "Mob.Node.Guardrails.run!()"
  end

  test "release docs require plain-text completion audit open item review" do
    release_doc = File.read!(@release_doc)
    artifact_bundle_doc = File.read!(@artifact_bundle_doc)

    assert release_doc =~
             "mix mob.node.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt"

    for doc <- [release_doc, artifact_bundle_doc] do
      assert doc =~ "OPEN_ITEMS 10"
      assert doc =~ "OPEN_ITEM"
      assert doc =~ "remaining"
      assert doc =~ "objective"
    end

    assert artifact_bundle_doc =~ "OPEN_ITEM objective=... status=... missing=..."
    assert artifact_bundle_doc =~ "mix mob.node.remaining_items.audit --json"
    assert artifact_bundle_doc =~ "mix mob.node.local_release.recent_evidence --json"
    assert artifact_bundle_doc =~ "focused_remaining_items_audit_path"
    assert artifact_bundle_doc =~ "direct_full_mx_aux_validation_checklist_path"
    assert artifact_bundle_doc =~ "upstream_patch_maintainer_handoff_path"
    assert artifact_bundle_doc =~ "recent_evidence_inventory_path"
    assert artifact_bundle_doc =~ "direct full-MX AUX completion"
    assert artifact_bundle_doc =~ "upstream patch migration completion"

    assert release_doc =~ "mix mob.node.remaining_items.audit --json"
    assert release_doc =~ "mix mob.node.local_release.recent_evidence --json"
    assert release_doc =~ "extended_advertising_interop_aux_scan_response"
    assert release_doc =~ "upstreaming_mob_dev_mob_patches"
    assert release_doc =~ "direct full-MX AUX validation checklist"
    assert release_doc =~ "upstream maintainer handoff"
    assert release_doc =~ "must not claim whole-project completion"
    assert release_doc =~ "direct full-MX AUX completion"
    assert release_doc =~ "upstream patch migration completion"
  end
end
