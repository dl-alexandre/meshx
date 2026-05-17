# Updated Remaining Items Audit

Date: 2026-05-17.
Last verified: 2026-05-17T13:58:54-0700.

This audit tracks the four-item thread objective after the iOS responder
implementation. It is narrower than the whole-project completion audit.
The machine-readable focused checklist is archived at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json`.
Regenerate it with:

```sh
mix meshx.mobile.remaining_items.audit --json \
  --out artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json
```

## Checklist

| Item | Current status | Evidence | Remaining gap |
| --- | --- | --- | --- |
| Hardware validation of the full iOS responder path | Complete for attached SM-T577U -> iPad12,1 hardware | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json`; `docs/ble_transport_re_evaluation.md` | None for the requested end-to-end path. This does not prove background BLE, routing, ACKs, trusted delivery, or direct full-MX extended adverts. |
| Extended advertising interop (AUX scan response / direct full-MX advert path) | Still limited / blocked on tested iOS hardware | `docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_hardware_validation_gates.ex`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md` | Direct full-MX AUX manufacturer-data delivery is not reliable on tested iOS hardware. The latest device recheck still has no alternate iOS receiver available. The local validation checklist and closure-progress artifact record the exact callback, parse, fallback, metadata, and missing receiver-path evidence required to close this row. Supported full-envelope path is MB beacon cue plus GATT fetch where validated. |
| Upstreaming the `mob_dev` / `mob` patches | Advanced to upstream PRs, not complete | `docs/upstream_mob_patches.md`; `GenericJam/mob_dev#6`; `GenericJam/mob_new#5`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json` | PRs remained open, mergeable, GitGuardian-passing, and unmerged at the 2026-05-17T13:58:54-0700 upstream PR recheck. Maintainer handoff issue comments are posted and the local handoff artifact records maintainer actions plus MeshX post-merge migration gates. The migration-progress artifact records downstream patch verification, open replacement PRs, handoff, and READ-only permission as satisfied, while keeping upstream merge, release, MeshX dependency migration, downstream patch removal, and post-migration verification missing. Current token has `READ` permission on the upstream repos, so a GenericJam maintainer must merge/release before MeshX can migrate. The downstream patch check was re-run at 2026-05-17T12:12:03-0700 and still reports both patches already applied. |
| Test startup friction (`--no-start` workaround) | Complete | Root `mix test` passed without `--no-start` at 2026-05-17T12:09:58-0700; log archived at `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log`; runtime fix is in `apps/meshx_runtime/lib/meshx_runtime.ex` and script startup guards are in `scripts/*.exs` | None for the umbrella startup conflict. |

## Prompt-To-Artifact Checklist

| Prompt requirement | Artifact or command inspected | Coverage decision |
| --- | --- | --- |
| Android beacon cue -> iOS responder serving MX -> Android fetch | `apps/meshx_mobile_app/android/app/src/androidTest/java/dev/meshx/mob/ble/IOSResponderFetchSmokeTest.kt`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-instrumentation-2.log`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/android-logcat-2.log`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/ipad-responder-2.log` | Covered for attached SM-T577U -> iPad12,1 foreground hardware run. The passing Android instrumentation result and GATT logs cover cue discovery, service discovery, MFQ write, MFR read, MX envelope parse, and clean terminal state. `summary.json` also records this row as complete and leaves the AUX/upstream rows incomplete. |
| Avoid stale Android cached-name false positives in responder smoke | `IOSResponderFetchSmokeTest.kt` uses only `ScanRecord.deviceName`; first failing rerun and second passing rerun are archived in `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-fetch-ios-responder-rerun/` | Covered. The failed `not_found` rerun is explained and the passing rerun validates the corrected cue source. |
| Extended advertising interop / AUX scan response reliability | `docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_platform_parity.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_hardware_validation_gates.ex`; `apps/meshx_mobile_app/android/app/src/androidTest/java/dev/meshx/mob/ble/IOSAuxFullMxAdvertSmokeTest.kt`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-validation-checklist.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/aux-closure-progress.json` | Not complete. Fresh SM-T577U -> iPad12,1 probes emitted 80-byte full-MX scan-response extended adverts from Android and iOS still did not log `received_message`, decode error, candidate/discovery callback evidence, or `FF FF 4D 58` MX callback evidence for the AUX payload. The 11:19 rerun kept the iOS scanner active and observed 120 legacy-beacon lines while surfacing zero direct AUX MX lines. The AUX validation checklist records the exact sender/observer metadata, platform callback, canonical parse, and MB fallback evidence required to close this row. The closure-progress artifact marks sender metadata, observer metadata, MB fallback control, and negative-boundary notes satisfied for the negative runs while keeping platform callback proof, canonical parse proof, and an alternate iOS receiver path missing. MB beacon plus GATT fetch remains the supported full-envelope path where validated. |
| Alternate iOS AUX target availability | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/aux-alternate-ios-target-check/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md`; `devicectl-devices.txt`; `adb-devices.txt`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_hardware_validation_gates.ex`; `apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_release_evidence_manifest_test.exs` | No new AUX hardware path available in this workspace at 2026-05-17T13:58:54-0700. The SM-T577U Android device and Coding iPad iPad12,1 are connected, but `DairyPhoneDeaux` iPhone 13 remains `unavailable`, so there is no second iOS receiver target for a fresh direct full-MX AUX probe. The local release manifest preserves this availability artifact under the open iOS participation hardware gate. |
| Machine-readable readiness preserves the AUX boundary | `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_project_readiness.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_parity_evidence_manifest.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_parity_hardware_validation_plan.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_hardware_validation_gates.ex`; focused `mix test` for those snapshots | Covered as negative evidence. The readiness and iOS parity manifests now name the `android-aux-full-mx-ios-observe` probe plus the `android-aux-full-mx-ios-observe-rerun` probe and keep direct full-MX AUX claims blocked. This does not complete the AUX interop row because the required receiver-side callback evidence is absent. |
| iOS foreground emit vs iOS gossip distinction | `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_advert_carrier_decision.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_native_source_inventory.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_ios_parity_evidence_manifest.ex`; focused `mix test` for those snapshots | Covered as boundary evidence. The source inventory now records foreground iOS MB beacon emit source markers and the carrier decision records that emitter as `implemented_unvalidated`, while keeping iOS-origin cross-radio gossip proof, iOS parity, and direct full-MX AUX claims blocked. |
| Upstream `mob_dev` patch migration | `https://github.com/GenericJam/mob_dev/pull/6`; `docs/upstream_mob_patches.md`; scratch clone test result `mix test test/mob_dev/native_build_test.exs`; PR body rechecked by `gh pr view`; `gh repo view GenericJam/mob_dev`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-pr-6.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-dev-repo.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json` | Not complete. PR is open, mergeable, GitGuardian-passing, and its description includes MeshX integration evidence, but upstream had not merged it at the 2026-05-17T13:58:54-0700 PR recheck. Current token has `READ` permission, so this is now a maintainer merge/release blocker. The maintainer handoff and migration-progress artifact record the upstream merge/release action, MeshX post-merge dependency migration gates, and which pre-merge criteria are already satisfied. |
| Upstream generated `mob_new` template migration | `https://github.com/GenericJam/mob_new/pull/5`; `docs/upstream_mob_patches.md`; scratch clone focused result `mix test test/mob_new/project_generator_test.exs:866`; PR body rechecked by `gh pr view`; `gh repo view GenericJam/mob_new`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-pr-5.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/mob-new-repo.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json` | Not complete. PR is open, mergeable, GitGuardian-passing, and its description includes MeshX integration evidence, but upstream had not merged it at the 2026-05-17T13:58:54-0700 PR recheck. Current token has `READ` permission, so this is now a maintainer merge/release blocker. The maintainer handoff and migration-progress artifact record the upstream merge/release action, MeshX post-merge dependency migration gates, and which pre-merge criteria are already satisfied. |
| Keep downstream patch path valid until upstream migration | `mix meshx.patch_deps --check` from `apps/meshx_mobile_app`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log`; `patches/01-mob_dev-meshx-build-additions.patch`; `patches/02-mob-static-nif-table.patch`; `docs/upstream_mob_patches.md` | Covered as a fallback. The check reports both local patch files already patched for the locked dependency versions. This is not upstream completion. |

The maintainer handoff records the upstream merge/release action and MeshX
post-merge dependency migration gates. The migration-progress artifact records
downstream patch verification, open replacement PRs, handoff, and READ-only
permission as satisfied while keeping upstream merge, release, MeshX dependency
migration, downstream patch removal, and post-migration verification missing.
| Release readiness preserves downstream patch blocker | `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_project_readiness.ex`; `apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_project_readiness_test.exs` | Covered as release-hardening evidence. Local readiness now explicitly keeps `patches/`, `mix meshx.patch_deps`, and the locked downstream patch path until `GenericJam/mob_dev#6` and `GenericJam/mob_new#5` are merged, released, MeshX migrates, and post-merge gates pass. This is not upstream completion. |
| Completion audit preserves upstream migration blocker | `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_project_completion_audit.ex`; `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_project_completion_blocker_matrix.ex`; focused `mix test` for both surfaces | Covered as whole-project audit evidence. The completion audit and blocker matrix now require merged/released upstream PRs plus MeshX post-merge dependency migration before downstream patch removal. This is not upstream completion. |
| Release artifact bundle preserves upstream migration blocker | `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_release_artifact_bundle.ex`; `apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_release_artifact_bundle_test.exs`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md` | Covered as release-note packaging evidence. Operator release notes must not claim upstream patch migration complete while the GenericJam PRs remain unmerged or MeshX has not migrated. The release bundle and release manifest now include the maintainer handoff as a generated required artifact. This is not upstream completion. |
| Regenerated release/iOS parity manifests preserve blocked claims | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-ios-parity-evidence.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release.json`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/release-candidate/review.json` | Covered as release evidence hygiene. The regenerated manifests record foreground iOS MB beacon emit as implemented but cross-radio unvalidated, keep `ios_parity_claim_allowed?=false`, and keep whole-project completion false. This does not complete the AUX or upstream rows. |
| Recent evidence inventory preserves iOS emit boundary and closure artifact pointers | `apps/meshx_mobile_app/lib/meshx_mobile_app/ble/local_release_recent_evidence_inventory.ex`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/local-release-recent-evidence.json`; `mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_release_recent_evidence_inventory_test.exs apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_release_recent_evidence_test.exs` | Covered. The recent-evidence inventory now includes foreground iOS MB beacon emit source inventory support plus the AUX validation checklist and upstream maintainer handoff artifact paths, while explicitly blocking iOS-origin cross-radio gossip proof, iOS legacy beacon gossip, direct full-MX AUX completion, upstream PR merge completion, downstream patch removal, and iOS parity claims. This does not complete the AUX or upstream rows. |
| Cross-surface guardrail test pass | Focused `mix test` over `local_project_readiness_test.exs`, `local_project_completion_audit_test.exs`, `local_project_completion_blocker_matrix_test.exs`, `local_release_artifact_bundle_test.exs`, `local_hardware_validation_gates_test.exs`, `local_ios_parity_evidence_manifest_test.exs`, and `local_ios_parity_hardware_validation_plan_test.exs`; plus later carrier/source-inventory/parity, blocker, release-manifest, recent-evidence, and AUX-rerun source-backed focused suites | Covered. The combined guardrail suite passed with 82 tests and 0 failures earlier, the carrier/source-inventory/parity focused suite passed with 47 tests and 0 failures, the blocker/release/iOS parity suite passed with 67 tests and 0 failures, the negative-validation/release-artifact suite passed with 42 tests and 0 failures, the recent-evidence inventory/task suite passed with 8 tests and 0 failures after adding the closure artifact pointers, and the AUX-rerun source-backed suite passed with 35 tests and 0 failures after adding the rerun to hardware gates/readiness/iOS parity surfaces. This confirms the AUX-negative and upstream-migration blockers are consistent across readiness, release, completion audit, hardware gates, iOS parity manifests, and release evidence inventory. This does not complete the blocked rows. |
| Stale status wording scan | Broad remaining-item status wording scan over root docs, app docs, and patch docs; exact iOS emit/gossip stale-string scan over `artifacts/local-ble/2026-05-17-sm-t577u-ipad9`, BLE gate modules, and focused docs | Covered. No contradictory user-facing status text was found outside the focused audit rows themselves, and no generated artifact still says the iOS emit carrier is absent or that iOS gossip is blocked because no emitter exists. Root docs link to this audit for the responder proof, AUX boundary, upstream PRs, and startup fix. |
| Evidence bundle README mirrors current blockers | `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/README.md`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json` | Covered. The bundle README now names the direct AUX-negative probe, the 82-test guardrail pass, and the upstream patch merge/release/migration blocker. |
| Remove `--no-start` workaround / umbrella startup conflict | Root `mix test` without `--no-start`; `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/root-mix-test-1210.log`; `apps/meshx_runtime/lib/meshx_runtime.ex`; `scripts/tcp_sender.exs`; `scripts/tcp_receiver.exs`; `scripts/tcp_relay_node.exs`; `scripts/ble_sender.exs`; `scripts/ble_receiver.exs` | Covered. The runtime now starts dependency workers only where needed and the scripts explicitly ensure dependencies after application startup. Root `mix test` passed at 2026-05-17T12:09:58-0700 with 59 `meshx_transport`, 47 `meshx_protocol` including 11 properties, 18 `meshx_noise`, 30 `meshx_store`, 15 `meshx_mob`, 10 `meshx_transport_ble`, 70 `meshx_runtime`, and 1265 `meshx_mobile_app` tests. |
| Final diff hygiene | `git diff --check` | Covered for the current working tree at the time of this audit. |

## Hardware Responder Path

The requested high-priority path is:

1. iOS harness advertises an MB cue and starts `MeshxFetchGattResponder`.
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
     --console dev.meshx.mobile.harness \
     -- --meshx-auto-beacon
   ```

2. Run the Android instrumented smoke:

   ```sh
   adb -s R52W90AW7EN shell am instrument -w \
     -e class dev.meshx.mob.ble.IOSResponderFetchSmokeTest \
     dev.meshx.mob.test/androidx.test.runner.AndroidJUnitRunner
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

## Upstream Boundary

The remaining upstreamable gap is project Swift source inclusion:

- `GenericJam/mob_dev#6` adds `mob.exs :ios_swift_sources` handling in native
  build arguments.
- `GenericJam/mob_new#5` teaches generated iOS Zig build templates to compile
  those project Swift sources.

Both PRs are open, mergeable, not draft, and have passing GitGuardian checks.
Their visible merge-state status is `UNSTABLE`. The GitHub PR timelines
returned no review submissions or inline review comments; the only visible issue
comments are the maintainer handoff comments listed below. They are still not
merged, so this item remains open. `gh repo view` reports `READ` viewer
permission for both upstream repositories, so this checkout cannot perform the
upstream merge. Branch-protection details are not visible to this token; the
branch protection API returns `404 Not Found`.

Maintainer handoff comments were posted on both PRs with the MeshX validation
summary and read-only merge blocker:

- `GenericJam/mob_dev#6`: https://github.com/GenericJam/mob_dev/pull/6#issuecomment-4471758623
- `GenericJam/mob_new#5`: https://github.com/GenericJam/mob_new/pull/5#issuecomment-4471758634

The locked MeshX dependency state still uses the downstream patch path.
`mix meshx.patch_deps --check` from `apps/meshx_mobile_app` was re-run after
the upstream handoff comments, including the archived
2026-05-17T12:12:03-0700 check at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log`,
and still reports both local patch files as already patched.

## Completion Decision

This four-item objective is not complete because:

- direct full-MX extended advertising interop remains limited on tested
  hardware and needs a new hardware/API capture proving MX AUX delivery to the
  scanner callback before the claim can change;
- upstream PRs are not merged, and the current token has only `READ`
  permission on the upstream repositories.

Local work completed in this checkout:

- the high-priority iOS responder path has hardware evidence and a rerun
  recipe;
- the `--no-start` startup friction is fixed and covered by root `mix test`;
- downstream patch application remains verified by `mix meshx.patch_deps
  --check`;
- upstream PRs are open, documented, and carry MeshX integration evidence;
- the post-merge dependency migration and maintainer handoff are documented in
  `docs/upstream_mob_patches.md`;
- release readiness preserves the downstream patch blocker until upstream
  merge/release, MeshX migration, and post-merge verification are complete;
- whole-project completion audit and blocker matrix preserve the same upstream
  migration blocker;
- release artifact bundle wording review preserves the upstream migration
  blocker in operator release notes;
- focused cross-surface guardrail tests pass for the readiness, release,
  completion audit, hardware gate, and iOS parity manifest surfaces;
- regenerated release/iOS parity manifests and the release-candidate review
  preserve foreground iOS MB beacon emit as implemented but cross-radio
  unvalidated, while keeping iOS parity and whole-project completion blocked;
- a stale wording scan found no contradictory status text outside this focused
  audit;
- the hardware evidence bundle README mirrors the current AUX and upstream
  blockers from `summary.json`;
- the direct full-MX AUX unblock criteria are documented here and in
  `docs/BLE_BRIDGE.md`;
- the direct full-MX AUX negative probe is preserved in local readiness,
  hardware gates, and the iOS parity evidence manifest.

External unblock actions:

- AUX/direct full-MX can close only when a future iOS hardware/API capture
  proves `FF FF 4D 58` MX AUX manufacturer data reaches the platform scanner
  callback and parses through the canonical `received_message` path, while the
  MB beacon fallback still works in the same run.
- upstreaming can close only after a GenericJam maintainer merges and releases
  both `GenericJam/mob_dev#6` and `GenericJam/mob_new#5`, MeshX migrates to the
  released dependency versions, the downstream patch files and
  `mix meshx.patch_deps` requirement are removed, and the post-migration gates
  pass.

Do not remove `mix meshx.patch_deps` or the downstream patch files until the
upstream PRs land and MeshX has migrated to released dependency versions with
the needed extension points.
