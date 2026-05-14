defmodule MeshxMobileApp.AndroidManifestTest do
  use ExUnit.Case, async: true

  @manifest Path.expand("../../android/AndroidManifest.xml", __DIR__)
  @gradle Path.expand("../../android/build.gradle.kts", __DIR__)

  test "Android manifest declares required BLE permissions for both permission eras" do
    xml = File.read!(@manifest)

    # Hardware gate so the Play Store only offers the app to BLE devices.
    assert xml =~ ~s(android:name="android.hardware.bluetooth_le")
    assert xml =~ ~s(android:required="true")

    # Pre-Android 12 permissions, capped at API 30 so they don't show on newer OS.
    assert xml =~ ~s(android:name="android.permission.BLUETOOTH")
    assert xml =~ ~s(android:name="android.permission.BLUETOOTH_ADMIN")
    assert xml =~ ~s(android:maxSdkVersion="30")

    # Android 12+ split permissions. SCAN must declare neverForLocation so the
    # platform decouples it from ACCESS_FINE_LOCATION.
    assert xml =~ ~s(android:name="android.permission.BLUETOOTH_SCAN")
    assert xml =~ ~s(android:usesPermissionFlags="neverForLocation")
    assert xml =~ ~s(android:name="android.permission.BLUETOOTH_ADVERTISE")
    assert xml =~ ~s(android:name="android.permission.BLUETOOTH_CONNECT")

    # Launcher Activity wired up.
    assert xml =~ ~s(android:name=".MainActivity")
    assert xml =~ "android.intent.action.MAIN"
    assert xml =~ "android.intent.category.LAUNCHER"
  end

  test "Gradle module targets BLE-capable API floor and matches iOS bundle id" do
    gradle = File.read!(@gradle)

    assert gradle =~ ~s(applicationId = "dev.meshx.mob")
    # minSdk 26 is the floor for BLE peripheral advertising support.
    assert gradle =~ "minSdk = 26"
    assert gradle =~ "compileSdk = 34"
  end
end
