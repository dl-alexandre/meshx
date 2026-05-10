# MeshX v1 Contracts

This document defines the **hard boundary** of what MeshX guarantees and
what it explicitly does not. Everything inside is normative; everything
outside is the application's job. Proposals to add functionality that
changes a guarantee here are v2 conversations, not v1 work.

Key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY**
follow [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) usage.

---

## 1. Peer Identity

- A `peer_id` is an **opaque term** chosen by the application or transport.
  MeshX MUST treat it as a comparison key only.
- MeshX MUST NOT issue, allocate, or validate peer ids.
- MeshX MUST NOT bind a `peer_id` to a cryptographic identity. Binding the
  static Noise public key to a `peer_id` is the application's
  responsibility, persisted in `MeshxStore.Trust`.
- Two peers with the same `peer_id` reachable via different transports MUST
  be treated as the same logical peer for routing and dedup.

**Out of scope.** Naming schemes, identity rotation, identity revocation
beyond removing a Trust row, name resolution.

---

## 2. Authorization

- MeshX MUST deliver every successfully decoded, deduped, decrypted packet
  to subscribers. It MUST NOT drop packets based on application policy.
- MeshX MUST NOT decide which peers may join, send, or receive.
- The application MUST gate sensitive operations at the subscriber, after
  delivery. A typical pattern: bind `peer_id` ↔ identity at trust setup,
  then check capability per message.

**Out of scope.** ACLs, role-based access control, rate limiting per peer,
quota enforcement.

---

## 3. Session Lifecycle

- A "session" means a Noise XX session between this node and one peer.
- A session MUST be established lazily on the first call to
  `Router.send_packet/3` with `secure: true`, or explicitly via
  `Router.ensure_secure_session/2`.
- A session MUST be torn down when its transport reports `:peer_down` for
  the peer, or when `SessionManager.reset_peer/1` is called.
- The runtime MUST re-establish a session on the next secure send after
  teardown. It MUST NOT silently fall back to plaintext.
- A handshake failure (bad key, bad payload, peer unreachable) MUST emit
  `[:meshx_runtime, :noise, :handshake, :error]` and propagate
  `{:error, reason}` to the caller.
- Session keys MUST NOT be persisted across BEAM restarts. Static keys MAY
  be persisted (and SHOULD be, via `MeshxStore.Identity`).

**Out of scope.** Multi-party sessions, session resumption across restarts,
forward-secret rekeying within a session.

---

## 4. Discovery Freshness

- A discovery layer MAY surface peers via `MeshxRuntime.Discovery`.
  Surfaced peers MUST appear as `[:router, :peer, :discovered]` events.
- Discovery MUST NOT guarantee that a discovered peer is currently
  reachable. Reachability is established only after a transport reports
  `:peer_up` for the same `peer_id`.
- A peer MAY be re-announced. The runtime MUST be idempotent on
  re-announcement (no duplicate `peer_up` events to subscribers).
- Discovery announcements MUST NOT be relied on as a heartbeat. Liveness
  is established via transport-level `peer_up`/`peer_down` only.

**Out of scope.** Discovery scope (LAN only? cross-region?), discovery
authentication, anti-flood policy on announcements.

---

## 5. Message Envelope

- The wire format is `MeshxProtocol.Packet` framed by
  `MeshxProtocol.Framing`. The frame layout is defined in
  `framing.ex` and MUST NOT change within v1.
- A packet MUST carry: `version`, `type`, `flags`, `ttl`, `msg_id`,
  `payload`. The runtime MUST reject packets whose `version` does not
  match `MeshxProtocol.Packet.version/0`.
- `msg_id` MUST be a 32-bit unsigned integer chosen by the sender. It is
  the dedup key.
- `payload` MUST be a binary. MeshX MUST NOT interpret its contents.
- Maximum payload size is **65,535 bytes**. Larger payloads MUST be
  fragmented (see §10).

**Out of scope.** Payload schemas, per-application envelopes, content
type negotiation.

---

## 6. Delivery Semantics

MeshX provides two delivery modes, selected per call:

| Mode | API | Guarantee |
| --- | --- | --- |
| Best-effort | `send_packet(peer, p)` | At-most-once. Dropped on transport error or peer-not-found. |
| Stored + ACKed | `send_packet(peer, p, store: true)` | At-least-once **until ACK received or `max_attempts` exhausted**. Survives BEAM restarts via `MeshxStore.Outbox`. Dedup at the receiver suppresses duplicates within the dedup window (see §8). |

- A successful return from `send_packet/3` MUST mean "accepted by the
  runtime." It MUST NOT imply delivery to the peer.
- After a `store: true` send, the packet MUST eventually be delivered or
  marked failed (`max_attempts` reached). MeshX MUST NOT silently drop a
  stored packet.
- Across the dedup window, delivery to subscribers is **exactly-once per
  `msg_id`**. Outside the window, the application MUST tolerate replays.

**Out of scope.** Causal ordering, cross-peer atomicity, exactly-once
across infinite time.

---

## 7. Retry / ACK Behavior

- A packet sent with `store: true` MUST have its ACK flag set on the
  wire (the runtime sets it before enqueuing). Best-effort sends MUST
  NOT set the ACK flag implicitly.
- The receiver MUST emit a direct ACK packet to the previous hop
  immediately after a packet with the ACK-requested flag is delivered to
  subscribers.
- ACKs MUST NOT be relayed.
- An ACK MUST clear the matching outbox row. ACKs for unknown `msg_id`s
  MUST be ignored without error.
- The runtime MUST retry pending outbox rows on:
  - `:peer_up` for the destination peer
  - the periodic retry interval (default 30s, configurable)
  - explicit `Outbox.retry_now/0`
- After `max_attempts` (default 5) without an ACK, the row MUST be
  marked failed. Failed rows MUST NOT be auto-retried.

**Out of scope.** Selective ACKs, batched ACKs, ACK-of-ACK confirmation.

---

## 8. Deduplication Window

- Every received packet's `msg_id` MUST be checked against the dedup table
  (`MeshxStore.Dedupe`).
- If the `msg_id` is already present, the packet MUST NOT be delivered to
  subscribers and MUST NOT be relayed. A `[:router, :packet, :duplicate]`
  event MUST be emitted.
- The dedup window is **bounded by `MeshxStore.Dedupe`'s eviction policy**
  (size-based, configurable). MeshX MUST NOT promise dedup beyond the
  window.
- The window size is a tuning parameter, not a contract. Applications
  that need stronger replay protection MUST add their own.

**Out of scope.** Persistent cross-restart dedup beyond what the store
provides, cryptographic replay protection.

---

## 9. Ordering

- MeshX MUST NOT preserve send order across distinct `msg_id`s, even to
  the same peer.
- Within a single fragmented packet, fragments MAY arrive out of order;
  reassembly MUST present the original payload (see §10).
- ACKs MAY arrive in any order relative to the packets they acknowledge.
- Subscribers MUST be designed to tolerate arbitrary inter-message
  ordering. Applications that need ordering MUST embed sequencing in
  the payload.

**Out of scope.** Per-peer FIFO, per-conversation ordering, total order.

---

## 10. Fragmentation / Reassembly

- Outbound packets MUST be fragmented when `:mtu` is provided in send
  opts or the destination peer advertises an MTU in capabilities.
- Each fragment MUST encode the original packet's frame in chunks of
  `mtu - fragment_overhead` bytes. The fragment header MUST carry
  `original_msg_id`, `index`, `total`.
- Fragments MUST NOT exceed 255 per packet. A request that would exceed
  this MUST return `{:error, :too_many_fragments}`.
- Inbound fragments MUST be buffered in `FragmentBuffer` and delivered
  to subscribers **only after every fragment has arrived**.
- A partial fragment set MAY be evicted by buffer policy. Evictions MUST
  emit a `[:router, :fragment, :error]` event.
- Reassembly MUST preserve the original packet's `type`, `flags`, `ttl`,
  and `payload`. Encryption flags MUST survive reassembly.

**Out of scope.** Per-fragment ACK, fragment-level retransmit, FEC.

---

## 11. Transport Adapter Responsibilities

A transport that implements `MeshxTransport` MUST:

1. Emit `{:meshx_transport, name, {:peer_up, peer}}` exactly once when a
   peer becomes reachable.
2. Emit `{:meshx_transport, name, {:peer_down, peer_id}}` exactly once
   when a previously-up peer becomes unreachable.
3. Emit `{:meshx_transport, name, {:frame, peer_id, frame}}` for every
   complete inbound frame, in arrival order on that transport.
4. Implement `send_frame/4`, `broadcast_frame/3`, `peers/1`.
5. Reject malformed handshakes and frames **without crashing the
   transport process**. Bad input MUST close the offending peer only.
6. Carry transport metadata (MTU, relay willingness, secure-required) in
   peer announcements via `MeshxTransport.Capabilities`.

A transport MUST NOT:

- Decode `MeshxProtocol.Packet`. Frames are opaque bytes to the
  transport.
- Apply dedup, retry, or ACK logic. Those live in the runtime.
- Persist frames. Outbox is a runtime concern.
- Speak Noise. Encryption is layered above the transport.

**Out of scope.** Connection multiplexing semantics, per-transport
authentication beyond what the wire-level handshake provides.

---

## 12. Application Responsibilities

The application MUST:

1. **Choose `peer_id`s** and persist the binding to identity material.
2. **Authorize** every received packet before acting on it.
3. **Schema** payloads. MeshX delivers bytes; meaning is the application's.
4. **Idempotent handlers** for any packet sent with `ack: true` or
   `store: true`. Replays outside the dedup window are expected.
5. **Order-tolerant handlers**. If ordering matters, encode it in the
   payload.
6. **Bound the outbox**. MeshX retries indefinitely up to `max_attempts`;
   the application chooses `max_attempts` and decides what to do with
   permanently failed rows.
7. **Trust management**. `MeshxStore.Trust` rows are added/removed by
   the application during onboarding, key rotation, and offboarding.
8. **Backpressure at the source**. MeshX surfaces drops via
   `[:router, :backpressure, :dropped]`; the application MUST throttle.

The application MUST NOT:

- Assume MeshX has authenticated the peer beyond the static-key check.
- Assume delivery happened because `send_packet/3` returned `:ok`.
- Rely on per-message ordering, cross-peer atomicity, or persistent
  dedup beyond the configured window.

---

## Versioning

- The wire format (`MeshxProtocol`) MUST NOT change within v1. A breaking
  change requires bumping `Packet.version/0` and a v2 release.
- The runtime API surface (`MeshxRuntime.Router`, `Outbox`,
  `SessionManager`) is **stable within v1 majors**. Internal modules
  (everything not in this document or the runtime API guide) MAY change
  without notice.
- Telemetry event names defined in [`METRICS.md`](METRICS.md) are stable
  within v1 majors. New events MAY be added.

---

## Conformance

This document is **normative** — it defines the v1 contract. The current
codebase implements the bulk of it, but a small number of clauses are
**aspirational**: the contract is committed, the enforcement is still
being closed. Known gaps as of this draft:

- §3: The Noise session is not yet automatically torn down on transport
  `:peer_down`. Reset is currently explicit via
  `SessionManager.reset_peer/1`. v1 finalization will close this.
- §8: The dedup window's eviction policy is size-bounded but not yet
  documented as a stable configuration knob.

Any divergence not listed here is a bug. Report it; do not paper over it
in the contract.

---

## 10. Compatibility Guarantees

### 10.1 Stability Tiers

Every exported symbol in the `Meshx` namespace falls into exactly one of
these tiers:

| Tier | Contract | Examples |
|------|----------|----------|
| **Stable** | Preserved across minor releases; deprecation window ≥ 1 minor before removal. | `Router.send_packet/3`, `Trust.authorize/3`, `Noise.Session` handshake |
| **Internal** | Exists in public modules but is **not** a supported extension point. May change in any release without notice. | `MeshxStore.DB` tuple keys, CubDB data directory layout, internal GenServer state shapes |
| **Private** | Unexported or `@moduledoc false`. No guarantees at all; may change in any commit. | Private helper functions, test-only callbacks, supervision-internal child ordering |

Stable symbols are identified by `@doc` presence and absence of an
`@moduledoc false` parent. Internal symbols are identified by explicit
warnings in their moduledoc (e.g. `"internal implementation detail"`).
Everything else is private.

### 10.2 Persistence Compatibility

`meshx_store` uses CubDB as its local-first engine. The following guarantees
apply to the data directory written by a MeshX node:

- **Forward compatibility (upgrade)**: A newer minor version of MeshX MUST
  be able to open a CubDB data directory written by any older minor version
  within the same major line.
- **Backward compatibility (downgrade)**: A data directory written by a newer
  minor version MAY be unreadable by an older minor version. Downgrades are
  not guaranteed and require explicit data migration or wipe.
- **Cross-engine compatibility**: The CubDB data directory is **not**
  portable to Ecto/SQLite or any other storage engine. Migration between
  engines is an out-of-band operation (export/import, not in-place).
- **Schema evolution**: CubDB is schemaless at the engine level. MeshX
  internally versions persisted structs by adding or removing fields. Unknown
  fields in loaded structs are ignored; missing fields default to `nil`. This
  is the only supported schema evolution strategy.

### 10.3 Wire-Format Compatibility

- **Packet framing**: The `MeshxProtocol.Packet` binary layout is frozen for
  the lifetime of the major version. A v1 node MUST be able to exchange frames
  with any other v1 node regardless of minor or patch level.
- **Noise protocol**: Handshake patterns and cipher selection follow the
  Noise Protocol revision bound in `MeshxNoise`. A v1 node MUST complete a
  Noise XX handshake with any other v1 node.
- **Transport headers**: Transport-specific headers (UDP port framing, BLE
  MTU negotiation, TCP length-prefixing) are **internal** to each transport
  implementation and are not guaranteed across minor versions. Applications
  MUST NOT parse raw transport frames.

### 10.4 Node-Version Compatibility

- **Same-major meshing**: Nodes with different minor versions within the same
  major version SHOULD form a functional mesh for all stable features. Feature
  detection for optional capabilities is the transport's responsibility, not
  the application's.
- **Cross-major isolation**: Nodes with different major versions MUST NOT
  attempt to form a mesh. The connection MUST be rejected at the handshake
  layer (future: version negotiation with explicit refusal).
- **Feature gating**: New minor-version features that change wire behavior
  MUST be opt-in per transport and MUST degrade gracefully to stable behavior
  when the peer does not advertise support.

### 10.5 Upgrade Semantics

A compliant v1 upgrade sequence MUST satisfy:

1. **Stop**: The old node stops cleanly, persisting all in-flight outbox
   entries to CubDB.
2. **Preserve**: The CubDB data directory is kept on disk.
3. **Start**: The new node starts against the same data directory.
4. **Resume**: Pending outbox entries resume delivery. Trust and identity
   records are intact. Dedupe and relay caches are cold-started (acceptable
   because both are TTL-bounded soft state).

No explicit migration step is required for in-place minor-version upgrades.
Major-version upgrades are out of scope for v1 and require full data
re-initialization.

> See [`FAILURE_DOMAINS.md`](FAILURE_DOMAINS.md) for exact guarantees per
> failure mode (process crash, node failure, partition, identity loss,
> storage corruption, replay window expiry).

---

## Out-of-Scope (v1)

The following are explicitly **not** v1 and SHOULD NOT be added without a
v2 conversation:

- Distributed consensus (Raft, Paxos, CRDT merge engines).
- Application-level pub/sub topics.
- Multicast group membership semantics.
- Persistent cross-restart causal ordering.
- Built-in identity issuance / rotation automation.
- Built-in authorization / RBAC.
- Built-in rate limiting or quota enforcement.
- Cross-language bindings beyond the BLE bridge boundary.

These are valid product choices — they are just not what MeshX is.
