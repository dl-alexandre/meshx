# mob mesh

**mob mesh** is a modular, BEAM-native mesh networking stack for building
resilient, decentralized applications on Elixir/Erlang. It is the mesh
networking layer of the **mob** ecosystem (BEAM-on-device + plugins).

It provides compact binary protocol framing, Noise XX encryption,
store-and-forward message queuing, and pluggable transports (TCP, UDP,
BLE) — all supervised as a first-class OTP application.

> **Renamed from MeshX (2026-05):** the `meshx_*` umbrella was absorbed
> into the `mob_*` package family for a single, consistent prefix across
> the ecosystem. Wire format is unchanged; captured BLE advertisements
> with the historical `meshx-` local-name prefix remain parseable. See
> [CHANGELOG.md](CHANGELOG.md) for the full rename table and migration
> notes.

## What mob mesh Is

- A **substrate library** for mesh networking inside a BEAM application
- **Noise XX** end-to-end encryption between peers
- **Store-and-forward** message delivery for offline or partitioned peers
- **Pluggable transports** with TCP, UDP, and BLE adapters included
- **TTL-based relay** with deduplication and fragmentation
- **Identity pinning** with TOFU (trust-on-first-use) and allowlist policies
- **Causality-agnostic** — no consensus, no global ordering, no leader election

## What mob mesh Is Not

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

Add `mob_runtime` to your `mix.exs`:

```elixir
defp deps do
  [
    {:mob_runtime, git: "https://github.com/dl-alexandre/mob.git"}
  ]
end
```

> **Note:** the `mob_*` umbrella is not yet published to Hex. Installation
> is via `git` dependency only until all umbrella apps can be published
> coherently. See [`docs/RELEASE.md`](docs/RELEASE.md) for the planned
> publish order.

Start a node and send a packet:

```elixir
# Start the runtime application (usually in your supervision tree)
{:ok, _apps} = Application.ensure_all_started(:mob_runtime)

# Attach a TCP transport
{:ok, tcp} = Mob.Routing.TCP.start_link(id: "node-a", event_target: Mob.Runtime.Router)
:ok = Mob.Runtime.Router.attach_transport(:tcp, Mob.Routing.TCP, tcp)

# Connect to a peer
:ok = Mob.Routing.TCP.connect(tcp, {127, 0, 0, 1}, 4040)

# Send a packet (encrypted via Noise XX if secure session exists)
packet = Mob.Protocol.Packet.new(:data, 1, "hello")
:ok = Mob.Runtime.Router.send_packet("peer-b", packet, store: true, secure: true)
```

Packets with `store: true` are queued in `Mob.Store.Outbox` when the peer is
offline and replayed automatically when it reappears on any transport.

## Architecture

The project is structured as an **umbrella application** with the following
child apps:

### Core Libraries

- **`mob_protocol`** — Compact binary framing, TTL, gossip primitives, and fragmentation
- **`mob_noise`** — Noise XX session wrapper over Decibel
- **`mob_store`** — CubDB persistence, ETS dedupe, relay cache, and outbox
- **`mob_routing`** — Transport behavior plus in-memory and TCP transports
- **`mob_routing_ble`** — Bluetooth Low Energy (BLE) native bridge adapter

### Runtime

- **`mob_runtime`** — Top-level OTP application. Depends on all other components and starts the supervision tree.

### Mobile App

- **`mob_node`** — Mob-based mobile app shell. Runs the mob mesh runtime
  inside the on-device BEAM and delegates platform BLE to a native bridge
  contract. Also hosts the chat MVP (`Mob.Node.Chat.*`,
  `Mob.Node.ChatScreen`, `Mob.Node.ChannelsScreen`).

## Implemented Components

- `Mob.Protocol.Packet`, `Ack`, `Framing`, `Fragment`, `Gossip`, and `Codec`
- `Mob.Noise.Session` and `Mob.Noise.Supervisor`
- `Mob.Store.DB`, `Identity`, `Trust`, `Message`, `Outbox`, `Dedupe`, and `RelayCache`
- `Mob.Routing.Peer`, `Capabilities`, `Event`, `Memory`, `Memory.Hub`, `TCP`, `UDP`, and `QUIC`
- `Mob.Routing.BLE.Bridge`, `NoopBridge`, `PortBridge`, and `BluezBridge`
- `Mob.Node.Platform`, `Session`, `HomeScreen`, `ChatScreen`, `ChannelsScreen`, and native bridge contract
- `Mob.Node.Chat.Identity`, `Composer`, `ChannelViewModel`, and `ChannelNativeSurface`
- `Mob.Runtime.SessionManager`, `FragmentBuffer`, `PeerRegistry`, `Router`, `Outbox`, and `Topology`

## Transport and Runtime Status

| Transport | Status | Notes |
|-----------|--------|-------|
| TCP | ✅ Stable | Production-ready for local networks |
| UDP | ✅ Stable | Best-effort datagram delivery |
| BLE | ⚠️ Partial | BlueZ bridge works on Linux; iOS/Android bridges are application-specific |
| QUIC | ✅ Implemented | Requires `:quicer` optional dep; detection is runtime via `Mob.Routing.QUIC.available?/0` |
| mDNS Discovery | ✅ Stable | LAN peer discovery via `Mob.Runtime.Discovery` |

The runtime starts all transports you attach. Unattached transports have no
overhead. The supervision tree restarts transports automatically on failure.

## Secure Routing

`Mob.Runtime.Router.ensure_secure_session/2` performs a Noise XX handshake with
a peer over existing transports using non-relayed `:control` packets. Once the
session is established, `Router.send_packet/3` with `secure: true` encrypts the
packet payload and sets the protocol encrypted flag.

## Fragmentation

`Mob.Runtime.Router` fragments outbound packets when `:mtu` is provided or a
peer advertises `metadata.mtu`. Fragments carry the encoded original frame, so
reassembly preserves packet type, flags, TTL, and encrypted payloads. Inbound
fragments are buffered by `Mob.Runtime.FragmentBuffer` and delivered only after
the original packet has been fully reassembled.

## Store And Forward

`Router.send_packet/3` with `store: true` queues packets in `Mob.Store.Outbox`
when a peer is not currently reachable. `Mob.Runtime.Outbox` subscribes to peer
discovery events and replays matching pending packets when the destination peer
appears. Replayed rows remain pending until an ACK arrives; missing ACKs trigger
retry attempts until `max_attempts` marks the row failed.

## TCP Transport

`Mob.Routing.TCP` provides a real node-to-node transport for local networks
and test deployments. Endpoints listen on a TCP port, exchange peer IDs and
metadata during a transport handshake, then carry mob mesh protocol frames as
length-prefixed TCP messages. Runtime nodes attach it the same way as other
transports:

```elixir
{:ok, tcp} = Mob.Routing.TCP.start_link(id: "node-a", event_target: Mob.Runtime.Router)
:ok = Mob.Runtime.Router.attach_transport(:tcp, Mob.Routing.TCP, tcp)
:ok = Mob.Routing.TCP.connect(tcp, {127, 0, 0, 1}, remote_port)
```

TCP and UDP provide general-purpose node-to-node transports. BLE is exposed
through `mob_routing_ble`; Linux deployments can use the bundled BlueZ
bridge, while iOS and Android deployments provide CoreBluetooth/Android BLE
bridge modules behind the same behaviour.

## Documentation

Read the contracts first — they define what mob mesh guarantees and what it
does not:

- **[v1 Contracts](docs/CONTRACTS.md)** — normative boundary doc. Read this first.
- [Failure Domains](docs/FAILURE_DOMAINS.md) — exact runtime behavior under every failure mode
- [Architecture](docs/ARCHITECTURE.md)
- [Runtime API](docs/RUNTIME_API.md)
- [Transport Integration](docs/TRANSPORTS.md)
- [BLE Native Bridge Guide](docs/BLE_BRIDGE.md)
- [Chat MVP Architecture](docs/chat_interface_mvp.md) — `Mob.Node.Chat.*`
  module layout, identity contract, send/receive flow
- [BLE Remaining Items Audit](docs/remaining_items_audit.md) — focused status
  for the iOS responder proof, direct full-MX AUX boundary, upstream Mob PRs,
  and `--no-start` startup fix
- [Operations](docs/OPERATIONS.md)
- [Deployment](docs/DEPLOYMENT.md)
- [Metrics](docs/METRICS.md)
- [Key Rotation](docs/KEY_ROTATION.md)
- [Failure Recovery](docs/FAILURE_RECOVERY.md)
- [Workspace Safety](docs/WORKSPACE_SAFETY.md) — agent execution rules for contributors

## ACKs And Capabilities

Delivered packets with the ACK-requested flag generate direct ACK packets back to
the previous hop. ACKs mark matching outbox rows sent. Peers can advertise
`Mob.Routing.Capabilities` through metadata, including MTU, secure-required,
relay willingness, protocol version, and background mode.

## Relay Policy

The router only relays public `:data`, `:gossip`, and unencrypted `:fragment`
packets. ACKs, control packets, and encrypted per-peer packets are not flooded.
Relay broadcasts skip peers that advertise `relay: false`.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       mob_runtime                           │
│             (Application + Supervisor)                      │
├─────────────────────────────────────────────────────────────┤
│  mob_protocol   mob_noise        mob_store                  │
│  mob_routing    mob_routing_ble                             │
├─────────────────────────────────────────────────────────────┤
│                        mob_node                             │
│       (mobile shell + chat MVP + native BLE bridge)         │
└─────────────────────────────────────────────────────────────┘
```

All components follow BEAM-oriented design practices:
- Strict supervision hierarchies
- Immutable data & functional core
- Context boundaries between modules
- Explicit runtime events and warning logs for recoverable protocol failures
- Proper error isolation via OTP supervisors

## Development

```bash
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
