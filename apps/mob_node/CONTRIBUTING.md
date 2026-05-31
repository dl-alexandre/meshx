# Contributing to `mob_node`

## iOS BLE build path

`mix mob.deploy --native` is the canonical iOS device deploy. It
cross-compiles the BEAM, links our Swift package + statically-linked
NIFs (`mob_ble_nif`), signs, and pushes to a connected iPhone or iPad
via `xcrun devicectl`.

The iOS build now consumes the upstream extension points introduced
by `GenericJam/mob_dev#6` and `GenericJam/mob_new#5`:

- `mob.exs` under `config :mob_dev`:
  - `:ios_swift_sources` — list of project Swift files (Mob.Node +
    local bridge) to compile into the device .app
  - `:static_nifs` — declarative registration for `:mob_ble_nif` (and
    future project NIFs) so they appear in the generated driver tab

See `docs/upstream_mob_migration_checklist.md` for the exact migration
steps, verification commands, and what was removed (`patches/01...`,
`02...`, the `mob.patch_deps` task, and its aliases).

## Historical note (patch system)

The downstream patch machinery (`patches/`, `mob.patch_deps` task,
aliases in mix.exs) was removed in the migration PR after upstream
landed support for `:ios_swift_sources` and `:static_nifs`. See the
checklist in `docs/upstream_mob_migration_checklist.md` and the
updated `apps/mob_node/mob.exs`.

## Android dev opt-in: full MX envelopes

By default, `MobBleNative.sendToPeer/2` dispatches a 22-byte MB
legacy beacon — fleet-safe across all hardware including API 28
devices that cannot scan BLE 5 extended advertising. Full envelope
delivery on iOS goes through the MB beacon cue + GATT fetch path
([docs/BLE_BRIDGE.md] explains why direct extended-advert delivery
is empirically unreliable on current iOS).

For development & cross-platform integration testing, you can flip
the build to route `sendToPeer` through the full-MX path (envelope +
connectable `MobFetchGatt` responder). The same flag also enables
Android's scanner-side fetch coordinator: when Android observes an MB
beacon cue and then a connectable `MobFetchGatt` service advert, it
requests the matching envelope and emits the fetched payload as the
canonical `received_message` event. The flag has two equivalent inputs:

**Option A: `android/local.properties`** (persistent per-engineer):

```properties
mob.mx.send=true
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
> mob.mx.send=true is incompatible with the release build. …
```

To build a release, remove the line from `local.properties` (or
unset `MESHX_MX_SEND`) first.

## Android runtime opt-in: receive-side GATT fetch

Receive-side fetch resolution can also be enabled at runtime without
turning on full-MX sending. Launch the Android app with:

```bash
adb shell am start \
  -n dev.mob.mob/.MainActivity \
  --ez mob_ble_fetch_on_beacon true
```

For clean hardware captures, combine it with the BLE selftest and disable
the selftest sender:

```bash
adb shell am start \
  -n dev.mob.mob/.MainActivity \
  --ez mob_ble_selftest true \
  --ez mob_ble_selftest_send false \
  --ez mob_ble_fetch_on_beacon true
```

**New recommended path (post-Phase 2/3, default)**: use the `mob_ble_*` extras (forwarded by `MainActivity.kt` / `AppDelegate.m` to `MOB_BLE_*` envs consumed by `Mob.Node.App` + `Mob.Ble.SelfTest` / `Mob.Ble.*`). The `mob_ble` path (via `Mob.Ble.Bridge`) is active unless `MOB_BLE_TRANSPORT=0`.

```bash
adb shell am start \
  -n dev.mob.mob/.MainActivity \
  --ez mob_ble_selftest true \
  --es mob_ble_local_name "my-val-device" \
  --ez mob_ble_fetch_on_beacon true
# Opt-out to legacy (rare, for comparison):
#   --ez mob_ble_transport_0 true
```

The legacy `mob_ble_*` extras continue to work for backward compat (dual handling in MainActivity).

**Convenience launcher script** (preferred for evidence captures):

```bash
./scripts/launch_mob_ble_default_path.sh --serial <SERIAL> --selftest --local-name cutover-val --fetch-on-beacon
# Legacy comparison:
./scripts/launch_mob_ble_default_path.sh --serial <SERIAL> --legacy --selftest
```

See the script for full flags, evidence tips, and artifact layout (use `artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/cutover-manifest.json` + 5-step recipe for first post-cutover physical runs). iOS parity: `MOB_BLE_*` keys are also forwarded from launch opts in `AppDelegate.m` (DEBUG autoselftest uses the recommended path; full harness env passing via devicectl --environment or equivalent).

The legacy `mob_ble_*` extras continue to work for backward compat.

This installs only the scanner-side MB-cue / service-hash-cue ->
`MobFetchGatt` coordinator. It leaves the default `sendToPeer` path on
MB-only unless `MESHX_MX_SEND=true` or `mob.mx.send=true` is also used.

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

`MobBleNative.sendFullMxEnvelope/2` remains a Kotlin-only public
entry point that always uses the MX path regardless of the
`BuildConfig` flag. The instrumented `MXFullEnvelopeSmokeTest` calls
it directly so test coverage doesn't depend on how the build was
configured.

## CI

Post-migration, the `mix mob.patch_deps --check` gate is no longer
present (task and patches removed). Typical CI runs `mix format --check`,
`mix credo`, `mix test --no-start`, and `mix deps.get && mix compile`
(which now exercises the `:ios_swift_sources` + `:static_nifs` paths
directly). See `docs/upstream_mob_migration_checklist.md` §4 for the
full verification command list used in the migration PR.
