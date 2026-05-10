# MeshxTransportBle

BLE transport boundary for MeshX.

`MeshxTransportBLE` is an adapter around a native/mobile BLE bridge. Platform
code implements `MeshxTransportBLE.Bridge` and sends normalized bridge messages
back to the Elixir process:

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

Mobile integrations can still provide their own bridge modules for
CoreBluetooth or Android BLE when those platforms are the deployment target.

See [../../docs/BLE_BRIDGE.md](../../docs/BLE_BRIDGE.md) for the native bridge
implementation contract, metadata expectations, and test checklist.
