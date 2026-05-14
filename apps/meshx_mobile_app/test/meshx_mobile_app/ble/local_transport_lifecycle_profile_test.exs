defmodule MeshxMobileApp.BLE.LocalTransportLifecycleProfileTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalTransportLifecycleProfile}

  test "foreground manual profile declares supported and unsupported lifecycle behavior" do
    profile = LocalTransportLifecycleProfile.foreground_manual()

    assert LocalTransportLifecycleProfile.supports?(profile, :foreground_scan)
    assert LocalTransportLifecycleProfile.supports?(profile, :foreground_advertise)
    assert LocalTransportLifecycleProfile.supports?(profile, :manual_harness_validation)
    assert LocalTransportLifecycleProfile.supports?(profile, :explicit_start_stop)

    assert LocalTransportLifecycleProfile.unsupported?(profile, :android_foreground_service)
    assert LocalTransportLifecycleProfile.unsupported?(profile, :android_background_scan)
    assert LocalTransportLifecycleProfile.unsupported?(profile, :ios_background_scan)
    assert LocalTransportLifecycleProfile.unsupported?(profile, :background_gossip)
    assert LocalTransportLifecycleProfile.unsupported?(profile, :automatic_restart)
    assert LocalTransportLifecycleProfile.unsupported?(profile, :scheduled_retry)
  end

  test "snapshot exposes lifecycle notes for product and release checks" do
    snapshot =
      LocalTransportLifecycleProfile.foreground_manual()
      |> LocalTransportLifecycleProfile.snapshot()

    assert snapshot.name == :foreground_manual_ble
    assert :foreground_scan in snapshot.supports
    assert :ios_background_advertise in snapshot.does_not_support
    assert Enum.any?(snapshot.lifecycle_notes, &String.contains?(&1, "foreground/manual"))
  end

  test "local inbox snapshot carries foreground-only lifecycle profile" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.lifecycle_profile.name == :foreground_manual_ble
    assert :android_foreground_service in snapshot.lifecycle_profile.does_not_support
    assert :ios_background_scan in snapshot.lifecycle_profile.does_not_support
  end
end
