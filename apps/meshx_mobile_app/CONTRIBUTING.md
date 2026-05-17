# Contributing to `meshx_mobile_app`

## iOS BLE build path

`mix mob.deploy --native` is the canonical iOS device deploy. It
cross-compiles the BEAM, links our Swift package + statically-linked
NIFs (`meshx_ble_nif`), signs, and pushes to a connected iPhone or iPad
via `xcrun devicectl`.

The locked `mob_dev` / `mob` dependency versions do not expose the
extension points MeshX needs for project-specific Swift sources and
static NIF registration, so we carry the required additions as
unified-diff patches in `patches/` at the repo root. The patches are
applied automatically by `mix meshx.patch_deps`, which is wired into
the `deps.get` / `deps.update` / `deps.compile` aliases in `mix.exs`.
You should not normally need to think about it.

Upstream PRs now exist for the Swift-source extension point:

- `GenericJam/mob_dev#6`
- `GenericJam/mob_new#5`

Until those PRs are merged, released, and MeshX migrates to released
dependency versions with the new `mob.exs :ios_swift_sources` support,
the downstream patch system remains the known-good build path. See
`docs/upstream_mob_patches.md` for the current PR state, maintainer
handoff, and post-merge migration checklist.

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

## Android dev opt-in: full MX envelopes

By default, `MeshxBleNative.sendToPeer/2` dispatches a 22-byte MB
legacy beacon — fleet-safe across all hardware including API 28
devices that cannot scan BLE 5 extended advertising. Full envelope
delivery on iOS goes through the MB beacon cue + GATT fetch path
([docs/BLE_BRIDGE.md] explains why direct extended-advert delivery
is empirically unreliable on current iOS).

For development & cross-platform integration testing, you can flip
the build to route `sendToPeer` through the full-MX path (envelope +
connectable `MeshxFetchGatt` responder). The same flag also enables
Android's scanner-side fetch coordinator: when Android observes an MB
beacon cue and then a connectable `MeshxFetchGatt` service advert, it
requests the matching envelope and emits the fetched payload as the
canonical `received_message` event. The flag has two equivalent inputs:

**Option A: `android/local.properties`** (persistent per-engineer):

```properties
meshx.mx.send=true
```

**Option B: environment variable** (one-off / CI):

```bash
MESHX_MX_SEND=true ./gradlew :app:assembleDebug
```

Either flips a `BuildConfig.USE_FULL_MX_ENVELOPES` compile-time
constant; the dispatcher reads it in `sendToPeer`, and `RealBleBridge`
uses it to install the scanner-side fetch coordinator. The branch is a
compile-time constant so R8 strips the unused path from release builds.

### Release-build safety

Setting the flag for a release build (`./gradlew assembleRelease`,
`bundleRelease`, etc.) fails with a build-time error. You cannot
accidentally ship the dev MX path:

```
> meshx.mx.send=true is incompatible with the release build. …
```

To build a release, remove the line from `local.properties` (or
unset `MESHX_MX_SEND`) first.

## Android runtime opt-in: receive-side GATT fetch

Receive-side fetch resolution can also be enabled at runtime without
turning on full-MX sending. Launch the Android app with:

```bash
adb shell am start \
  -n dev.meshx.mob/.MainActivity \
  --ez meshx_ble_fetch_on_beacon true
```

For clean hardware captures, combine it with the BLE selftest and disable
the selftest sender:

```bash
adb shell am start \
  -n dev.meshx.mob/.MainActivity \
  --ez meshx_ble_selftest true \
  --ez meshx_ble_selftest_send false \
  --ez meshx_ble_fetch_on_beacon true
```

This installs only the scanner-side MB-cue / service-hash-cue ->
`MeshxFetchGatt` coordinator. It leaves the default `sendToPeer` path on
MB-only unless `MESHX_MX_SEND=true` or `meshx.mx.send=true` is also used.

### Hardware caveat (API 28)

Older Android devices (e.g. some Samsung tablets at API 28) can
broadcast extended advertising but cannot reliably **scan** for
non-Apple AUX_ADV_IND packets — same constraint as iOS, see
[docs/BLE_BRIDGE.md] § "Extended-advertising AUX delivery
limitation". Android-to-Android dev testing with both ends at API
28 will not see the MX envelope via the air. The iOS-side observer
(iPad/iPhone) still works because it uses the MB beacon as the cue
and pulls the envelope via GATT — that path doesn't depend on the
peer being able to scan extended advertising.

If your dev workflow needs Android-to-Android MX delivery, prefer a
newer Android device on at least one side.

### Force-MX hook for tests

`MeshxBleNative.sendFullMxEnvelope/2` remains a Kotlin-only public
entry point that always uses the MX path regardless of the
`BuildConfig` flag. The instrumented `MXFullEnvelopeSmokeTest` calls
it directly so test coverage doesn't depend on how the build was
configured.

## CI

`mix meshx.patch_deps --check` exits non-zero if any patch is
unapplied or doesn't apply at all. Wire it into CI to catch:

- An untracked dep upgrade that broke a patch.
- A patch file that was edited locally but not regenerated.

```yaml
- run: mix meshx.patch_deps --check
```

## Long-term

The patches are technical debt. The long-term fix is upstream support
for project-supplied Swift sources and project-registered static NIFs.
Do not delete `patches/`, `lib/mix/tasks/meshx.patch_deps.ex`, or the
`meshx.patch_deps` aliases merely because the PRs are open. Remove
them only after the upstream changes are merged, released, the MeshX
dependencies are upgraded, and the iOS harness device build plus
Android-to-iOS responder smoke still pass. The current migration plan
lives in `docs/upstream_mob_patches.md`.
