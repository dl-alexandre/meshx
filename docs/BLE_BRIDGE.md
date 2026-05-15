# BLE Native Bridge Guide

`meshx_transport_ble` is the supported integration path for platform BLE code.
The Elixir side owns normalization into MeshX transport events; platform code
owns BLE scanning, advertising, GATT, MTU, background behavior, and OS
callbacks.

The repo ships one production platform backend:

* `MeshxTransportBLE.BluezBridge` for Linux/BlueZ. It supervises
  `priv/bin/meshx_bluez_bridge`, which talks to BlueZ over D-Bus, registers the
  MeshX BLE GATT service, advertises the service UUID, scans for peers, writes
  frames to peer RX characteristics, and reassembles inbound ATT chunks.

CoreBluetooth and Android BLE deployments should implement the same bridge
behaviour in the mobile/native app layer.

## Elixir Adapter

Start the adapter with a bridge module:

```elixir
{:ok, ble} =
  MeshxTransportBLE.start_link(
    event_target: MeshxRuntime.Router,
    bridge: MyApp.NativeBLEBridge,
    bridge_opts: [
      service_uuid: "0000feed-0000-1000-8000-00805f9b34fb",
      platform: MeshxMob.Platform.new(os: :ios, permissions: [:bluetooth])
    ]
  )

:ok = MeshxRuntime.Router.attach_transport(:ble, MeshxTransportBLE, ble)
```

On Linux with BlueZ:

```elixir
{:ok, ble} =
  MeshxTransportBLE.start_link(
    event_target: MeshxRuntime.Router,
    bridge: MeshxTransportBLE.BluezBridge,
    bridge_opts: [
      adapter: "hci0",
      local_name: "meshx-relay-1",
      mtu: 185
    ]
  )
```

The BlueZ backend requires:

- Linux with BlueZ exposing `org.bluez` on the system D-Bus.
- Python 3 and the `dbus-next` package available to the bridge executable.
- Permission for the runtime user to access the Bluetooth adapter and register
  GATT/advertisement objects.

Before starting a production node, run the backend health check on the target
host:

```bash
python3 apps/meshx_transport_ble/priv/bin/meshx_bluez_bridge --adapter hci0 --health-check
```

Release code can run the same check through the Elixir bridge module:

```elixir
MeshxTransportBLE.BluezBridge.health_check(adapter: "hci0")
```

The command exits successfully only when the selected BlueZ adapter exposes
`Adapter1`, `GattManager1`, and `LEAdvertisingManager1`, which are required for
MeshX scanning, GATT service registration, and BLE advertising.

## Bridge Behaviour

Native bridge modules implement `MeshxTransportBLE.Bridge`:

```elixir
defmodule MyApp.NativeBLEBridge do
  @behaviour MeshxTransportBLE.Bridge

  use GenServer

  @impl true
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def send_frame(bridge, peer_id, frame, opts) do
    GenServer.call(bridge, {:send_frame, peer_id, frame, opts})
  end

  @impl true
  def broadcast_frame(bridge, frame, opts) do
    GenServer.call(bridge, {:broadcast_frame, frame, opts})
  end

  @impl true
  def init(opts) do
    event_target = Keyword.fetch!(opts, :event_target)
    # Start native BLE owner here and keep event_target for callbacks.
    {:ok, %{event_target: event_target}}
  end
end
```

The adapter adds `:event_target` to `bridge_opts`. The bridge uses that PID to
send callbacks back to `MeshxTransportBLE`.

## Required Callback Messages

When a peer appears:

```elixir
send(event_target, {:ble_peer_up, peer_id, metadata})
```

When a peer disappears:

```elixir
send(event_target, {:ble_peer_down, peer_id})
```

When a full MeshX frame arrives:

```elixir
send(event_target, {:ble_frame, peer_id, frame})
```

The adapter converts these to:

```elixir
{:meshx_transport, :ble, {:peer_up, peer}}
{:meshx_transport, :ble, {:peer_down, peer_id}}
{:meshx_transport, :ble, {:frame, peer_id, frame}}
```

## Metadata

Advertise transport and mobile constraints with `MeshxTransport.Capabilities`
and `MeshxMob.Platform`:

```elixir
metadata =
  %{}
  |> Map.merge(MeshxTransport.Capabilities.to_metadata(
    MeshxTransport.Capabilities.new(mtu: 185, relay: false, background_mode: :background)
  ))
  |> Map.merge(MeshxMob.Platform.to_metadata(
    MeshxMob.Platform.new(os: :ios, background_mode: :background, permissions: [:bluetooth])
  ))
```

Use the negotiated BLE ATT payload size as the advertised MTU. Router
fragmentation depends on this value.

## Native Responsibilities

A production bridge must own:

- Scanning and advertising lifecycle.
- GATT service/characteristic setup.
- Peer identity mapping from platform IDs to stable MeshX peer IDs.
- MTU negotiation and chunking at the BLE characteristic layer.
- Background mode constraints and reconnection policy.
- Delivery of complete MeshX frame binaries to the Elixir adapter.
- Explicit errors from `send_frame/4` and `broadcast_frame/3`.

`MeshxTransportBLE.BluezBridge` covers these responsibilities for Linux/BlueZ.
It uses the BLE peer's address as the default peer ID and includes `address`,
`path`, `name`, `rssi`, `mtu`, `service_uuid`, and `platform: "bluez"` in peer
metadata. The BlueZ bridge enables port command acknowledgements, so
`send_frame/4` and `broadcast_frame/3` return native write errors and command
timeouts instead of reporting success when BlueZ rejects a peer or
characteristic write.

## Test Checklist

Native bridge integrations should include tests for:

- Peer up/down callback normalization.
- Sending a frame to a connected peer.
- Broadcast behavior.
- MTU metadata propagation.
- Disconnect during send.
- Permission denied or Bluetooth disabled startup failures.
- Background mode transition behavior.
- Malformed native callback payloads.

`MeshxTransportBLE.NoopBridge` remains the desktop/test fallback. It starts the
adapter without native BLE and returns `{:error, :not_configured}` for sends so
misconfigured production systems fail explicitly.

## Platform Parity Matrix (Advert-Only Profile)

The mobile bridges live in two layers: the GATT/connection-oriented
path (Noise XX over a paired link) and the advert-only profile
(manufacturer-data references — `WIRE_FORMAT.md §10`, `CONTRACTS.md
§11.1`). Both Android and iOS host both layers, but the *advert-only*
surface they expose is asymmetric today.

| Capability | Android | iOS | Notes |
| --- | --- | --- | --- |
| `start_scan/1` returns `:ok` | ✅ | ✅ | NIF surface is identical (`src/meshx_ble_nif.erl`). |
| `start_advertising/2` returns `:ok` | ✅ | ✅ | Same NIF surface. |
| Receive `%DeviceDiscovered{}` | ✅ | ❌ | iOS emits legacy `{:connected, peer_id}` / `{:disconnected, peer_id}` tuples (GATT path) — there's no equivalent "I saw an ambient BLE device" event. Adding it means surfacing `CBCentralManager` discovery results into a `meshx_ble_emit_device_discovered` NIF entry. |
| Receive `%AdvertisementReceived{}` | ✅ | ❌ | Same reasoning as `DeviceDiscovered`. |
| Receive `%ReceivedMessageBeacon{}` (22-byte `MB` legacy beacon) | ✅ | ✅ | `MeshxBLEClient.meshxDidObserveLegacyBeacon` → `meshx_ble_emit_received_message_beacon` → v1 atom-keyed map. |
| Receive `%ReceivedMessage{}` (full `MX` envelope, extended advertising) | ✅ | ❌ | Android decodes via `MeshxMessageAdvertisement.decodeScanRecord`; iOS has no equivalent path on the central side. |
| Dispatch send via legacy-beacon advertise | ✅ | ❌ | Android: `BleDispatcher.dispatch(payload, forceLegacyBeacon: true)` builds a `MeshxMessageEnvelope`, derives the beacon, advertises via manufacturer data. iOS: `sendPing` only does GATT-connection writes (`client.send` / `peripheral.send`). For advert-only parity, iOS needs an equivalent that advertises the 22-byte beacon via `CBPeripheralManager` with `CBAdvertisementDataManufacturerDataKey` (company id `0xFFFF`). |
| Canonical `%BLE.Events.Error{kind, detail}` surface | ✅ | partial | Android emits typed `BleEvent.Error(kind = SCAN_FAILED/UNAUTHORIZED/BLUETOOTH_OFF/...)`. iOS emits legacy `{:error, string}` tuples — the kind taxonomy isn't enforced on the iOS path. |
| Adapter-state recovery (auto-replay intent) | ✅ | n/a | Android uses `BluetoothAdapter.ACTION_STATE_CHANGED` + intent replay. iOS BLE state restoration is a separate CoreBluetooth mechanism (`CBCentralManagerOptionRestoreIdentifierKey`); the equivalent is opt-in via `MeshxBLEClient`'s manager init options. |

### iOS parity gap — minimum work to close

Shipping the advert-only contract end to end on iOS requires three
pieces of native work that don't exist today:

1. **Advert-only send path.** A Swift component that takes a payload,
   builds a v1 `MeshxMessageEnvelope`, derives the 22-byte legacy
   beacon (the receive side's `MeshxLegacyBeaconAdvertisement` already
   defines the layout), and advertises via
   `CBAdvertisementDataManufacturerDataKey` with company id `0xFFFF`.
   `sendPing` then prefers the GATT path when a paired peer exists
   and falls back to the beacon dispatch otherwise — mirroring
   Android's `MeshxBleNative.sendToPeer(forceLegacyBeacon: true)`.
2. **Full-envelope (`MX` magic) advert decode on the central side.**
   Extended-advertising scans surface as `CBCentralManager` discovery
   results with a `kCBAdvDataManufacturerData` blob; parsing it to a
   `MeshxMessageEnvelope` and emitting a new
   `meshx_ble_emit_received_message` NIF entry gives iOS the same
   wire-shape coverage Android has today.
3. **v1 wire migration for the legacy tuples.** The iOS NIF still
   emits `{:status, _}`, `{:connected, _}`, `{:disconnected, _}`,
   `{:received, _, _}` legacy tuples. `BridgeProtocol.decode`
   accepts them for backward compatibility, but the long-term
   contract is v1; each legacy emitter should be migrated to its v1
   wire-map counterpart (`device_discovered`,
   `connection_state_changed`, `received_message`) so both platforms
   produce the same shape.

None of these require BEAM-side changes — the Elixir decoder already
accepts every shape both bridges produce, and `CONTRACTS.md §11.1`
defines what advert-only delivery means independent of platform.
Matching iOS to that contract is the remaining native work.

### Hardware proof of the advert-only path

The Android side has been exercised on two physical tablets
(SM-T577U / API 33 and SM-T390 / API 28) — bidirectional MeshX
message-reference exchange verified in commit `cd5b473`. iOS-side
hardware verification of the advert-only contract is the remaining
on-device deliverable; the matrix above is what an iOS bring-up
session must satisfy to claim parity.
