---
title: "BLE: iOS foreground CoreBluetooth does not deliver third-party manufacturer data (0xFFFF) or custom 128-bit service data"
repo: "GenericJam/mob_dev"
labels: ["ble", "ios", "documentation", "carrier"]
---

## Summary

Extensive bidirectional hardware testing (iPhone 13 + SM-T577U/T390, May 2026) shows that the direct-MX service-data carrier (custom 128-bit UUID `8F4F1201-...-1001` carrying the full MX envelope) is not delivered on iOS in foreground mode.

- iOS as emitter: The radio does not transmit recognizable manufacturer data (`FFFF 4D 58`) or the custom service-data payload when using non-Apple UUIDs in foreground. Only the 22-byte MB legacy beacon (`FFFF 4D 42`) is reliably emitted.
- iOS as observer: `scanForPeripherals(withServices: nil)` and explicit filters never surface the custom 128-bit service data or extended AUX manufacturer data, even when the Android sender emits it correctly.

This is a CoreBluetooth platform restriction on foreground apps using third-party manufacturer data and custom 128-bit service UUIDs, not a defect in the bridge.

## Evidence bundles

- `artifacts/local-ble/2026-05-18-iphone13-direct-mx-hybrid/recapture-3/` (iPhone emit)
- `artifacts/local-ble/2026-05-18-iphone13-direct-mx-hybrid/recapture-4-reverse/` (Android emit)
- `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/`
- Internal decision record: `docs/ble_carrier_decision.md` (2026-05-18)

## Request

Please document in the mob / mob_dev BLE bridge guidance that for reliable delivery of full MX envelopes (>31 bytes) involving iOS devices, the supported production carrier is:

**MB legacy beacon cue (22-byte manufacturer data) + GATT fetch (responder serving the envelope)**.

Direct service-data and extended-advertising AUX paths should be marked experimental / Android-only or "may work on future iOS releases".

This decision is independent of the Swift sources extension point in #6.

## Cross references

- GenericJam/mob_dev#6
- GenericJam/mob_new#5
- MeshX `docs/BLE_BRIDGE.md` (section "Extended-advertising AUX delivery limitation")
- MeshX `docs/ble_carrier_decision.md`
