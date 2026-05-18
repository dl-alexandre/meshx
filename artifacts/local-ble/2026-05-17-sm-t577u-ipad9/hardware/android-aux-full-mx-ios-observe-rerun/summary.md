# Android AUX Full-MX Advert -> iOS Observe Rerun

Date: 2026-05-17.
Last verified: 2026-05-17T11:19:47-0700.

This rerun targeted the remaining direct full-MX extended-advertising
interop row. It does not complete that row.

## Devices

- Android emitter: SM-T577U `R52W90AW7EN`, Android 13/API 33.
- iOS observer: Coding iPad, iPad12,1, iOS 26.5.

## Commands

Launch the iOS observer:

```sh
xcrun devicectl device process launch \
  --device 39FD8D3A-9CA5-5DEF-AFC0-AA5205511117 \
  --terminate-existing \
  --console dev.meshx.mobile.harness \
  -- --meshx-auto-scan --meshx-log-candidate-discoveries
```

Run the Android emitter:

```sh
adb -s R52W90AW7EN shell am instrument -w \
  -e class dev.meshx.mob.ble.IOSAuxFullMxAdvertSmokeTest \
  dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
```

## Result

- Android instrumentation: `OK (1 test)`.
- Android radio capability: extended advertising supported, maximum
  advertising data length 1024.
- Android advertiser event: `advertising_set_started` with
  `payload_size=80`, `scannable=true`, `connectable=false`, and
  `data_carrier="scan_response"`.
- iOS observer session: scan started and observed 120 MB legacy-beacon
  lines, proving the scanner was active and still receiving the fleet-safe
  fallback path.
- iOS observer session: zero `received_message`, zero decode-error, zero
  candidate/discovery lines, and zero `FF FF 4D 58`/MX callback evidence for
  the direct full-MX AUX payload.

This is fresh negative evidence for the iOS direct full-MX AUX path: the
Android sender accepted and started an extended scan-response advert, but iOS
CoreBluetooth did not surface the MX manufacturer data to the harness callback
in this run.

## Artifacts

- `android-instrumentation.log`
- `android-logcat.log`
- `ipad-aux-scan-response.log`
