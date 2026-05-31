defmodule Mob.Node.IOSDeviceBuildTest do
  use ExUnit.Case, async: true

  test "patches Mob physical device build with MeshX BLE bridge sources" do
    script =
      legacy_mob_device_script()
      |> Mob.Node.IOSDeviceBuild.bridge_linked_script()

    assert script =~ ~s(MESHX_SWIFT_DIR="../../mob_node/Sources/Mob.Node")
    assert script =~ ~s("$MESHX_SWIFT_DIR/BLAKE2s.swift")
    assert script =~ ~s("$MESHX_SWIFT_DIR/MessageEnvelope.swift")
    assert script =~ ~s("$MESHX_SWIFT_DIR/MobFetchProtocol.swift")
    assert script =~ ~s("$MESHX_SWIFT_DIR/MobFetchGatt.swift")
    assert script =~ ~s("$MESHX_SWIFT_DIR/MobFetchGattResponder.swift")
    assert script =~ ~s("ios/MobBLEBridge.swift")
    assert script =~ ~s(-c ios/mob_ble_nif.m -o "$BUILD_DIR/mob_ble_nif.o")
    assert script =~ ~s(-c ios/driver_tab_mob_ios.c -o "$BUILD_DIR/driver_tab_ios.o")
    assert script =~ ~s("$BUILD_DIR/mob_ble_nif.o")
    assert script =~ "-Xlinker -framework -Xlinker CoreBluetooth"
    assert script =~ "-Xlinker -framework -Xlinker CryptoKit"
    assert script =~ ~s(PROFILE_PLIST="$BUILD_DIR/embedded_profile.plist")
    refute script =~ ~s(Print :Entitlements:aps-environment" /dev/stdin)
  end

  defp legacy_mob_device_script do
    """
    BUILD_DIR=$(mktemp -d)
    SWIFT_BRIDGING="$MOB_DIR/ios/MobDemo-Bridging-Header.h"

    swiftc \\
        "$MOB_DIR/ios/MobViewModel.swift" \\
        "$MOB_DIR/ios/MobRootView.swift" \\
        -c -o "$BUILD_DIR/swift_mob.o"

    $CC -fobjc-arc -fmodules $IFLAGS \\
        -I "$BUILD_DIR" -DSTATIC_ERLANG_NIF \\
        -c "$MOB_DIR/ios/mob_nif.m" -o "$BUILD_DIR/mob_nif.o"

    $CC $IFLAGS $SQLITE_FLAG \\
        -c "$MOB_DIR/ios/driver_tab_ios.c" -o "$BUILD_DIR/driver_tab_ios.o"

    $CC \\
        "$BUILD_DIR/swift_mob.o" \\
        "$BUILD_DIR/mob_nif.o" \\
        "$BUILD_DIR/mob_beam.o" \\
        -Xlinker -framework -Xlinker QuartzCore \\
        -Xlinker -framework -Xlinker SwiftUI \\
        -o "$BUILD_DIR/$APP_NAME"

        APS_ENV=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null \\
            | /usr/libexec/PlistBuddy -c "Print :Entitlements:aps-environment" /dev/stdin 2>/dev/null \\
            || true)
    """
  end
end
