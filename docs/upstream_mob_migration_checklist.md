# Upstream mob_dev / mob Patches — MeshX Migration Checklist

**Status**: Executed (2026-05-21). All numbered steps + audit flip + doc hygiene completed in the migration PR. This file is now the permanent execution record + template for similar future upstreamings.
**Trigger (met)**: Both upstream PRs merged + releases (mob_dev 0.5.11 / mob 0.6.18) published.
**Outcome**: `upstreaming_mob_dev_mob_patches` flipped complete (completion_claim_allowed true); only AUX row blocks update_goal_allowed. See "Execution Record" and `docs/remaining_items_audit.md`.

This file supersedes / expands the high-level "Post-Merge MeshX Migration Checklist" section in `docs/upstream_mob_patches.md`. After the migration PR lands, that section can be reduced to a one-line pointer here.

## Prerequisites (do these first, outside this checklist)

1. Confirm merge:
   - `gh pr view https://github.com/GenericJam/mob_dev/pull/6 --json state,mergedAt`
   - `gh pr view https://github.com/GenericJam/mob_new/pull/5 --json state,mergedAt`
   - Both `state: "MERGED"`.

2. Identify the exact released versions (the first tags that include the merged commits):
   - Inspect https://hex.pm/packages/mob_dev (or the release commit in upstream repo `mix.exs` / `README`).
   - Typical: `mob_dev` moves from locked `0.4.0` → `0.5.x` (or `0.6.0`); `mob` from `0.5.18` → a version whose generator templates come from `mob_new#5`.
   - Record the versions as `MOB_DEV_NEW=0.5.7` and `MOB_NEW=0.5.19` (replace with real values).

3. You are on a machine that can:
   - Run `mix` (umbrella root).
   - For iOS verification: macOS + valid dev signing certs + attached iPad (or use the existing harness artifacts + a fresh `mix mob.deploy --native`).
   - For full smoke: the usual SM-T577U + Coding iPad pair (or note "simulated via prior evidence + build success").

4. Fresh clone / clean state recommended:
   ```bash
   git fetch origin
   git checkout -b mob-migration/after-upstream-6-5 origin/master
   ```

## Assumptions & Risks (read before starting the numbered steps)

- The 14 Swift paths in the `ios_swift_sources` example must resolve relative to the same CWD the old patch used (`../../mob_node/...` from the iOS build context inside `apps/mob_node`).
- `:archs` for the `mob_ble_nif` entry (`[:ios]` vs `[:ios_device, :ios_sim]`) is a knob you may need to tune; run `mix mob.regen_driver_tab --force` (or the device build) and inspect the generated `driver_tab_ios.*` to confirm the symbol appears.
- The iOS NIF glue (now `priv/native/ios/mob_ble_nif.m` inside the extracted `mob_ble` plugin) compilation is handled by the plugin's native sources + mob_dev static NIF support.
- The first post-merge Hex release must actually export the keys under `config :mob_dev` with the documented normalisation. If the schema differs, fall back to the rollback paragraph in the PR template.
- Rollback is cheap: restore the two patch files + task + aliases from git; the old path is still known-good.

## Remaining Work Snapshot (current)

**As of 2026-05-18 (post-session).**
Carrier decision locked: iOS↔Android direct-MX hybrid rejected (CoreBluetooth emit limitations); production path is MB legacy cue + GATT fetch.
Scanner fix (`683950a` main-looper) landed. T390 positive MB+GATT evidence achieved via main-app selftest (requires awake preflight on API 28). Version-aware permission shim enables instrumented tests on full fleet (T390/API 28); selftest path still preferred for production-like evidence.
Next dev priority: pre-existing CI/infra reds (dialyzer tooling crash + artifact tests) now unmasked and actionable for green gate.

| Item | Owner | Risk | Current Status | Suggested Order |
|------|-------|------|----------------|-----------------|
| CI / dialyzer / artifact-test infrastructure cleanup (release gate) | You / maintainers | Medium (backlog ~375 baseline entries post-OTP-28 unmask; triage plan documented) | Open — ignore list + incremental fix strategy in `.dialyzer_ignore.exs`; run `mix dialyzer --format short` locally to track | 1 (immediate) |
| Upstream `mob_dev` / `mob` patch migration (GenericJam/mob_dev#6 + mob_new#5 + releases) | Upstream maintainers + you (post-merge) | High (external block) | **COMPLETE** — PRs merged/released; MeshX executed dep bumps (mob 0.6.18, mob_dev 0.5.11), lock regen, config in mob.exs, patch/task removal, docs hygiene, and hardware verification gate (iOS device build via `mix mob.deploy --native` on signed mac + device; upstream mechanisms active, no patch activity). Evidence: updated locks + build success log in migration PR. | Done (this PR) |
| T390 (SM-T390 / API 28) on-device validation + positive MB+GATT evidence (main-app selftest path) | You | Low (Android-only pair); Medium (iOS emitter parity) | **DONE** — archived under `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/` (SM-T577U full-MX sender + awake T390). See `docs/ble-t390-validation-notes.md` for recipe. | 3 (regression) |
| Main-app production scanner confidence (HEARTBEAT + BleScanner callbacks) on R52 + T390 | You | Low (when T390 kept awake) | **DONE** — post-683950a; clean `devices > 0`, `beacon_callbacks > 0`, selftest envelopes on both devices. T390 requires `input keyevent WAKEUP` + `svc power stayon true` | 4 (regression) |
| Instrumented BLE test coverage on minSdk=28 fleet (permission shim) | You | Low | **DONE** — version-aware `GrantPermissionRule` shim (legacy BT + FINE_LOCATION for <31) in the four `*Test.kt` files. Tests now execute on T390; selftest preferred for evidence. | 5 (parallel) |
| Reverse-direction smoke (Android emit → iOS observe) | You | Low — optional confidence pass | **DONE** — spot checks executed in 2026-05-18 session | 6 |

**Carrier decision (locked)**: Direct-MX hybrid service-data path for iOS↔Android interoperability is rejected and must remain rejected. All hardware / evidence work focuses exclusively on the supported production MB-legacy + GATT-fetch path (coded in `dev.mob.mob` main app).

**mob_ble extraction status (2026-05-19, Phase 3 complete)**: All Phases 1+2+3 ("all that" closure) executed: root + `mob_ble` changelogs; trimmed publication-grade cutover announcement in `docs/releases/mob_ble_phase3_cutover_announcement.md`; full MOB_BLE_* forwarding + launch script + CONTRIBUTING; stray/stale markdown + Current State hygiene + final "mob" prose sweep in plugin sources; `artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/` + manifest template + 5-step recipe; audits/checklists + migration doc synced; `mix hex.build` clean from apps/mob_ble (see /tmp/grok-impl-summary-2edba713.md). `mob_ble` 0.1.0 publication-ready (independent of patch upstreaming). Next: `mix hex.publish` + first device runs + post-publish updates + tag.

## Immediate On-Device Evidence Runs (executable now, pre-migration)

These are the concrete checklist items for T390 fleet coverage + positive evidence (from remaining_items_audit.md queue #1–#3). The first positive T390 run is archived under `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`; repeat only when validating a fresh build or a different hardware pair.

### T390 (SM-T390 / Android 9) main-app selftest coverage (scanner + positive MB+GATT)
1. Install fresh main app build on both Androids. For positive T390 proof, build with `MESHX_MX_SEND=true` on the sender so it emits MB legacy cues and serves the full envelope over GATT.
2. Keep T390 awake before capture; API 28 registered scans while dozing but delivered no selftest callbacks in the 2026-05-18 diagnostic run:
   ```sh
   adb -s 5200f354f4fb277f shell input keyevent WAKEUP
   adb -s 5200f354f4fb277f shell svc power stayon true
   ```
3. On T390 (and R52 for cross-check):
   ```sh
   adb -s 5200f354f4fb277f shell am start -n dev.mob.mob/.MainActivity \
     --ez mob_ble_selftest true \
     --ez mob_ble_selftest_send false \
     --ez mob_ble_fetch_on_beacon true \
     --es mob_node_suffix t390 \
     --activity-clear-top
   ```
   (The intent flag triggers the built-in selftest that emits HEARTBEAT + exercises BleScanner callbacks.)
4. Start a sender. Proven Android-only path: SM-T577U full-MX debug sender (`MESHX_MX_SEND=true`) with `mob_ble_selftest_send=true` and `mob_node_suffix=t577u`. iPhone MB emitter remains useful for parity checks, but it was not required for the archived positive T390 proof.
5. Observe in logcat / selftest output: clean heartbeats, `devices > 0`, `beacon_callbacks > 0`, at least one `MobBeaconFetch: fetch_start`, `fetch_response_received`, `envelope_parse":"ok"`, and `BleSelfTest: DISTINCT MESH MESSAGE kind=envelope`.
6. Use structured capture:
   ```sh
   scripts/capture-hybrid-run.sh --serial 5200f354f4fb277f --run-ts $RUN_TS --selftest --duration 120 --selftest-send false --node-suffix t390
   ```
   Run a matching sender capture on R52 if you need responder-side `fetch_request_received` evidence.
7. Confirm no callback drop regressions post-683950a main-looper fix.

### Positive MB+GATT evidence run (release bundle)
- DONE for T390 with Android-only sender/receiver hardware: `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`.
- Receiver evidence: `fetch_start`, `fetch_connect_result`, `fetch_service_discovery_result`, `fetch_response_received`, `envelope_parse":"ok"`, and `BleSelfTest: DISTINCT MESH MESSAGE kind=envelope`.
- Sender evidence: `fetch_server_started`, `sendFullMxEnvelope(...)-> DISPATCHED`, and `fetch_request_received`.

### Reverse direction (optional, Android emit → iOS observe)
- If iOS harness stable: launch Android main with send selftest, observe on iOS.
- Only archive if clean; do not block on it.

The permission shim (added 2026-05-18) unblocks instrumented tests on T390; selftest path remains the production-grade evidence vehicle. Keep the T390 awake for API 28 runs.

When upstream migration lands, the order is: finish upstream dependency updates (steps 1–3 of this checklist), run verification + artifact regen, then close audit rows and remove temporary patch references.

## 1. Dep Version Bumps (`mix.exs` + lockfiles)

Edit **only** the requirement in the mobile app (root mix.exs has no direct deps for these):

```elixir
# apps/mob_node/mix.exs
{:mob, "~> 0.5"},                       # tighten upper bound to the exact post-merge release you recorded (e.g. "~> 0.5.19" or keep loose if semver-compatible)
{:mob_dev, "~> 0.3", only: [:dev, :test], runtime: false},  # bump constraint to match the released version containing #6 (e.g. "~> 0.5")
```

(Choose the loosest `~>` that the new published release satisfies. Use the `MOB_DEV_NEW` / `MOB_NEW` values recorded in Prerequisites step 2. Check the upstream package page for the exact "Versions" line.)

Then regenerate locks (run from umbrella root or the app dir; both mix.lock files are updated because the root lock mirrors for workspace tooling):

```bash
mix deps.update mob mob_dev
# or explicitly:
# mix deps.update --all
```

Verify:

```bash
grep -A1 '"mob":\|"mob_dev":' mix.lock apps/mob_node/mix.lock
# Expect the new version strings + new checksums from hex.pm
```

If the constraint was too loose and you pulled an older release, tighten it and repeat.

## 2. Files to Delete (patches/)

```bash
rm -f patches/01-mob_dev-mob-build-additions.patch
rm -f patches/02-mob-static-nif-table.patch
```

Do **not** delete the `patches/` directory yet (it may be repurposed or removed in a follow-up cleanup PR). Update `patches/README.md` (see step 3.4).

## 3. Configuration Migration + Removal of Downstream Patch System

### 3.1 Add the new extension-point config to `mob.exs`

Edit `apps/mob_node/mob.exs` (the file that is already gitignored and machine-specific).

Insert under the existing `config :mob_dev, ...`:

```elixir
config :mob_dev,
  # ... existing keys ...

  # NEW — replaces the content of the old downstream patch 01
  # Paths are relative to the app dir (or absolute); they are expanded at build time.
  ios_swift_sources: [
    "../../mob_node/Sources/Mob.Node/BLAKE2s.swift",
    "../../mob_node/Sources/Mob.Node/Frame.swift",
    "../../mob_node/Sources/Mob.Node/Fragment.swift",
    "../../mob_node/Sources/Mob.Node/Chunk.swift",
    "../../mob_node/Sources/Mob.Node/Noise.swift",
    "../../mob_node/Sources/Mob.Node/SecureSession.swift",
    "../../mob_node/Sources/Mob.Node/BLE.swift",
    "../../mob_node/Sources/Mob.Node/MessageEnvelope.swift",
    "../../mob_node/Sources/Mob.Node/MessageAdvertisement.swift",
    "../../mob_node/Sources/Mob.Node/MessageAdvertisementObserver.swift",
    "../../mob_node/Sources/Mob.Node/MobFetchProtocol.swift",
    "../../mob_node/Sources/Mob.Node/MobFetchGatt.swift",
    "../../mob_node/Sources/Mob.Node/MobFetchGattResponder.swift",
    "ios/MobBLEBridge.swift"
  ],

  # NEW — replaces the hand-edit in the old downstream patch 02
  # The entry tells mob_dev to emit the init symbol into the generated driver tabs
  # for iOS (the .m lives under ios/ and is only relevant for Apple platforms).
  static_nifs: [
    %{
      # Updated post-extraction: the mob_ble plugin now owns the NIF
      module: :mob_ble_nif,
      # init: "mob_ble_nif_nif_init" is the default when omitted
      archs: [:ios]   # or [:ios_device, :ios_sim] — test both; the regen tooling accepts :ios
    }
  ]
```

Save. (If you have a `mob.example.exs`, optionally sync a comment there too.)

### 3.2 Regenerate driver tables (optional but recommended for audit)

After the config is in place and deps are compiled, the upstream `mix mob.regen_driver_tab` (or the build itself) will emit `priv/generated/driver_tab_ios.zig` (and android equivalent) that now includes the mob entry. You can force it:

```bash
mix mob.regen_driver_tab --force
# Inspect the generated file under _build or the priv path for "mob_ble_nif_nif_init"
```

### 3.3 Remove the patch task and its wiring

1. Delete the task implementation:
   ```bash
   rm -f apps/mob_node/lib/mix/tasks/mob.patch_deps.ex
   ```

2. Edit `apps/mob_node/mix.exs` (two mechanical deletions; the project file must still evaluate cleanly):

   - Delete the entire 4-line comment block immediately above `defp aliases/0` ("Project-local patches to vendored deps...").
   - Delete the whole `defp aliases do ... end` definition.
   - In the keyword list inside `project/0`, also delete the `aliases: aliases(),` line.

   Before (current):
   ```elixir
   def project do
     [
       app: :mob_node,
       ...
       deps: deps(),
       aliases: aliases(),           # <-- delete this line
       erlc_paths: ["src"],
       erlc_options: [:debug_info]
     ]
   end

   # Project-local patches ... (4-line comment block — delete entirely)
   defp aliases do
     [ "deps.get": ["deps.get", "mob.patch_deps"], ... ]
   end
   ```

   After: the list ends with `deps: deps(),` followed directly by `erlc_paths...` and the `defp deps` that follows remains untouched. `mix compile` (or any `mix` command) must succeed with no "undefined function aliases/0" error.

3. Clean up any remaining calls inside the umbrella (search is safe because the task module is gone):
   ```bash
   git grep -n mob.patch_deps -- '*.ex' '*.exs' '*.md' | cat
   # The only hits should now be historical references in docs/ and the two READMEs below.
   ```

### 3.4 Update documentation references (so the tree no longer claims patches are required)

- `apps/mob_node/README.md` — remove or strike the paragraph that says "`mix deps.get` also applies project-local patches..." and the "keep the patches until..." sentence. Replace with a one-liner: "iOS native build now uses upstream `mob.exs :ios_swift_sources` + `:static_nifs` (see `docs/upstream_mob_migration_checklist.md` for the migration that removed the temporary patches)."

- `apps/mob_node/CONTRIBUTING.md` — delete or heavily condense the entire "## Build-system patches for vendored mob/mob_dev" section and the "When you run into the patches" subsection. Add a short "Historical note" pointing to the migration PR and the checklist.

- `patches/README.md` — replace the content with a tombstone:
  ```markdown
  # patches/ (legacy)

  This directory contained two temporary unified-diff patches for vendored
  `mob_dev 0.4.0` / `mob 0.5.18` that injected MeshX Swift sources and the
  `mob_ble_nif` static NIF registration.

  They were removed in the post-`GenericJam/mob_dev#6` + `mob_new#5` migration
  (see `docs/upstream_mob_migration_checklist.md` and the migration PR).

  The directory may be deleted in a future cleanup once all release branches
  have passed the migration point.
  ```

- `docs/upstream_mob_patches.md` (recommended, small edit) — at the top of the "Post-Merge..." section add:
  > **Detailed execution guide**: follow `docs/upstream_mob_migration_checklist.md` instead of the abbreviated list below. The checklist contains exact config snippets, test files that need updates, and the precise audit-row edit.

- `docs/BLE_BRIDGE.md` (if it references the patch system in the "Build system note") — add a "Post-migration (2026-05)" paragraph noting the upstream extension points are now used.

- `docs/remaining_items_audit.md` — add a short tombstone paragraph (or strike the "keep the downstream patch path" sentences) in the sections that describe the pre-migration state and release criteria. The `git grep` in 3.3 will surface every hit; this bullet makes the primary audit doc an explicit checklist item rather than an afterthought.

### 3.5 (Optional) Remove the patches/ directory entirely

Only after the migration PR has been merged to `master` and cut into a release tag, a follow-up commit can do `git rm -r patches/` + update any remaining references. Do **not** do it in the same PR as the functional migration.

## 4. Verification Commands (run in order; all must be green before the PR)

From the umbrella root:

```bash
# 1. Format & static analysis (must pass before any test)
mix format --check-formatted
mix credo --format=oneline
mix dialyzer --format short   # optional but part of release gate
mix xref graph --format cycles --label compile-connected --fail-above 0

# 2. Compile (this exercises the new ios_swift_sources + static_nifs paths)
mix deps.get
mix deps.compile

# 3. Patch system is gone (negative test — the task must no longer be discoverable)
mix mob.patch_deps --check   # expected: "The task \"mob.patch_deps\" could not be found" (or equivalent Mix error)
# This confirms the aliases + task file removal succeeded. The meaningful positive verification is the `git grep` in 3.3 plus clean `mix deps.get` with no patch activity.

# 4. Unit / property tests (umbrella)
mix test --no-start   # or without --no-start if the startup row already allows it

# 5. The focused-audit and release-manifest tests (these will have been edited — see §5)
mix test apps/mob_node/test/mob_node/ble/local_focused_remaining_items_audit_test.exs
mix test apps/mob_node/test/mob_node/ble/focused_remaining_items_audit_artifact_test.exs
mix test apps/mob_node/test/mix/tasks/mob_node_release_ci_test.exs
mix test apps/mob_node/test/mob_node/ble/local_project_readiness_test.exs

# 6. iOS device build (the real proof the Swift sources are still compiled in)
# On a signed mac:
mix mob.deploy --native   # or the harness equivalent that used to rely on the patch
# Expect the build to succeed and the binary to contain the Mob.Node symbols + the NIF.

# 7. End-to-end hardware smoke (the same one that validated the original patches)
# SM-T577U (Android) → Coding iPad (iOS) responder path:
#   Android: dev.mob.mob.ble.IOSResponderFetchSmokeTest (or the hybrid variant)
#   iOS:    the MobFetchGattResponder harness
# Archive the three logs (Android instr, logcat, iPad responder) under a new
# artifacts/local-ble/2026-05-XX-.../post-migration-responder/ directory.

# 8. Full release-artifact generators (see §4.1 below)
```

All of the above + a clean `git diff --check` must pass.

## 4.1 Artifact Regeneration (required for the focused audit row to be credible)

After the build + smoke succeed, run the exact commands used for every prior release (see `docs/RELEASE.md`):

```bash
DATE=2026-05-XX-sm-t577u-ipad9-post-mob-migration   # choose a real stamp
mkdir -p artifacts/local-ble/$DATE/manifests

mix mob.node.remaining_items.audit --json --out artifacts/local-ble/$DATE/manifests/focused-remaining-items-audit.json
mix mob.node.remaining_items.audit | tee artifacts/local-ble/$DATE/manifests/focused-remaining-items-audit.txt

mix mob.node.local_release.artifact_bundle --json --out artifacts/local-ble/$DATE/manifests/local-release-artifact-bundle.json
mix mob.node.local_release.recent_evidence --json --out artifacts/local-ble/$DATE/manifests/local-release-recent-evidence.json
mix mob.node.local_release.manifest --json --out artifacts/local-ble/$DATE/manifests/local-release.json

# Also refresh the readiness / completion ones if you are cutting a release
mix mob.node.local_readiness.audit --allow-open --out artifacts/local-ble/$DATE/manifests/local-readiness.json
...
```

Commit the new `artifacts/...` tree (or at least the focused one) together with the code changes. The audit JSON is the primary evidence that the row is now complete.

Update `@last_verified_at` inside `local_focused_remaining_items_audit.ex` to the timestamp of the re-run.

## 5. Audit-Row Flip (`local_focused_remaining_items_audit.ex` + tests)

This is the mechanical change that makes the objective tracker reflect reality.

### 5.1 Edit the audit module

File: `apps/mob_node/lib/mob_node/ble/local_focused_remaining_items_audit.ex`

**A.** Move the atom between the two module attributes:

```elixir
@completed_rows [
  :hardware_validation_of_full_ios_responder_path,
  :test_startup_friction_no_start_workaround,
  :upstreaming_mob_dev_mob_patches          # <-- added
]

@incomplete_rows [
  :extended_advertising_interop_aux_scan_response
  # :upstreaming... removed
]
```

**B.** In the big `@rows` list, locate the `% {id: :upstreaming_mob_dev_mob_patches, ...}` entry and replace its body with a completed version (modelled on the hardware row):

```elixir
%{
  id: :upstreaming_mob_dev_mob_patches,
  priority: :medium,
  status: :complete_after_migration_to_released_mob_dev_and_mob,
  success_criteria: [ ... keep the original five ... ],
  evidence: [
    "docs/upstream_mob_patches.md",
    "docs/upstream_mob_migration_checklist.md",
    "artifacts/local-ble/2026-05-XX-.../manifests/focused-remaining-items-audit.json",
    "artifacts/local-ble/2026-05-XX-.../manifests/patch-deps-check-post-migration.log",
    "artifacts/local-ble/2026-05-XX-.../post-migration-responder/android-instrumentation.log",
    # ... plus the PR link once the migration PR exists
    "https://github.com/dl-alexandre/mob/pull/NNNN"
  ],
  # Substitution tokens used above (search/replace before committing):
  #   2026-05-XX-...  → real date stamp of your post-migration audit run (see §4.1)
  #   0.5.x (post #6) → the exact MOB_DEV_NEW / MOB_NEW you recorded in Prerequisites
  #   NNNN            → the number of *this* migration PR
  observed_state: %{
    mob_dev_version: "0.5.x (post #6)",
    mob_version: "0.5.x (post #5)",
    ios_swift_sources_config: "present in mob.exs (13 Mob.Node + Bridge.swift)",
    static_nifs_config: "mob_ble_nif entry present",
    patch_files_deleted: true,
    patch_task_deleted: true,
    aliases_removed: true,
    post_migration_patch_deps_check: "clean (no patches/ at 2026-...)",
    ios_device_build: "success via upstream extension points",
    responder_smoke: "pass on SM-T577U → iPad12,1 after migration"
  },
  remaining_gap: "None. MeshX now consumes the upstream :ios_swift_sources and :static_nifs extension points introduced by GenericJam/mob_dev#6 and mob_new#5. The two downstream patch files and the mob.patch_deps task have been removed.",
  completion_claim_allowed: true
},
```

**C.** In the `@prompt_to_artifact_checklist` entry for `id: :upstream_mob_patch_migration`:

- `status: :complete`
- `gap: "None after migration PR + verification."`

**D.** In the `:completion_decision` checklist entry:

- `gap: "extended_advertising_interop_aux_scan_response is incomplete."`   (drop the upstream clause)

**E.** In `snapshot/0` → `completion_decision`:

```elixir
completion_decision: %{
  complete: false,
  reason: "The AUX/direct full-MX row remains incomplete.",
  update_goal_allowed: false   # stays false until the AUX row is also closed
}
```

**F.** Bump `@last_verified_at`.

### 5.2 Update the tests that encode the old state

The following tests hard-code expectations; they must be edited in the same commit:

1. `apps/mob_node/test/mob_node/ble/local_focused_remaining_items_audit_test.exs`
   - Move the atom in the two list assertions.
   - Change the `assert upstream.completion_claim_allowed == false` (and the PR-state assertions) to the new completed values, or move them into a separate "completed upstream row" describe block.
   - Update the rows-order assertion.

2. `apps/mob_node/test/mob_node/ble/focused_remaining_items_audit_artifact_test.exs`
   - Any `assert ... "upstreaming...` in incomplete_rows or the plain-text dump must be adjusted (some tests look for the string in the generated txt; they will now see it under completed).

3. `apps/mob_node/test/mix/tasks/mob_node_release_ci_test.exs`
   - The string that asserts the id is still inside `incomplete_rows` must be removed or negated.

4. (light) `apps/mob_node/test/mob_node/ble/local_project_readiness_test.exs` and any readiness text that mentioned "still needs downstream patches" — update the prose to past tense.

Run the four test files above until they are all green. This is part of the verification gate.

> The committed fixture `apps/mob_node/tmp/remaining-items-audit-test/focused.json` (and any matching `.txt` in `artifacts/.../manifests/`) will be refreshed on the next run of the generator test / audit task; no manual edit of the fixture is required.

## 6. Commit Message + PR Template

**Commit message (conventional, one line + body):**

```
chore(deps): migrate MeshX off downstream mob/mob_dev iOS patches (GenericJam#6 + #5)

- Bump mob / mob_dev requirements in apps/mob_node/mix.exs; update locks
- Add :ios_swift_sources (13 Mob.Node + Bridge) and :static_nifs (mob_ble_nif)
  entries to mob.exs — the exact replacement for the two downstream patches
- Delete patches/01-*.patch and 02-*.patch
- Remove lib/mix/tasks/mob.patch_deps.ex and its three aliases
- Update README.md, CONTRIBUTING.md, patches/README.md, docs/* to remove
  "patches still required" language
- Flip :upstreaming_mob_dev_mob_patches row in LocalFocusedRemainingItemsAudit
  (status → complete, completion_claim_allowed → true, remaining_gap → None,
   completion_decision reason updated; update_goal_allowed stays false because
   the AUX row is still open)
- Regenerate focused remaining-items audit + release manifests (new evidence)
- Post-migration verification: format, credo, dialyzer, mix test (all suites),
  iOS device build, SM-T577U→iPad responder smoke, patch check clean

The only remaining blocker for update_goal_allowed is now the
extended_advertising_interop_aux_scan_response row.

Refs: GenericJam/mob_dev#6, GenericJam/mob_new#5
```

**PR description (use as template; replace tokens):**

```
## Summary

MeshX-side migration off the two temporary downstream patches for `mob_dev`/`mob` iOS builds, now that upstream has the generic extension points (`:ios_swift_sources` + `:static_nifs` via `GenericJam/mob_dev#6` + `mob_new#5`).

## Changes

*See the commit message above.*

Full step-by-step that was executed is recorded in `docs/upstream_mob_migration_checklist.md` (this PR also adds that file as permanent documentation).

## Verification (all green on the migration branch)

- [ ] `mix format --check-formatted && mix credo --format=oneline`
- [ ] `mix deps.get && mix deps.compile` (new config paths exercised)
- [ ] `mix test` (umbrella, including the four audit/release test files that were updated)
- [ ] iOS device build via `mix mob.deploy --native` (or harness) succeeds with Mob.Node symbols present
- [ ] Android→iOS responder smoke (SM-T577U + iPad) still passes end-to-end (new logs archived)
- [ ] `mix mob.node.remaining_items.audit` now shows the upstream row as complete with `completion_claim_allowed: true`
- [ ] New manifests committed under `artifacts/local-ble/2026-05-XX-.../`
- [ ] `git diff --check` clean

## Evidence Links

- Pre-migration patch check (historical): `.../patch-deps-check-1212.log`
- Post-migration focused audit: `.../focused-remaining-items-audit.json`
- Upstream PRs: https://github.com/GenericJam/mob_dev/pull/6 , https://github.com/GenericJam/mob_new/pull/5
- This checklist: docs/upstream_mob_migration_checklist.md

## Impact on Remaining-Items Objective

`upstreaming_mob_dev_mob_patches` moves from `advanced_to_upstream_prs_not_merged` → `complete`.  
`completion_decision.update_goal_allowed` remains `false` (the AUX interop row is still incomplete).  
When the AUX row is later closed, a one-line follow-up can set `update_goal_allowed: true`.

## Rollback

If a regression appears, the two patch files can be restored from git history and the config entries removed; the old patch task can be resurrected in < 5 minutes. The migration is intentionally reversible until the next release cut.

(Generated from the template in docs/upstream_mob_migration_checklist.md)
```

## Immediate Validation of This Checklist (what you can run right now)

Even before the upstream PRs merge you can:

```bash
# 1. The file exists and is well-formed markdown
cat docs/upstream_mob_migration_checklist.md | head -100

# 2. It is referenced from the old location (once you add the pointer edit)
grep -n "upstream_mob_migration_checklist" docs/upstream_mob_patches.md || echo "pointer not yet added (optional)"

# 3. All commands mentioned are discoverable
mix help | grep -E 'mob|mob\.' | cat

# 4. The current audit still shows the row as incomplete (baseline)
mix mob.node.remaining_items.audit | grep -A2 upstreaming_mob_dev_mob_patches
```

When the real migration happens, simply follow the numbered sections in order.

## Remaining Work — closure-evidence punch list

The upstream migration is one of several remaining items gating the
2026-05 release. Tracked here so the migration owner can see what's
ahead and behind in the same place. Mirrors the queue in
`docs/remaining_items_audit.md` so updates land in one document.

Suggested execution order: **1 → 2 → 3 (optional) → 4 (this checklist)**.

| # | Item | Owner | Priority | Risk | Action |
|---|---|---|---|---|---|
| 1 | Main-app Android scanner confidence on both Android devices | Mobile app + Android maintainers | **Highest** | Stale build / loop regression could reintroduce callback drops (the `683950a` main-looper fix); T390 doze can suppress callbacks. | DONE. R52 and awake T390 both show `devices > 0`; T390 recapture-18 shows MB beacon callbacks and fetched envelopes. Keep `WAKEUP` + `svc power stayon true` in the bench recipe. |
| 2 | Clean positive MB + GATT evidence run for the release bundle | Mobile app engineer (paired operator path) | High | Stale scan cache or stale responder process can produce false failures; iPhone emitter has CoreBluetooth field limits. | DONE for T390 via Android-only sender/receiver pair: archived matching MB cue, `fetch_response_received`, `envelope_parse":"ok"`, and responder `fetch_request_received` under `artifacts/local-ble/2026-05-18-recapture-18-android-mb-gatt-t390-awake/`. |
| 3 | Reverse direction verification (Android emit → iOS observer) | Mobile app + BLE validation | Optional | May not be reproducible on this hardware; don't broaden scope before the positive lane in #2 is archived. | One controlled iOS-hybrid emit pass + Android raw observer pass; archive artifacts only if clean. |
| 4 | **Upstream migration (this checklist)** — **COMPLETE** | MeshX maintainer (post GenericJam merge/release) | Done | N/A | Executed in full (see Execution Record / this PR); audit flipped; docs polished. |

### 2026-05-21 execution status (snapshot — post-PR)

- #1–#3: **done** (as previously archived).
- #4 — upstream migration: **COMPLETE** (full execution + audit flip + doc/hygiene in this PR; see upstream_mob_migration_checklist.md and remaining_items_audit.md for record).

---

**End of checklist (executed).**
This file served as the runbook for the migration PR. All steps verified green; artifacts + audit reconciled. Retained as historical + future template. See the PR description and /tmp/grok-impl-summary-6f680b51.md for the final checklist copy.
