# Upstream Maintainer Handoff 2026-05-17T12:40:47-0700

This checklist scopes the remaining work for the `mob_dev` / `mob_new`
upstream migration row. It is based on the raw `gh` JSON archived in this
directory.

## Current Upstream State

| Repository | PR | State | Merge state | Visible check | Viewer permission |
| --- | --- | --- | --- | --- | --- |
| `GenericJam/mob_dev` | https://github.com/GenericJam/mob_dev/pull/6 | `OPEN`, non-draft, unmerged | `MERGEABLE` / `UNSTABLE` | GitGuardian `SUCCESS` | `READ` |
| `GenericJam/mob_new` | https://github.com/GenericJam/mob_new/pull/5 | `OPEN`, non-draft, unmerged | `MERGEABLE` / `UNSTABLE` | GitGuardian `SUCCESS` | `READ` |

Both PRs have maintainer handoff comments that summarize the MeshX integration
evidence:

- https://github.com/GenericJam/mob_dev/pull/6#issuecomment-4471758623
- https://github.com/GenericJam/mob_new/pull/5#issuecomment-4471758634

No visible review submissions are present in the archived PR JSON.

## Maintainer Action Required

1. Review and merge `GenericJam/mob_dev#6`.
2. Review and merge `GenericJam/mob_new#5`.
3. Publish or tag released dependency versions that contain those changes.
4. Tell MeshX the released refs or versions to consume.

The current token has only `READ` permission on both upstream repositories, so
this checkout cannot perform those upstream merge or release actions.

## MeshX Post-Merge Migration Gate

After both upstream releases exist, MeshX can close this row only after all of
the following are true:

1. Update the MeshX dependency refs to the released upstream versions.
2. Remove the downstream patch files and the local patch requirement.
3. Remove or retire `mix meshx.patch_deps` from the required setup path.
4. Run the dependency migration verification:

```sh
mix deps.get
mix compile
mix test
```

5. Run the focused remaining-items audit again:

```sh
mix meshx.mobile.remaining_items.audit --json \
  --out artifacts/local-ble/2026-05-17-sm-t577u-ipad9/manifests/focused-remaining-items-audit.json
```

This row remains incomplete until the upstream PRs are merged/released and the
MeshX post-merge migration gate passes.
