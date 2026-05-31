# Upstreaming mob_dev / mob patches

**Historical context (pre-2026-05-21 migration PR).** The two temporary downstream patches have been removed. Upstream extension points are now in use (see `docs/upstream_mob_migration_checklist.md` for the as-built record and `patches/README.md` tombstone). This document preserves the original upstreaming rationale + pre-migration audit.

MeshX previously carried two temporary project-local patches for iOS
native builds:

- `patches/01-mob_dev-mob-build-additions.patch` targets
  `mob_dev 0.4.0` and injects project Swift sources plus
  `mob_ble_nif.m` into the generated iOS device build.
- `patches/02-mob-static-nif-table.patch` targets `mob 0.5.18` and
  registers `mob_ble_nif_nif_init` in the static NIF table.

These patches are downstream for the vendored dependency versions. They
should not be submitted upstream as-is: upstream `mob_dev` and `mob`
have moved substantially since these versions.

## Upstream Audit, 2026-05-17

Current upstream heads inspected locally:

- `GenericJam/mob_dev` `master` at `fc5e095`, version line `0.5.6`.
- `GenericJam/mob` `master` at `848014e`.

The static-NIF portion of MeshX's downstream patch has mostly been
superseded upstream:

- `mob_dev` now has `mix mob.add_nif` and
  `mix mob.regen_driver_tab`.
- `MobDev.StaticNifs` reads `mob.exs :static_nifs` entries with
  `:module`, `:init`, `:builtin`, `:archs`, and `:guard`.
- Generated driver tables default to
  `priv/generated/driver_tab_ios.zig` and
  `priv/generated/driver_tab_android.zig`.
- `MobDev.NativeBuild.project_nif_zig_args/1` classifies user NIFs
  from `c_src/<name>.c`, `native/<name>/Cargo.toml`, or Zigler stubs,
  then passes project C NIF names and static archives into the iOS and
  Android Zig build paths.
- Upstream `mob` no longer carries `ios/driver_tab_ios.c`; its
  reference table is `ios/driver_tab_ios.zig`.

That means the upstream path for `mob_ble_nif` should be a dependency
upgrade plus a `mob.exs :static_nifs` entry, not a hand-edited static
table patch.

## Upstream Shape

The remaining upstreamable gap is project Swift source inclusion. The
change should avoid hard-coding MeshX paths. Instead:

- `mob_dev` should accept app config for additional iOS Swift sources
  that are compiled into the app module alongside Mob's Swift sources.
- If the upstream release path continues to use the legacy shell build,
  it should either consume the same config or clearly document that the
  Zig native-build path is the extension point.
- The generated iOS build should preserve current default behavior when
  no extension config is present.

## Upstream PRs, 2026-05-17

Scratch upstream clones under `tmp/upstream/` contain the upstream PR
branches for that remaining gap:

- `tmp/upstream/mob_dev`
  - Branch: `mob-ios-swift-sources`; local commit `0cf9df0`
    `Support project iOS Swift sources`.
  - PR: https://github.com/GenericJam/mob_dev/pull/6
    - State: open, ready for review.
    - Mergeability: mergeable.
    - Checks: GitGuardian Security Checks passed.
  - `lib/mob_dev/native_build.ex` accepts `mob.exs`
    `:ios_swift_sources`, normalizes entries to absolute paths, rejects
    comma-containing entries, and passes
    `-Dproject_swift_sources=<comma paths>` into both iOS simulator and
    iOS device Zig build calls.
  - `test/mob_dev/native_build_test.exs` covers the config-to-Zig
    argument normalization.
- `tmp/upstream/mob_new`
  - Branch: `mob-ios-swift-sources`; local commit `3dbe111`
    `Compile project iOS Swift sources`.
  - PR: https://github.com/GenericJam/mob_new/pull/5
    - State: open, ready for review.
    - Mergeability: mergeable.
    - Checks: GitGuardian Security Checks passed.
  - `priv/templates/mob.new/ios/build.zig.eex` and
    `priv/templates/mob.new/ios/build_device.zig.eex` add a
    `project_swift_sources` build option and append each source to the
    `swiftc` compile command.
  - `test/mob_new/project_generator_test.exs` covers generated simulator
    and device templates.

Verification run in the scratch clones:

- `tmp/upstream/mob_dev`: `mix test test/mob_dev/native_build_test.exs`
  passed with 85 tests, 0 failures.
- `tmp/upstream/mob_new`:
  `mix test test/mob_new/project_generator_test.exs:866` passed with
  3 tests, 0 failures.
- `git -C tmp/upstream/mob_dev diff --check`,
  `git -C tmp/upstream/mob_new diff --check`, and root
  `git diff --check` passed.

The full `tmp/upstream/mob_new` generator test file was not green in
this environment because unrelated LiveView generator tests require the
`phx_new` Mix archive; failures were all `The task "phx.new" could not
be found`.

## MeshX Mapping

MeshX would configure the extension point with:

- Swift sources under `../../mob_node/Sources/Mob.Node/`.
- `ios/MobBLEBridge.swift`.
- A `:static_nifs` entry for `:mob_ble_nif`, with the native source
  at `c_src/mob_ble_nif.c` or another upstream-supported project NIF
  location after migration.

## Current Verification

The downstream patch path has been verified by:

- iOS harness device build on Coding iPad
  `00008030-000209510ED0C02E`.
- Android-to-iOS responder hardware smoke:
  `dev.mob.mob.ble.IOSResponderFetchSmokeTest`, passing on
  SM-T577U `R52W90AW7EN`.
- `mix mob.patch_deps --check` from `apps/mob_node`, archived at
  `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log`,
  which was re-run after the upstream handoff comments at
  2026-05-17T12:12:03-0700 and reported both local patch files as already
  patched for the locked dependency versions.

(The downstream patch path was retired in the post-merge migration PR; see `docs/upstream_mob_migration_checklist.md` and patches/README.md.)

## PR Status Recheck, 2026-05-17

Last verified: 2026-05-17T13:58:54-0700.

Rechecked with `gh pr view`:

- https://github.com/GenericJam/mob_dev/pull/6
  - State: open.
  - Draft: false.
  - Mergeability: mergeable.
  - Merge-state status: unstable.
  - Checks: GitGuardian Security Checks passed.
  - Head SHA: `0cf9df03224b163356404b5484b338005754b244`.
  - Review/comment state: no review submissions or inline review comments were
    returned by the GitHub PR timeline; one maintainer handoff issue comment is
    now present.
  - Base/head: `GenericJam/mob_dev:master` ←
    `dl-alexandre:mob-ios-swift-sources`.
- https://github.com/GenericJam/mob_new/pull/5
  - State: open.
  - Draft: false.
  - Mergeability: mergeable.
  - Merge-state status: unstable.
  - Checks: GitGuardian Security Checks passed.
  - Head SHA: `3dbe111e33ecb7e42ab2b8c3f55c8960c69f1c43`.
  - Review/comment state: no review submissions or inline review comments were
    returned by the GitHub PR timeline; one maintainer handoff issue comment is
    now present.
  - Base/head: `GenericJam/mob_new:master` ←
    `dl-alexandre:mob-ios-swift-sources`.

The PR descriptions were updated on 2026-05-17 to include the MeshX
integration evidence now available from the downstream checkout:

- `mix mob.patch_deps --check` reports both local patch files already
  patched for the locked dependency versions; latest archive:
  `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/patch-deps-check-1212.log`.
- The MeshX iOS harness device build succeeds with project Swift sources
  included.
- The SM-T577U -> iPad12,1 Android-to-iOS responder smoke passes through
  Android beacon cue, iOS MX responder, Android MFQ/MFR fetch, and MX
  envelope parse.

Maintainer handoff comments were also posted on 2026-05-17 with the same
validation summary and explicit read-only merge blocker:

- https://github.com/GenericJam/mob_dev/pull/6#issuecomment-4471758623
- https://github.com/GenericJam/mob_new/pull/5#issuecomment-4471758634

No upstream merge has happened yet. The MeshX downstream patch path is
therefore still required for the locked dependency versions, even
though the upstream migration path is now reduced to PR review, merge,
dependency upgrade, and replacing the local Swift-source patch with the
new `mob.exs :ios_swift_sources` extension point.

The 2026-05-17T13:58:54-0700 external blocker recheck is archived at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/external-blocker-recheck-1358/summary.md`.
The 2026-05-17T13:58:54-0700 upstream PR recheck is archived with raw
`gh` JSON output at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/summary.md`.
The maintainer handoff checklist for the same recheck is archived at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/maintainer-handoff.md`.
The structured migration-progress review is archived at
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1358/upstream-migration-progress.json`;
it records downstream patch verification, open replacement PRs, maintainer
handoff, and READ-only permission evidence as satisfied, while keeping upstream
merge, release, MeshX dependency migration, downstream patch removal, and
post-migration verification missing.

The current GitHub token has `READ` viewer permission on both upstream
repositories, so MeshX cannot complete the upstream merge/release action from
this checkout. A GenericJam maintainer must merge the PRs or grant write access
before the downstream patch migration can start.

This item can close only after both PRs are merged and released, MeshX is
migrated to the released dependency versions, the downstream patch files and
`mix mob.patch_deps` requirement are removed, and the post-migration MeshX
gates pass.

Branch-protection details are not visible to this token:
`gh api repos/GenericJam/mob_dev/branches/master/protection` and
`gh api repos/GenericJam/mob_new/branches/master/protection` both return
`404 Not Found`. The PR-level data visible through `gh pr view` shows only the
successful GitGuardian check, an empty review decision, `MERGEABLE`
mergeability, and `UNSTABLE` merge-state status.

## Maintainer Handoff

Ask a GenericJam maintainer to review and merge these together:

- https://github.com/GenericJam/mob_dev/pull/6
- https://github.com/GenericJam/mob_new/pull/5

Suggested maintainer context:

> These two PRs replace MeshX's downstream iOS build patches with generic
> upstream extension points. `mob_dev#6` reads project Swift source
> configuration from `mob.exs`; `mob_new#5` teaches the generated iOS Zig
> templates to compile those sources. MeshX has validated the downstream patch
> path with `mix mob.patch_deps --check`, an iOS harness device build, and a
> physical SM-T577U -> iPad12,1 responder smoke covering Android beacon cue,
> iOS MX responder, Android MFQ/MFR fetch, and MX envelope parse.
>
> The PRs are open, non-draft, mergeable, have the MeshX maintainer handoff
> comments above, have no visible review submissions, and the visible
> GitGuardian checks are passing. The requesting token only has read access, so
> a maintainer must perform the merge/release step.

After both PRs are merged, publish or select dependency versions that contain
the changes, then follow the post-merge MeshX migration checklist below.

## Post-Merge MeshX Migration Checklist

**EXECUTED in the 2026-05-21 migration PR.**

Detailed runbook + evidence + commands: see `docs/upstream_mob_migration_checklist.md` (supersedes the abbreviated list that followed).

The Post-Merge steps (dep bump to 0.6.18/0.5.11, mob.exs config for :ios_swift_sources + :static_nifs, deletion of the two patches + task + aliases, README/patches/README hygiene, audit flip, iOS device verification) are complete. This section retained only as historical reference for the shape of the upstreaming.
