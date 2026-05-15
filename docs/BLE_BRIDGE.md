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
| Receive `%ReceivedMessageBeacon{}` (22-byte `MB` legacy beacon) | ✅ | ✅ | App bridge: `MeshxBLEClient.meshxDidObserveLegacyBeacon` → `meshx_ble_emit_received_message_beacon` → v1 atom-keyed map. Harness (post `fb5afa8`): `MessageAdvertisementObserver` falls through to `MeshxLegacyBeaconAdvertisement.parse` after MX decode declines, surfacing `meshxMessageObserverDidObserveLegacyBeacon`. Validated cross-platform on hardware (Android SM-T577U → iPhone 13, see `artifacts/local-ble/2026-05-15-iphone13-sm-t577u/`). |
| Receive `%ReceivedMessage{}` (full `MX` envelope, extended advertising) | ✅ | partial | Harness `MessageAdvertisementObserver` already decodes `MX` envelopes via `MessageAdvertisement.decode` and emits `ReceivedMessageEvent` to the delegate. iOS production bridge (`MeshxNativeBLEBridge`) does not yet run an equivalent promiscuous observer or emit a `meshx_ble_emit_received_message` NIF entry — see gap (2) below. |
| Dispatch send via legacy-beacon advertise | ✅ | ✅ | Android: `BleDispatcher.dispatch(payload, forceLegacyBeacon: true)` builds a `MeshxMessageEnvelope`, derives the beacon, advertises via manufacturer data. iOS: `MeshxBLEPeripheral.advertiseLegacyBeacon(messageId:senderPeerId:payloadKind:)` puts the 22-byte beacon on air via `CBAdvertisementDataManufacturerDataKey` with company id `0xFFFF`; bridge exposes this through `MeshxNativeBLEBridge.sendPing` fallback when no GATT peer is paired (commit `022b6f4`). Harness exercises the same path under `--meshx-auto-beacon`. Hardware-validated on iPhone 13 (commit `fb5afa8` evidence bundle). |
| Canonical `%BLE.Events.Error{kind, detail}` surface | ✅ | partial | Android emits typed `BleEvent.Error(kind = SCAN_FAILED/UNAUTHORIZED/BLUETOOTH_OFF/...)`. iOS emits legacy `{:error, string}` tuples — the kind taxonomy isn't enforced on the iOS path. |
| Adapter-state recovery (auto-replay intent) | ✅ | n/a | Android uses `BluetoothAdapter.ACTION_STATE_CHANGED` + intent replay. iOS BLE state restoration is a separate CoreBluetooth mechanism (`CBCentralManagerOptionRestoreIdentifierKey`); the equivalent is opt-in via `MeshxBLEClient`'s manager init options. |

### iOS parity gap — minimum work to close

Two of the three pieces originally called out here have landed and been
exercised on hardware. The remaining gap is the full-envelope (`MX`)
receive path on the production app bridge.

1. ~~**Advert-only send path.**~~ **Closed.**
   `MeshxBLEPeripheral.advertiseLegacyBeacon(messageId:senderPeerId:payloadKind:)`
   builds the 22-byte beacon and advertises via
   `CBAdvertisementDataManufacturerDataKey` with company id `0xFFFF`.
   `MeshxNativeBLEBridge.sendPing` falls back to this path when no
   GATT peer is paired, mirroring Android's
   `MeshxBleNative.sendToPeer(forceLegacyBeacon: true)`. Validated on
   iPhone 13 hardware in commit `fb5afa8`'s evidence bundle.
2. **Full-envelope (`MX` magic) advert decode on the central side.**
   Still open for the production bridge. The harness's
   `MessageAdvertisementObserver` already decodes `MX` envelopes and
   surfaces `ReceivedMessageEvent`, but `MeshxNativeBLEBridge` does
   not yet instantiate an equivalent promiscuous observer. Closing
   this means either (a) wiring `MessageAdvertisementObserver` into
   `MeshxNativeBLEBridge` and routing its `ReceivedMessageEvent`
   through a new `meshx_ble_emit_received_message` NIF entry, or
   (b) extending `MeshxBLEClient.didDiscover` to attempt
   `MessageAdvertisement.decode` symmetrically to the current MB
   legacy-beacon check. Either way the BEAM-side
   `BridgeProtocol.decode` already understands the resulting v1
   `received_message` map.
3. **v1 wire migration for the legacy tuples.** Still open. The iOS
   NIF still emits `{:status, _}`, `{:connected, _}`,
   `{:disconnected, _}`, `{:received, _, _}` legacy tuples.
   `BridgeProtocol.decode` accepts them for backward compatibility,
   but the long-term contract is v1; each legacy emitter should be
   migrated to its v1 wire-map counterpart (`device_discovered`,
   `connection_state_changed`, `received_message`) so both platforms
   produce the same shape.

Neither of the remaining items requires BEAM-side changes — the Elixir
decoder already accepts every shape both bridges produce, and
`CONTRACTS.md §11.1` defines what advert-only delivery means
independent of platform.

### Hardware proof of the advert-only path

The Android-only side has been exercised on two physical tablets
(SM-T577U / API 33 and SM-T390 / API 28) — bidirectional MeshX
message-reference exchange verified in commit `cd5b473` and archived
under `artifacts/local-ble/2026-05-12-sm-t577u-sm-t390/`.

The iOS leg landed 2026-05-15 (commit `fb5afa8`). Both iPhone dispatch
and Android → iPhone receive are validated on hardware:

* iPhone 13 (DairyPhoneDeaux, ECID `00008110-0006619A2132801E`, iOS
  26.4.2) dispatched 59 consecutive MB legacy beacons at a 1.5 s
  cadence via the harness's `--meshx-auto-beacon` driver.
* The same iPhone, scanning simultaneously, decoded MB legacy beacons
  from two Android peers in radio range — the USB-attached
  SM-T577U (`sender_peer_id_hash` `da6e7833…49`, matching the
  base64 `2m54M5Qylkk=` the Android side emits in
  `MeshxBleDispatch.legacy_beacon_advertising_started`) and an
  ambient Android peer (`f70806ed…cc`) — with byte-for-byte v1
  envelope/beacon/payload-kind match. ~10 callbacks/sec with
  `CBCentralManagerScanOptionAllowDuplicatesKey`.

Full logs and per-leg JSON summaries:
`artifacts/local-ble/2026-05-15-iphone13-sm-t577u/`.

iPhone → Android receive is **not** in scope of this bundle: the
shipping Android app's MeshX-level scanner was not running in the
capture (only `BleSelfTest` dispatch was active). Reliably starting
the Android scanner from the session-bring-up path is the remaining
work to close the loop in the other direction.
