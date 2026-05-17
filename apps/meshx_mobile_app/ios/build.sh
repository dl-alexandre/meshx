#!/bin/bash
# ios/build.sh — Build and deploy MeshxMobileApp to iOS simulator.
# Reads paths from environment (set by `mix mob.deploy --native` via mob.exs,
# or export them manually before running this script directly).
#
# Required env vars (set in mob.exs or export manually):
#   MOB_DIR         — path to mob library repo
#   MOB_ELIXIR_LIB  — path to Elixir lib dir
#   MOB_IOS_OTP_ROOT — iOS OTP runtime root (set automatically by mob_dev OtpDownloader)
set -e
cd "$(dirname "$0")/.."     # project root (contains mix.exs)

# Tell `mix compile` we're building for iOS so any `unless
# System.get_env("MOB_TARGET") == "ios" do …` compile-time gates in the
# user's config.exs short-circuit. The python feature uses this gate to
# skip Pythonx's desktop `:uv_init` (which can't run in the simulator —
# no uv at compile time). Harmless for non-Python apps.
export MOB_TARGET=ios

# ── Paths ─────────────────────────────────────────────────────────────────────
MOB_DIR="${MOB_DIR:?MOB_DIR not set — configure mob.exs}"
ELIXIR_LIB="${MOB_ELIXIR_LIB:?MOB_ELIXIR_LIB not set — configure mob.exs}"
OTP_ROOT="${MOB_IOS_OTP_ROOT:?MOB_IOS_OTP_ROOT not set — run mix mob.install to download OTP}"

# Auto-detect ERTS version from the OTP runtime root.
ERTS_VSN=$(ls "$OTP_ROOT" | grep '^erts-' | sort -V | tail -1)
if [ -z "$ERTS_VSN" ]; then
    echo "ERROR: No erts-* directory found in $OTP_ROOT"
    echo "       Have you built OTP for iOS simulator?"
    exit 1
fi

BEAMS_DIR="$OTP_ROOT/meshx_mobile_app"
SDKROOT=$(xcrun -sdk iphonesimulator --show-sdk-path)
# -Os + per-function/data sections (the C-side analog of beam_lib:strip_release/1).
# Combined with -Wl,-dead_strip on the final link, the linker drops every
# function and data object that no live symbol references. Per the GRiSP nano
# 2025-06-11 writeup, this is the single biggest C-side win on bundle size.
CC="xcrun -sdk iphonesimulator cc -arch arm64 -mios-simulator-version-min=17.0 -isysroot $SDKROOT -Os -ffunction-sections -fdata-sections"

IFLAGS="-I$OTP_ROOT/$ERTS_VSN/include \
        -I$OTP_ROOT/$ERTS_VSN/include/aarch64-apple-iossimulator \
        -I$MOB_DIR/ios"

LIBS="
  $OTP_ROOT/$ERTS_VSN/lib/libbeam.a
  $OTP_ROOT/$ERTS_VSN/lib/internal/liberts_internal_r.a
  $OTP_ROOT/$ERTS_VSN/lib/internal/libethread.a
  $OTP_ROOT/$ERTS_VSN/lib/libzstd.a
  $OTP_ROOT/$ERTS_VSN/lib/libepcre.a
  $OTP_ROOT/$ERTS_VSN/lib/libryu.a
  $OTP_ROOT/$ERTS_VSN/lib/asn1rt_nif.a
  $OTP_ROOT/$ERTS_VSN/lib/crypto.a
  $OTP_ROOT/$ERTS_VSN/lib/libcrypto.a
"

# ── Find booted simulator ──────────────────────────────────────────────────────
if [ -n "$1" ]; then
    SIM_ID="$1"
else
    SIM_ID=$(xcrun simctl list devices booted -j \
        | python3 -c "
import json,sys
d=json.load(sys.stdin)
for sims in d['devices'].values():
    for s in sims:
        if s.get('state') == 'Booted':
            print(s['udid'])
            exit()
" 2>/dev/null || true)
fi

if [ -z "$SIM_ID" ]; then
    echo "ERROR: No booted simulator found. Boot one in Simulator.app or pass UDID as argument."
    exit 1
fi
echo "=== Target simulator: $SIM_ID ==="

# ── Compile Erlang/Elixir ──────────────────────────────────────────────────────
echo "=== Compiling Erlang/Elixir ==="
mix compile

echo "=== Copying BEAM files to $BEAMS_DIR ==="
mkdir -p "$BEAMS_DIR"
chmod -R u+w "$BEAMS_DIR" 2>/dev/null || true
find _build/dev/lib -path "*/ebin" -type d | while read -r ebin; do
    cp "$ebin"/* "$BEAMS_DIR/"
done

# crypto: provided by the OTP runtime tarball (real OpenSSL, statically
# linked into the app's main native lib via crypto.a + libcrypto.a in
# erts-VSN/lib/). No shim needed. crypto.beam, crypto.app, public_key,
# and ssl ship in the tarball under lib/crypto-VSN/, lib/public_key-VSN/,
# and lib/ssl-VSN/ respectively.

echo "=== Copying Elixir stdlib ==="
mkdir -p "$OTP_ROOT/lib/elixir/ebin"
mkdir -p "$OTP_ROOT/lib/logger/ebin"
chmod -R u+w "$OTP_ROOT/lib/elixir/ebin" "$OTP_ROOT/lib/logger/ebin" 2>/dev/null || true
cp "$ELIXIR_LIB/elixir/ebin/"*.beam  "$OTP_ROOT/lib/elixir/ebin/"
cp "$ELIXIR_LIB/elixir/ebin/elixir.app" "$OTP_ROOT/lib/elixir/ebin/"
cp "$ELIXIR_LIB/logger/ebin/"*.beam  "$OTP_ROOT/lib/logger/ebin/"
cp "$ELIXIR_LIB/logger/ebin/logger.app" "$OTP_ROOT/lib/logger/ebin/"

# ── Sync OTP runtime to the simulator's runtime dir ──────────────────────────
# mob_beam.m reads MOB_SIM_RUNTIME_DIR (passed by `mix mob.deploy` via
# simctl's SIMCTL_CHILD_* mechanism) to find the OTP runtime at startup.
# Default lives under ~/.mob/runtime/ios-sim so `mix mob.cache` can list and
# clean it. Override with MOB_SIM_RUNTIME_DIR in the calling environment.
#
# `--no-perms` is essential on Nix systems: ELIXIR_LIB lives in /nix/store
# where files are mode 444, and macOS BSD `cp` (used above for the stdlib
# cps) preserves source mode in practice — leaving 444 .beam files all over
# OTP_ROOT. Without --no-perms, rsync would carry that mode into RUNTIME_DIR
# and the next `mix mob.deploy` would trip on
# `cp: cannot create regular file ...: Permission denied` when overwriting.
# --no-perms keeps existing destination perms untouched and uses the user's
# umask for newly-created files in RUNTIME_DIR.
RUNTIME_DIR="${MOB_SIM_RUNTIME_DIR:-$HOME/.mob/runtime/ios-sim}"
echo "=== Syncing OTP runtime to $RUNTIME_DIR ==="
mkdir -p "$RUNTIME_DIR"
chmod -R u+w "$RUNTIME_DIR" 2>/dev/null || true
rsync -a --delete --no-perms "$OTP_ROOT/" "$RUNTIME_DIR/"
# Defensive chmod after rsync — even with --no-perms, files that already
# existed at 444 keep their mode. Make everything writable so the deployer's
# subsequent BEAM push (mix mob.deploy without --native) can overwrite cleanly.
chmod -R u+w "$RUNTIME_DIR" 2>/dev/null || true

echo "=== Copying Mob logos ==="
cp "$MOB_DIR/assets/logo/logo_dark.png"  "$RUNTIME_DIR/mob_logo_dark.png"
cp "$MOB_DIR/assets/logo/logo_light.png" "$RUNTIME_DIR/mob_logo_light.png"

echo "=== Spot-check ==="
ls "$BEAMS_DIR/Elixir.MeshxMobileApp.App.beam"
ls "$BEAMS_DIR/Elixir.MeshxMobileApp.HomeScreen.beam"

# ── Compile C/ObjC/Swift ──────────────────────────────────────────────────────
echo "=== Compiling native sources ==="
BUILD_DIR=$(mktemp -d)
SWIFT_BRIDGING="$MOB_DIR/ios/MobDemo-Bridging-Header.h"
MESHX_SWIFT_DIR="../../meshx_mobile/Sources/MeshxMobile"

$CC -fobjc-arc -fmodules $IFLAGS \
    -c "$MOB_DIR/ios/MobNode.m" -o "$BUILD_DIR/MobNode.o"

xcrun -sdk iphonesimulator swiftc \
    -target arm64-apple-ios17.0-simulator \
    -module-name MeshxMobileApp \
    -emit-objc-header -emit-objc-header-path "$BUILD_DIR/MobApp-Swift.h" \
    -import-objc-header "$SWIFT_BRIDGING" \
    -I "$MOB_DIR/ios" \
    -parse-as-library \
    -wmo \
    "$MOB_DIR/ios/MobViewModel.swift" \
    "$MOB_DIR/ios/MobRootView.swift" \
    "$MESHX_SWIFT_DIR/BLAKE2s.swift" \
    "$MESHX_SWIFT_DIR/Frame.swift" \
    "$MESHX_SWIFT_DIR/Fragment.swift" \
    "$MESHX_SWIFT_DIR/Chunk.swift" \
    "$MESHX_SWIFT_DIR/Noise.swift" \
    "$MESHX_SWIFT_DIR/SecureSession.swift" \
    "$MESHX_SWIFT_DIR/BLE.swift" \
    "$MESHX_SWIFT_DIR/MessageEnvelope.swift" \
    "$MESHX_SWIFT_DIR/MessageAdvertisement.swift" \
    "$MESHX_SWIFT_DIR/MessageAdvertisementObserver.swift" \
    "$MESHX_SWIFT_DIR/MeshxFetchProtocol.swift" \
    "$MESHX_SWIFT_DIR/MeshxFetchGatt.swift" \
    "$MESHX_SWIFT_DIR/MeshxFetchGattResponder.swift" \
    "ios/MeshxBLEBridge.swift" \
    -c -o "$BUILD_DIR/swift_mob.o"

$CC -fobjc-arc -fmodules $IFLAGS \
    -I "$BUILD_DIR" \
    -DSTATIC_ERLANG_NIF \
    -c "$MOB_DIR/ios/mob_nif.m"   -o "$BUILD_DIR/mob_nif.o"

$CC -fobjc-arc -fmodules $IFLAGS \
    -I "$BUILD_DIR" \
    -DSTATIC_ERLANG_NIF \
    -c ios/meshx_ble_nif.m -o "$BUILD_DIR/meshx_ble_nif.o"

$CC -fobjc-arc -fmodules $IFLAGS \
    -c "$MOB_DIR/ios/mob_beam.m"  -o "$BUILD_DIR/mob_beam.o"

$CC $IFLAGS \
    -c ios/driver_tab_meshx_ios.c -o "$BUILD_DIR/driver_tab_ios.o"

$CC -fobjc-arc -fmodules $IFLAGS \
    -I "$BUILD_DIR" \
    -c ios/AppDelegate.m  -o "$BUILD_DIR/AppDelegate.o"

$CC -fobjc-arc -fmodules $IFLAGS \
    -c ios/beam_main.m    -o "$BUILD_DIR/beam_main.o"

# Generate enif_* keep-alive table so -dead_strip doesn't remove enif_*
# symbols that dlopen'd dynamic NIFs (libpythonx.so, others) need at
# runtime. Each enif_* exported by erl_nif.o gets one __attribute__((used))
# reference — `used` only protects the listed symbol (not siblings in the
# same .o), so we need one reference per symbol. See README in mob_dev for
# the dead_strip + flat namespace background.
echo "=== Generating enif_* keep-alive table ==="
NIF_O_TMP=$(mktemp -d)
$(xcrun -find ar) x "$OTP_ROOT/$ERTS_VSN/lib/libbeam.a" --output="$NIF_O_TMP" erl_nif.o 2>/dev/null \
    || $(xcrun -find ar) x "$OTP_ROOT/$ERTS_VSN/lib/libbeam.a" erl_nif.o
[ ! -f erl_nif.o ] || mv erl_nif.o "$NIF_O_TMP/erl_nif.o"

{
    echo "/* Auto-generated. References every enif_* in erl_nif.o so dead_strip keeps them. */"
    xcrun nm -arch arm64 "$NIF_O_TMP/erl_nif.o" 2>/dev/null \
        | awk '/ T _enif_/ { sym = substr($3, 2); printf "extern void %s(void); __attribute__((used)) static void *_keep_%s = (void *)&%s;\n", sym, sym, sym }'
} > "$BUILD_DIR/enif_keepalive.c"
rm -rf "$NIF_O_TMP"
KEEP_COUNT=$(grep -c '^extern void enif_' "$BUILD_DIR/enif_keepalive.c" || true)
echo "  $KEEP_COUNT enif_* symbols pinned"
$CC -c "$BUILD_DIR/enif_keepalive.c" -o "$BUILD_DIR/enif_keepalive.o"

# ── Link ───────────────────────────────────────────────────────────────────────
echo "=== Linking MeshxMobileApp binary ==="
xcrun -sdk iphonesimulator swiftc \
    -target arm64-apple-ios17.0-simulator \
    "$BUILD_DIR/driver_tab_ios.o" \
    "$BUILD_DIR/MobNode.o" \
    "$BUILD_DIR/swift_mob.o" \
    "$BUILD_DIR/mob_nif.o" \
    "$BUILD_DIR/meshx_ble_nif.o" \
    "$BUILD_DIR/mob_beam.o" \
    "$BUILD_DIR/AppDelegate.o" \
    "$BUILD_DIR/beam_main.o" \
    "$BUILD_DIR/enif_keepalive.o" \
    $LIBS \
    -lz -lc++ -lpthread \
    -Xlinker -dead_strip \
    -Xlinker -framework -Xlinker UIKit \
    -Xlinker -framework -Xlinker Foundation \
    -Xlinker -framework -Xlinker CoreGraphics \
    -Xlinker -framework -Xlinker QuartzCore \
    -Xlinker -framework -Xlinker SwiftUI \
    -Xlinker -framework -Xlinker CoreBluetooth \
    -Xlinker -framework -Xlinker CryptoKit \
    -o "$BUILD_DIR/MeshxMobileApp"

# ── Bundle + install ───────────────────────────────────────────────────────────
echo "=== Building .app bundle ==="
APP="$BUILD_DIR/MeshxMobileApp.app"
rm -rf "$APP"
mkdir -p "$APP"
cp "$BUILD_DIR/MeshxMobileApp" "$APP/"
cp ios/Info.plist "$APP/"
if [ -d "ios/Assets.xcassets/AppIcon.appiconset" ]; then
    ACTOOL_PLIST=$(mktemp /tmp/actool_XXXXXX.plist)
    xcrun actool ios/Assets.xcassets \
        --compile "$APP" \
        --platform iphonesimulator \
        --minimum-deployment-target 17.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$ACTOOL_PLIST" \
        2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Merge $ACTOOL_PLIST" "$APP/Info.plist" 2>/dev/null || true
    rm -f "$ACTOOL_PLIST"
fi

echo "=== Installing on simulator $SIM_ID ==="
xcrun simctl install "$SIM_ID" "$APP"

echo "=== Installing complete ==="
