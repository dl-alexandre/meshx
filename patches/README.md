# Project-local patches

Unified-diff patches applied to vendored deps via `mix meshx.patch_deps`.

Each file in this directory is a standard `git apply`-compatible patch
targeting a path under `apps/<app>/deps/<dep>/`. Patches are applied
from the repo root, so paths in the `--- a/...` / `+++ b/...` headers
are project-relative.

## File naming

`NN-<dep>-<short-description>.patch`, where `NN` is a zero-padded
two-digit number controlling apply order. Order matters when two
patches target the same file (each patch must apply cleanly on top of
the previous one's result).

## Header convention

Each patch begins with a comment block (lines starting with `#`) above
the `--- a/...` line. `git apply` ignores these. Required fields:

```
# NN-<short-name>.patch
#
# <one-paragraph description of what the patch does and why>
#
# Author: <attribution>
# Authored against: <dep>@<exact version from mix.lock>
# Updated: <YYYY-MM-DD>
# Tracked by: apps/meshx_mobile_app/lib/mix/tasks/meshx.patch_deps.ex
# Background: <links to docs or memory entries with full context>
#
```

The `Authored against:` line is load-bearing — when upstream changes
break the patch, the recovery procedure starts by reading this line
to find what version the diff was computed against.

## Adding a new patch

1. Make the change directly in `apps/<app>/deps/<dep>/<file>`.
2. Revert the dep file to its upstream state in a scratch copy.
3. `diff -u --label "a/apps/<app>/deps/<dep>/<file>" --label "b/apps/<app>/deps/<dep>/<file>" <unpatched> <patched> > patches/NN-<name>.patch`
4. Prepend the header block.
5. Verify: `mix meshx.patch_deps --check` should report "needs apply"
   for the new patch (or "already patched" if the dep file is still in
   the patched state from step 1). Then `mix meshx.patch_deps` should
   apply it.

## When a patch breaks after `mix deps.get`

`mix meshx.patch_deps` will raise `patch does not apply` with the
patch path and the `git apply` error output. Recovery:

1. Inspect the relevant file in `apps/<app>/deps/<dep>/` to see what
   the new upstream looks like.
2. Edit the file by hand to apply the change again.
3. Regenerate the patch with `diff -u` (see "Adding a new patch").
4. Bump the `Updated:` and `Authored against:` lines in the header.
5. Commit.

## Why patches and not a fork

A project-local fork is more work to maintain than a small patch set
and would couple us to an unmerged branch. The patches are intended
to be **temporary** — the long-term fix is upstream PRs to `mob_dev`
and `mob` that add proper extension points (extra Swift sources,
extra static NIFs registrable via config). When those PRs land,
delete the patches directory and the `meshx.patch_deps` task.

See `apps/meshx_mobile_app/CONTRIBUTING.md` for the developer
workflow and `docs/BLE_BRIDGE.md` § "Build system note" for the BLE
context that makes these patches necessary.
