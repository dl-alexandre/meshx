# Agent guide — mob mesh (umbrella)

Instructions for AI coding agents and automation working in this repository.
Read this before changing runtime, mobile, or BLE wiring.

## Project

- **What:** BEAM-native mesh networking (`mob_runtime`, `mob_protocol`, transports).
- **Mobile app:** `apps/mob_node` — MobNode on iOS (Elixir on device + Swift BLE NIF).
- **Prefix:** Packages use `mob_*` (renamed from `meshx_*` in 2026-05). Do not reintroduce `meshx_*` module names in new code.

## Repo layout (umbrella)

| App | Role |
|-----|------|
| `mob_protocol` | Wire codec, packets, acks |
| `mob_runtime` | Router, outbox, sessions, `attach_transport/3` |
| `mob_routing_ble` | `Mob.Routing.BLE` adapter |
| `mob_ble` | Mobile BLE bridge (`Mob.Ble.MobileBridge`) |
| `mob_node` | MobNode UI (`Mob.Screen`), session, chat, iOS build |
| `mob_store` | Identity, DB, dedupe |

Deep mobile rules: [`apps/mob_node/AGENTS.md`](apps/mob_node/AGENTS.md).

## Mandatory checks before merge or device install

Run from **repo root** (umbrella), not only `apps/mob_node`:

```bash
mix mob.node.guardrails
```

Or from `apps/mob_node`: `mix preinstall` (alias for the same).

CI runs the same paths in `.github/workflows/ci.yml` under **MobNode mesh and chat wiring guardrails**.  
`mix mob.node.deploy_device` runs guardrails automatically after compile.

**Do not skip** these when touching: `Mob.Node.App`, `BleTransport`, `BlePlatformConfig`, `Session`, `ChannelViewModel`, `RouterIngress`, `BLE.Adapter`, or iOS deploy scripts.

Full suite: `mix test` from repo root.

## Production wiring contracts (do not break)

These failures were silent in production (UI looked fine, mesh/chat did nothing):

1. **`:ble_adapter` vs `:native_bridge`** — `Mob.Node.Session` uses `Mob.Node.BLE.Adapter.configured/0` (`:ble_adapter`). Setting only `:native_bridge` left the UI on `NativeBridge.Noop`. Always sync via `Mob.Node.BlePlatformConfig.put_ble_adapter/1` on iOS/Android when the NIF loads.

2. **Router transport** — Chat send uses `Mob.Runtime.Router.broadcast_packet/2`. BLE must be attached: `Mob.Node.BleTransport.start/0` → `Mob.Routing.BLE.start_link` + `Router.attach_transport(:ble, Mob.Routing.BLE, pid)` with `event_target: Mob.Runtime.Router`. Starting BLE without attach makes broadcast a no-op; empty transports now return `{:error, :no_transports}`.

3. **Inbound chat over BLE gossip** — Passive adverts arrive as `Mob.Node.BLE.Events.ReceivedMessage` on the session bridge. Forward CHAT envelopes through `Mob.Node.Chat.RouterIngress` into the router (default channel `#general`) so `ChannelViewModel` subscribers receive `{:mob_runtime, :packet, ...}`.

4. **NIF owner** — Only one `:mob_ble_nif` owner. `MobileBridge` uses `boot_native?: false` so Home **Session** owns scan/advertise toggles. Do not auto-start scan+advertise in bridge `init` without that flag.

5. **Home UI snapshot** — Use `LocalInbox.product_snapshot/1` on device, not full `LocalInbox.snapshot/1` (audit/crypto fixtures crash on device OTP).

## Common agent tasks

| Task | Command / location |
|------|-------------------|
| Guardrails only | `mix mob.node.guardrails` |
| Deploy iPhone | `cd apps/mob_node && mix mob.node.deploy_device --device <udid>` |
| List devices | `cd apps/mob_node && mix mob.devices` |
| Chat MVP doc | `docs/chat_interface_mvp.md` |
| BLE bridge | `docs/BLE_BRIDGE.md`, `docs/mob_ble_bridge_migration.md` |
| Remaining BLE gaps | `docs/remaining_items_audit.md` |

## Testing map (mob_node integration)

| Concern | Test path |
|---------|-----------|
| Adapter env sync | `apps/mob_node/test/mob_node/ble/adapter_test.exs` |
| BLE transport + router | `apps/mob_node/test/mob_node/mob_ble_transport_wiring_test.exs` |
| Production contracts | `apps/mob_node/test/mob_node/production_wiring_test.exs` |
| Chat mesh E2E (host) | `apps/mob_node/test/mob_node/chat/chat_mesh_integration_test.exs` |
| BLE → router ingress | `apps/mob_node/test/mob_node/chat/router_ingress_test.exs` |
| Chat units | `apps/mob_node/test/mob_node/chat/` |
| TCP chat E2E | `apps/mob_node/test/mob_node/chat/chat_e2e_tcp_test.exs` |
| CI workflow strings | `apps/mob_node/test/mix/tasks/mob_node_release_ci_test.exs` |

Add or extend tests in these files when changing wiring — do not rely on device-only manual checks.

## Code style for agents

- Match existing module style; minimal diffs; no drive-by refactors.
- Prefer extending `BleTransport`, `BlePlatformConfig`, `Guardrails` rather than duplicating logic in `App`.
- Elixir/Phoenix plugin skills under user config apply when editing Phoenix apps; this umbrella is primarily OTP + `Mob.Screen`, not Phoenix LiveView.
- Never claim whole-project BLE completion; see audit docs for AUX/upstream boundaries.

## When stuck on device

1. Pull `Documents/beam_stdout.log` from the app container after reproduce.
2. Confirm log shows `mob_ble transport up` and `step 5 => {ok,...}` (not GenServer crash on Home mount).
3. Confirm user flow: **Advertise + Start Advertising** on one device, **Scan + Start Scanning** on the other, then **Chat → #general**.

## Doc index

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — system overview  
- [`docs/BLE_BRIDGE.md`](docs/BLE_BRIDGE.md) — BLE wire and iOS limits  
- [`docs/chat_interface_mvp.md`](docs/chat_interface_mvp.md) — chat UI and send/receive path  
- [`docs/RELEASE.md`](docs/RELEASE.md) — release and CI manifests  
- [`apps/mob_node/AGENTS.md`](apps/mob_node/AGENTS.md) — MobNode-specific agent rules