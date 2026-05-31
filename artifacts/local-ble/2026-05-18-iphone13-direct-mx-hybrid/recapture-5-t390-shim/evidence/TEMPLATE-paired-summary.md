# Recapture-5c — iPhone 13 emit → SM-T390 receive (paired, unlocked)

**Date:** 2026-05-18 HH:MM:SS  
**RUN_TS:** `YYYYMMDD-HHMMSS`

**Goal:** First fully-paired iPhone → T390 instrumented receive run.
Earlier runs in recapture-5 either had no emitter (iPhone locked) or
substituted R52 for the emitter. This closes the loop with the
intended emitter-receiver pair.

## Devices

- **Emitter:** iPhone 13 (DairyPhoneDeaux, UDID `1780F216-CB5C-560B-A86F-85D31F79ADEF`) — `Mob.NodeHarness` launched via `devicectl` with `--mob-auto-direct-mx-hybrid-advertise`. **Screen unlocked and kept awake for the full window.**
- **Receiver:** SM-T390 (`5200f354f4fb277f`), Android 9 / API 28 — `IOSHybridDirectMxReceiveTest` with the version-aware permission shim.

## Run

- Receiver: `am instrument -w` in background; 45 s window + 2 s settle.
- iPhone emit triggered ~3 s after receiver start so the scan is live before any beacons appear.
- iPhone messageId: `__FILL_IN_FROM_LOG__`.

## Results

| Signal | Value |
|---|---:|
| iPhone `iOS_HYBRID_STARTED` | _yes/no_ |
| iPhone `iOS_HYBRID_WINDOW_COMPLETE` | _yes/no_ |
| Receiver reached `@Test` | ✓ (shim works) |
| `production_sink_events` | `__N__` |
| `MB_cues` | `__N__` |
| `direct_MX_envelopes` | `__N__` |
| `fetch_svc_sightings` | `__N__` |
| Test result | `PASS` / `FAIL on <which assertion>` |

## Interpretation

Expected per the carrier-decision pattern (see
`docs/ble_carrier_decision.md`, recapture-3 with R52 receiver):

- `MB_cues > 0` — legacy MB beacon path is the iOS-supported emit channel.
- `direct_MX_envelopes = 0` — direct-MX service-data carrier remains
  blocked by iOS CoreBluetooth foreground restrictions on the emit side.
- Test fails on the **direct-MX** assertion, not on the MB-cue assertion.

If `MB_cues = 0` despite a live emitter:
- T390-specific receive-path issue (Android-9 ScanRecord parsing or
  bench RF). Cross-check against R52 with the same emitter — if R52
  sees MB cues but T390 doesn't, that's a T390 receive triage item,
  not a carrier-decision regression.

## Artifacts

- `android-rx/<RUN_TS>-logcat.log` — T390 receiver filtered logcat.
- `android-rx/<RUN_TS>-test-result.txt` — receiver `am instrument` output.
- `ios/<RUN_TS>-ios-console.log` — iPhone harness console.

## Closes

- "Permission shim end-to-end with intended emitter" — the final
  data point that recapture-5's earlier runs were missing.
- T390 fleet coverage on the instrumented receive path.
