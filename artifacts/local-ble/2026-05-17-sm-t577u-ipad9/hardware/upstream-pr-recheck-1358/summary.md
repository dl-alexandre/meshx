# Upstream PR Recheck 2026-05-17T13:58:54-0700

## Current PR State

| Repository | PR | State | Draft | Mergeability | Merge-state | Visible check | Permission |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `GenericJam/mob_dev` | https://github.com/GenericJam/mob_dev/pull/6 | Open | false | MERGEABLE | UNSTABLE | GitGuardian Security Checks passed | READ |
| `GenericJam/mob_new` | https://github.com/GenericJam/mob_new/pull/5 | Open | false | MERGEABLE | UNSTABLE | GitGuardian Security Checks passed | READ |

## Raw Outputs

- `mob-dev-pr-6.json`
- `mob-new-pr-5.json`
- `mob-dev-repo.json`
- `mob-new-repo.json`
- `maintainer-handoff.md`
- `upstream-migration-progress.json`

## Result

Both upstream PRs remain open and unmerged at the latest upstream-only recheck.
The current token still has `READ` permission on both upstream repositories.
The MeshX downstream patch path must remain in place until a GenericJam
maintainer merges/releases both PRs, MeshX migrates to dependency versions that
contain the changes, downstream patches are removed, and post-migration
verification passes.
