---
title: "BLE: Recommend MB legacy beacon + GATT fetch as the documented canonical path for full MX envelopes involving iOS"
repo: "GenericJam/mob"
labels: ["ble", "documentation", "ios", "android"]
---

## Summary

After four independent device-pair hardware validation runs (iPhone 13 ↔ SM-T577U, SM-T390, R52, plus reverse), the only cross-platform route that reliably delivers full MX envelopes (>31 bytes) between Android and iOS is:

**MB legacy 22-byte manufacturer-data beacon (as cue) + GATT fetch (responder serving the complete envelope over the MeshX fetch service).**

Direct-MX service-data (custom 128-bit UUID) and extended AUX advertising were exhaustively tested in both directions and rejected due to iOS CoreBluetooth foreground restrictions.

## Production status (2026-05-18)

- Positive MB + GATT round-trips validated on SM-T390 (API 28, awake) and SM-T577U (API 33) using the main app `BleSelfTest` path.
- iOS harness can emit clean MB cues and serve full envelopes over GATT.
- Android production scanner (post main-looper fix) receives the cue and performs the fetch.

## Request

In the official mob / mob_dev BLE transport documentation and any "getting started" or "advertising carriers" sections, please:

1. List "MB legacy beacon cue + GATT fetch" as the supported production path for full MX envelopes when iOS is involved.
2. Note the iOS limitations on direct manufacturer-data / custom service-data / AUX paths (with links to the two limitation issues).
3. Keep the direct-MX and hybrid paths as "experimental / Android-only / future iOS platform evolution" with clear caveats.

This gives downstream projects (such as MeshX) a clear, low-surprise target instead of having to discover the limitation through extensive recapture sessions.

## Related

- GenericJam/mob_dev#6 + GenericJam/mob_new#5 (Swift sources + generator support — prerequisite for removing MeshX downstream patches)
- MeshX `docs/ble_carrier_decision.md` and `docs/BLE_BRIDGE.md` contain the full evidence tables and "do not attempt without new proof" criteria.
