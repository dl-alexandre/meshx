# MeshX

**MeshX** is a modular, BEAM-native mesh networking stack for building resilient, decentralized applications on Elixir/Erlang.

## Architecture

The project is structured as an **umbrella application** with the following child apps:

### Core Libraries

- **`meshx_protocol`** — Compact binary framing, TTL, gossip primitives, and fragmentation
- **`meshx_noise`** — Noise XX session wrapper over Decibel
- **`meshx_store`** — CubDB persistence, ETS dedupe, relay cache, and outbox
- **`meshx_transport`** — Transport behavior plus in-memory and TCP transports
- **`meshx_transport_ble`** — Bluetooth Low Energy (BLE) native bridge adapter
- **`meshx_mob`** — Mobile platform context and transport metadata helpers

### Runtime

- **`meshx_runtime`** — Top-level OTP application. Depends on all other components and starts the supervision tree.

## Implemented Components

- `MeshxProtocol.Packet`, `Ack`, `Framing`, `Fragment`, `Gossip`, and `Codec`
- `MeshxNoise.Session` and `MeshxNoise.Supervisor`
- `MeshxStore.DB`, `Identity`, `Trust`, `Message`, `Outbox`, `Dedupe`, and `RelayCache`
- `MeshxTransport.Peer`, `Capabilities`, `Event`, `Memory`, `Memory.Hub`, `TCP`, `UDP`, and `QUIC`
- `MeshxTransportBLE.Bridge`, `NoopBridge`, `PortBridge`, and `BluezBridge`
- `MeshxMob.Platform`
- `MeshxRuntime.SessionManager`, `FragmentBuffer`, `PeerRegistry`, `Router`, `Outbox`, and `Topology`

## Secure Routing

`MeshxRuntime.Router.ensure_secure_session/2` performs a Noise XX handshake with
a peer over existing transports using non-relayed `:control` packets. Once the
session is established, `Router.send_packet/3` with `secure: true` encrypts the
packet payload and sets the protocol encrypted flag.

## Fragmentation

`MeshxRuntime.Router` fragments outbound packets when `:mtu` is provided or a
peer advertises `metadata.mtu`. Fragments carry the encoded original frame, so
reassembly preserves packet type, flags, TTL, and encrypted payloads. Inbound
fragments are buffered by `MeshxRuntime.FragmentBuffer` and delivered only after
the original packet has been fully reassembled.

## Store And Forward

`Router.send_packet/3` with `store: true` queues packets in `MeshxStore.Outbox`
when a peer is not currently reachable. `MeshxRuntime.Outbox` subscribes to peer
discovery events and replays matching pending packets when the destination peer
appears. Replayed rows remain pending until an ACK arrives; missing ACKs trigger
retry attempts until `max_attempts` marks the row failed.

## TCP Transport

`MeshxTransport.TCP` provides a real node-to-node transport for local networks
and test deployments. Endpoints listen on a TCP port, exchange peer IDs and
metadata during a transport handshake, then carry MeshX protocol frames as
length-prefixed TCP messages. Runtime nodes attach it the same way as other
transports:

```elixir
{:ok, tcp} = MeshxTransport.TCP.start_link(id: "node-a", event_target: MeshxRuntime.Router)
:ok = MeshxRuntime.Router.attach_transport(:tcp, MeshxTransport.TCP, tcp)
:ok = MeshxTransport.TCP.connect(tcp, {127, 0, 0, 1}, remote_port)
```

TCP and UDP provide general-purpose node-to-node transports. BLE is exposed
through `meshx_transport_ble`; Linux deployments can use the bundled BlueZ
bridge, while iOS and Android deployments provide CoreBluetooth/Android BLE
bridge modules behind the same behaviour.

## Documentation

- **[v1 Contracts](docs/CONTRACTS.md)** — normative boundary doc. Read this first.
- [Architecture](docs/ARCHITECTURE.md)
- [Runtime API](docs/RUNTIME_API.md)
- [Transport Integration](docs/TRANSPORTS.md)
- [BLE Native Bridge Guide](docs/BLE_BRIDGE.md)
- [Operations](docs/OPERATIONS.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Metrics](docs/METRICS.md)
- [Key Rotation](docs/KEY_ROTATION.md)
- [Failure Recovery](docs/FAILURE_RECOVERY.md)

## ACKs And Capabilities

Delivered packets with the ACK-requested flag generate direct ACK packets back to
the previous hop. ACKs mark matching outbox rows sent. Peers can advertise
`MeshxTransport.Capabilities` through metadata, including MTU, secure-required,
relay willingness, protocol version, and background mode.

## Relay Policy

The router only relays public `:data`, `:gossip`, and unencrypted `:fragment`
packets. ACKs, control packets, and encrypted per-peer packets are not flooded.
Relay broadcasts skip peers that advertise `relay: false`.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                   meshx_runtime                     │
│  (Application + Supervisor)                         │
├─────────────────────────────────────────────────────┤
│  meshx_protocol   meshx_noise     meshx_store      │
│  meshx_transport  meshx_transport_ble  meshx_mob   │
└─────────────────────────────────────────────────────┘
```

All components follow BEAM-oriented design practices:
- Strict supervision hierarchies
- Immutable data & functional core
- Context boundaries between modules
- Explicit runtime events and warning logs for recoverable protocol failures
- Proper error isolation via OTP supervisors

## Documentation

- [`docs/CONTRACTS.md`](docs/CONTRACTS.md) — public API guarantees, stability tiers, wire-format and persistence compatibility
- [`docs/FAILURE_DOMAINS.md`](docs/FAILURE_DOMAINS.md) — exact runtime behavior under process crash, node failure, network partition, identity loss, storage corruption, and replay window expiry
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — system design and component boundaries
- [`docs/OPERATIONS.md`](docs/OPERATIONS.md) — deployment, configuration, and data management
- [`docs/WORKSPACE_SAFETY.md`](docs/WORKSPACE_SAFETY.md) — agent execution rules and git safety guardrails
- [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) — release builds and container notes

## Development

```bash
cd meshx

# Build everything
mix deps.get
mix compile

# Run tests
mix test

# Run the runtime application
iex -S mix
```

## License

Apache 2.0 (see LICENSE file).
