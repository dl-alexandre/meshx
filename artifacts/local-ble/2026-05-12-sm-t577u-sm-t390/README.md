# Local BLE Evidence Bundle: SM-T577U / SM-T390

Run date: May 12, 2026

This bundle archives the current Android hardware evidence for the
advertisement-only local mesh release boundary. It is not whole-project
completion evidence.

## Devices

| Role evidence | Serial | Model | Android |
| --- | --- | --- | --- |
| SM-T577U runs | `R52W90AW7EN` | Samsung SM-T577U | Android 13 / API 33 |
| SM-T390 runs | `5200f354f4fb277f` | Samsung SM-T390 | Android 9 / API 28 |

Both devices reported Bluetooth LE support in the archived validation
summaries.

## Hardware Evidence

| Directory | Purpose | Outcome |
| --- | --- | --- |
| `hardware/m26-full-envelope/` | SM-T577U full-envelope advert observed by SM-T390 | Incomplete: no canonical Android-to-Android full `received_message` proof |
| `hardware/m26b-legacy-beacon/` | SM-T577U legacy beacon advert observed by SM-T390 | Passed: `legacy_beacon_delivery_complete=true` with no legacy completion blockers |
| `hardware/m40-gatt-interop/` | Standalone GATT interop harness in both directions | Blocked: both directions fail with Android `gatt_status=133` before service discovery |

The M40 rerun woke both devices and dismissed keyguard before validation.
The same status 133 failure still occurred in both directions, so the
current GATT blocker is not explained by the prior screen-off/keyguard
harness issue.

## Generated Manifests

| File | Purpose |
| --- | --- |
| `manifests/local-readiness.json` | Current project readiness audit with open blockers |
| `manifests/local-release.json` | Advert-only release boundary, completion audit, hardware gates, and wording constraints |
| `manifests/advert-gossip-audit.txt` | Deterministic replay audit output for advert gossip scenarios |

## Operator Release Note

Allowed wording:

> MeshX can show messages seen nearby from passive BLE advertisement observations.

This bundle supports the constrained claim that old Android hardware can
participate through legacy beacon refs. Legacy beacon refs are unresolved
pointers, not full message delivery.

Do not claim:

- whole-project completion;
- guaranteed delivery;
- trusted or authenticated message delivery;
- full message resolution from beacon refs;
- known-good GATT fetch on SM-T577U / SM-T390;
- routed or multi-hop hardware delivery;
- background mobile operation;
- iOS advert-only participation.

Open hardware gates remain visible in `manifests/local-release.json`.
