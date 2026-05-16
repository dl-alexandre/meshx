# Contributing to `meshx_mobile_app`

## iOS BLE build path

`mix mob.deploy --native` is the canonical iOS device deploy. It
cross-compiles the BEAM, links our Swift package + statically-linked
NIFs (`meshx_ble_nif`), signs, and pushes to a connected iPhone or iPad
via `xcrun devicectl`.

The mob tooling does not currently expose parameterizable hooks for
adding project-specific Swift sources or static NIFs, so we carry the
required additions as unified-diff patches in `patches/` at the repo
root. The patches are applied automatically by `mix meshx.patch_deps`,
which is wired into the `deps.get` / `deps.update` / `deps.compile`
aliases in `mix.exs`. You should not normally need to think about it.

## When you run into the patches

### `mix deps.get` shows patch activity

Normal — every `deps.get` reapplies the patches (idempotent). Output
looks like:

```
  ✓  patches/01-mob_dev-meshx-build-additions.patch: already patched
  ✓  patches/02-mob-static-nif-table.patch: already patched
```

### `mix meshx.patch_deps` says "patch does not apply"

The upstream `mob_dev` or `mob` dep changed in a way that breaks one
of our patches. Recovery:

1. Read the patch file in `patches/` to see what it was trying to do.
2. Inspect the now-divergent dep file in
   `apps/meshx_mobile_app/deps/<dep>/...`.
3. Edit by hand to re-apply the change against the new upstream.
4. Regenerate the `.patch` file with `diff -u` against an unpatched
   copy. See `patches/README.md` for the exact incantation.
5. Bump the `Updated:` and `Authored against:` lines in the patch
   header.
6. Commit the regenerated patch and the bumped dep version (if any).

### You're adding a new Swift source or NIF

If your addition needs the iOS build to compile a new `.swift` file
in `meshx_mobile/Sources/MeshxMobile/` or link a new `.m` NIF, you
need to update the existing patches (or add a new one). Specifically:

- **New Swift source**: add the path to the `swiftc` arg list inside
  `patches/01-mob_dev-meshx-build-additions.patch`. Look for the
  existing `MessageAdvertisementObserver.swift` line and append.
- **New static NIF**: add a compile step + link step to the same
  patch, and a registration entry in
  `patches/02-mob-static-nif-table.patch`.

For each, regenerate the affected `.patch` file (see above) so the
diff stays clean.

## CI

`mix meshx.patch_deps --check` exits non-zero if any patch is
unapplied or doesn't apply at all. Wire it into CI to catch:

- An untracked dep upgrade that broke a patch.
- A patch file that was edited locally but not regenerated.

```yaml
- run: mix meshx.patch_deps --check
```

## Long-term

The patches are technical debt. The long-term fix is upstream PRs to
`mob_dev` and `mob` that add proper extension points (project-supplied
extra Swift sources, project-registered static NIFs). When those land,
delete `patches/`, delete `lib/mix/tasks/meshx.patch_deps.ex`, and
remove the `aliases/0` block in `mix.exs`. The project memory entry
[[mob-dev-ios-build-vendored-patches]] tracks the status of that work.
