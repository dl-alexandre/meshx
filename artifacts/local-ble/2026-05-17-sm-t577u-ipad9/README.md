# Local BLE Evidence Bundle: SM-T577U / iPad 9th generation

Run date: May 17, 2026.

This bundle archives fresh attached-hardware evidence from the devices
available to this workspace. It is not whole-project completion evidence.
For the focused four-row follow-up audit, see
[docs/remaining_items_audit.md](../../../docs/remaining_items_audit.md).

## Devices

| Role | Identifier | Model | OS |
| --- | --- | --- | --- |
| Android sender / observer | `R52W90AW7EN` | Samsung SM-T577U | Android 13 / API 33 |
| iOS observer / sender | `39FD8D3A-9CA5-5DEF-AFC0-AA5205511117` | iPad 9th generation (`iPad12,1`) | iOS 26.5 |

The iPhone 13 listed by CoreDevice was unavailable and was not used.

## Hardware Evidence

| Directory | Purpose | Outcome |
| --- | --- | --- |
| `hardware/android-fetch-ios-responder-rerun/` | Android scans the iOS responder cue, connects to the iPad fetch service, writes MFQ, reads MFR, and parses the returned MX envelope. | Passed after fixing the Android smoke test to ignore stale cached `BluetoothDevice.name`: `IOSResponderFetchSmokeTest` reported `OK (1 test)`, Android logcat showed GATT status 0, `fetch_response_received status="ok"`, `envelope_parse="ok"`, and terminal `complete`. |
| `hardware/android-aux-full-mx-ios-observe/` | Android emits a direct full-MX extended advertising scan-response payload while the iPad harness scans for MX callbacks. | Negative AUX evidence: `IOSAuxFullMxAdvertSmokeTest` reported `OK (1 test)` and Android logcat showed an 80-byte `MX` scan-response advertising set, but iOS logged zero direct `received_message`, decode-error, candidate-discovery, or `FF FF 4D 58` callback evidence while still receiving MB legacy beacons. |
| `hardware/android-aux-full-mx-ios-observe-rerun/` | Same direct full-MX extended advertising probe rerun against the attached SM-T577U/iPad12,1 pair. | Still negative AUX evidence: Android again reported `OK (1 test)` and started an 80-byte scan-response advertising set; iOS scan stayed active with 120 legacy-beacon lines but zero direct `received_message`, decode-error, candidate-discovery, or `FF FF 4D 58` callback evidence. |
| `hardware/aux-alternate-ios-target-check/` | Checks whether another iOS receiver is available for a fresh AUX probe. | No alternate iOS receiver available: Coding iPad is connected, but `DairyPhoneDeaux` iPhone 13 is unavailable. |
| `hardware/external-blocker-recheck-1358/` | Rechecks external device availability after the focused audit update. | Still blocked at 2026-05-17T13:58:54-0700: `DairyPhoneDeaux` iPhone 13 remains unavailable, so there is no alternate iOS AUX receiver in this workspace. |
| `hardware/upstream-pr-recheck-1358/` | Archives raw `gh` JSON for the upstream PR/repo state. | Still blocked at 2026-05-17T13:58:54-0700: `GenericJam/mob_dev#6` and `GenericJam/mob_new#5` remain open, non-draft, mergeable, GitGuardian-passing, and unmerged with only READ permission from this checkout. |
| `hardware/android-to-ipad-beacon-rerun/` | SM-T577U emits MB legacy beacon refs while the iPad harness observes. | Passed foreground observe evidence: iPad logged 474 `legacy_beacon_received` lines, including 247 lines with the attached Android sender hash `12f78557517a13f9`. |
| `hardware/ipad-to-android-beacon-rerun/` | iPad harness emits MB legacy beacon refs while Android selftest scans. | Partial: iPad logged 28 `beacon_dispatched` lines. Android scan was active but did not record a matched iPad sender hash (`04a884d8e17b1704`). |
| `hardware/ipad-to-android-beacon-instrumented/` | Instrumented rerun after adding iOS console output for sender hash and CoreBluetooth advertising callbacks. | Still partial: iPad logged 31 `beacon_dispatched` lines, 31 `peripheral_advertising_started` callbacks, and 0 `peripheral_error` lines for sender hash `1032dc6f4584999f`. Android scan was active but reported 0 beacon callbacks and no matching iPad sender hash. |
| `hardware/ipad-to-android-raw-scan/` | Android raw scanner diagnostics enabled to capture non-MeshX scan records and manufacturer IDs. | Diagnostic: Android raw logging worked, but this run did not produce iPad sender markers, so it cannot prove iPad-origin visibility. |
| `hardware/ipad-basic-to-android-raw-scan/` | iPad basic MB beacon sender plus Android raw scanner diagnostics. | Still blocked: iPad logged 36 `beacon_dispatched` lines, 36 `peripheral_advertising_started` callbacks, and 0 `peripheral_error` lines for sender hash `a597ba03c3738fed`. Android logged 40 raw scan records, 4 manufacturer `65535` records, and 33 beacon callbacks by final heartbeat, but all decoded `65535/MB` records carried sender hash `f70806eddc285bcc`; none matched the iPad sender hash. |
| `hardware/ipad-service-advertise-raw-scan/` | iPad advertises the MeshX service UUID and local name while Android raw scanner diagnostics run. | Passed discovery-carrier evidence: iPad logged 1 `service_advertise_requested`, 1 `peripheral_advertising_started`, and 0 `peripheral_error` lines. Android logged 47 raw scan records, including 2 records with service UUID `8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1000`, and 4 `BleSelfTest: MESHX PEER` lines for `meshx-ipad`. This proves iOS-origin foreground service UUID discovery is visible to Android, but not that service advertising carries MeshX message payloads. |
| `hardware/ipad-full-beacon-android-auto-fetch-hash-cue/` | Android opt-in scanner coordinator resolves an iPad hash-cued fetch-service advert into a GATT fetch. | Passed explicit full-MX debug path: iPad logged 1 `beacon_dispatched`, 1 `fetch_responder_advertising_started`, and 1 `fetch_responder_served status=0` for message hash `19f161af172a01c8`. Android saw the fetch service UUID once, started 1 coordinator fetch, requested the iPad hash, logged 1 `fetch_response_received` with `status:"ok"`, and had 14 fetched-envelope evidence lines with 0 fetch failures. |
| `hardware/ipad-full-beacon-android-runtime-fetch-receive-only/` | Default Android debug build uses runtime receive-only fetch opt-in while self-test send is disabled. | Passed clean receive-only path: iPad logged 1 `beacon_dispatched`, served 1 `status=0` fetch for message hash `11a7fcb0a1861396`, and Android requested that hash, logged 1 `fetch_response_received` with `status:"ok"`, emitted canonical `received_message` evidence with `ble_android_gatt_fetch` / `gatt_fetch_response`, and recorded 0 native self dispatches while rejecting 5 stale self-test send attempts. |
| `hardware/ipad-android-advert-only/` and `hardware/ipad-to-android-beacon/` | Earlier pre-rebuild attempts. | Diagnostic only. The current iPad harness was rebuilt and reinstalled before the rerun directories above. |

## Review Artifacts

| File | Purpose |
| --- | --- |
| `summary.json` | Machine-readable capture summary. |
| `manifests/focused-remaining-items-audit.json` | Machine-readable four-row audit for the active remaining-items objective, generated by `mix meshx.mobile.remaining_items.audit --json --out artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json`. |
| `manifests/focused-remaining-items-audit.txt` | Plain-text four-row audit and prompt-to-artifact checklist, generated by `mix meshx.mobile.remaining_items.audit`. |
| `hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md` | Direct full-MX AUX closure checklist. It records the callback, canonical parse, MB fallback, and metadata evidence required before the AUX row can be marked complete. |
| `hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json` | Structured AUX closure-progress review. It records sender metadata, observer metadata, MB fallback control, and negative-boundary notes as satisfied for the negative runs while keeping platform callback proof, canonical parse proof, and alternate iOS receiver path missing. |
| `hardware/upstream-pr-recheck-1358/maintainer-handoff.md` | Upstream maintainer handoff checklist. It records the upstream merge/release actions and MeshX post-merge migration gates required before downstream patches can be removed. |
| `hardware/upstream-pr-recheck-1358/upstream-migration-progress.json` | Structured upstream migration-progress review. It records downstream patch verification, open replacement PRs, maintainer handoff, and READ-only permission evidence as satisfied while keeping upstream merge, release, MeshX dependency migration, downstream patch removal, and post-migration verification missing. |
| `manifests/local-ios-parity-evidence.json` | Regenerated iOS parity evidence manifest that records foreground iOS MB beacon emit as implemented but cross-radio unvalidated. |
| `manifests/local-release-recent-evidence.json` | Regenerated recent-evidence inventory that records iOS foreground observe and MB beacon emit source inventory plus the AUX validation checklist and upstream maintainer handoff paths, while blocking cross-radio gossip, direct full-MX AUX completion, upstream patch migration completion, and iOS parity claims. |
| `manifests/local-release.json` | Local release manifest and artifact bundle. The bundle currently lists 54 artifacts, including the AUX validation checklist, upstream maintainer handoff, and upstream migration-progress gate, while keeping whole-project completion false. |
| `ios/evidence.json` | Operator-supplied iOS parity hardware review metadata. |
| `ios/review.json` | `mix meshx.mobile.local_ios_parity.hardware_review` output. |
| `release-candidate/evidence.json` | Top-level release-candidate evidence input assembled from this run and existing manifests. |
| `release-candidate/review.json` | `mix meshx.mobile.local_release.candidate_review` output; reports `status=ready` for the evidence metadata while preserving open hardware gates and blocked claims, and requires the AUX validation checklist plus upstream maintainer handoff paths in operator notes. |

`ios/review.json` reports `status=ready` and
`ios_hardware_evidence_complete?=true` for the supplied metadata, while
leaving `ios_parity_claim_allowed?`, full-envelope, background BLE, and
delivery-style claims false.

Focused readiness/release/completion guardrail tests also passed for this
bundle's current status surfaces: 82 tests, 0 failures across local project
readiness, completion audit, blocker matrix, release artifact bundle, hardware
gates, and iOS parity manifests.

A follow-up carrier/source-inventory/parity guardrail pass also completed with
47 tests and 0 failures after splitting foreground iOS MB beacon emit source and
local dispatch evidence from missing iOS-origin cross-radio gossip proof.

## Remaining Blockers

For the updated remaining-items objective specifically, this bundle completes
the Android beacon cue -> iOS responder serving MX -> Android fetch row. It
does not complete the upstream patch merge/release row or the direct full-MX
AUX advertising row.

The downstream patch path remains required until `GenericJam/mob_dev#6` and
`GenericJam/mob_new#5` are merged, released, MeshX migrates to those dependency
versions, and post-merge verification passes.

The direct full-MX AUX row remains blocked until a future hardware/API capture
shows `FF FF 4D 58` manufacturer data reaching the observer platform callback
and then parsing through the canonical `received_message` / MX envelope path.
The exact evidence checklist is archived at
`hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md`.

The upstream patch row remains blocked until a GenericJam maintainer merges and
releases both upstream PRs, then MeshX migrates to released dependency versions,
removes the downstream patches and patch task requirement, and passes
post-migration verification. The exact maintainer and MeshX handoff checklist is
archived at `hardware/upstream-pr-recheck-1358/maintainer-handoff.md`, and the
structured migration-progress review is archived at
`hardware/upstream-pr-recheck-1358/upstream-migration-progress.json`.

This bundle does not close:

- known-good constrained fetch transport;
- physical three-participant multi-hop proof;
- Android receipt of iPad-origin beacons;
- full-envelope iOS observation;
- iOS background BLE behavior;
- whole-project completion.

Allowed wording now includes the attached-hardware Android fetch / iOS
responder MFQ/MFR proof, foreground iOS MB beacon local dispatch evidence, and
foreground iOS service UUID discovery visible to Android. It also includes the
explicit Android full-MX debug opt-in resolving an iOS fetch-service hash cue
into a successful GATT fetch, plus a default-build runtime receive-only fetch
opt-in with Android self-send disabled. It still does not include guaranteed delivery,
trusted delivery, routing, background BLE, direct full-MX extended-advert
delivery, upstream patch migration completion, or whole-project completion.
