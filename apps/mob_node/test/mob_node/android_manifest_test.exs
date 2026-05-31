defmodule Mob.Node.AndroidManifestTest do
  use ExUnit.Case, async: true

  # Paths follow the Mob Android app-module layout the project restructure
  # adopted (commit a4c80ec). The bare-Gradle layout these tests originally
  # targeted no longer exists; manifest and gradle live under android/app/.
  @manifest Path.expand("../../android/app/src/main/AndroidManifest.xml", __DIR__)
  @gradle Path.expand("../../android/app/build.gradle", __DIR__)

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

    # The Mob template ships Groovy-flavoured Gradle (no `=` between key and
    # value); minSdk 28 is the floor Mob's bundled OTP runtime targets.
    assert gradle =~ ~s(applicationId "dev.mob.mob")
    assert gradle =~ "minSdk 28"
    assert gradle =~ "compileSdk 34"
  end
end
