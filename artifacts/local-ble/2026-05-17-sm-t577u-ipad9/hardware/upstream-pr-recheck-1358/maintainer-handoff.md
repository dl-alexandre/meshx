# Upstream Patch Maintainer Handoff 2026-05-17T13:58:54-0700

## Current PRs

Shorthand: `GenericJam/mob_dev#6` and `GenericJam/mob_new#5`.

| Repository | PR | Branch | Status | Permission |
| --- | --- | --- | --- | --- |
| `GenericJam/mob_dev` | https://github.com/GenericJam/mob_dev/pull/6 | `meshx-ios-swift-sources` -> `master` | Open, mergeable, unstable | `READ` |
| `GenericJam/mob_new` | https://github.com/GenericJam/mob_new/pull/5 | `meshx-ios-swift-sources` -> `master` | Open, mergeable, unstable | `READ` |

## Handoff

The replacement PRs are still upstream-owned. The current token has only `READ` permission, can inspect but cannot merge either repository, and the checks only show GitGuardian success.

## MeshX Post-Merge Migration Gate

The MeshX downstream patch path must remain in place until:

1. GenericJam merges `mob_dev#6` and `mob_new#5`.
2. The merged changes are released or otherwise available as dependency refs.
3. MeshX updates the dependency pins to the upstream refs.
4. `mix meshx.patch_deps --check` is no longer required for those changes.
5. The post-merge MeshX build/test gates, including `mix test`, pass without the downstream patches.

Until all five steps pass, `upstream_patch_migration_complete` remains a blocked
claim.

The structured migration-progress review for this recheck is archived at
`upstream-migration-progress.json`. It marks downstream patch verification,
open replacement PRs, maintainer handoff, and READ-only permission evidence as
satisfied while keeping upstream merge, release, MeshX dependency migration,
downstream patch removal, and post-migration verification missing.
