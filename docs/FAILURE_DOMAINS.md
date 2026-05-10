# MeshX Failure Domains

This document defines how MeshX behaves when each failure domain is
exercised, and what guarantees the runtime does or does not provide.

Key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY**
follow [RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) usage.

Each section describes:

1. The failure domain and triggering conditions.
2. Which state is durable vs ephemeral.
3. What the runtime MUST guarantee.
4. What the runtime MUST NOT guarantee.
5. Recovery action required by the application, if any.

---

## 1. Process Failure

A **process failure** is the unexpected termination of any single
`GenServer` or `Agent` inside the MeshX supervision tree.

### Triggers

- Uncaught exception in a GenServer callback.
- `Kernel.exit/1` or linked process crash.
- OOM kill of the BEAM scheduler running the process.

### Guarantees

- The supervisor MUST restart the crashed process with the
  strategy declared in its child spec (`:one_for_one` for most
  children, `:one_for_all` for `MeshxNoise.Supervisor`).
- State rebuilt from durable storage (CubDB) MUST be identical
  to the state at the last successful write. MeshX does not
  buffer in-memory state without writing it.
- Ephemeral state (dedupe cache, relay cache, flow-control windows)
  MAY be reset to empty. This is acceptable because all three are
  TTL-bounded soft state.
- In-flight packets held only in process mailboxes MAY be lost.
  The transport MUST surface the loss to `MeshxRuntime.Router` as
  a `:peer_down` event if the peer process also died.

### Non-Guarantees

- MeshX MUST NOT guarantee exactly-once delivery for in-flight
  packets that were in a crashed process mailbox but not yet
  acknowledged.
- MeshX MUST NOT guarantee continuity of GenServer call timeouts
  across a restart.

### Application Recovery

None. The supervisor restarts automatically. If the crash repeats
rapidly and the supervisor escalates, the node SHOULD be
considered failed and restarted via the runtime's top-level
supervisor.

---

## 2. Node Failure

A **node failure** is the complete termination of the BEAM VM or the
operating system process hosting it.

### Triggers

- `kill -9` of the BEAM process.
- Host power loss.
- OS kernel panic or reboot.

### Guarantees

- On restart, `MeshxStore.Identity` MUST recover the same static
  Noise key pair that was persisted before the crash.
- `MeshxStore.Trust` records MUST survive; the node MUST resume
  with the same trust posture (pinned keys, blocked peers).
- `MeshxStore.Outbox` entries that were successfully enqueued MUST
  survive and be eligible for retry or replay by
  `MeshxRuntime.Outbox`.
- `MeshxStore.Message` records MUST survive for local query.

### Non-Guarantees

- MeshX MUST NOT guarantee delivery of packets that were in transit
  inside the BEAM VM but not yet written to the transport's
  socket/kernel buffer at the moment of crash.
- MeshX MUST NOT guarantee that other peers will retain any
  session state for this node; peers MUST treat the restarted
  node as a fresh `:peer_down` followed by `:peer_up`.
- Dedupe cache, relay cache, and flow-control windows are
  ephemeral and MAY be lost.

### Application Recovery

None required for MeshX itself. The application MAY choose to
re-subscribe to `Router` events on boot if its own processes are
not supervised under the same tree.

---

## 3. Transport Failure

A **transport failure** is the inability of a single transport
implementation (TCP, UDP, BLE) to send or receive data, while
other transports and the runtime remain operational.

### Triggers

- TCP connection reset by peer or NAT timeout.
- UDP socket closed by OS (port reuse, firewall rule change).
- BLE link layer disconnect or adapter power-down.
- Network interface down.

### Guarantees

- The transport MUST surface the failure to
  `MeshxRuntime.Router` as a `:peer_down` event for every affected
  peer.
- `MeshxRuntime.SessionManager` MUST tear down Noise sessions
  associated with that transport/peer tuple.
- Other transports for the same peer, if any, MUST NOT be
  affected.
- Pending outbox entries targeting the affected peer MUST remain
  in `MeshxStore.Outbox` with `:pending` status and be retried
  when the peer reappears on any transport.

### Non-Guarantees

- MeshX MUST NOT auto-reconnect at the transport level.
  Reconnection is the transport's responsibility or the
  application's.
- MeshX MUST NOT guarantee that a transport failure is detected
  instantly; detection MAY rely on keepalive timeouts or OS
  socket errors.

### Application Recovery

The application MAY restart the transport (e.g., call
`MeshxTransport.TCP.start_link/1` again) or wait for a
higher-level orchestrator to do so. MeshX does not require
action.

---

## 4. Network Partition

A **network partition** is the situation where two or more nodes
are alive but unable to exchange packets, or where a subset of
nodes can reach each other but not the rest.

### Triggers

- Firewall rule change.
- Router misconfiguration.
- Physical link failure between subnets.
- Asymmetric routing.

### Guarantees

- MeshX MUST continue accepting and enqueuing packets from local
  subscribers for partitioned peers. Those packets MUST be
  stored in `MeshxStore.Outbox`.
- When the partition heals and the peer reappears on any
  transport, `MeshxRuntime.Outbox` MUST attempt delivery of
  pending entries in insertion order.
- Duplicate suppression (`MeshxStore.Dedupe`) MUST prevent the
  same message from being processed twice if the partition
  caused it to be relayed through an alternate path.

### Non-Guarantees

- MeshX MUST NOT detect partitions automatically. Detection is
  transport-specific (TCP timeouts, BLE link loss, etc.).
- MeshX MUST NOT guarantee that messages sent during the
  partition will be delivered in exactly the same order they
  were sent. Order is preserved per outbox insertion, but
  interleaving with new messages after heal is not guaranteed.
- MeshX MUST NOT implement vector clocks or causal ordering
  across partitions. Message causality is the application's
  responsibility.

### Application Recovery

None required. The outbox handles buffering automatically. If
partition duration exceeds TTL or outbox capacity limits, the
application MAY purge old entries via `Outbox.clear/0` or
selective deletion.

---

## 5. Identity Loss

An **identity loss** is the situation where the node's local
`MeshxStore.Identity` record is deleted, corrupted, or rendered
unreadable.

### Triggers

- Accidental deletion of the CubDB data directory.
- Storage media corruption.
- Manual operator intervention (`rm -rf` on the data dir).
- Restoring a backup from a different node.

### Guarantees

- On the next call to `Identity.ensure_local/1`, MeshX MUST
  generate a new `x25519` key pair and persist it.
- The new identity MUST be immediately usable for new Noise XX
  handshakes.

### Non-Guarantees

- MeshX MUST NOT recover the previous key pair. Identity loss
  is treated as a new node birth.
- MeshX MUST NOT automatically notify peers of the identity
  change. Peers that had the old public key pinned in
  `MeshxStore.Trust` will see the new key as untrusted.
- All existing `MeshxStore.Trust` records for this node's own
  `peer_id` on *remote* nodes are outside MeshX's control and
  MUST NOT be assumed to update automatically.

### Application Recovery

The application SHOULD treat identity loss as a catastrophic
security event. Recommended recovery:

1. Alert the operator.
2. Re-establish trust out-of-band (re-pin keys, re-scan QR
   codes, re-exchange fingerprints).
3. Optionally wipe `MeshxStore.Trust` locally and start fresh
   if the node has no prior relationships it needs to preserve.

---

## 6. Storage Corruption

A **storage corruption** is the situation where the CubDB data
files are partially or wholly unreadable.

### Triggers

- Disk-full during a CubDB compaction.
- Power loss mid-write.
- Filesystem bug or media degradation.
- Operator overwriting files with unrelated data.

### Guarantees

- CubDB itself provides ACID guarantees for individual writes.
  A crash during compaction MUST leave the database in a
  consistent prior state (CubDB's copy-on-write semantics).
- If CubDB detects a checksum mismatch or unreadable file on
  open, it MUST raise at startup.

### Non-Guarantees

- MeshX MUST NOT silently repair corrupted CubDB files.
- MeshX MUST NOT continue operating with partial data.
- MeshX MUST NOT provide automatic point-in-time recovery
  beyond what CubDB's built-in compaction history provides.

### Application Recovery

The operator MUST:

1. Stop the node.
2. Assess whether the corruption is in the main database or a
   compaction artifact.
3. Either restore from a filesystem-level backup taken while the
   node was stopped, or delete the data directory and allow the
   node to reinitialize (accepting identity loss and outbox
   loss).

There is no in-place repair tool provided by MeshX.

---

## 7. Replay Window Expiry

A **replay window expiry** is the situation where a peer
reconnects after a long enough absence that the local dedupe
window (`MeshxStore.Dedupe`) has already evicted the message
IDs it is now re-sending.

### Triggers

- Peer offline longer than the dedupe TTL (default 5 minutes).
- Peer clock skew causing it to emit old `msg_id` values.
- Byzantine peer deliberately re-emitting historical messages.

### Guarantees

- MeshX MUST accept and deliver a message whose `msg_id` is no
  longer in the dedupe cache, because the cache is bounded and
  eviction is expected.
- MeshX MUST still apply TTL-based relay limits (`ttl > 0`) so
  ancient messages do not circulate forever.

### Non-Guarantees

- MeshX MUST NOT guarantee exactly-once delivery across replay
  window expiry. At-most-once is guaranteed; exactly-once is
  not.
- MeshX MUST NOT cryptographically bind `msg_id` to payload.
  `msg_id` collision by a different sender is possible (though
  statistically unlikely with large random IDs).

### Application Recovery

The application SHOULD design its subscriber logic to be
idempotent. If a message cannot safely be processed twice, the
application MUST maintain its own application-level deduplication
or version vector.

---

## Failure Domain Matrix

| Domain | Durable State | Ephemeral State | Auto-Recover | App Action |
|--------|-------------|-----------------|--------------|------------|
| Process failure | Identity, Trust, Outbox, Message | Dedupe, RelayCache, FlowControl | Yes (supervisor) | None |
| Node failure | Identity, Trust, Outbox, Message | Dedupe, RelayCache, FlowControl | On boot | None |
| Transport failure | Outbox (pending) | Sessions, FlowControl windows | No (transport) | Optional restart |
| Network partition | Outbox (pending) | None | On heal | None |
| Identity loss | Trust, Outbox (orphaned) | All | Yes (new key) | Re-establish trust |
| Storage corruption | None if unrecoverable | All | No | Restore or wipe |
| Replay window expiry | N/A | Dedupe entry gone | N/A | Idempotent subscribers |

---

*This document is normative for MeshX v1. Updates that change a
failure guarantee are v2 conversations.*
