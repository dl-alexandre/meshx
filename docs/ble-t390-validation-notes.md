# T390 (SM-T390 / Android 9 / API 28) On-Device Validation Notes

Focused practical guide for the older Android test device (serial `5200f354f4fb277f`).  
Companion to `docs/ble-lab-cheat-sheet.md` and the T390 sections in `docs/upstream_mob_migration_checklist.md`.

**Core rule**: Keep the device awake for all selftest / scan work. API 28 registers scans while dozing but delivers zero callbacks to the main-app selftest (observed 2026-05-18 diagnostic run). The positive MB+GATT evidence run required the awake preflight.

## Awake Preflight (mandatory before every T390 capture)

```sh
adb -s 5200f354f4fb277f shell input keyevent WAKEUP
adb -s 5200f354f4fb277f shell svc power stayon true
```

Run this immediately before launching the main app selftest or instrumented test. Pair with `adb shell input keyevent KEYCODE_HOME` or keyguard dismiss if needed for bench stability.

## Selftest Path vs Instrumented Test Path

- **Main-app selftest** (`meshx_ble_selftest=true` intents): exercises the **exact shipping** `BleScanner` + bridge + fetch coordinator code path. Preferred for production scanner confidence and positive MB+GATT release evidence.
- **Instrumented tests** (the four `*Test.kt`): `IOSHybridDirectMxReceiveTest`, `IOSAuxFullMxAdvertSmokeTest`, `IOSResponderFetchSmokeTest`, `MXFullEnvelopeSmokeTest`. Now unblocked on T390 by the version-aware permission shim (see below). Useful for targeted negative carrier evidence (hybrid) and responder smoke, but still shim-exercising rather than the prod main-activity path.

**Recommendation (2026-05-18 session)**: Use selftest + `capture-hybrid-run.sh` for all positive evidence and regression recipes on T390. Use instrumented tests when you specifically need the JUnit harness or hybrid negative probes.

## Running Positive MB+GATT Evidence (production path, Android-only pair recommended)

Proven recipe (archived in `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`):

1. Fresh debug build with full-MX sender opt-in on the emitter:
   ```sh
   cd apps/meshx_mobile_app/android
   MESHX_MX_SEND=true ./gradlew :app:assembleDebug
   adb -s R52W90AW7EN install -r app/build/outputs/apk/debug/app-debug.apk
   adb -s 5200f354f4fb277f install -r app/build/outputs/apk/debug/app-debug.apk
   ```

2. Create structured capture root (recommended):
   ```sh
   RUN_TS=$(date +%Y%m%d-%H%M%S)
   ROOT=artifacts/local-ble/$(date +%Y-%m-%d)-recapture-N
   mkdir -p $ROOT/{t390-rx,t577u-tx}
   cp scripts/capture-hybrid-run.sh scripts/verify-t390-gatt-capture.sh $ROOT/t390-rx/
   cp scripts/capture-hybrid-run.sh scripts/verify-t390-gatt-capture.sh $ROOT/t577u-tx/
   ```

3. Awake T390 (see section above).

4. Receiver (T390) in one terminal:
   ```sh
   cd $ROOT/t390-rx
   ./capture-hybrid-run.sh --serial 5200f354f4fb277f --run-ts $RUN_TS \
     --selftest --duration 120 --selftest-send false --node-suffix t390
   ```

5. Sender (SM-T577U) in second terminal (full-MX debug):
   ```sh
   cd $ROOT/t577u-tx
   ./capture-hybrid-run.sh --serial R52W90AW7EN --run-ts $RUN_TS \
     --selftest --duration 120 --selftest-send true --node-suffix t577u
   ```

6. Success signals (in T390 logcat / selftest output):
   - `BleSelfTest: HEARTBEAT events=... devices=1 ... beacon_callbacks=NN`
   - `BleSelfTest: DISTINCT MESH MESSAGE kind=beacon ...`
   - `MeshxBeaconFetch: fetch_start ...`
   - `fetch_connect_result`, `fetch_service_discovery_result`, `fetch_response_received` with `envelope_parse":"ok"`
   - `BleSelfTest: DISTINCT MESH MESSAGE kind=envelope ... from=meshx-t577u`

7. Post-capture verification (accepts lightweight `GATT_FETCH_RECEIVED` or full selftest envelope markers):
   ```sh
   cd $ROOT/t390-rx
   ./verify-t390-gatt-capture.sh $RUN_TS .
   ```
   Reference archive: `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`.

Use the helper for reproducible filtered logs and subdir layout. When broad `adb logcat` is too noisy, the dedicated capture script is the reliable path.

## Running Instrumented Tests (post-permission-shim)

The shim (conditional legacy `BLUETOOTH`/`BLUETOOTH_ADMIN` + `ACCESS_FINE_LOCATION` for API < 31) lives in the `@Rule` of each test class and lets `GrantPermissionRule` succeed on T390.

Build both APKs first:
```sh
cd apps/meshx_mobile_app/android
./gradlew :app:assembleDebug :app:assembleDebugAndroidTest
adb -s 5200f354f4fb277f install -r -t app/build/outputs/apk/debug/app-debug.apk
adb -s 5200f354f4fb277f install -r -t app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

Awake the device, then run any of the four:

```sh
# Negative carrier evidence (iOS hybrid emit + Android receive)
adb -s 5200f354f4fb277f shell am instrument -w \
  -e class dev.meshx.mob.ble.IOSHybridDirectMxReceiveTest \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner

# AUX / full-MX advert smoke
adb -s 5200f354f4fb277f shell am instrument -w \
  -e class dev.meshx.mob.ble.IOSAuxFullMxAdvertSmokeTest \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner

# Responder fetch smoke (iOS responder)
adb -s 5200f354f4fb277f shell am instrument -w \
  -e class dev.meshx.mob.ble.IOSResponderFetchSmokeTest \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner

# MX envelope send smoke
adb -s 5200f354f4fb277f shell am instrument -w \
  -e class dev.meshx.mob.ble.MXFullEnvelopeSmokeTest \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
```

Expect the tests to reach BLE (previously blocked by permission grant on API 28). For negative hybrid carrier runs, launch iOS harness first with `--meshx-auto-direct-mx-hybrid-advertise` (see `ble-lab-cheat-sheet.md`).

## Known Limitations & 2026-05-18 Session Tips

- **Doze / screen-off**: T390 (API 28) pauses unfiltered scans when screen is off even if the scan was accepted. Always use the WAKEUP + stayon sequence + keep device visible/charged on the bench.
- **Main-looper scanner fix**: Pre-`683950a` builds report scan start `:ok` but deliver no `BleEvent` callbacks. Always verify fresh build after scanner changes.
- **Carrier decision**: iOS direct-MX hybrid (`...1001` service data) produces zero usable envelopes on Android in practice (CoreBluetooth foreground restriction). Use `IOSHybridDirectMxReceiveTest` + iOS hybrid launch only for negative evidence (`direct_MX_envelopes=0` expected). Never rely on it for positive interop.
- **iOS emitter for T390 parity**: CoreBluetooth also drops custom manufacturer data in some foreground cases; Android-only sender (T577U debug) is the cleanest path for T390 positive MB+GATT proof.
- **Structured runs**: Prefer `capture-hybrid-run.sh --selftest ...` over raw `am start` + `logcat` for every lab session. It produces timestamped, filtered artifacts under the conventional `recapture-N/{ios,android,test,evidence}` layout.
- **Verification**: `verify-t390-gatt-capture.sh` is the quick gate after a T390 receiver run. It tolerates both the lightweight `GATT_FETCH_RECEIVED` marker and the full selftest envelope path.
- **Permission shim note**: The shim is deliberately narrow and version-gated so it does not affect API 31+ behavior. It only unblocks the test runner on the minSdk=28 device.
- **Rebuild hygiene**: After any `BleScanner` or test change, reassemble both debug + androidTest APKs and reinstall (`-r -t`) before the next T390 run.
- **Cache / TMPDIR**: The app seeds a writable cache dir; `MeshxStore.DB` failures on API 28 are usually fixed by a clean reinstall.

## Quick One-Shot T390 Selftest (no capture script)

```sh
# Awake
adb -s 5200f354f4fb277f shell input keyevent WAKEUP
adb -s 5200f354f4fb277f shell svc power stayon true

# Receiver (no send)
adb -s 5200f354f4fb277f shell am start -n dev.meshx.mob/.MainActivity \
  --ez meshx_ble_selftest true \
  --ez meshx_ble_selftest_send false \
  --ez meshx_ble_fetch_on_beacon true \
  --es mob_node_suffix t390 \
  --activity-clear-top

# Watch logcat for HEARTBEAT + fetch + envelope signals
```

For the next lab session, copy the structured capture recipe from the cheat sheet "Quick focused T390 MB+GATT positive evidence capture" section and always start with the awake commands.

**End of notes.** Update this file with any new T390-specific gotchas discovered in future sessions.
