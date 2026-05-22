# MeshxTransportBle

BLE transport boundary for MeshX.

`MeshxTransportBLE` is the **MeshX adapter layer** for any BLE bridge that
speaks the stable `{:ble_peer_up, ...}` / `{:ble_peer_down, ...}` /
`{:ble_frame, ...}` contract. It normalizes those into `{:meshx_transport, :ble, ...}`
events for the runtime.

## Bridge behaviours

- `MeshxTransportBLE.Bridge` — the MeshX-named behaviour definition (for
  custom/desktop bridges, BlueZ, etc.). This is a kept-in-sync copy of the
  canonical contract.
- `Mob.Ble.Bridge` — the **canonical authoritative behaviour** (owned by the
  `mob_ble` Hex package, no meshx_* runtime dependency). Mobile production
  code should prefer `Mob.Ble.MobileBridge` (returned by `Mob.Ble.bridge_module()`).

The callback signatures are identical; the adapter accepts modules declaring
either behaviour (or neither — it only does dynamic calls). See the CONTRACT
SYNC markers in both behaviour files and `docs/mob_ble_bridge_migration.md`
(Phase 1/2) for the split-ownership hygiene story.

Platform code (or `Mob.Ble.MobileBridge`) implements the bridge and sends:

```elixir
{:ble_peer_up, peer_id, metadata}
{:ble_peer_down, peer_id}
{:ble_frame, peer_id, frame}
```

The default `MeshxTransportBLE.NoopBridge` starts in desktop and test
environments but returns `{:error, :not_configured}` for sends. Linux systems
can use `MeshxTransportBLE.BluezBridge`, which supervises the bundled
`priv/bin/meshx_bluez_bridge` executable. That executable owns BlueZ D-Bus
scanning, advertising, GATT registration, ATT chunking, and native callbacks.

Mobile production integrations use the `mob_ble` plugin + `Mob.Ble.Bridge`
(see `MeshxMobileApp.App` and the wiring test for the exact integration).

See [../../docs/BLE_BRIDGE.md](../../docs/BLE_BRIDGE.md) for the full native
bridge contract, the recommended `mob` + `mob_ble` path, metadata expectations,
and test checklist.
