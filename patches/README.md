# patches/ (legacy)

This directory contained two temporary unified-diff patches for vendored
`mob_dev` / `mob` that injected MeshX Swift sources (`ios_swift_sources`)
and the `mob_ble_nif` static NIF registration (`static_nifs`).

- `01-mob_dev-meshx-build-additions.patch`
- `02-mob-static-nif-table.patch`

They were removed in the post-`GenericJam/mob_dev#6` + `mob_new#5` migration
PR (see `docs/upstream_mob_migration_checklist.md` and the migration PR
that added `:ios_swift_sources` + `:static_nifs` to `apps/meshx_mobile_app/mob.exs`,
deleted the patch files, removed `meshx.patch_deps` task + aliases, and
updated docs).

The directory is preserved (empty of active patches) for now and may be
deleted in a future cleanup PR once all release branches have passed the
migration point. Historical patch content remains in git history.

See `docs/upstream_mob_patches.md` for the upstreaming context.
