# MeshX Architecture

MeshX is an Elixir umbrella application split into transport-agnostic layers.
Each layer has a narrow responsibility so transports, persistence, and routing
can evolve independently.

## Layers

### Protocol

`mob_protocol` owns the wire format:

- `Mob.Protocol.Packet` defines packet types, flags, TTL, message IDs, and
  default packet construction.
- `Mob.Protocol.Framing` encodes and decodes compact binary frames with a
  truncated CRC-32 checksum.
- `Mob.Protocol.Ack` encodes delivery acknowledgements.
- `Mob.Protocol.Gossip` encodes message availability summaries.
- `Mob.Protocol.Fragment` splits and reassembles large payloads.
- `Mob.Protocol.Codec` provides the high-level encode/decode API used by
  runtime and transport tests.

### Security

`mob_noise` wraps Decibel Noise sessions in GenServers so each peer session
has isolated process state. `Mob.Runtime.SessionManager` owns per-peer session
lookup, initiator/responder handshakes, and encryption/decryption calls used by
the router.

Current secure routing uses Noise XX over regular MeshX `:control` packets.
Secure application packets set the encrypted protocol flag and are never relayed
after decryption.

### Store

`mob_store` combines durable CubDB state and in-memory caches:

- `Mob.Store.DB` is the local CubDB key-value store.
- `Mob.Store.Message` persists received or cached messages.
- `Mob.Store.Outbox` persists offline deliveries and retry counters.
- `Mob.Store.Dedupe` suppresses repeated message IDs with TTL-based ETS state.
- `Mob.Store.RelayCache` tracks relay-eligible message IDs and payloads.

### Transport

`mob_routing` defines the common transport behavior and includes:

- `Mob.Routing.Memory` for deterministic in-memory simulation and tests.
- `Mob.Routing.TCP` for real node-to-node links over length-prefixed TCP.
- `Mob.Routing.UDP` for datagram links with hello exchange, keepalives, and
  idle-peer reaping.
- `Mob.Routing.QUIC` as an optional adapter when the `:quicer` NIF is
  installed by the deployment.

`mob_routing_ble` provides the BLE adapter boundary. Linux/BlueZ is covered
by the bundled `Mob.Routing.BLE.BluezBridge`; mobile platforms can provide
CoreBluetooth or Android BLE bridge modules behind the same behaviour.

### Runtime

`mob_runtime` starts the node supervision tree and wires the layers together:

- `Mob.Runtime.Router` receives transport events, decodes frames, dedupes
  messages, sends ACKs, decrypts secure packets, reassembles fragments, relays
  public packets, and queues offline packets when requested.
- `Mob.Runtime.PeerRegistry` tracks visible peers and advertised capabilities.
- `Mob.Runtime.FragmentBuffer` buffers inbound fragments until complete.
- `Mob.Runtime.Outbox` replays persisted outbox rows on peer discovery and
  retry ticks.
- `Mob.Runtime.Topology` announces relay cache IDs through gossip.
- `Mob.Runtime.Discovery` provides opt-in LAN peer discovery through a compact
  UDP beacon and mDNS/DNS-SD service records for `_mob._udp.local`.

### Mobile App

`mob_node` is the deployable Mob app. Its UI and session state run in
Elixir on the device BEAM, start `mob_runtime`, and talk to platform BLE
through `Mob.Node.NativeBridge`.

The existing Swift package under `mob_node/` remains the interop and native
BLE harness. Production mobile UI should be built in the Mob app; Swift and
platform code should sit behind the bridge boundary.

## Event Flow

Inbound:

1. Transport emits `{:mob_routing, name, {:frame, peer_id, frame}}`.
2. Router decodes the frame with `Mob.Protocol.Codec`.
3. Router handles ACK/control/fragment packets before application delivery.
4. Application packets are decrypted when flagged, deduped, cached for relay,
   delivered to runtime subscribers, and optionally relayed with TTL decremented.

Outbound:

1. Caller builds a `Mob.Protocol.Packet`.
2. Caller uses `Mob.Runtime.Router.send_packet/3` or `broadcast_packet/2`.
3. Router optionally encrypts, fragments to MTU, and delegates to the attached
   transport.
4. If `store: true` is set and the peer is unavailable, runtime queues an
   ACK-requested packet in `Mob.Store.Outbox`.

## Current Node Model

The public runtime modules are registered by module name. That means a single
BEAM VM runs one MeshX runtime node. For multi-node local testing, run separate
BEAM OS processes and connect them with `Mob.Routing.TCP`, or use
`Mob.Routing.Memory` for multiple simulated endpoints attached to one
runtime.

## Reliability Model

MeshX currently provides at-least-once delivery for queued packets:

- Outbox rows stay pending until an ACK arrives or max attempts are exhausted.
- Replayed packets set the ACK-requested flag.
- Late ACKs can still mark exhausted rows as sent.
- Duplicate inbound packets are suppressed by message ID.

It does not yet provide exactly-once semantics, authenticated peer identity
binding beyond the active Noise session, cross-node clock coordination, or
automatic outbox compaction policy.
