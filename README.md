# MeshX

**MeshX** is a modular, BEAM-native mesh networking stack for building
resilient, decentralized applications on Elixir/Erlang.

It provides compact binary protocol framing, Noise XX encryption,
store-and-forward message queuing, and pluggable transports (TCP, UDP,
BLE) — all supervised as a first-class OTP application.

## What MeshX Is

- A **substrate library** for mesh networking inside a BEAM application
- **Noise XX** end-to-end encryption between peers
- **Store-and-forward** message delivery for offline or partitioned peers
- **Pluggable transports** with TCP, UDP, and BLE adapters included
- **TTL-based relay** with deduplication and fragmentation
- **Identity pinning** with TOFU (trust-on-first-use) and allowlist policies
- **Causality-agnostic** — no consensus, no global ordering, no leader election

## What MeshX Is Not

- A **distributed consensus** system (no Raft, no Paxos)
- An **application-level pub/sub broker** — topics and routing logic are the
  application's responsibility
- A **blockchain or DHT** — there is no global ledger or distributed hash table
- A **NAT traversal / hole-punching** library — transports operate on whatever
  reachability the underlying network provides
- A **persistent causal ordering** system — causal tracking is the
  application's responsibility if needed
- A **replacement for MQTT, NATS, or RabbitMQ** — it is a lower-level mesh
  substrate, not a message broker with QoS guarantees

## Quickstart

Add MeshX to your `mix.exs`:

```elixir
defp deps do
  [
    {:meshx_runtime, "~> 0.1.0"}
  ]
end
```

Start a node and send a packet:

```elixir
# Start the runtime application (usually in your supervision tree)
{:ok, _apps} = Application.ensure_all_started(:meshx_runtime)

# Attach a TCP transport
{:ok, tcp} = MeshxTransport.TCP.start_link(id: "node-a", event_target: MeshxRuntime.Router)
:ok = MeshxRuntime.Router.attach_transport(:tcp, MeshxTransport.TCP, tcp)

# Connect to a peer
:ok = MeshxTransport.TCP.connect(tcp, {127, 0, 0, 1}, 4040)

# Send a packet (encrypted via Noise XX if secure session exists)
packet = MeshxProtocol.Packet.new(:data, 1, "hello")
:ok = MeshxRuntime.Router.send_packet("peer-b", packet, store: true, secure: true)
```

Packets with `store: true` are queued in `MeshxStore.Outbox` when the peer is
offline and replayed automatically when it reappears on any transport.

## Architecture

The project is structured as an **umbrella application** with the following
child apps:

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

## Transport and Runtime Status

| Transport | Status | Notes |
|-----------|--------|-------|
| TCP | ✅ Stable | Production-ready for local networks |
| UDP | ✅ Stable | Best-effort datagram delivery |
| BLE | ⚠️ Partial | BlueZ bridge works on Linux; iOS/Android bridges are application-specific |
| QUIC | 🔮 Planned | Requires `:quicer` optional dep; detection is runtime |
| mDNS Discovery | ✅ Stable | LAN peer discovery via `MeshxRuntime.Discovery` |

The runtime starts all transports you attach. Unattached transports have no
overhead. The supervision tree restarts transports automatically on failure.

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

Read the contracts first — they define what MeshX guarantees and what it
does not:

- **[v1 Contracts](docs/CONTRACTS.md)** — normative boundary doc. Read this first.
- [Failure Domains](docs/FAILURE_DOMAINS.md) — exact runtime behavior under every failure mode
- [Architecture](docs/ARCHITECTURE.md)
- [Runtime API](docs/RUNTIME_API.md)
- [Transport Integration](docs/TRANSPORTS.md)
- [BLE Native Bridge Guide](docs/BLE_BRIDGE.md)
- [Operations](docs/OPERATIONS.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Metrics](docs/METRICS.md)
- [Key Rotation](docs/KEY_ROTATION.md)
- [Failure Recovery](docs/FAILURE_RECOVERY.md)
- [Workspace Safety](docs/WORKSPACE_SAFETY.md) — agent execution rules for contributors

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

Apache 2.0 (see [LICENSE](LICENSE) file).
