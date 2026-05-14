# MeshX Architecture

MeshX is an Elixir umbrella application split into transport-agnostic layers.
Each layer has a narrow responsibility so transports, persistence, and routing
can evolve independently.

## Layers

### Protocol

`meshx_protocol` owns the wire format:

- `MeshxProtocol.Packet` defines packet types, flags, TTL, message IDs, and
  default packet construction.
- `MeshxProtocol.Framing` encodes and decodes compact binary frames with a
  truncated CRC-32 checksum.
- `MeshxProtocol.Ack` encodes delivery acknowledgements.
- `MeshxProtocol.Gossip` encodes message availability summaries.
- `MeshxProtocol.Fragment` splits and reassembles large payloads.
- `MeshxProtocol.Codec` provides the high-level encode/decode API used by
  runtime and transport tests.

### Security

`meshx_noise` wraps Decibel Noise sessions in GenServers so each peer session
has isolated process state. `MeshxRuntime.SessionManager` owns per-peer session
lookup, initiator/responder handshakes, and encryption/decryption calls used by
the router.

Current secure routing uses Noise XX over regular MeshX `:control` packets.
Secure application packets set the encrypted protocol flag and are never relayed
after decryption.

### Store

`meshx_store` combines durable CubDB state and in-memory caches:

- `MeshxStore.DB` is the local CubDB key-value store.
- `MeshxStore.Message` persists received or cached messages.
- `MeshxStore.Outbox` persists offline deliveries and retry counters.
- `MeshxStore.Dedupe` suppresses repeated message IDs with TTL-based ETS state.
- `MeshxStore.RelayCache` tracks relay-eligible message IDs and payloads.

### Transport

`meshx_transport` defines the common transport behavior and includes:

- `MeshxTransport.Memory` for deterministic in-memory simulation and tests.
- `MeshxTransport.TCP` for real node-to-node links over length-prefixed TCP.
- `MeshxTransport.UDP` for datagram links with hello exchange, keepalives, and
  idle-peer reaping.
- `MeshxTransport.QUIC` as an optional adapter when the `:quicer` NIF is
  installed by the deployment.

`meshx_transport_ble` provides the BLE adapter boundary. Linux/BlueZ is covered
by the bundled `MeshxTransportBLE.BluezBridge`; mobile platforms can provide
CoreBluetooth or Android BLE bridge modules behind the same behaviour.

### Runtime

`meshx_runtime` starts the node supervision tree and wires the layers together:

- `MeshxRuntime.Router` receives transport events, decodes frames, dedupes
  messages, sends ACKs, decrypts secure packets, reassembles fragments, relays
  public packets, and queues offline packets when requested.
- `MeshxRuntime.PeerRegistry` tracks visible peers and advertised capabilities.
- `MeshxRuntime.FragmentBuffer` buffers inbound fragments until complete.
- `MeshxRuntime.Outbox` replays persisted outbox rows on peer discovery and
  retry ticks.
- `MeshxRuntime.Topology` announces relay cache IDs through gossip.
- `MeshxRuntime.Discovery` provides opt-in LAN peer discovery through a compact
  UDP beacon and mDNS/DNS-SD service records for `_meshx._udp.local`.

### Mobile App

`meshx_mobile_app` is the deployable Mob app. Its UI and session state run in
Elixir on the device BEAM, start `meshx_runtime`, and talk to platform BLE
through `MeshxMobileApp.NativeBridge`.

The existing Swift package under `meshx_mobile/` remains the interop and native
BLE harness. Production mobile UI should be built in the Mob app; Swift and
platform code should sit behind the bridge boundary.

## Event Flow

Inbound:

1. Transport emits `{:meshx_transport, name, {:frame, peer_id, frame}}`.
2. Router decodes the frame with `MeshxProtocol.Codec`.
3. Router handles ACK/control/fragment packets before application delivery.
4. Application packets are decrypted when flagged, deduped, cached for relay,
   delivered to runtime subscribers, and optionally relayed with TTL decremented.

Outbound:

1. Caller builds a `MeshxProtocol.Packet`.
2. Caller uses `MeshxRuntime.Router.send_packet/3` or `broadcast_packet/2`.
3. Router optionally encrypts, fragments to MTU, and delegates to the attached
   transport.
4. If `store: true` is set and the peer is unavailable, runtime queues an
   ACK-requested packet in `MeshxStore.Outbox`.

## Current Node Model

The public runtime modules are registered by module name. That means a single
BEAM VM runs one MeshX runtime node. For multi-node local testing, run separate
BEAM OS processes and connect them with `MeshxTransport.TCP`, or use
`MeshxTransport.Memory` for multiple simulated endpoints attached to one
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
