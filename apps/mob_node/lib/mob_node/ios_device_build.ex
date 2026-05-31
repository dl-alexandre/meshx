defmodule Mob.Node.IOSDeviceBuild do
  @moduledoc false

  @mob_swift_sources """
      "$MESHX_SWIFT_DIR/BLAKE2s.swift" \\
      "$MESHX_SWIFT_DIR/Frame.swift" \\
      "$MESHX_SWIFT_DIR/Fragment.swift" \\
      "$MESHX_SWIFT_DIR/Chunk.swift" \\
      "$MESHX_SWIFT_DIR/Noise.swift" \\
      "$MESHX_SWIFT_DIR/SecureSession.swift" \\
      "$MESHX_SWIFT_DIR/BLE.swift" \\
      "$MESHX_SWIFT_DIR/MessageEnvelope.swift" \\
      "$MESHX_SWIFT_DIR/MessageAdvertisement.swift" \\
      "$MESHX_SWIFT_DIR/MessageAdvertisementObserver.swift" \\
      "$MESHX_SWIFT_DIR/MobFetchProtocol.swift" \\
      "$MESHX_SWIFT_DIR/MobFetchGatt.swift" \\
      "$MESHX_SWIFT_DIR/MobFetchGattResponder.swift" \\
      "ios/MobBLEBridge.swift" \\
  """

  def bridge_linked_script(script) do
    script
    |> replace_once(
      """
      BUILD_DIR=$(mktemp -d)
      SWIFT_BRIDGING="$MOB_DIR/ios/MobDemo-Bridging-Header.h"
      """,
      """
      BUILD_DIR=$(mktemp -d)
      SWIFT_BRIDGING="$MOB_DIR/ios/MobDemo-Bridging-Header.h"
      MESHX_SWIFT_DIR="../../mob_node/Sources/Mob.Node"
      """
    )
    |> replace_once(
      """
          "$MOB_DIR/ios/MobViewModel.swift" \\
          "$MOB_DIR/ios/MobRootView.swift" \\
          -c -o "$BUILD_DIR/swift_mob.o"
      """,
      """
          "$MOB_DIR/ios/MobViewModel.swift" \\
          "$MOB_DIR/ios/MobRootView.swift" \\
      #{@mob_swift_sources}    -c -o "$BUILD_DIR/swift_mob.o"
      """
    )
    |> replace_once(
      """
      $CC -fobjc-arc -fmodules $IFLAGS \\
          -I "$BUILD_DIR" -DSTATIC_ERLANG_NIF \\
          -c "$MOB_DIR/ios/mob_nif.m" -o "$BUILD_DIR/mob_nif.o"
      """,
      """
      $CC -fobjc-arc -fmodules $IFLAGS \\
          -I "$BUILD_DIR" -DSTATIC_ERLANG_NIF \\
          -c "$MOB_DIR/ios/mob_nif.m" -o "$BUILD_DIR/mob_nif.o"

      $CC -fobjc-arc -fmodules $IFLAGS \\
          -I "$BUILD_DIR" -DSTATIC_ERLANG_NIF \\
          -c ios/mob_ble_nif.m -o "$BUILD_DIR/mob_ble_nif.o"
      """
    )
    |> replace_once(
      """
      $CC $IFLAGS $SQLITE_FLAG \\
          -c "$MOB_DIR/ios/driver_tab_ios.c" -o "$BUILD_DIR/driver_tab_ios.o"
      """,
      """
      $CC $IFLAGS $SQLITE_FLAG \\
          -c ios/driver_tab_mob_ios.c -o "$BUILD_DIR/driver_tab_ios.o"
      """
    )
    |> replace_once(
      """
          "$BUILD_DIR/swift_mob.o" \\
          "$BUILD_DIR/mob_nif.o" \\
          "$BUILD_DIR/mob_beam.o" \\
      """,
      """
          "$BUILD_DIR/swift_mob.o" \\
          "$BUILD_DIR/mob_nif.o" \\
          "$BUILD_DIR/mob_ble_nif.o" \\
          "$BUILD_DIR/mob_beam.o" \\
      """
    )
    |> replace_once(
      """
          -Xlinker -framework -Xlinker QuartzCore \\
          -Xlinker -framework -Xlinker SwiftUI \\
          -o "$BUILD_DIR/$APP_NAME"
      """,
      """
          -Xlinker -framework -Xlinker QuartzCore \\
          -Xlinker -framework -Xlinker SwiftUI \\
          -Xlinker -framework -Xlinker CoreBluetooth \\
          -Xlinker -framework -Xlinker CryptoKit \\
          -o "$BUILD_DIR/$APP_NAME"
      """
    )
    |> replace_once(
      """
          APS_ENV=$(security cms -D -i "$APP/embedded.mobileprovision" 2>/dev/null \\
              | /usr/libexec/PlistBuddy -c "Print :Entitlements:aps-environment" /dev/stdin 2>/dev/null \\
              || true)
      """,
      """
          PROFILE_PLIST="$BUILD_DIR/embedded_profile.plist"
          security cms -D -i "$APP/embedded.mobileprovision" > "$PROFILE_PLIST" 2>/dev/null || true
          APS_ENV=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:aps-environment" "$PROFILE_PLIST" 2>/dev/null || true)
      """
    )
  end

  defp replace_once(script, needle, replacement) do
    if String.contains?(script, needle) do
      String.replace(script, needle, replacement)
    else
      raise ArgumentError, "Mob iOS device build template changed; missing snippet:\n#{needle}"
    end
  end
end
