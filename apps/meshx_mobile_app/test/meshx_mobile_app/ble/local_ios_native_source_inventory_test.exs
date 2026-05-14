defmodule MeshxMobileApp.BLE.LocalIOSNativeSourceInventoryTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalIOSNativeSourceInventory

  test "snapshot verifies current iOS foreground beacon observe source markers" do
    snapshot = LocalIOSNativeSourceInventory.snapshot()

    assert snapshot.boundary == :ios_native_source_inventory
    assert snapshot.source_inventory_complete?
    assert snapshot.foreground_observe_source_present?
    refute snapshot.ios_hardware_claim_allowed?
    refute snapshot.ios_parity_claim_allowed?
    assert snapshot.missing_files == []
    assert :ios_parity_claim in snapshot.blocked_claims

    assert Enum.any?(
             snapshot.files,
             &(&1.id == :swift_bridge and &1.present? and &1.missing_markers == [])
           )

    assert Enum.any?(
             snapshot.files,
             &(&1.id == :nif_bridge and &1.present? and &1.missing_markers == [])
           )
  end

  test "snapshot fails closed when expected files are absent" do
    snapshot = LocalIOSNativeSourceInventory.snapshot(root: "/tmp/meshx-missing-ios-source")

    refute snapshot.source_inventory_complete?
    refute snapshot.foreground_observe_source_present?
    assert length(snapshot.missing_files) == 3
    refute snapshot.ios_hardware_claim_allowed?
    refute snapshot.ios_parity_claim_allowed?
  end

  test "json snapshot preserves claim boundaries" do
    snapshot = LocalIOSNativeSourceInventory.json_snapshot()

    assert snapshot["boundary"] == "ios_native_source_inventory"
    assert snapshot["source_inventory_complete?"] == true
    assert snapshot["foreground_observe_source_present?"] == true
    assert snapshot["ios_hardware_claim_allowed?"] == false
    assert snapshot["ios_parity_claim_allowed?"] == false
    assert "ios_hardware_participation" in snapshot["blocked_claims"]
  end
end
