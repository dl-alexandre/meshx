# BLE Native Bridge Guide

> **Production mobile path (recommended).** Depend on `mob_ble` and use
> `Mob.Ble.Bridge` / `Mob.Ble.MobileBridge` (canonical behaviour owned by
> the `mob_ble` Hex package). See the `mob_ble` README, `Mob.Ble` moduledoc,
> and `Mob.Ble.Bridge` moduledoc for the full contract, carrier policy,
> and plugin activation.
>
> The `MeshxTransportBLE.Bridge` behaviour documented below is the
> equivalent contract for the MeshX transport adapter and for writing
> custom (e.g. desktop BlueZ) bridges. It is kept in sync with `Mob.Ble.Bridge`
> (see CONTRACT SYNC markers in both behaviour files and
> `docs/mob_ble_bridge_migration.md`).
>
> Quick wire from a Mob app (using the canonical mobile implementation):
>
> ```elixir
> # config
> config :mob, :plugins, [:mob_ble]
> config :mob_ble, config: [evidence_mode: :production]
>
> # at boot (see MeshxMobileApp.App.maybe_start_mob_ble_transport/0)
> {:ok, _} =
>   MeshxTransportBLE.start_link(
>     bridge: Mob.Ble.bridge_module(),
>     bridge_opts: [local_name: "my-device"]
>   )
> ```
>
> Carrier policy is opaque: only `:mb_gatt` is accepted; anything else
> raises `Mob.Ble.CarrierRejectedError` at `start_link`. See
> `Mob.Ble.Diagnostics.rejected_carriers/0` for the evidence trail.
>
> > The rest of this document describes the `MeshxTransportBLE` adapter
> > and `MeshxTransportBLE.Bridge` contract in detail. Read it when writing
> > a *different* native backend (e.g. desktop BlueZ) or debugging a
> > custom MeshX transport — not when integrating BLE into a pure `mob`
> > mobile app.

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
| Receive `%ReceivedMessage{}` (full `MX` envelope, extended advertising) | ✅ | iOS bridge present; PHY-blocked | Bridge integration done end-to-end: `MeshxNativeBLEBridge` instantiates `MessageAdvertisementObserver`, `meshxDidObserveReceivedMessage` calls `meshx_ble_emit_received_message`, NIF emits the v1 `received_message` map, `BridgeProtocol.decode/1` parses the envelope. `dev.meshx.mob-central-…` confirmed registered with `bluetoothd` on hardware. **However:** iPhone 13 / iOS 26.4 and iPad12,1 / iPadOS 26.5 do not deliver non-Apple extended-advertising (AUX_ADV_IND) packets to `CBCentralManager.didDiscover`, regardless of `withServices` filter, `AllowDuplicates`, or whether Android puts the data in scan-response or primary AUX. Hardware evidence includes the 2026-05-15 iPhone 13 run and the 2026-05-17 SM-T577U -> iPad12,1 probe in `artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/`: Android emitted an 80-byte `MX` scan-response advert, while iOS logged MB beacons but zero direct `received_message` / `FF FF 4D 58` callback evidence. This is an iOS CoreBluetooth API limitation, not a bridge defect. Full MX envelopes on iOS arrive via the existing MB legacy-beacon + GATT-fetch path. |
| Dispatch send via legacy-beacon advertise | ✅ | ✅ | Android: `BleDispatcher.dispatch(payload, forceLegacyBeacon: true)` builds a `MeshxMessageEnvelope`, derives the beacon, advertises via manufacturer data. iOS: `MeshxBLEPeripheral.advertiseLegacyBeacon(messageId:senderPeerId:payloadKind:)` puts the 22-byte beacon on air via `CBAdvertisementDataManufacturerDataKey` with company id `0xFFFF`; bridge exposes this through `MeshxNativeBLEBridge.sendPing` fallback when no GATT peer is paired (commit `022b6f4`). Harness exercises the same path under `--meshx-auto-beacon`. Hardware-validated on iPhone 13 (commit `fb5afa8` evidence bundle). |
| Canonical `%BLE.Events.Error{kind, detail}` surface | ✅ | partial | Android emits typed `BleEvent.Error(kind = SCAN_FAILED/UNAUTHORIZED/BLUETOOTH_OFF/...)`. iOS emits legacy `{:error, string}` tuples — the kind taxonomy isn't enforced on the iOS path. |
| Adapter-state recovery (auto-replay intent) | ✅ | n/a | Android uses `BluetoothAdapter.ACTION_STATE_CHANGED` + intent replay. iOS BLE state restoration is a separate CoreBluetooth mechanism (`CBCentralManagerOptionRestoreIdentifierKey`); the equivalent is opt-in via `MeshxBLEClient`'s manager init options. |

### iOS parity gap — minimum work to close

The two advert-only delivery paths (send + full-envelope receive) have
both landed in the production bridge. The remaining gap is the v1 wire
migration for the legacy event tuples.

1. ~~**Advert-only send path.**~~ **Closed.**
   `MeshxBLEPeripheral.advertiseLegacyBeacon(messageId:senderPeerId:payloadKind:)`
   builds the 22-byte beacon and advertises via
   `CBAdvertisementDataManufacturerDataKey` with company id `0xFFFF`.
   `MeshxNativeBLEBridge.sendPing` falls back to this path when no
   GATT peer is paired, mirroring Android's
   `MeshxBleNative.sendToPeer(forceLegacyBeacon: true)`. Validated on
   iPhone 13 hardware in commit `fb5afa8`'s evidence bundle.
2. **Full-envelope (`MX` magic) advert decode on the central side.**
   **Wired, PHY-blocked on tested iOS hardware.** `MeshxNativeBLEBridge`
   now owns a `MessageAdvertisementObserver` alongside `MeshxBLEClient`,
   started/stopped on the same lifecycle. Its
   `meshxDidObserveReceivedMessage` callback forwards the
   `ReceivedMessageEvent` through the new
   `meshx_ble_emit_received_message` NIF entry, which builds the v1
   `received_message` map (envelope as raw `MX` bytes; BEAM-side
   `MessageEnvelope.parse/1` does the structural decode via
   `BridgeProtocol.decode_envelope/1`). Hardware runs on iPhone 13 and
   iPad12,1 did not deliver non-Apple AUX_ADV_IND manufacturer data to
   CoreBluetooth, so full envelopes on iOS use the MB legacy-beacon + GATT
   fetch path instead.
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

### iOS production receive capabilities (end of 2026-05-15 session)

| Receive mechanism | Status | Notes |
|---|---|---|
| MB legacy beacon (22 byte) | ✅ Working | `MessageAdvertisementObserver` decodes via `MeshxLegacyBeaconAdvertisement.parse`; emits `received_message_beacon` v1 map through `meshx_ble_emit_received_message_beacon`. Hardware proof: commit `fb5afa8` evidence bundle (iPhone 13). |
| Full MX envelope receive (advert direct) | ⚠ Wired, PHY-blocked on iOS | All Swift + NIF + Elixir pieces ship in the production binary (`_meshx_ble_nif_nif_init` registered in `erts_static_nif_tab`, MeshxNativeBLEBridge hosts `MessageAdvertisementObserver`, `meshx_ble_emit_received_message` emits to the bridge). However iOS 26.4 / iPhone 13 + iPad12,1 / Broadcom BCM4387 does not deliver AUX_ADV_IND data from non-Apple `AdvertisingSet` broadcasts to `CBCentralManager.didDiscover`, regardless of scan filter or advertising-set parameter tuning. See "Extended-advertising AUX delivery limitation" below. |
| MB beacon → GATT fetch | ✅ Working | New in this session. `MessageAdvertisementObserver.rememberBeacon` caches recent MB beacons by `messageIdHash`; when a connectable advert for the MeshX fetch service UUID arrives (from a different private random address per Android `AdvertisingSet` semantics), `maybeStartFetchOnFetchService` instantiates `MeshxFetchGattClient`, which performs the MFQ Request / MFR Response cycle and synthesizes a `ReceivedMessageEvent` with `transport: "ble_ios_gatt_fetch"`. Hardware-validated on iPad12,1 ↔ Samsung SM-T577U: bluetoothd shows `Le topology – role: central, state: CONNECTED` to the fetch responder's MAC; Android responder logs `fetch_request_received {status: ok}` for the matched hash; iPad disconnects immediately after the read response (visible in bluetoothd) — the only path that triggers `central.cancelPeripheralConnection` in `MeshxFetchGattClient.finish(envelope:)`. |

### Android `MeshxBleNative` send surface

The Android side exposes two distinct send paths:

| Method | Use case | Wire shape |
|---|---|---|
| `sendToPeer(peerId, payload)` | Production / fleet-safe default. JNI-callable. | 22-byte MB legacy beacon (primary-channel manufacturer data). Every device in the fleet — including API 28 hardware that cannot scan extended advertising — can both send and receive it. |
| `sendFullMxEnvelope(peerId, payload)` | Dev/test opt-in. Kotlin-only (not on JNI surface yet). Exercised by `MXFullEnvelopeSmokeTest`. | Starts a `MeshxFetchGatt` responder serving the full envelope + dispatches an MB legacy beacon as the cue. iOS peers running the matching `MessageAdvertisementObserver` + fetch-client see the beacon → connect to the responder → pull the full envelope via the MFQ/MFR GATT protocol. |

Pair `sendFullMxEnvelope/2` with `stopFullMxResponder/0` to tear down
the GATT server when done; sending again before stopping replaces the
previously-served envelope.

When the BEAM transport policy is ready to direct individual messages
through the full-MX path, lift `sendFullMxEnvelope` to a JNI method and
add a matching NIF entry point (`meshx_ble_send_full_mx_envelope`).
Until then, the JNI surface stays MB-only for backwards compatibility.

### Build system note: vendored-dep patches (historical)

These iOS additions (MeshxMobile Swift protocol sources + `meshx_ble_nif` /
`mob_ble_nif` static NIF registration) were previously carried as downstream
patches applied by `mix meshx.patch_deps` (wired into `deps.*` aliases).

Post-`GenericJam/mob_dev#6` + `mob_new#5` migration, use the official upstream
keys in `apps/meshx_mobile_app/mob.exs` under `config :mob_dev`:

- `:ios_swift_sources` (the 14 project `.swift` paths)
- `:static_nifs` (for `:mob_ble_nif`, etc.)

See `docs/upstream_mob_migration_checklist.md` for the removal of the patches,
task, and aliases, plus verification steps. Historical patch diffs and the
prior version of this note remain in git.

### Extended-advertising AUX delivery limitation

Empirically determined across three Android advertising configurations and two iOS scan-options configurations, on iPhone 13 / iOS 26.4 and iPad (9th generation) / iPadOS 26.4:

| Android advertising mode | iOS scan filter | Result |
|---|---|---|
| `setLegacyMode(false)` + data in `setScanResponseData` | `withServices: nil` | bluetoothd never logs MX manufacturer data (`FF FF 4D 58`) |
| `setLegacyMode(false)` + data in `setAdvertisingData` (primary AUX_ADV_IND) | `withServices: nil` | No MX delivery |
| Same as above | `withServices: [MeshxBLEUUID.service]` | No MX delivery |

In all three cases the iPhone's BLE controller continued to deliver `FF FF 4D 42` (MB legacy beacons, primary advertising channels) reliably — proving radio link and scan engine are working. No `CBCentralManagerScanOption*` or `AdvertisingSetParameters` tuning surfaced AUX_ADV_IND data to `didDiscover`. This is an iOS CoreBluetooth API limitation, not a defect in the bridge.

A fresh 2026-05-17 probe repeated the most relevant scan-response case with
SM-T577U Android 13/API 33 as sender and iPad12,1 iPadOS 26.5 as observer.
`IOSAuxFullMxAdvertSmokeTest` emitted an 80-byte full-MX envelope through a
scannable, non-connectable extended advertising set with
`data_carrier="scan_response"`. Android instrumentation passed and logcat
recorded `advertising_set_started`, but the iOS harness log recorded zero
direct full-MX `received_message`, zero decode-error, and zero
candidate/discovery callback lines for the AUX payload while still recording
276 MB legacy-beacon receives. Artifact:
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md`.

The iOS harness supports `--meshx-log-raw-advert-data` (use together with `--meshx-auto-scan --meshx-log-candidate-discoveries`) to emit `raw_advert keys=[...]` + value types for every `didDiscover`; this surfaces exactly which advertisementData fields (service UUIDs, service data, local name, TX power, etc.) from Android extended sets reach CoreBluetooth on the tested stack, guiding any future pivot to non-manufacturer-data carriers for direct cues.

The MB beacon → GATT fetch path is the production-supported way to deliver >31-byte envelopes from Android to iOS.

Do not promote the direct full-MX AUX path on iOS without a new hardware
capture that proves all of the following:

* `FF FF 4D 58` MX manufacturer data is delivered to the platform scanner
  callback, not only emitted by the sender.
* The capture records sender and observer device model, OS version,
  controller/API capability, scan filter, duplicate setting, advertising mode,
  payload placement, and payload length.
* The observer parses the delivered bytes into the canonical
  `received_message` / MX envelope path.
* The same run confirms the MB legacy beacon path still works as the
  fleet-safe fallback.

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
