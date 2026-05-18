# BLE Lab Cheat Sheet

Single-page reference for on-device BLE validation runs. Keep printed or
phone-bookmarked. Companion to `docs/BLE_BRIDGE.md` and
`docs/ble_carrier_decision.md`.

## Devices

| Role          | Device      | ID                                       | OS         |
|---------------|-------------|------------------------------------------|------------|
| iPhone (iOS)  | DairyPhoneDeaux | `1780F216-CB5C-560B-A86F-85D31F79ADEF` | iOS 16+    |
| Android #1    | SM-T577U    | `R52W90AW7EN`                            | Android 13 |
| Android #2    | SM-T390     | `5200f354f4fb277f`                       | Android 9  |

App IDs: `dev.meshx.mob` (Android main + `.test` runner) /
`dev.meshx.mobile.harness` (iOS harness, bundle `dev.meshx.mobile.harness`).

## Pre-flight

```sh
# All three devices reachable?
adb devices && xcrun devicectl list devices | grep -i dairy

# Fresh build + install (Android)
cd apps/meshx_mobile_app/android
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
for s in R52W90AW7EN 5200f354f4fb277f; do
  adb -s $s install -r -t app/build/outputs/apk/debug/app-debug.apk
  adb -s $s install -r -t app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
done

# Fresh run directory
RUN_TS=$(date +%Y%m%d-%H%M%S)
ROOT=artifacts/local-ble/$(date +%Y-%m-%d)-recapture-N
mkdir -p $ROOT/{ios,android,test,evidence}
```

## iOS harness launch patterns

```sh
UDID=1780F216-CB5C-560B-A86F-85D31F79ADEF

# Hybrid emit (MB cue + direct-MX service data on …1001)
xcrun devicectl device process launch --device $UDID --terminate-existing --console \
  dev.meshx.mobile.harness -- --meshx-auto-direct-mx-hybrid-advertise

# MB legacy cue only (canonical production iOS-emit path)
xcrun devicectl device process launch --device $UDID --terminate-existing --console \
  dev.meshx.mobile.harness -- --meshx-auto-beacon

# Observer (raw advert dump + candidate discovery logs)
xcrun devicectl device process launch --device $UDID --terminate-existing --console \
  dev.meshx.mobile.harness -- \
    --meshx-auto-scan --meshx-log-raw-advert-data --meshx-log-candidate-discoveries
```

## Android launch patterns

```sh
SM=R52W90AW7EN  # or 5200f354f4fb277f

# Main app with selftest scan + advertise (the production NIF path)
adb -s $SM shell am start -n dev.meshx.mob/.MainActivity \
  --ez meshx_ble_selftest true --es mob_node_suffix lab

# Instrumented hybrid receive test
adb -s $SM shell am instrument -w \
  -e class dev.meshx.mob.ble.IOSHybridDirectMxReceiveTest \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner

# Instrumented hybrid emit (Android → iOS)
adb -s $SM shell am instrument -w \
  -e class dev.meshx.mob.ble.IOSAuxFullMxAdvertSmokeTest#emitsHybridMbCuePlusServiceDataFullMxEnvelope \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
```

## Logcat capture

```sh
# Filtered for hybrid + scan + selftest
adb -s $SM logcat -c
adb -s $SM logcat -v threadtime \
  HybridExperiment:* MeshxBleScanRaw:* BleSelfTest:* \
  MeshxBleNative:* MeshxBleNif:* Elixir:I BEAMout:I '*:S' \
  > $ROOT/android/$RUN_TS-logcat.log &
LOGPID=$!
# ... run emit / test ...
kill $LOGPID; wait $LOGPID 2>/dev/null
```

## Validation day order

1. **Scanner sanity** (verifies the 683950a main-looper fix). Launch
   main app with `meshx_ble_selftest=true` on both Android devices,
   emit MB beacons from iPhone. Watch `BleSelfTest: HEARTBEAT` —
   pass iff `devices > 0` and `beacon_callbacks > 0`. If still zero,
   the regression is back.

2. **Carrier-decision re-confirm.** Run `IOSHybridDirectMxReceiveTest`
   on SM-T577U while iPhone emits hybrid. Expected per the rejected
   carrier: MB cues received, `direct_MX_envelopes=0`.

3. **Positive production-path evidence.** iPhone emits MB legacy cue
   only; Android performs GATT fetch in response. Look for matching
   messageId across `HYBRID_SUCCESS` / `iOS_HYBRID_STARTED` lines plus
   visible GATT activity. Capture at least one clean run per Android
   device (T390 covers older API/BT4 fleet).

4. **Optional — reverse direction.** Android emits hybrid via
   `emitsHybridMbCuePlusServiceDataFullMxEnvelope`; iPhone observes
   with raw logging. Expected per recapture-4: 52+ MB cues on iOS,
   zero direct-MX (iOS scan-side restriction).

## Correlation / evidence cheats

```sh
# Pull messageIds from both sides
grep -oE "messageId=[0-9a-f]+" $ROOT/ios/*.log | sort -u
grep -oE "messageId=[0-9a-f]+" $ROOT/android/*.log | sort -u

# Confirm hybrid emit on iOS
grep -E "iOS_HYBRID_STARTED|HYBRID_WINDOW_COMPLETE" $ROOT/ios/*.log

# Confirm receive on Android
grep -E "HYBRID_(RECEIVED|SUCCESS)|DIRECT_MX_SERVICE_DATA_WITH_MAGIC" $ROOT/android/*.log

# MeshX MB cues at iOS (mfg data starts with ffff)
grep -cE "kCBAdvDataManufacturerData=ffff" $ROOT/ios/*.log
```

## Gotchas

- **SM-T390 (Android 9):** `GrantPermissionRule` fails on API 28; the
  Hybrid receive test never reaches BLE logic. Run instrumented tests
  on SM-T577U only; use main-app selftest path for T390 fleet coverage.
- **iOS scan-side restriction:** `scanForPeripherals(withServices: nil)`
  excludes extended adverts on custom 128-bit UUIDs. iPhone will never
  see the direct-MX `…1001` envelope; only the MB cue. This is by design
  and documented in `ble_carrier_decision.md`.
- **iOS emit-side restriction:** CoreBluetooth foreground drops
  third-party `kCBAdvDataManufacturerData` + custom 128-bit service
  data. iOS console logs `direct_mx_service_data_started=true` while
  the radio transmits nothing. Verify against Android receive, never
  trust the iOS console alone.
- **Main-looper requirement (fixed in `683950a`):** if you're on a
  build before that commit, the main-app scanner reports `:ok` but
  delivers no callbacks. Confirm the build is fresh.
- **Temporary DIAG instrumentation:** if `IOSHybridDirectMxReceiveTest`
  has `setLegacy(false)` or `DIAG` log lines, it's pre-cleanup. The
  test asserts MB cue receipt — `setLegacy(false)` blocks that.

## Post-run hygiene

- Move logs into `$ROOT/{ios,android,test}/` if not already structured.
- Write `$ROOT/evidence/$RUN_TS-summary.md` (template:
  `artifacts/local-ble/2026-05-18-iphone13-direct-mx-hybrid/recapture-4-reverse/evidence/20260518-095213-summary.md`).
- Strip any temporary DIAG / `setLegacy(false)` from tests before push.
- `git status` — confirm only artifact files outside the gitignored
  `local-ble/` paths are staged.
