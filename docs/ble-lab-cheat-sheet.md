# BLE Lab Cheat Sheet

Single-page reference for on-device BLE validation runs. Keep printed or
phone-bookmarked. Companion to `docs/BLE_BRIDGE.md` and
`docs/ble_carrier_decision.md`.

Uses the structured capture layout + `capture-hybrid-run.sh` (see
`artifacts/local-ble/2026-05-18-iphone13-direct-mx-hybrid/`).

## Devices

| Role          | Device      | ID                                       | OS         |
|---------------|-------------|------------------------------------------|------------|
| iPhone (iOS)  | DairyPhoneDeaux | `1780F216-CB5C-560B-A86F-85D31F79ADEF` | iOS 16+    |
| Android #1    | SM-T577U    | `R52W90AW7EN`                            | Android 13 |
| Android #2    | SM-T390     | `5200f354f4fb277f`                       | Android 9  |

App IDs: `dev.mob.mob` (Android main + `.test` runner) /
`dev.mob.node.harness` (iOS harness, bundle `dev.mob.node.harness`).

## Pre-flight

```sh
# All three devices reachable?
adb devices && xcrun devicectl list devices | grep -i dairy

# Fresh build + install (Android)
cd apps/mob_node/android
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
for s in R52W90AW7EN 5200f354f4fb277f; do
  adb -s $s install -r -t app/build/outputs/apk/debug/app-debug.apk
  adb -s $s install -r -t app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
done

# Fresh structured run (recommended)
RUN_TS=$(date +%Y%m%d-%H%M%S)
ROOT=artifacts/local-ble/$(date +%Y-%m-%d)-recapture-N
mkdir -p $ROOT/{ios,android,test,evidence}
# Then use the helper below for Android side (creates timestamped subdirs)
```

## iOS harness launch patterns

```sh
UDID=1780F216-CB5C-560B-A86F-85D31F79ADEF

# Hybrid emit (MB cue + direct-MX service data on …1001)
xcrun devicectl device process launch --device $UDID --terminate-existing --console \
  dev.mob.node.harness -- --mob-auto-direct-mx-hybrid-advertise

# MB legacy cue only (canonical production iOS-emit path)
xcrun devicectl device process launch --device $UDID --terminate-existing --console \
  dev.mob.node.harness -- --mob-auto-beacon

# Observer (raw advert dump + candidate discovery logs)
xcrun devicectl device process launch --device $UDID --terminate-existing --console \
  dev.mob.node.harness -- \
    --mob-auto-scan --mob-log-raw-advert-data --mob-log-candidate-discoveries
```

## Android launch patterns (preferred = structured helper)

```sh
SM=R52W90AW7EN  # or 5200f354f4fb277f

# Preferred: structured capture (creates timestamped subdirs + filtered logs)
./capture-hybrid-run.sh --serial $SM --run-ts $RUN_TS

# Main app with selftest (quick scanner sanity / production path)
adb -s $SM shell am start -n dev.mob.mob/.MainActivity \
  --ez mob_ble_selftest true --es mob_node_suffix lab

# Receive-side MB+GATT selftest (clean positive-evidence mode)
adb -s $SM shell am start -n dev.mob.mob/.MainActivity \
  --ez mob_ble_selftest true \
  --ez mob_ble_selftest_send false \
  --ez mob_ble_fetch_on_beacon true \
  --es mob_node_suffix lab

# T390 bench pre-flight: keep API 28 device awake or scans can register
# while selftest receives zero callbacks.
adb -s 5200f354f4fb277f shell input keyevent WAKEUP
adb -s 5200f354f4fb277f shell svc power stayon true

# Instrumented hybrid receive test (direct)
adb -s $SM shell am instrument -w \
  -e class dev.mob.mob.ble.IOSHybridDirectMxReceiveTest \
  dev.mob.mob.test/androidx.test.runner.AndroidJUnitRunner

# Instrumented hybrid emit (Android → iOS)
adb -s $SM shell am instrument -w \
  -e class dev.mob.mob.ble.IOSAuxFullMxAdvertSmokeTest#emitsHybridMbCuePlusServiceDataFullMxEnvelope \
  dev.mob.mob.test/androidx.test.runner.AndroidJUnitRunner
```

## Capture helper (recommended for reproducible runs)

```sh
# From the repo root
cd artifacts/local-ble/2026-05-18-...-recapture-N

./capture-hybrid-run.sh --serial R52W90AW7EN --run-ts $RUN_TS
```

The script:
- Clears logcat
- Starts filtered background capture
- Runs the requested instrumented test
- Saves everything under `android/$RUN_TS-*.log`

Use it for steps 2–4 of the validation day.

## Logcat capture (use the helper when possible)

```sh
# Preferred (via capture-hybrid-run.sh)
./capture-hybrid-run.sh --serial $SM --run-ts $RUN_TS

# Manual filtered capture (hybrid/scan/selftest focus)
adb -s $SM logcat -c
adb -s $SM logcat -v threadtime \
  HybridExperiment:* MobBleScanRaw:* BleSelfTest:* \
  MobBleNative:* MobBleNif:* Elixir:I BEAMout:I '*:S' \
  > $ROOT/android/$RUN_TS-logcat.log &
LOGPID=$!
# ... run emit / test ...
kill $LOGPID; wait $LOGPID 2>/dev/null
```

## Validation day order (use the helper for steps 2–4)

1. **Scanner sanity** (verifies the 683950a main-looper fix). Launch
   main app with `mob_ble_selftest=true` on both Android devices,
   emit MB beacons from iPhone. Watch `BleSelfTest: HEARTBEAT` —
   pass iff `devices > 0` and `beacon_callbacks > 0`.

2. **Carrier-decision re-confirm.** Use
   `./capture-hybrid-run.sh` + `IOSHybridDirectMxReceiveTest` while
   iPhone emits hybrid. Expected: MB cues received,
   `direct_MX_envelopes=0` (service-data carrier rejected).

3. **Positive production-path evidence.** iPhone emits MB legacy cue
   only; Android performs GATT fetch. Look for matching messageId +
   visible GATT. Use the helper for clean artifacts.

4. **Optional — reverse direction.** Android emits hybrid via the
   AUX test method; iPhone observes with raw logging.

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

- **SM-T390 (Android 9 / API 28):** Previously `GrantPermissionRule` failed
  for post-31 Bluetooth perms and instrumented tests (IOSHybrid*, AUX, Responder,
  MXEnvelope) never reached BLE. Fixed by version-aware permission shim in the
  four `*Test.kt` files (conditional legacy BT + FINE_LOCATION for <31). The
  tests now run on the full minSdk=28 fleet. Still prefer the main-app
  `mob_ble_selftest` path (see "Main app with selftest" recipe) for T390
  production scanner confidence and positive MB+GATT evidence runs, as it
  exercises the exact shipping `BleScanner` + bridge code.
- **T390 awake requirement:** For API 28 bench captures, run
  `adb -s 5200f354f4fb277f shell input keyevent WAKEUP` and
  `adb -s 5200f354f4fb277f shell svc power stayon true` before starting
  selftest. A dozing T390 diagnostic registered the scan but delivered
  no selftest callbacks; the awake run produced the positive MB+GATT
  evidence in `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`.
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
- **DIAG / extended-scan cleanup complete (2026-05-18):** `IOSHybridDirectMxReceiveTest`
  and `BleScanner` hybrid observer are now free of `setLegacy(false)` / duplicate-DIAG spam.
  The test correctly exercises production MB-legacy + direct-service paths (for negative
  carrier evidence: expect `direct_MX_envelopes=0`). Rebuild after edits.

## Post-run hygiene

- Use `./capture-hybrid-run.sh` — it already creates the right
  timestamped subdirs under `ios/`, `android/`, `test/`.
- Write `$ROOT/evidence/$RUN_TS-summary.md` (use a previous one as
  template, e.g. `recapture-4-reverse/evidence/...`).
- `git status` — only stage non-artifact changes outside `local-ble/`.
- (Cleanup done: no more DIAG/setLegacy bits to strip from test or BleScanner hybrid path.)

## Quick focused T390 (SM-T390 / API 28) MB+GATT positive evidence capture

For clean release-bundle evidence of the supported production path on
the older device. The archived positive run used Android-only hardware:
SM-T577U emitted MB legacy cues and served the full envelope over GATT;
SM-T390 observed and fetched via the main-app production path.

1. Fresh full-MX debug build + install on both Androids:
   ```sh
   cd apps/mob_node/android
   MESHX_MX_SEND=true ./gradlew :app:assembleDebug
   adb -s R52W90AW7EN install -r app/build/outputs/apk/debug/app-debug.apk
   adb -s 5200f354f4fb277f install -r app/build/outputs/apk/debug/app-debug.apk
   ```
2. Create dated capture dir + copy the canonical helper:
   ```sh
   RUN_TS=$(date +%Y%m%d-%H%M%S)
   ROOT=artifacts/local-ble/$(date +%Y-%m-%d)-t390-android-mb-gatt
   mkdir -p $ROOT/{t390-rx,t577u-tx}
   cp scripts/capture-hybrid-run.sh scripts/verify-t390-gatt-capture.sh $ROOT/t390-rx/
   cp scripts/capture-hybrid-run.sh scripts/verify-t390-gatt-capture.sh $ROOT/t577u-tx/
   ```
3. Keep T390 awake:
   ```sh
   adb -s 5200f354f4fb277f shell input keyevent WAKEUP
   adb -s 5200f354f4fb277f shell svc power stayon true
   ```
4. Start the T390 receiver capture (terminal A):
   ```sh
   cd $ROOT/t390-rx
   ./capture-hybrid-run.sh --serial 5200f354f4fb277f --run-ts $RUN_TS \
     --selftest --duration 120 --selftest-send false --node-suffix t390
   ```
5. Start the T577U sender capture (terminal B):
   ```sh
   cd $ROOT/t577u-tx
   ./capture-hybrid-run.sh --serial R52W90AW7EN --run-ts $RUN_TS \
     --selftest --duration 120 --selftest-send true --node-suffix t577u
   ```

6. Success looks like (in `t390-rx/android/*-logcat.log`):
   - `BleSelfTest: HEARTBEAT events=... devices=1 ... beacon_callbacks=NN ...`
   - `BleSelfTest: DISTINCT MESH MESSAGE kind=beacon ...`
   - `MobBeaconFetch: fetch_start device_id=... message_id_hash=...`
   - `MobBleFetch {"v":1,"event":"fetch_connect_result"...}`
   - `MobBleFetch {"v":1,"event":"fetch_service_discovery_result"... "service_found":true}`
   - `MobBleFetch {"v":1,"event":"fetch_response_received"... "status":"ok", "envelope_parse":"ok"}`
   - `BleSelfTest: DISTINCT MESH MESSAGE kind=envelope ... from=mob-t577u`

7. Validate:
   ```sh
   cd $ROOT/t390-rx
   ./verify-t390-gatt-capture.sh $RUN_TS .
   ```
   The known-good archive is
   `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`.

The Android app seeds `TMPDIR` to an app-writable cache directory before BEAM
startup, so `Mob.Store.DB` should not fail through `System.tmp_dir!/0` on
API 28. If that error appears in logcat, rebuild and reinstall before rerunning.

This is the minimal lab block for T390; prefers the exact shipping
BleScanner + fetch coordinator path over instrumented tests (which
still exercise the shim on API 28).

### One-shot post-run validation

After the run, validate key signals quickly:

```sh
./scripts/verify-t390-gatt-capture.sh 20260518-164256 \
  artifacts/local-ble/2026-05-18-recapture-7-t390-gatt
```
