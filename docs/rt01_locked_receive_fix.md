# RT-01 locked-receive fix — design

## Problem (measured)

`scripts/android/rt01-sustained.sh` run `rt-01-sustained-002` (2026-05-27, T577U /
Android 13 / API 33) gave a deterministic result: **a locked device receives
nothing.** With a deterministic sender (`mob.ble.SustainedAdvertiseDriver`
advertising every 75 s) and a confirmed-healthy *awake* receive path, a 10‑minute
screen‑off hold produced `receive_events_in_window=0`, `after_5m=0`, and no
post‑unlock resume — despite the foreground service + Doze battery‑whitelist from
commit `292da30`.

Isolated: not the sender, not power/wakefulness, not the awake path. The break is
the **receiver's background BLE scan stopping on screen‑off.**

## Root cause

`apps/mob_ble/priv/native/android/.../BleScanner.kt` starts the scan as:

```kotlin
leScanner.startScan(null, settings, callback)   // null filters, ScanCallback, SCAN_MODE_LOW_LATENCY
```

Two Android facts make this fail when locked:

1. **Unfiltered scans are halted while the screen is off.** Since Android 8.1, a
   `startScan` with `null`/empty filters delivers no results once the screen
   turns off — *by design*, independent of any foreground service. This alone
   explains `after_5m=0`.
2. **A `ScanCallback` scan is bound to the app process** and is subject to
   background-scan throttling; it does not survive the process being backgrounded
   the way a `PendingIntent` scan does.

`292da30` added FGS type `connectedDevice` + a Doze whitelist, which keeps the
**BEAM alive** (so *send* survives) — but it does nothing about the unfiltered‑scan
screen‑off rule, because the scan still has `null` filters and is owned by the
BEAM thread, not a foreground service.

## Fix — layered, cheapest lever first

The MeshX advert always carries a known signature (from `BleDispatcher`):
`MOB_SERVICE_UUID` (added via `addServiceUuid`) and manufacturer data under
`MOB_COMPANY_IDENTIFIER = 0xFFFF`. So a filter is available.

### 1. Add a `ScanFilter` (primary — likely sufficient, smallest change)
Replace `null` with a filter on the MeshX signature so the scan is no longer the
screen‑off‑killed unfiltered kind:

```kotlin
val filters = listOf(
  ScanFilter.Builder()
    .setServiceUuid(ParcelUuid(BleDispatcher.MOB_SERVICE_UUID))
    .build()
)
leScanner.startScan(filters, settings, callback)
```

Trade‑off: a filtered scan only reports adverts that carry that UUID — confirm
every MeshX advert the receiver must see (MB beacon cue **and** the fetch‑service
advert) includes `MOB_SERVICE_UUID` or `0xFFFF` manufacturer data; add a second
`ScanFilter` for the manufacturer id if the MB beacon doesn't carry the UUID.
Lives entirely in `BleScanner.kt` (mob_ble submodule).

### 2. Foreground‑service‑owned scan (secondary)
Start/stop the scan from the `BeamForegroundService` (already FGS type
`connectedDevice` after `292da30`) rather than the BEAM worker thread, so the app
counts as foreground for scan‑throttle purposes for the whole locked window.

### 3. `PendingIntent` scan (strongest, optional)
`leScanner.startScan(filters, settings, pendingIntent)` — the OS delivers results
via a broadcast even if the app process is backgrounded or killed. Requires
non‑null filters (provided by #1). Higher latency, OEM‑variable; needs a
`BroadcastReceiver` that re‑injects results into the BEAM via the existing
`nativeDeliverEvent` path. Reserve for if #1+#2 still throttle on some OEM.

## Validation

Re‑run the **same harness** after each lever:

```sh
scripts/android/rt01-sustained.sh --sender 5200f354f4fb277f --receiver R52W90AW7EN \
  --run-id rt-01-sustained-fixN --hold-secs 900
```

Pass = `receive_events_after_5m >= 1` (ideally rising across bursts). The harness’s
live `locked deliveries=` now uses the analyzer’s definition (commit `bc1dd96`), so
in‑run progress matches the final verdict.

## Scope / risk

All three levers are **native** (mostly `BleScanner.kt` in the `mob_ble`
submodule) and require an **app rebuild + reinstall** — the one operation that
touches `dev.mob.mob`'s embedded BEAM payload (`install -r` preserves `/data`,
but validate the BEAM still boots after). Start with lever #1: one‑file change,
biggest expected lever, then re‑measure before doing more.
