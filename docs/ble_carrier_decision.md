# BLE Advertising Carrier Decision

Which BLE advertising carrier is canonical for which path, and what
gets retired once the hybrid strategy is validated on hardware.

Companion to:
- `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex` — typed carrier states + evidence.
- `docs/BLE_BRIDGE.md` — protocol-level wire format and PHY limitations.

## Status (2026-05-18)

| Carrier | Direction | Status | Canonical for |
|---|---|---|---|
| MB legacy beacon (22-byte manufacturer data) | observe | hardware_validated | iOS receiving Android beacons |
| MB legacy beacon | emit | implemented_unvalidated | iOS dispatch cue for GATT fetch responder |
| Full MX extended advert (AUX_ADV_IND) | observe | **phy_blocked** | — (does not deliver on tested iOS stack) |
| Direct-MX service-data carrier | emit | **rejected** (2026-05-18 hardware) | — (iOS platform restrictions block both directions) |
| Service UUID identity advert | emit | insufficient_for_beacon_ref | peer presence only |
| Local-name encoded beacon ref | emit | rejected | — (fragile, user-visible) |

## Decision

### Production paths (canonical)

| Path | Carrier(s) | Why |
|---|---|---|
| **Android → iOS full envelope** | MB legacy beacon cue (emit) + GATT fetch (responder) | Only validated cross-platform full-envelope route. AUX-direct doesn't reach CoreBluetooth on tested iOS hardware. |
| **iOS → Android full envelope** | MB legacy beacon cue (emit) + GATT fetch (responder) | Symmetric. iOS peripheral advertises MB cue; Android initiates GATT fetch. Foreground only. |
| **Either → either beacon reference** | MB legacy beacon (22-byte manufacturer data) | Validated observe path. Sufficient for `BeaconRef` (message_id_hash, sender_peer_hash, payload_kind, envelope_version). |
| **Peer presence / discovery** | Service UUID identity advert | Carries no payload. Used for connection-establishment hints, not message transport. |

### Opt-in / experimental paths

| Path | Carrier(s) | Gate |
|---|---|---|
| **Hybrid emit (MB cue + direct-MX service-data)** | Both carriers in parallel | Behind `USE_FULL_MX_ENVELOPES` (Android) and equivalent iOS opt-in. Goal: produce full envelopes without GATT round-trip *when receiver supports it*. Validation: HYBRID_SUCCESS counts from overnight bidirectional capture. |
| **Direct-MX service-data only (no MB cue)** | service_data_beacon_ref | Not selected. Requires hybrid validation first; without the MB cue, iOS receivers fall back to nothing. |

### Retired / never-shipped

| Carrier | Reason |
|---|---|
| Full MX extended advert (AUX_ADV_IND) direct receive on iOS | PHY-blocked. CoreBluetooth on tested iOS stack does not surface non-Apple AUX manufacturer data to apps. See `docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation` and `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`. Do not re-attempt without a meaningfully different iOS stack or CoreBluetooth release. |
| Local-name encoded beacon ref | Rejected by carrier-decision module. Fragile, user-visible, inconsistent with manufacturer-data ingress. |

## Hybrid validation outcome (2026-05-18)

Bidirectional hardware validation on iPhone 13 (DairyPhoneDeaux, UDID `1780F216-CB5C-560B-A86F-85D31F79ADEF`) and SM-T577U (R52W90AW7EN, Android 13) settled the question: the direct-MX service-data carrier is **rejected** for iOS↔Android. The MB legacy beacon + GATT fetch route remains canonical.

### Evidence summary

| Direction | MB cue | Direct-MX `…1001` | Limiting platform |
|---|:-:|:-:|---|
| iPhone emit → Android receive | ✗ (0) | ✗ (0) | **iOS emit-side**. CoreBluetooth foreground restrictions silently drop third-party `kCBAdvDataManufacturerData` and custom 128-bit service data. iOS console logs `iOS_HYBRID_STARTED` + `direct_mx_service_data_started=true` while the radio transmits nothing matching either claim. Android DIAG observer with `setLegacy(false)` + `PHY_LE_ALL_SUPPORTED` proved extended-adv reception works (caught one 90-byte extended adv from an unrelated device); zero from the iPhone during the emit window. |
| Android emit → iPhone receive | ✓ (52) | ✗ (0) | **iOS scan-side**. `scanForPeripherals(withServices: nil)` excludes extended adverts on custom 128-bit UUIDs. iPhone sees 52 MeshX MB cues (manufacturer data starting `ffff`) and 252 service-data adverts on 16-bit SIG UUIDs, but zero on `8F4F1201-…-1001`. |

Both blockers are iOS platform restrictions, not code defects. The carrier shape itself is sound (Android→Android tests pass); iOS cannot reliably emit it, and cannot generically receive it without an explicit-UUID scan filter.

### Run references

- `artifacts/local-ble/2026-05-18-iphone13-direct-mx-hybrid/recapture-3/summary.md` — iPhone emit messageId `f1aa757a484dc0f29ddfb5e65735320a`; Android DIAG, 82 distinct scan signatures, zero from iPhone.
- `artifacts/local-ble/2026-05-18-iphone13-direct-mx-hybrid/recapture-4-reverse/evidence/20260518-095213-summary.md` — Android emit messageId `db9ae2550656ebe81d3ed252351625bb`; iPhone observer 4191 raw-advert lines, 52 MB cues, zero direct-MX.

### Code disposition

Applied:

- `service_data_beacon_ref` carrier status moved to `:rejected` in `local_ios_advert_carrier_decision.ex`, with the recapture-3/4 summaries listed as evidence.

Deferred (do when convenient, not blocking):

- Strip the `USE_FULL_MX_ENVELOPES` flag handling that gates direct-MX emission on the iOS dispatch path.
- Remove `MeshxBeaconFetchCoordinator` direct-MX dispatch paths that aren't needed for the GATT fetch route.
- Keep all the HYBRID_* log lines and correlation hooks — harmless and useful if iOS platform constraints change in a future release.
- Keep `IOSAuxFullMxAdvertSmokeTest#emitsHybridMbCuePlusServiceDataFullMxEnvelope` and `IOSHybridDirectMxReceiveTest` as evidence-bundle tests; they document the carrier shape and would re-validate it cheaply if iOS evolves.

### Revisit triggers

Reopen this decision only if one of the following changes:

- A future iOS release exposes a `setLegacy(false)`-equivalent on `CBCentralManager` scans, or relaxes foreground restrictions on `kCBAdvDataManufacturerData` / custom 128-bit service data.
- Product scope changes to Android↔Android-only, where the carrier already works.
- An iOS receive-only configuration (Android emit + iOS receive, with iPhone scanning by explicit `MESHX_DIRECT_MX_SERVICE_UUID` filter) becomes a useful intermediate path — would require one harness flag change to validate.

## Open questions (deferred until hardware evidence)

1. iOS hybrid timing — gap between MB cue and direct-MX service-data payload. Currently fixed; should it become configurable? Decide *after* observing real gap statistics.
2. Direct-MX service-data fragmentation — does iOS surface multi-frame service-data reliably? Untested.
3. Background mode — all current decisions are foreground-only. Background is a separate carrier evaluation, not covered here.

## Source of truth

This document explains the rationale. The machine-readable state lives
in `local_ios_advert_carrier_decision.ex` and the release artifact
bundle. If they disagree, the source module wins — update this doc.
