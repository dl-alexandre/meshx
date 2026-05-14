defmodule MeshxMobileApp.IOSDeviceBuildTest do
  use ExUnit.Case, async: true

  test "patches Mob physical device build with MeshX BLE bridge sources" do
    script =
      []
      |> MobDev.NativeBuild.generate_build_device_sh("/tmp/otp")
      |> MeshxMobileApp.IOSDeviceBuild.bridge_linked_script()

    assert script =~ ~s(MESHX_SWIFT_DIR="../../meshx_mobile/Sources/MeshxMobile")
    assert script =~ ~s("$MESHX_SWIFT_DIR/BLAKE2s.swift")
    assert script =~ ~s("ios/MeshxBLEBridge.swift")
    assert script =~ ~s(-c ios/meshx_ble_nif.m -o "$BUILD_DIR/meshx_ble_nif.o")
    assert script =~ ~s(-c ios/driver_tab_meshx_ios.c -o "$BUILD_DIR/driver_tab_ios.o")
    assert script =~ ~s("$BUILD_DIR/meshx_ble_nif.o")
    assert script =~ "-Xlinker -framework -Xlinker CoreBluetooth"
    assert script =~ "-Xlinker -framework -Xlinker CryptoKit"
    assert script =~ ~s(PROFILE_PLIST="$BUILD_DIR/embedded_profile.plist")
    refute script =~ ~s(Print :Entitlements:aps-environment" /dev/stdin)
  end
end
