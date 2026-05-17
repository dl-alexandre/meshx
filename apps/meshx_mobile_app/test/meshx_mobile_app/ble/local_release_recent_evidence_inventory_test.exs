defmodule MeshxMobileApp.BLE.LocalReleaseRecentEvidenceInventoryTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalReleaseRecentEvidenceInventory

  test "snapshot inventories recent local evidence while keeping release incomplete" do
    snapshot = LocalReleaseRecentEvidenceInventory.snapshot()

    assert snapshot.boundary == :local_release_recent_evidence_inventory
    refute snapshot.release_candidate_complete?
    assert snapshot.item_count == 9
    assert :whole_project_complete in snapshot.blocked_claims
    assert :trusted_delivery in snapshot.blocked_claims
    assert :full_message_resolution in snapshot.blocked_claims

    ids = Enum.map(snapshot.items, & &1.id)
    assert :nearby_messages_selected_detail_copy in ids
    assert :durable_snapshot_schema_policy in ids
    assert :beacon_reference_security_risk in ids
    assert :local_routing_dry_run in ids
    assert :foreground_manual_lifecycle_session in ids
    assert :ios_native_source_inventory in ids
    assert :direct_full_mx_aux_validation_checklist in ids
    assert :upstream_patch_maintainer_handoff in ids
    assert :upstream_patch_migration_progress in ids
  end

  test "iOS source inventory includes foreground emit source without claiming parity" do
    snapshot = LocalReleaseRecentEvidenceInventory.snapshot()

    ios_item = Enum.find(snapshot.items, &(&1.id == :ios_native_source_inventory))

    assert :ios_foreground_observe_source_inventory in ios_item.supports
    assert :ios_foreground_mb_beacon_emit_source_inventory in ios_item.supports
    assert :ios_origin_cross_radio_gossip_proof in ios_item.does_not_support
    assert :ios_legacy_beacon_gossip in ios_item.does_not_support
    assert :ios_parity_claim in ios_item.does_not_support
  end

  test "each item names its required objective review and blocked claims" do
    snapshot = LocalReleaseRecentEvidenceInventory.snapshot()

    assert :nearby_messages_ux_review in snapshot.required_reviews
    assert :production_persistence_review in snapshot.required_reviews
    assert :security_release_review in snapshot.required_reviews
    assert :production_routing_review in snapshot.required_reviews
    assert :mobile_lifecycle_hardware_review in snapshot.required_reviews
    assert :ios_parity_hardware_review in snapshot.required_reviews
    assert :direct_full_mx_aux_hardware_review in snapshot.required_reviews
    assert :upstream_patch_merge_review in snapshot.required_reviews

    for item <- snapshot.items do
      assert item.required_review
      assert item.supports != []
      assert item.does_not_support != []
    end
  end

  test "json snapshot is machine readable" do
    snapshot = LocalReleaseRecentEvidenceInventory.json_snapshot()

    assert snapshot["boundary"] == "local_release_recent_evidence_inventory"
    assert snapshot["release_candidate_complete?"] == false
    assert snapshot["item_count"] == 9
    assert "whole_project_complete" in snapshot["blocked_claims"]
  end

  test "recent inventory includes focused closure artifact paths without closing blocked claims" do
    snapshot = LocalReleaseRecentEvidenceInventory.snapshot()

    aux_item =
      Enum.find(snapshot.items, &(&1.id == :direct_full_mx_aux_validation_checklist))

    upstream_item =
      Enum.find(snapshot.items, &(&1.id == :upstream_patch_maintainer_handoff))

    upstream_progress =
      Enum.find(snapshot.items, &(&1.id == :upstream_patch_migration_progress))

    assert aux_item.source ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md"

    assert :direct_full_mx_aux_closure_criteria in aux_item.supports
    assert :ios_aux_callback_proof in aux_item.does_not_support
    assert :direct_full_mx_aux_interop_complete in aux_item.does_not_support

    assert upstream_item.source ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md"

    assert :upstream_pr_state_rechecked in upstream_item.supports
    assert :downstream_patch_retention_decision in upstream_item.supports
    assert :upstream_prs_merged in upstream_item.does_not_support
    assert :downstream_patch_removal in upstream_item.does_not_support

    assert upstream_progress.source ==
             "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json"

    assert :downstream_patch_path_verified in upstream_progress.supports
    assert :replacement_prs_open in upstream_progress.supports
    assert :viewer_permission_recorded in upstream_progress.supports
    assert :upstream_changes_released in upstream_progress.does_not_support
    assert :meshx_dependency_migration in upstream_progress.does_not_support
    assert :post_migration_verification in upstream_progress.does_not_support
    assert :upstream_patch_migration_complete in upstream_progress.does_not_support
  end
end
