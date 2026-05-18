# BLE Advertising Carrier Decision

Which BLE advertising carrier is canonical for which path, and what
gets retired once the hybrid strategy is validated on hardware.

Companion to:
- `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex` — typed carrier states + evidence.
- `docs/BLE_BRIDGE.md` — protocol-level wire format and PHY limitations.

## Status (2026-05-17)

| Carrier | Direction | Status | Canonical for |
|---|---|---|---|
| MB legacy beacon (22-byte manufacturer data) | observe | hardware_validated | iOS receiving Android beacons |
| MB legacy beacon | emit | implemented_unvalidated | iOS dispatch cue for GATT fetch responder |
| Full MX extended advert (AUX_ADV_IND) | observe | **phy_blocked** | — (does not deliver on tested iOS stack) |
| Direct-MX service-data carrier | emit | candidate, exercised in hybrid experiment | full-envelope without GATT round-trip |
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

## What hybrid validation will decide

When the overnight bidirectional hybrid run produces evidence, the
decision split is:

- **HYBRID_SUCCESS count > 0 in both directions, GATT fallback rate low** → promote direct-MX service-data to a co-canonical full-envelope carrier alongside GATT fetch. Keep GATT fetch for fragmentation / large envelopes.
- **HYBRID_SUCCESS works one direction only** → keep GATT fetch as canonical full-envelope, document direct-MX service-data as optional emit on the working side only.
- **HYBRID_SUCCESS sparse or zero on hardware** → demote direct-MX service-data to "experiment only" in the carrier decision module, document it as not selected, and stop adding code that depends on it.

In all three cases, **MB legacy beacon stays canonical** as the cue
carrier — the hybrid is about what carries the *payload*, not the cue.

## What to retire from code if hybrid fails

If the overnight evidence says no:

- Strip the `USE_FULL_MX_ENVELOPES` flag handling that gates direct-MX emission.
- Remove `MeshxBeaconFetchCoordinator` direct-MX dispatch paths that aren't needed for the GATT fetch route.
- Mark `service_data_beacon_ref` carrier `status: :rejected` in `local_ios_advert_carrier_decision.ex`.
- Keep all the HYBRID_* log lines and correlation hooks — they're harmless and useful for any future re-test.

## What to retire from code if hybrid succeeds

- Nothing immediate. GATT fetch stays for fragmentation. Direct-MX service-data becomes the fast path for small full envelopes.
- Eventually: a size threshold in the emit path picks direct-MX for ≤N bytes, GATT cue for larger payloads.

## Open questions (deferred until hardware evidence)

1. iOS hybrid timing — gap between MB cue and direct-MX service-data payload. Currently fixed; should it become configurable? Decide *after* observing real gap statistics.
2. Direct-MX service-data fragmentation — does iOS surface multi-frame service-data reliably? Untested.
3. Background mode — all current decisions are foreground-only. Background is a separate carrier evaluation, not covered here.

## Source of truth

This document explains the rationale. The machine-readable state lives
in `local_ios_advert_carrier_decision.ex` and the release artifact
bundle. If they disagree, the source module wins — update this doc.
