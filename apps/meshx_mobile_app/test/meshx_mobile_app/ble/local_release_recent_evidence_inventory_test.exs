defmodule MeshxMobileApp.BLE.LocalReleaseRecentEvidenceInventoryTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalReleaseRecentEvidenceInventory

  test "snapshot inventories recent local evidence while keeping release incomplete" do
    snapshot = LocalReleaseRecentEvidenceInventory.snapshot()

    assert snapshot.boundary == :local_release_recent_evidence_inventory
    refute snapshot.release_candidate_complete?
    assert snapshot.item_count == 6
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
  end

  test "each item names its required objective review and blocked claims" do
    snapshot = LocalReleaseRecentEvidenceInventory.snapshot()

    assert :nearby_messages_ux_review in snapshot.required_reviews
    assert :production_persistence_review in snapshot.required_reviews
    assert :security_release_review in snapshot.required_reviews
    assert :production_routing_review in snapshot.required_reviews
    assert :mobile_lifecycle_hardware_review in snapshot.required_reviews
    assert :ios_parity_hardware_review in snapshot.required_reviews

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
    assert snapshot["item_count"] == 6
    assert "whole_project_complete" in snapshot["blocked_claims"]
  end
end
