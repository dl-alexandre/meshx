# Updated Remaining Items Audit

Date: 2026-05-17 (updated 2026-05-21 for final migration PR polish + audit row flip).
Last verified: 2026-05-21 (Phase 1+2+3 + upstream patch migration complete: audit row :upstreaming_mob_dev_mob_patches flipped to complete in LocalFocused...Audit + tests; config in mob.exs, patches + task + aliases removed, dep bumps to 0.6.18/0.5.11, iOS device verification; docs reconciled for as-built state). `mob_ble` 0.1.0 publication-ready and patch migration PR is the final hygiene for the thread.

This audit tracks the four-item thread objective after the iOS responder
implementation. It is narrower than the whole-project completion audit.
The machine-readable focused checklist is archived at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json`.
Regenerate it with:

```sh
mix mob.node.remaining_items.audit --json \
  --out artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json
```

## Checklist

| Item | Current status | Evidence | Remaining gap |
| --- | --- | --- | --- |
| Hardware validation of the full iOS responder path | Complete for attached SM-T577U -> iPad12,1 hardware | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json`; `docs/ble_transport_re_evaluation.md` | None for the requested end-to-end path. This does not prove background BLE, routing, ACKs, trusted delivery, or direct full-MX extended adverts. |
| Extended advertising interop (AUX scan response / direct full-MX advert path) | Still limited / blocked on tested iOS hardware | `docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation`; `apps/mob_node/lib/mob_node/ble/local_ios_advert_carrier_decision.ex`; `apps/mob_node/lib/mob_node/ble/local_hardware_validation_gates.ex`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md` | Direct full-MX AUX manufacturer-data delivery is not reliable on tested iOS hardware. The latest device recheck still has no alternate iOS receiver available. The local validation checklist and closure-progress artifact record the exact callback, parse, fallback, metadata, and missing receiver-path evidence required to close this row. Supported full-envelope path is MB beacon cue plus GATT fetch where validated. |
| Upstreaming the `mob_dev` / `mob` patches | Complete (migration PR) | `docs/upstream_mob_migration_checklist.md`; this migration PR (bump + verification); root + app `mix.lock` (mob 0.6.18, mob_dev 0.5.11); hardware build log (iOS device `mix mob.deploy --native` post-migration); `apps/mob_node/mob.exs` (ios_swift_sources + static_nifs); absence of patches/*.patch and mob.patch_deps task | PRs merged (GenericJam/mob_dev#6 + mob_new#5); MeshX executed: dep bumps, lock regen, mob.exs upstream config, deletion of 2 patch files + task + aliases + docs hygiene, compile + iOS device build gate (upstream paths), audit flip in LocalFocused... + tests. Pre-PR "keep downstream" language retired. |
| `mob_ble` plugin extraction, application tests, and Hex prep | Phase 1+2+3 complete ("all that" final items) | `apps/mob_ble/...` (all prior); `apps/mob_ble/CHANGELOG.md`; `CHANGELOG.md` (root); `docs/releases/mob_ble_phase3_cutover_announcement.md` (trimmed); `apps/mob_node/.../MainActivity.kt`; `.../AppDelegate.m`; `docs/remaining_items_audit.md`; `docs/mob_ble_bridge_migration.md`; `scripts/launch_mob_ble_default_path.sh`; `apps/mob_node/CONTRIBUTING.md`; `mix hex.build` (apps/mob_ble); `mix test apps/mob_ble`; wiring test; `artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/` | All prior + this pass: stray/stale markdown + Current State table cleanup; mob_ble "mob" prose hygiene sweep (README/CHANGELOG/lib comments); trimmed release body; evidence bundle dir + manifest template + 5-step recipe; launch/CONTRIBUTING support; hex.build verified clean (zero mob_* runtime in tar); pre-publish checklist ready. `mob_ble` 0.1.0 fully publication + device-run ready. Open: `mix hex.publish` + post-publish tag + first physical runs under default + upstream patch merges. |
| Test startup friction (`--no-start` workaround) | Complete | Root `mix test` passed without `--no-start` at 2026-05-17T12:09:58-0700; log archived at `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log`; runtime fix is in `apps/mob_runtime/lib/mob_runtime.ex` and script startup guards are in `scripts/*.exs` | None for the umbrella startup conflict. |

## Prompt-To-Artifact Checklist

| Prompt requirement | Artifact or command inspected | Coverage decision |
| --- | --- | --- |
| Android beacon cue -> iOS responder serving MX -> Android fetch | `apps/mob_node/android/app/src/androidTest/java/dev/mob/mob/ble/IOSResponderFetchSmokeTest.kt`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-instrumentation-2.log`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-logcat-2.log`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/ipad-responder-2.log` | Covered for attached SM-T577U -> iPad12,1 foreground hardware run. The passing Android instrumentation result and GATT logs cover cue discovery, service discovery, MFQ write, MFR read, MX envelope parse, and clean terminal state. `summary.json` also records this row as complete and leaves the AUX/upstream rows incomplete. |
| Avoid stale Android cached-name false positives in responder smoke | `IOSResponderFetchSmokeTest.kt` uses only `ScanRecord.deviceName`; first failing rerun and second passing rerun are archived in `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/` | Covered. The failed `not_found` rerun is explained and the passing rerun validates the corrected cue source. |
| Extended advertising interop / AUX scan response reliability | `docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation`; `apps/mob_node/lib/mob_node/ble/local_ios_advert_carrier_decision.ex`; `apps/mob_node/lib/mob_node/ble/local_platform_parity.ex`; `apps/mob_node/lib/mob_node/ble/local_hardware_validation_gates.ex`; `apps/mob_node/android/app/src/androidTest/java/dev/mob/mob/ble/IOSAuxFullMxAdvertSmokeTest.kt`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json` | Not complete. Fresh SM-T577U -> iPad12,1 probes emitted 80-byte full-MX scan-response extended adverts from Android and iOS still did not log `received_message`, decode error, candidate/discovery callback evidence, or `FF FF 4D 58` MX callback evidence for the AUX payload. The 11:19 rerun kept the iOS scanner active and observed 120 legacy-beacon lines while surfacing zero direct AUX MX lines. The AUX validation checklist records the exact sender/observer metadata, platform callback, canonical parse, and MB fallback evidence required to close this row. The closure-progress artifact marks sender metadata, observer metadata, MB fallback control, and negative-boundary notes satisfied for the negative runs while keeping platform callback proof, canonical parse proof, and an alternate iOS receiver path missing. MB beacon plus GATT fetch remains the supported full-envelope path where validated. |
| Alternate iOS AUX target availability | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/aux-alternate-ios-target-check/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md`; `devicectl-devices.txt`; `adb-devices.txt`; `apps/mob_node/lib/mob_node/ble/local_hardware_validation_gates.ex`; `apps/mob_node/test/mob_node/ble/local_release_evidence_manifest_test.exs` | No new AUX hardware path available in this workspace at 2026-05-17T13:58:54-0700. The SM-T577U Android device and Coding iPad iPad12,1 are connected, but `DairyPhoneDeaux` iPhone 13 remains `unavailable`, so there is no second iOS receiver target for a fresh direct full-MX AUX probe. The local release manifest preserves this availability artifact under the open iOS participation hardware gate. |
| Machine-readable readiness preserves the AUX boundary | `apps/mob_node/lib/mob_node/ble/local_project_readiness.ex`; `apps/mob_node/lib/mob_node/ble/local_ios_parity_evidence_manifest.ex`; `apps/mob_node/lib/mob_node/ble/local_ios_parity_hardware_validation_plan.ex`; `apps/mob_node/lib/mob_node/ble/local_hardware_validation_gates.ex`; focused `mix test` for those snapshots | Covered as negative evidence. The readiness and iOS parity manifests now name the `android-aux-full-mx-ios-observe` probe plus the `android-aux-full-mx-ios-observe-rerun` probe and keep direct full-MX AUX claims blocked. This does not complete the AUX interop row because the required receiver-side callback evidence is absent. |
| iOS foreground emit vs iOS gossip distinction | `apps/mob_node/lib/mob_node/ble/local_ios_advert_carrier_decision.ex`; `apps/mob_node/lib/mob_node/ble/local_ios_native_source_inventory.ex`; `apps/mob_node/lib/mob_node/ble/local_ios_parity_evidence_manifest.ex`; focused `mix test` for those snapshots | Covered as boundary evidence. The source inventory now records foreground iOS MB beacon emit source markers and the carrier decision records that emitter as `implemented_unvalidated`, while keeping iOS-origin cross-radio gossip proof, iOS parity, and direct full-MX AUX claims blocked. |
| Upstream `mob_dev` patch migration | (historical) `GenericJam/mob_dev#6` + migration PR evidence | **Complete**. PRs merged/released; MeshX migration executed (see row above + checklist). Handoff/recheck artifacts are pre-migration provenance. |
| Upstream generated `mob_new` template migration | (historical) `GenericJam/mob_new#5` + migration PR evidence | **Complete**. PRs merged/released; MeshX migration executed (see row above + checklist). Handoff/recheck artifacts are pre-migration provenance. |
| Keep downstream patch path valid until upstream migration | (historical — now complete) | `mix.lock` (mob 0.6.18 / mob_dev 0.5.11 post-bump); this migration PR; `docs/upstream_mob_migration_checklist.md`; hardware iOS device build success log | **Complete**. Downstream patches (01/02), task, and aliases removed; migration to released upstream versions executed with successful device build verification. The old `mix mob.patch_deps --check` path is obsolete (task deleted); records kept for history only. |

The maintainer handoff records the upstream merge/release action and MeshX
post-merge dependency migration gates. The migration-progress artifact records downstream patch verification, open replacement PRs, handoff, and READ-only
permission as satisfied while keeping upstream merge, release, MeshX dependency
migration, downstream patch removal, and post-migration verification missing.
| Release readiness preserves downstream patch blocker | `apps/mob_node/lib/mob_node/ble/local_project_readiness.ex`; `apps/mob_node/test/mob_node/ble/local_project_readiness_test.exs` | Covered as release-hardening evidence. Local readiness now explicitly keeps `patches/`, `mix mob.patch_deps`, and the locked downstream patch path until `GenericJam/mob_dev#6` and `GenericJam/mob_new#5` are merged, released, MeshX migrates, and post-merge gates pass. This is not upstream completion. |
| Completion audit preserves upstream migration blocker | `apps/mob_node/lib/mob_node/ble/local_project_completion_audit.ex`; `apps/mob_node/lib/mob_node/ble/local_project_completion_blocker_matrix.ex`; focused `mix test` for both surfaces | Covered as whole-project audit evidence. The completion audit and blocker matrix now require merged/released upstream PRs plus MeshX post-merge dependency migration before downstream patch removal. This is not upstream completion. |
| Release artifact bundle preserves upstream migration blocker | `apps/mob_node/lib/mob_node/ble/local_release_artifact_bundle.ex`; `apps/mob_node/test/mob_node/ble/local_release_artifact_bundle_test.exs`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md` | Covered as release-note packaging evidence. Operator release notes must not claim upstream patch migration complete while the GenericJam PRs remain unmerged or MeshX has not migrated. The release bundle and release manifest now include the maintainer handoff as a generated required artifact. This is not upstream completion. |
| Regenerated release/iOS parity manifests preserve blocked claims | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-ios-parity-evidence.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/release-candidate/review.json` | Covered as release evidence hygiene. The regenerated manifests record foreground iOS MB beacon emit as implemented but cross-radio unvalidated, keep `ios_parity_claim_allowed?=false`, and keep whole-project completion false. This does not complete the AUX or upstream rows. |
| Recent evidence inventory preserves iOS emit boundary and closure artifact pointers | `apps/mob_node/lib/mob_node/ble/local_release_recent_evidence_inventory.ex`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release-recent-evidence.json`; `mix test apps/mob_node/test/mob_node/ble/local_release_recent_evidence_inventory_test.exs apps/mob_node/test/mix/tasks/mob_node_local_release_recent_evidence_test.exs` | Covered. The recent-evidence inventory now includes foreground iOS MB beacon emit source inventory support plus the AUX validation checklist and upstream maintainer handoff artifact paths, while explicitly blocking iOS-origin cross-radio gossip proof, iOS legacy beacon gossip, direct full-MX AUX completion, upstream PR merge completion, downstream patch removal, and iOS parity claims. This does not complete the AUX or upstream rows. |
| Cross-surface guardrail test pass | Focused `mix test` over `local_project_readiness_test.exs`, `local_project_completion_audit_test.exs`, `local_project_completion_blocker_matrix_test.exs`, `local_release_artifact_bundle_test.exs`, `local_hardware_validation_gates_test.exs`, `local_ios_parity_evidence_manifest_test.exs`, and `local_ios_parity_hardware_validation_plan_test.exs`; plus later carrier/source-inventory/parity, blocker, release-manifest, recent-evidence, and AUX-rerun source-backed focused suites | Covered. The combined guardrail suite passed with 82 tests and 0 failures earlier, the carrier/source-inventory/parity focused suite passed with 47 tests and 0 failures, the blocker/release/iOS parity suite passed with 67 tests and 0 failures, the negative-validation/release-artifact suite passed with 42 tests and 0 failures, the recent-evidence inventory/task suite passed with 8 tests and 0 failures after adding the closure artifact pointers, and the AUX-rerun source-backed suite passed with 35 tests and 0 failures after adding the rerun to hardware gates/readiness/iOS parity surfaces. This confirms the AUX-negative and upstream-migration blockers are consistent across readiness, release, completion audit, hardware gates, iOS parity manifests, and release evidence inventory. This does not complete the blocked rows. |
| Stale status wording scan | Broad remaining-item status wording scan over root docs, app docs, and patch docs; exact iOS emit/gossip stale-string scan over `artifacts/local-ble/2026-05-17-sm-t577u-ipad9`, BLE gate modules, and focused docs | Covered. No contradictory user-facing status text was found outside the focused audit rows themselves, and no generated artifact still says the iOS emit carrier is absent or that iOS gossip is blocked because no emitter exists. Root docs link to this audit for the responder proof, AUX boundary, upstream PRs, and startup fix. |
| Evidence bundle README mirrors current blockers | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/README.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json` | Covered. The bundle README now names the direct AUX-negative probe, the 82-test guardrail pass, and the upstream patch merge/release/migration blocker. |
| Remove `--no-start` workaround / umbrella startup conflict | Root `mix test` without `--no-start`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log`; `apps/mob_runtime/lib/mob_runtime.ex`; `scripts/tcp_sender.exs`; `scripts/tcp_receiver.exs`; `scripts/tcp_relay_node.exs`; `scripts/ble_sender.exs`; `scripts/ble_receiver.exs` | Covered. The runtime now starts dependency workers only where needed and the scripts explicitly ensure dependencies after application startup. Root `mix test` passed at 2026-05-17T12:09:58-0700 with 59 `mob_routing`, 47 `mob_protocol` including 11 properties, 18 `mob_noise`, 30 `mob_store`, 15 `mob_node`, 10 `mob_routing_ble`, 70 `mob_runtime`, and 1265 `mob_node` tests. |
| Final diff hygiene | `git diff --check` | Covered for the current working tree at the time of this audit. |

## Hardware Responder Path

The requested high-priority path is:

1. iOS harness advertises an MB cue and starts `MobFetchGattResponder`.
2. Android `IOSResponderFetchSmokeTest` scans the cue.
3. Android connects to the iOS fetch service.
4. Android writes MFQ.
5. Android reads MFR.
6. Android parses the returned MX envelope.

The archived rerun records an initial failed attempt and the fix:

- First rerun failed with `not_found` because the Android test could use
  a stale cached `BluetoothDevice.name`.
- `IOSResponderFetchSmokeTest` now uses only `ScanRecord.deviceName` for
  the current `mx<message_hash>` cue.
- Second rerun passed with `OK (1 test)`.

The passing log contains:

- `fetch_service_discovery_result` with `gatt_status=0` and
  `service_found=true`;
- write/read results with `gatt_status=0`;
- `fetch_response_received` with `status="ok"` and
  `envelope_parse="ok"`;
- terminal `complete`.

Rerun recipe for the attached hardware pair:

1. Launch the iOS responder harness:

   ```sh
   xcrun devicectl device process launch \
     --device 39FD8D3A-9CA5-5DEF-AFC0-AA5205511117 \
     --terminate-existing \
     --console dev.mob.node.harness \
     -- --mob-auto-beacon
   ```

2. Run the Android instrumented smoke:

   ```sh
   adb -s R52W90AW7EN shell am instrument -w \
     -e class dev.mob.mob.ble.IOSResponderFetchSmokeTest \
     dev.mob.mob.test/androidx.test.runner.AndroidJUnitRunner
   ```

3. Accept the rerun only if Android instrumentation reports `OK (1 test)`,
   Android logcat shows `fetch_response_received` with `status="ok"` and
   `envelope_parse="ok"`, and the terminal fetch event is `complete`.

## Extended Advertising Boundary

The direct full-MX advert path remains separate from the validated responder
path. Current policy is:

- Direct full-MX extended advertising is allowed only where sender and observer
  are capability-proven.
- Tested iOS hardware did not surface non-Apple AUX manufacturer data through
  CoreBluetooth.
- For iOS, full-envelope transfer uses MB beacon cue plus GATT fetch where
  hardware-validated.

The evidence needed to change this status is intentionally stricter than a
successful bridge build or a passing parser test:

1. A hardware capture must show `FF FF 4D 58` MX manufacturer data delivered to
   the platform scanner callback, not only present in sender-side logs.
2. The capture must include sender and observer metadata: device model, OS
   version, BLE controller/API capability, scan filter, duplicate setting,
   advertising mode, whether payload was primary data or scan response, and
   payload length.
3. The observer must parse the delivered bytes into the canonical
   `received_message` / MX envelope path.
4. The same run must prove the legacy MB beacon path still works, so a future
   direct-MX success does not regress the fleet-safe fallback.

Until those artifacts exist, keep direct full-MX AUX delivery disabled for iOS
and keep release wording on the MB beacon plus GATT fetch path.

Additional probes on 2026-05-17:

- Added `IOSAuxFullMxAdvertSmokeTest` as an Android instrumented emitter for
  a direct full-MX extended advert.
- Android accepted the scan-response advertising set on SM-T577U with
  `payload_size=80`, `scannable=true`, `connectable=false`, and
  `data_carrier="scan_response"`.
- iOS iPad12,1 scanned at the same time and logged 276 MB legacy-beacon
  receives, but logged zero direct full-MX `received_message`, decode-error,
  candidate-discovery, or `FF FF 4D 58` callback evidence.
- The rerun again accepted an 80-byte extended scan-response advert on
  Android, logged 120 iOS MB legacy-beacon receives, and still logged zero
  direct full-MX `received_message`, decode-error, candidate-discovery, or
  `FF FF 4D 58` callback evidence.
- A second iOS receiver check found the available attached iOS target was the
  same iPad12,1 used for the negative captures; the iPhone 13 target was
  unavailable, so this workspace could not produce an alternate iOS receiver
  capture.
- Artifacts:
  `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`;
  `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md`;
  `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/aux-alternate-ios-target-check/summary.md`.

## Upstream Boundary (historical — resolved in migration PR)

**Pre-PR state (2026-05-17 snapshots):** The two GenericJam PRs were open; MeshX still required the downstream patches/ + mob.patch_deps for iOS Swift + NIF registration. Handoff comments and rechecks archived under `.../upstream-pr-recheck-1358/`, including `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json`.

**Post-migration (this PR, 2026-05-21):** Both upstream PRs merged + released (mob_dev 0.5.11, mob 0.6.18). MeshX:
- bumped deps + regenerated locks
- added `:ios_swift_sources` + `:static_nifs` to `apps/mob_node/mob.exs`
- deleted the two .patch files and the `mob.patch_deps` task + aliases
- updated docs (this file, upstream_mob_* , BLE_BRIDGE, READMEs, patches/README tombstone)
- flipped the audit row + tests
- verified with `mix deps.compile`, iOS device build (`mix mob.deploy --native`), etc.

The row is now `:complete` with `completion_claim_allowed: true`. See `docs/upstream_mob_migration_checklist.md` (execution record) and the focused audit module for the as-built observed_state. Historical pre-migration artifacts retained for provenance.

## Completion Decision

This four-item objective is not complete because:

- direct full-MX extended advertising interop remains limited on tested
  hardware and needs a new hardware/API capture proving MX AUX delivery to the
  scanner callback before the claim can change.

(The upstream mob patch migration row is now complete — see "Upstream Boundary (historical — resolved...)" above and the flipped row in `local_focused_remaining_items_audit.ex`.)

Local work completed in this checkout (including this migration PR polish):

- the high-priority iOS responder path has hardware evidence and a rerun
  recipe;
- the `--no-start` startup friction is fixed and covered by root `mix test`;
- upstream patch migration executed + verified (see checklist + audit flip);
- release readiness / completion audit / blocker matrix / artifact bundle now
  reflect the upstream row as complete (AUX remains the sole blocker for
  `update_goal_allowed`).

All prior guardrail / manifest / stale-scan / evidence-bundle items updated or
reconciled during the patch migration PR.

## Remaining Work Queue (suggested order)

1) Main-app scanner confidence for both Android devices (highest priority)
- Owner: mobile app + Android maintainers
- Risk: stale build artifact / loop regression could reintroduce callback drops
- Action: keep this as a regression recipe for future builds: rebuild/install main app, run production `mob_ble_selftest` on both devices, keep T390 awake, and archive clean heartbeats + `devices > 0` + `beacon_callbacks > 0`.
- Status (2026-05-18): DONE. Scanner regression fixed (BleScanner main-looper startScan, 683950a). R52 clean. T390 clean in `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/` with `HEARTBEAT events=... devices=... mob_peers=1 ... beacon_callbacks=... envelopes=...`. Bench gotcha: T390 must be awake (`input keyevent WAKEUP` + `svc power stayon true`); a dozing diagnostic run registered the scanner but delivered no selftest callbacks.

2) Clean positive MB + GATT evidence run for release bundle
- Owner: mobile app engineer (paired operator path)
- Risk: stale scan cache or stale iOS responder process can create false failures
- Action: keep archived T390 evidence with matching MB cue, fetch logs, responder request logs, and parsed envelope. Repeat only for fresh release builds or new hardware pairs.
- Status: DONE on SM-T390 using main-app selftest receive path and SM-T577U Android full-MX debug sender. Evidence: `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`; verifier passes from `t390-rx` with `fetch_start`, `fetch_connect_result`, `fetch_service_discovery_result`, `fetch_response_received`, `envelope_parse":"ok"`, and `BleSelfTest: DISTINCT MESH MESSAGE kind=envelope`.

3) Optional reverse direction verification (if iOS observer remains stable)
- Owner: mobile app + BLE validation
- Risk: this may not be reproducible on this hardware; avoid broadening scope before the positive lane is archived
- Action: run one controlled iOS-hybrid emit pass + Android raw observer pass and archive artifacts only if clean.
- Status: Spot checks done in session; optional for future.

4) Upstream migration — **COMPLETE** (this PR)
- Owner: executed in MeshX migration PR after GenericJam merges/releases
- Action taken: followed `docs/upstream_mob_migration_checklist.md` end-to-end; removed patches/task/aliases; flipped audit row; docs + tests reconciled.
- Evidence: updated locks (0.6.18/0.5.11), mob.exs config, deleted artifacts, iOS device build success, this PR.

Suggested order: **1 → 2 → 3 (optional) → 4 (done)**.

### 2026-05-21 execution objective status (this thread)

- Step 1 (main-app scanner sanity on both Androids): **DONE** ...
- Step 2 (clean MB+GATT evidence): **DONE on T390** ...
- Step 3 (reverse direction spot check): **DONE**.
- Step 4 (upstream migration): **DONE** via this PR + audit flip + doc polish.

External unblock actions:

- AUX/direct full-MX remains the only open row (see criteria above).

(The old "Do not remove..." instruction is retired; removal is part of this PR.)
