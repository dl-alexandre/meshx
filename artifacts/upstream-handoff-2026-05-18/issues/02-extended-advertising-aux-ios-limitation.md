---
title: "BLE: Extended advertising (AUX_ADV_IND + scan response) not delivered to CoreBluetooth didDiscover on iOS for full MX envelopes"
repo: "GenericJam/mob_dev"
labels: ["ble", "ios", "documentation", "extended-advertising"]
---

## Summary

Multiple controlled experiments (Android emitting extended advertising sets with 80-byte full MX envelopes placed in scan response data or advertising data, `setLegacyMode(false)`, scannable) show that iOS `CBCentralManager` `didDiscover` never receives the payload.

Tested configurations:
- Android `setScanResponseData` with 80-byte MX payload
- Android primary `setAdvertisingData` (AUX_ADV_IND)
- Both with and without `withServices:` filter on the iOS side

In every case the iPhone/iPad continued to receive the 22-byte MB legacy beacons (`FFFF 4D 42`) on the primary channels, proving the link and scanner were working, but zero `FFFF 4D 58` or custom service-data from the extended set reached the app.

## Key artifact

`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md` (SM-T577U sender, iPad12,1 observer, 276 MB beacons observed, 0 direct MX).

Additional raw-advert logging via the iOS harness (`--meshx-log-raw-advert-data`) is available to inspect exactly which `advertisementData` keys arrive.

## Request

Document the limitation in the bridge / mob_dev guidance:

> On current iOS (tested through iPadOS 26.5 / iOS 26.4), extended advertising manufacturer data and custom service data placed in AUX_ADV_IND or scan responses are not surfaced to `CBCentralManagerDelegate.didDiscoverPeripheral` for third-party UUIDs. The MB legacy beacon + GATT fetch path remains the only validated route for full MX envelopes involving iOS.

This is an iOS CoreBluetooth API characteristic, not a bridge bug. Future iOS releases may relax this; the limitation should be called out so downstream projects do not spend time on unworkable direct-AUX paths.

Cross-ref: GenericJam/mob_dev#6, GenericJam/mob_new#5 (these two PRs unblock patch removal for the build side; this issue is the corresponding documentation / carrier guidance item).
