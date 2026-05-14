defmodule MeshxMobileApp.BLE.LocalBackgroundLifecycleContractTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalBackgroundLifecycleContract, LocalInbox}

  test "android foreground service requirement remains unimplemented" do
    assert {:ok, requirement} = LocalBackgroundLifecycleContract.get(:android_foreground_service)

    assert requirement.status == :not_implemented
    assert Enum.any?(requirement.required_evidence, &String.contains?(&1, "foreground service"))
    assert requirement.current_gap =~ "not a foreground service"
  end

  test "android background BLE policy is foreground-only today" do
    assert {:ok, requirement} =
             LocalBackgroundLifecycleContract.get(:android_background_ble_policy)

    assert requirement.status == :foreground_only
    assert Enum.any?(requirement.required_evidence, &String.contains?(&1, "Battery"))
    assert Enum.any?(requirement.notes, &String.contains?(&1, "foregrounded"))
  end

  test "snapshot lists all open background lifecycle requirements" do
    snapshot = LocalBackgroundLifecycleContract.snapshot()
    ids = Enum.map(snapshot.open_requirements, & &1.id)

    assert snapshot.open_requirement_count == 5
    assert :android_foreground_service in ids
    assert :android_background_ble_policy in ids
    assert :ios_background_ble_policy in ids
    assert :automatic_restart in ids
    assert :background_gossip_limits in ids
  end

  test "local inbox snapshot exposes background lifecycle contract" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.background_lifecycle_contract.open_requirement_count == 5

    assert Enum.any?(
             snapshot.background_lifecycle_contract.notes,
             &String.contains?(&1, "foreground/manual")
           )
  end
end
