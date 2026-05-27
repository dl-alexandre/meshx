# RT-01 locked-receive — fix levers (post lever-#1)

Follow-up to `docs/rt01_locked_receive_fix.md`. Lever #1 (blanket `ScanFilter`)
was tried and **reverted** (mob_ble `3bbbfef`): it regressed *awake* receive —
the filter matched the 30 s fetch-service advert (`advertisement_received` seen)
but `beacon_callbacks=0`, so `fetch_on_beacon` never triggered. This doc designs
the two real levers, grounded in the actual advert construction.

## What the sender actually broadcasts (measured, `rt-01-sustained-002`)

`SustainedAdvertiseDriver` → `MobBleNative.sendFullMxEnvelope` emits **two**
concurrent things:

1. **Fetch service** (`MobFetchGatt`, `SERVICE_UUID …2000`) — connectable GATT
   server + service-UUID advert, up for the ~30 s responder window.
2. **Legacy MB beacon cue** (`BleDispatcher.startLegacyAdvertising`, line 80):
   `AdvertiseData.addManufacturerData(0xFFFF, payload)` in the **advertise
   packet** (NOT scan response), `connectable=false`, advertised for only
   `window_ms = 5000` (~5 s) per burst.

`fetch_on_beacon` needs to see **(2)**, the short 5 s manufacturer-data beacon,
to start a fetch. Critical correction to the lever-#1 post-mortem: the legacy
beacon's `0xFFFF` data is in the *advertise packet*, so a `ScanFilter` on `0xFFFF`
*should* match it — the `beacon_callbacks=0` was most likely a **timing miss**
(the filtered scan didn't overlap the 5 s window) or `setManufacturerData(id,
ByteArray(0))` empty-match quirk, **not** an unmatchable scan-response payload.
(Only `startExtendedAdvertising` when `scannable` puts data in scan response,
line 126 — and the cue used the legacy path, `data_carrier:legacy_advertisement`.)

## Lever 2a — FGS-owned scan (recommended first; lowest regression risk)

Keep the scan **unfiltered** (so awake receive behaves exactly as the proven
working `sustained-002`), but start/own it from the foreground service so the app
is "foreground" for Android's background-scan rule.

- `BeamForegroundService` (meshx_mobile_app) is already FGS type
  `connectedDevice` (`292da30`). Add a start path that, on `ACTION_START`,
  triggers the scan to (re)start within the service's foreground context.
- Mechanism options: (i) have `MobBleNative.startScan` post the
  `BluetoothLeScanner.startScan` from a context the FGS holds, or (ii) the FGS
  calls into `MobBleNative.startScan()` after `startForeground` so the scan's
  lifecycle is bound to the FGS.
- **No filter change** → awake receive unaffected → no repeat of the lever-#1
  regression.
- **Unknown it tests:** whether a foreground service is sufficient to keep an
  *unfiltered* scan delivering on screen-off on API 33 (the 8.1 rule targets
  *background* apps; an FGS may or may not exempt — device-specific). One run
  answers it.

## Lever 2b — beacon-matched filter (if 2a doesn't survive screen-off)

A filtered scan *does* survive screen-off; lever #1 just didn't reliably catch
the 5 s legacy beacon. Make the cue catchable:

1. **Filter on `0xFFFF` manufacturer data with a concrete prefix**, not empty
   bytes: the beacon payload starts with the MB magic (`"MB\x01…"`,
   `0x4D 0x42 0x01`). Use
   `setManufacturerData(0xFFFF, byteArrayOf(0x4D,0x42,0x01), byteArrayOf(-1,-1,-1))`
   so the match is specific and avoids the empty-data quirk — and add the two
   service-UUID filters (`MOB_SERVICE_UUID …1000`, `MobFetchGatt.SERVICE_UUID …2000`)
   as OR backstops for the fetch-service advert.
2. **Widen the beacon's on-air window** so a filtered (slower, screen-off) scan
   overlaps it: raise `window_ms` for the cue, or re-advertise the cue across the
   burst rather than once for 5 s. (Sender-side, in the `SustainedAdvertiseDriver`
   hold loop or the dispatch window.)
3. If any cue path ever uses `startExtendedAdvertising(scannable=true)`, add a
   matching `setServiceData(ParcelUuid(serviceDataUuid), prefix, mask)` filter,
   since that payload lives in the scan response.

## Pre-flight diagnostic (do this on-device before committing to either)

Before a full hold, confirm awake which adverts the filter matches:
`adb -s <receiver> logcat` while the sender bursts, grep
`advertisement_received` vs `beacon_callbacks` — verify the **legacy beacon**
(not just the fetch service) reaches the receiver under whatever filter/no-filter
is in place. This is exactly what lever #1's awake-confirm caught; keep it as the
gate.

## Validation

Same harness, one run each:

```sh
scripts/android/rt01-sustained.sh --sender 5200f354f4fb277f --receiver R52W90AW7EN \
  --run-id rt-01-lever2a --hold-secs 900
```

Pass = `receive_events_after_5m >= 1`. The awake-confirm gate fails fast (~3 min)
if a lever regresses awake receive, so iterations are cheap.

## Recommended order

1. **2a first** — no filter change, can't regress awake; one run tells us if FGS
   ownership alone keeps the unfiltered scan alive locked.
2. If 2a still dies on screen-off → **2b** with the prefix-matched `0xFFFF`
   filter + a widened cue window.

Both are native (`mob_ble` `BleScanner`/`MobBleNative` + meshx_mobile_app
`BeamForegroundService`) and need an app rebuild + reinstall on the **receiver**
(T577U) — the BEAM-payload-touching step; `install -r` preserves `/data`.
