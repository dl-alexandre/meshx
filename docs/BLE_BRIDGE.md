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
