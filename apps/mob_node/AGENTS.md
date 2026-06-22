# Agent guide — MobNode (`apps/mob_node`)

Mobile MeshX app: Elixir UI on the device BEAM, Swift/CoreBluetooth via `:mob_ble_nif`.
Umbrella context: [`../../AGENTS.md`](../../AGENTS.md).

## User-visible flows (intended)

```text
Home
  ├─ Readiness banner (not_ready → radio_off → listening → ready)
  ├─ Your name (nickname) + Save
  ├─ Scan | Advertise  →  Start / Stop
  ├─ Open #general  |  All channels
  └─ Advanced: nearby inbox, events, ping

Two devices: one Advertise+Start, one Scan+Start, then both tap Open #general.
```

Readiness: `Mob.Node.MeshStatus.readiness/1` (session hint published by `Session`).  
Banner colors via `Mob.Node.MeshStatusBanner.colors_for/1`.

## BLE architecture (two paths — keep both in mind)

| Path | Entry | Purpose |
|------|--------|---------|
| **Session / Home** | `Mob.Node.BLE.Adapter` → `NativeBridge.IOS` | User scan/advertise; events as `Mob.Node.BLE.Adapter` / `NativeBridge` tuples; inbox ingestion |
| **Mesh transport** | `Mob.Node.BleTransport` → `Mob.Routing.BLE` + `Mob.Ble.MobileBridge` | Router `broadcast_packet`, inbound `{:mob_routing, :ble, {:frame, ...}}` |

**Boot order** (`Mob.Node.App.on_start/0`):

1. `BlePlatformConfig.apply_from_platform/2` — sets **both** `:ble_adapter` and `:native_bridge`
2. `BleTransport.start/0` — attaches `:ble` to `Mob.Runtime.Router`, `boot_native?: false`
3. `Mob.Screen.start_root(HomeScreen)` → `Session` uses `Adapter.configured()`

## Chat pipeline

```text
Send:
  ChatScreen → ChannelViewModel.send_text/2
    → Composer.build_packet/3
    → Router.broadcast_packet/2
    → Mob.Routing.BLE.broadcast_frame/2
    → native BLE (when transport attached)

Receive (host + device gossip):
  ReceivedMessage (session) → RouterIngress.forward_received_message/1
    → Router handle_info frame
    → ChannelViewModel {:mob_runtime, :packet, ...}
```

Default channel: `#general`. Channel id is on `%Packet{}`, not inside `MessageEnvelope`.

## Modules you will touch most

| Module | Responsibility |
|--------|----------------|
| `Mob.Node.App` | Boot, transport, navigation root |
| `Mob.Node.BlePlatformConfig` | Sync adapter env keys |
| `Mob.Node.BleTransport` | Start BLE + `Router.attach_transport` |
| `Mob.Node.Guardrails` | Pre-install / CI test runner |
| `Mob.Node.Session` | Home BLE state, inbox, bridge events |
| `Mob.Node.HomeScreen` | Scan/advertise/chat UI |
| `Mob.Node.Chat.RouterIngress` | BLE gossip → router packets |
| `Mob.Node.Chat.ChannelViewModel` | Per-channel messages + router subscribe |
| `Mob.Node.BLE.LocalInbox` | `product_snapshot/1` for UI (not full `snapshot/1` on device) |
| `Mob.Node.NativeBridge.IOS` | Thin NIF delegate |

## Build and deploy (iOS)

```bash
cd apps/mob_node
mix deps.get
mix mob.node.guardrails          # required before install
mix mob.node.deploy_device --device <udid>
mix mob.devices                  # list UDIDs
```

Build script: `ios/build_device_meshx.sh` (generated/used by deploy task).  
Env: `MOB_BLE_TRANSPORT=0` in launch opts only when explicitly testing legacy path.

Device logs: copy `Documents/beam_stdout.log` from app container.

## Tests — run before you claim “fixed on device”

From repo root:

```bash
mix test apps/mob_node/test/mob_node/production_wiring_test.exs \
         apps/mob_node/test/mob_node/chat/ \
         apps/mob_node/test/mob_node/mob_ble_transport_wiring_test.exs \
         apps/mob_node/test/mob_node/ble/adapter_test.exs
```

From `apps/mob_node`: `mix preinstall` or `mix mob.node.guardrails` (runs same from umbrella root).

When adding behavior, add tests here first — especially for new wiring between Session, Router, and Chat.

## Known pitfalls (regression magnets)

1. **Noop bridge** — `configure_native_bridge` without `:ble_adapter` → advertise/chat appear to work, nothing hits CoreBluetooth.
2. **No router attach** — `Mob.Routing.BLE.start_link` without `attach_transport` → send succeeds in VM, no radio.
3. **Wrong snapshot on mount** — full `LocalInbox.snapshot/1` on Home → crash (`invalid_private_key`, fixture signing).
4. **Trust policy order** — in `product_snapshot`, build `:trust_evidence` before `:trust_policy`.
5. **Missing `Mob.Ble.Diagnostics.Metrics`** — `MobileBridge` init fails; transport never starts.
6. **Status tuples** — legacy `{:status, _}` from NIF are not canonical; do not expect Home Events to show “Advertising as …” until v1 wire maps exist.

## UI / UX guidance for agents

- Keep Home copy actionable (mode → Start → Chat). Avoid adding more filter rows to Nearby when empty.
- Chat send errors: distinguish `:no_transports` vs other broadcast failures (`ChatScreen.send_error_message/1`).
- Do not add Phoenix/LiveView patterns; UI is `Mob.Screen` + `~MOB` templates.
- Avoid markdown/doc drive-by unless the user asks.

## Out of scope unless explicitly requested

- Whole-project BLE completion claims (AUX direct full-MX, upstream patch rows) — see `docs/remaining_items_audit.md`
- Android Mob chat UI parity (Android is largely lab/selftest)
- Encryption / DM / ack reconciliation — listed in `docs/chat_interface_mvp.md` follow-ups

## Related docs

- [`docs/chat_interface_mvp.md`](../../docs/chat_interface_mvp.md)
- [`docs/mob_ble_bridge_migration.md`](../../docs/mob_ble_bridge_migration.md)
- [`docs/BLE_BRIDGE.md`](../../docs/BLE_BRIDGE.md)