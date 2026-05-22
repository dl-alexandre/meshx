# Changelog

All notable changes to this project will be documented in this file.

## 0.2.0 (Unreleased / 2026-05-19)

### Added / Changed
- `mob_ble` plugin extraction + `Mob.Ble.Bridge` migration (Phases 1+2 complete):
  - Canonical BLE bridge behaviour + rich contract documentation now owned by
    the `mob_ble` Hex package (`Mob.Ble.Bridge`, `Mob.Ble.MobileBridge`).
  - `mob_ble` has zero runtime dependencies on any `meshx_*` package and is
    independently publishable on Hex (see its own `CHANGELOG.md` and
    `docs/mob_ble_bridge_migration.md`).
  - `MeshxTransportBLE.Bridge` is a CONTRACT-SYNC copy (for MeshX ecosystem
    compatibility only; no behaviour changes, no wire changes).
- `meshx_mobile_app` now defaults to the recommended `mob_ble` production path
  (via `MeshxTransportBLE` + `Mob.Ble.bridge_module()`) unless
  `MOB_BLE_TRANSPORT=0` (full legacy `NativeBridge` backward compat preserved).
  Added `Mob.Ble.SelfTest` wiring + primary integration test
  (`mob_ble_transport_wiring_test.exs`).
- Explicit `{:meshx_transport_ble, in_umbrella: true}` hygiene dep in
  `meshx_mobile_app/mix.exs` (required for direct references post-migration).
- Quick polish pass (5-10min): stale "Current Reality/Problems" table rows
  in `docs/mob_ble_bridge_migration.md` retired + rewritten as post-Phase-2
  snapshot (Hex now "Ready"); cosmetic/artifact hygiene in
  `apps/meshx_mobile_app/README.md` + status tables.
- On-device launch parity & validation prep: Android `MainActivity.kt` +
  iOS `AppDelegate.m` now forward full `MOB_BLE_*` (incl. `mob_ble_fetch_on_beacon`,
  transport string, local_name, selftest, transport_0); `scripts/launch_mob_ble_default_path.sh`
  updated + iOS notes; `CONTRIBUTING.md` refreshed with script + parity examples;
  DEBUG autoselftest alignment notes + forwarding in place.
- Phase 3 release coordination artifacts: root + `mob_ble` changelogs enhanced,
  full cutover announcement at `docs/releases/mob_ble_phase3_cutover_announcement.md`
  (with evidence templates, upstream notes), audit/checklist sync
  (`remaining_items_audit.md`, `upstream_mob_migration_checklist.md`, migration doc),
  pre-publish checklist + `mix hex.build` verification commands, on-device evidence
  collection template. `mob_ble` is publication-ready.
- Final "all that" closure (2026-05-19): stray markdown / status table hygiene in
  `apps/meshx_mobile_app/README.md`; stale "Current State" table + pending language
  retired in `docs/mob_ble_bridge_migration.md`; trimmed publication-grade release
  body (internal refs + formatting nits removed); final `mob_ble`-owned prose
  hygiene sweep (minimized "MeshX" prose while preserving CONTRACT SYNC identifiers
  + paths); `artifacts/local-ble/2026-05-19-mob-ble-cutover-XXX/` dir +
  `cutover-manifest.json` template + README with header + 5-step recipe; tiny
  launch script + CONTRIBUTING improvements; `mix hex.build` re-verified clean from
  `apps/mob_ble/`. All constraints satisfied; ready for `mix hex.publish` + first
  device runs.

### Migration Notes
- Pure `mob` users: `{:mob_ble, "~> 0.1"}` + `config :mob, :plugins, [:mob_ble]`
  is now sufficient and clean (no MeshX deps ever pulled).
- MeshX consumers: unchanged public API surface; see migration doc for
  recommended wiring in mobile apps.
- No breaking changes for any existing code, scripts, or hardware flows.

## 0.1.0 (Unreleased)

### Added
- Initial release of MeshX mesh networking stack
- `meshx_protocol` — compact binary framing, TTL, gossip, fragmentation
- `meshx_noise` — Noise XX session encryption via Decibel
- `meshx_store` — CubDB persistence, dedupe, relay cache, outbox
- `meshx_transport` — TCP, UDP, and in-memory transports
- `meshx_transport_ble` — BLE native bridge adapter
- `meshx_mob` — mobile platform context helpers
- `meshx_runtime` — top-level OTP application and coordinator
- v1 contracts, failure domains, workspace safety, and architecture documentation
