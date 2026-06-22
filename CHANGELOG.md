# Changelog

All notable changes to this project will be documented in this file.

## 0.3.0 (2026-06-22)

### Added — group/channel chat encryption (Sender Keys)

`mob_noise`, `mob_store`, and `mob_runtime` bump to `0.3.0`.

- `mob_noise`: Signal-style Sender Keys stack — `Mob.Noise.SenderKey` (HMAC
  ratchet), `Mob.Noise.GroupCipher` (ChaCha20-Poly1305), `Mob.Noise.GroupSession`
  (per-sender receiving chains, skipped-key cache, replay rejection), and
  `Mob.Noise.SenderKeyDistribution` (40-byte SKDM wire format).
- `mob_store`: `Mob.Store.GroupKeys` — per-channel group-session persistence
  over CubDB.
- `mob_runtime`: `GroupKeyManager` (single-writer GenServer for
  ensure/encrypt/install/decrypt) and `GroupKeyControl` (MXG1 distribution /
  MXGR request codec), wired into the supervision tree.

Threat model: group chat is confidential to current key-holders with forward
secrecy via the one-way ratchet; there is no enforced member removal, and
symmetric sender keys permit a key-holder to forge as another member
(per-message signatures / SKDM v2 would close this). Automatic key distribution
over live Router/BLE is not yet wired — the crypto engine and on-demand SKDM
request/reply are complete and unit-tested. See `apps/mob_noise/README.md`.

## 0.2.0 (2026-05-31)

### Breaking — umbrella package rename

The entire `meshx_*` umbrella was renamed to `mob_*` to unify with the
`mob` framework + plugin ecosystem (`mob_ble`, `mob_cellular`, `mob_mesh`,
`mob_transport`, `mob_wifi`). Renamings:

| Old | New |
|---|---|
| `meshx_protocol` / `MeshxProtocol.*` | `mob_protocol` / `Mob.Protocol.*` |
| `meshx_runtime` / `MeshxRuntime.*` | `mob_runtime` / `Mob.Runtime.*` |
| `meshx_store` / `MeshxStore.*` | `mob_store` / `Mob.Store.*` |
| `meshx_noise` / `MeshxNoise.*` | `mob_noise` / `Mob.Noise.*` |
| `meshx_mobile_app` / `MeshxMobileApp.*` | `mob_node` / `Mob.Node.*` |
| `meshx_transport` / `MeshxTransport.*` | `mob_routing` / `Mob.Routing.*` |
| `meshx_transport_ble` / `MeshxTransportBLE.*` | `mob_routing_ble` / `Mob.Routing.BLE.*` |
| `meshx_mob` | absorbed into `mob_node` |
| `Mix.Tasks.Meshx.Mobile.*` / `mix meshx.mobile.X` | `Mix.Tasks.Mob.Node.*` / `mix mob.node.X` |

Wire format is unchanged. Captured BLE advertisements with `meshx-X` local
names remain parseable — `Mob.Node.BLE.Identity` accepts both `mob-` and
`meshx-` prefixes for backward compat with imaged devices.

iOS-specific names still pending follow-up: `apps/mob_node/src/meshx_ble_nif.erl`
keeps its old name (C function `meshx_ble_nif_nif_init` in the iOS driver
table requires it); the standalone `meshx_mobile/` Swift package is a separate
SPM project not yet renamed.

### Added

- **Chat MVP** (`Mob.Node.Chat.*`, `Mob.Node.ChatScreen`, `Mob.Node.ChannelsScreen`):
  Identity overlay with nickname, channel-scoped message composer, per-channel
  ViewModel (subscribed via `MeshxRuntime.Router` channel filter), screen
  surface, and `Mob.Socket.push_screen` nav wiring from `HomeScreen`. 34
  unit tests, full CI green. See `docs/chat_interface_mvp.md`.

- **RT-01 receive-pipeline fix** (`apps/mob_node/lib/mob_node/app.ex`,
  `ble_self_test.ex`): `MeshxTransportBLE` now wires `BleSelfTest` as its
  outer `event_target` when `MESHX_BLE_SELFTEST` is set; `BleSelfTest`
  parses inbound `{:meshx_transport, :ble, {:frame, …}}` envelopes,
  constructs `%ReceivedMessage{}`, and calls `Observability.record/1`.
  Closes the gap that left every prior RT-01 verdict structurally
  inconclusive. See `docs/rt01_locked_receive_fix_levers.md` post-mortem.

### Added / Changed
- `mob_ble` plugin extraction + `Mob.Ble.Bridge` migration (Phases 1+2 complete):
  - Canonical BLE bridge behaviour + rich contract documentation now owned by
    the `mob_ble` Hex package (`Mob.Ble.Bridge`, `Mob.Ble.MobileBridge`).
  - `mob_ble` has zero runtime dependencies on any `mob_*` package and is
    independently publishable on Hex (see its own `CHANGELOG.md` and
    `docs/mob_ble_bridge_migration.md`).
  - `Mob.Routing.BLE.Bridge` is a CONTRACT-SYNC copy (for MeshX ecosystem
    compatibility only; no behaviour changes, no wire changes).
- `mob_node` now defaults to the recommended `mob_ble` production path
  (via `Mob.Routing.BLE` + `Mob.Ble.bridge_module()`) unless
  `MOB_BLE_TRANSPORT=0` (full legacy `NativeBridge` backward compat preserved).
  Added `Mob.Ble.SelfTest` wiring + primary integration test
  (`mob_ble_transport_wiring_test.exs`).
- Explicit `{:mob_routing_ble, in_umbrella: true}` hygiene dep in
  `mob_node/mix.exs` (required for direct references post-migration).
- Quick polish pass (5-10min): stale "Current Reality/Problems" table rows
  in `docs/mob_ble_bridge_migration.md` retired + rewritten as post-Phase-2
  snapshot (Hex now "Ready"); cosmetic/artifact hygiene in
  `apps/mob_node/README.md` + status tables.
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
  `apps/mob_node/README.md`; stale "Current State" table + pending language
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
- `mob_protocol` — compact binary framing, TTL, gossip, fragmentation
- `mob_noise` — Noise XX session encryption via Decibel
- `mob_store` — CubDB persistence, dedupe, relay cache, outbox
- `mob_routing` — TCP, UDP, and in-memory transports
- `mob_routing_ble` — BLE native bridge adapter
- `mob_node` — mobile platform context helpers
- `mob_runtime` — top-level OTP application and coordinator
- v1 contracts, failure domains, workspace safety, and architecture documentation
