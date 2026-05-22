# `mob_ble` v0.1.0 Cutover Announcement

**Date**: 2026-05-19  
**Audience**: `mob` framework users, MeshX maintainers, GenericJam upstream, on-device validation teams  
**Status**: Publication-ready for GitHub release notes, blog post, or Hex release body

---

## Summary

`mob_ble` 0.1.0 is now the **canonical, self-contained BLE transport plugin** for the `mob` ecosystem.

After completion of the `Mob.Ble.Bridge` behaviour migration (Phases 1+2), the package:

- Owns the authoritative `Mob.Ble.Bridge` behaviour definition and the production `MobileBridge` implementation.
- Has **zero runtime dependencies** on any `meshx_*` package.
- Is ready for independent publication to Hex.pm.
- Is the **default production BLE path** inside `meshx_mobile_app` (with zero-breakage opt-out for legacy users).

Pure `mob + mob_ble` applications no longer transitively pull MeshX packages for mobile BLE.

---

## What Changed (for `mob` users)

```elixir
# Recommended (clean)
def deps do
  [
    {:mob, "~> 0.5"},
    {:mob_ble, "~> 0.1"}
  ]
end

# config/config.exs
config :mob, :plugins, [:mob_ble]
config :mob_ble, config: [evidence_mode: :production]

# in your Mob.App on_start (or equivalent)
{:ok, _} = MeshxTransportBLE.start_link(   # still the adapter name for now
  bridge: Mob.Ble.bridge_module(),
  bridge_opts: [local_name: "my-cool-device"]
)
```

(See `mob_ble` README and `Mob.Ble.Bridge` moduledoc for the exact 3-callback contract and inbound event tuples.)

The native Android/iOS BLE sources, MB legacy + GATT fetch carrier, carrier validation, plugin manifest, and NIF ownership all live inside the published `mob_ble` package.

---

## For Existing MeshX Users / `meshx_mobile_app`

- **No action required**. The new path is already the default.
- Your existing launches, intents (`meshx_ble_selftest` etc.), and CI continue to work via the legacy opt-out (`MOB_BLE_TRANSPORT=0`).
- Recommended: migrate your Android launch scripts / test harnesses to the new `mob_ble_*` extras for future-proofing (see "On-Device Validation" below).
- The wiring test and `MeshxMobileApp.App` docs were updated.

Full compatibility story and CONTRACT SYNC details: `docs/mob_ble_bridge_migration.md`.

---

## Release Coordination with Upstream (`mob` / `mob_dev`)

- This release of `mob_ble` is **independent** of the ongoing `mob_dev#6` / `mob_new#5` patch migration (those are about removing the downstream patches for Swift sources + static NIF table registration inside the umbrella).
- The `mob_ble` plugin already vendors its own native sources + uses the current patch-applied `mob_dev` build for iOS harness generation.
- The follow-up MeshX upstream patch migration PR (post GenericJam merges) has landed: bumped to mob 0.6.18 / mob_dev 0.5.11, removed patches + task + aliases, added upstream config to mob.exs, flipped audit row, docs reconciled (see `docs/upstream_mob_migration_checklist.md`).
- No coordinated version bump of `mob` itself is required for `mob_ble` 0.1.0 to be useful.
- Recommended upstream comms: tag the GenericJam maintainers on the `mob_ble` Hex release PR / announcement with a pointer to this cutover note and the migration strategy doc.

See also: `docs/upstream_mob_migration_checklist.md` (already updated with post-Phase-2 `mob_ble` status).

---

## On-Device Validation Commands (new default path)

### Android (T390 / R52 etc.)

Awake preflight (T390 API 28):

```sh
adb -s <SERIAL> shell input keyevent WAKEUP
adb -s <SERIAL> shell svc power stayon true
```

Launch with recommended `mob_ble` path + self-test (default path is already active; these extras enable the probe + custom name):

```sh
adb shell am start \
  -n dev.meshx.mob/.MainActivity \
  --ez mob_ble_selftest true \
  --es mob_ble_local_name "meshx-t390-val" \
  --ez mob_ble_fetch_on_beacon true   # preferred (MOB_BLE_*); legacy meshx_ alias still supported for transition
```

Legacy opt-out (for comparison runs):

```sh
adb shell am start \
  -n dev.meshx.mob/.MainActivity \
  --ez mob_ble_transport_0 true \   # or MOB_BLE_TRANSPORT=0 via other means
  --ez meshx_ble_selftest true
```

Capture with existing harnesses (the new path emits identical canonical events):

```sh
./scripts/capture-hybrid-run.sh --serial <SERIAL> ...
# or the two-device M26 verifier (it is transport-agnostic at the event layer)
```

See the `artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/` bundle (with `cutover-manifest.json` template and copy-paste 5-step recipe) for fresh post-cutover evidence layout.

### iPhone / iPad (via devicectl or mix mob)

For DEBUG harness builds (`mix mob.deploy --native`):

- The iOS `AppDelegate.m` now prefers `MOB_BLE_SELFTEST` in the DEBUG auto-start block (avoids NIF contention; matches the recommended path).
- To force legacy on a dev build: set the old env before beam start (advanced).

For physical device provision + deploy:

```sh
mix mob.provision
mix mob.devices
mix meshx.mobile.deploy_device --device <UDID>
# Then use devicectl or the harness to pass launch args if the template supports
# (current harness uses the DEBUG auto-selftest which now exercises mob_ble path)
```

See `docs/ble-t390-validation-notes.md`, `docs/android_ble_validation.md`, and `scripts/verify-t390-gatt-capture.sh` for full capture recipes. The new default does not change the air protocol or event shapes.

---

## Evidence Collection (post-cutover)

Use the prepared bundle layout:

```
artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/
├── cutover-manifest.json   # (template with versions, device info, git rev, mix.lock snapshot)
├── README.md               # header + 5-step copy-paste recipe
├── android/                # adb logs, instrumentation
├── ios/                    # devicectl / log captures
└── evidence/               # verifier summaries, adb-*.txt, host-*.txt
```

**Template header** (include in every summary.md / cutover-manifest.json sidecar):

```
mob_ble_path: default (MOB_BLE_TRANSPORT unset or !=0)
mob_ble_selftest: 1
bridge: Mob.Ble.MobileBridge (via Mob.Ble.bridge_module())
event_source: Mob.Ble.Internal.BridgeProtocol + native emitters
meshx_transport_ble_version: (from mix.lock)
mob_ble_version: 0.1.0 (or the published tar)
legacy_opt_out_used: false
capture_date: $(date -Iseconds)
device_pair: <model1> <serial1> <-> <model2> <serial2>
notes: "First post-Phase-3 cutover validation of the canonical mob_ble path"
```

The full 5-step recipe + launch script examples live in the bundle's `README.md` and `scripts/launch_mob_ble_default_path.sh`. All prior M14/M23/M26/M27 evidence remains valid (identical events on the wire).

---

## Publication

From a clean checkout:

```sh
cd apps/mob_ble
mix deps.get
mix compile
mix hex.build   # verify exit 0 + inspect tarball (file list, metadata, no meshx_* runtime deps)
mix hex.publish # (or with --yes after review)
```

Pre-publish checklist (run from `apps/mob_ble/`):
- `mix test` passes cleanly
- `mix hex.build` succeeds; `tar tf` the .tar shows expected sources + no stray meshx_* runtime entries in mix.exs
- Verify `mix.exs` version, description, files list, and links

**Post-publish**:
- Update `docs/remaining_items_audit.md` (mob_ble extraction row)
- Git tag + GitHub release (attach this body)
- Announce on relevant issues / GenericJam channels
- (Optional) pin `~> 0.1.0` example in consumer READMEs on next consumer release

---

## Rollback & Compatibility Notes

- Full backward compat: set `MOB_BLE_TRANSPORT=0` (or equivalent intent) to force the legacy `NativeBridge` path at any time. Zero behaviour or wire changes.
- The only cross-package note for MeshX consumers: explicit `meshx_transport_ble` dep remains inside `meshx_mobile_app` (required only for direct module references in App + tests; fully documented).
- Upstream patch migration (mob_dev#6 + mob_new#5) completed in follow-up PR tracked in `docs/upstream_mob_migration_checklist.md` (independent of this `mob_ble` 0.1.0 release).

---

**References**: `docs/mob_ble_bridge_migration.md`, `apps/mob_ble/README.md` + `Mob.Ble.Bridge` moduledoc, root `CHANGELOG.md`.

Ready for `mix hex.publish` + first device validation runs under the canonical path.
