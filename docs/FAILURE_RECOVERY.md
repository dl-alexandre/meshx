# Failure Recovery

This document is a playbook for the failure modes a MeshX operator is most
likely to hit. Each scenario has a **Detection** (how you know it's
happening), **Diagnosis** (what to check), and **Recovery** (what to do).

For metric event names referenced below see [`METRICS.md`](METRICS.md).

## 1. Peer cannot reach this node

**Detection**

- A specific `peer_id` never appears in `[:router, :peer, :up]`.
- The peer reports it is sending but the runtime never receives.

**Diagnosis**

```elixir
MeshxRuntime.PeerRegistry.list()         # Is the peer there at all?
MeshxRuntime.PeerRegistry.get("peer-x")  # What was the last known state?
:inet.getstat(some_socket)               # TCP-level health
```

Common causes:

1. Firewall / security group blocks the port.
2. NAT rebound and the peer hasn't re-issued its hello (UDP).
3. Wrong `MESHX_NODE_ID` on either side — IDs must match what's in
   metadata exchanges.
4. TLS / Noise key mismatch (peer rejects handshake silently).

**Recovery**

- Verify reachability with `nc`, `tcpdump`, or `dig`.
- For UDP: bump `keepalive_ms` lower so NAT mappings stay warm.
- For Noise mismatches: see [`KEY_ROTATION.md`](KEY_ROTATION.md).

## 2. Outbox backlog grows unbounded

**Detection**

- `[:outbox, :enqueue, :stop]` rate ≫ `[:outbox, :replay, :stop]` rate.
- CubDB store grows on disk; pending outbox row count climbs.

**Diagnosis**

```elixir
MeshxStore.Outbox.pending_for_destination("peer-x", 1000) |> length()
MeshxStore.Outbox.pending(1000) |> length()
```

The destination peer is offline longer than the configured retry window,
or the destination is up but ACKs aren't coming back (so `record_attempt`
keeps re-queuing).

**Recovery**

- Confirm peer reachability (scenario 1).
- Check `[:router, :ack, :received]` — if ACKs are arriving but rows aren't
  cleared, there's a dest-id mismatch between sender and receiver. Fix the
  ID on one side.
- For abandoned destinations, decide whether to leave rows until retry
  exhaustion or clear the outbox after documenting the data-loss decision.

## 3. Frequent `decode_error` events

**Detection**

- High rate of `[:router, :frame, :decode_error]` or
  `[:router, :packet, :decrypt_error]`.

**Diagnosis**

Either:

1. A peer is running an incompatible MeshX protocol version (check
   `MeshxProtocol.Packet.version/0` on both ends).
2. A peer has a stale Noise session (its session keys no longer match
   ours), usually after one side restarted without the other noticing.
3. Something on the path is mangling frames — proxy, IDS, NAT with deep
   packet inspection.

**Recovery**

- Force a new handshake by triggering peer down / up, or call
  `MeshxRuntime.SessionManager.reset_peer("peer-x")`.
- If protocol versions differ, plan an upgrade — the wire format is not
  backward-compatible across major versions.

## 4. Noise handshake repeatedly fails

**Detection**

- `[:router, :noise, :error]` and `[:noise, :handshake, :error]` recur for
  the same `peer_id`.

**Diagnosis**

```elixir
MeshxRuntime.SessionManager.status("peer-x")
```

Likely causes:

- Static key rotation went half-way (some peers updated, others didn't).
- Trust table missing the peer's new public key.
- Noise pattern mismatch (rare; only if the codebase was forked).

**Recovery**

- Cross-check trust:
  ```elixir
  MeshxStore.Trust.list_for_node("peer-x")
  ```
- If rotating keys, finish the rotation per
  [`KEY_ROTATION.md`](KEY_ROTATION.md).
- As a last resort, purge the session and let it re-handshake:
  ```elixir
  MeshxRuntime.SessionManager.reset_peer("peer-x")
  ```

## 5. CubDB store corruption

**Detection**

- BEAM startup fails while opening `MeshxStore.DB`.
- The CubDB data directory may become inconsistent after a crash or partial
  backup restore.

**Diagnosis**

Check the configured `MESHX_STORE_DATA_DIR`, disk health, permissions, and
whether the directory came from a complete stopped-runtime backup or filesystem
snapshot.

**Recovery**

1. Stop the runtime.
2. Restore the most recent complete data-directory backup.
3. If no backup exists, move the broken directory aside and start fresh:
   ```bash
   mv /var/lib/meshx/store /var/lib/meshx/store.broken
   mkdir -p /var/lib/meshx/store
   ```

The store carries dedupe state, relay cache, outbox, and identity/trust.
A fresh store means: dedupe forgets prior msg_ids (some replays may slip
through transient peers), the outbox is empty (pending packets lost), and
identity/trust must be re-established.

## 6. BEAM node crashes on startup

**Detection**

- Release fails to boot. Logs show stacktrace from `Application.start/2`.

**Diagnosis**

Check the order in which apps fail. `meshx_store` needs the CubDB data
directory writeable. `meshx_runtime` will not start without
`meshx_transport` and `meshx_noise`.

**Recovery**

- File permissions: `chown -R meshx:meshx /var/lib/meshx`.
- Data directory missing: create the configured `MESHX_STORE_DATA_DIR` or allow
  `MeshxStore.DB` to create it with a writeable parent directory.
- Stale store state: stop the runtime before moving or restoring the CubDB data
  directory.

## 7. Backpressure drops on a hot peer

**Detection**

- `[:router, :backpressure, :dropped]` count > 0 for `peer_id`.

**Diagnosis**

The per-peer in-flight queue is full. Either the peer is slow at ACKing
(network issue) or the application is sending faster than the peer can
process. Inspect:

```elixir
:sys.get_state(MeshxRuntime.Router).flow
```

**Recovery**

- Application-level: throttle the producer. MeshX is not designed to
  backpressure unbounded fan-out.
- Tuning: increase `:flow_control` opts (`send_window`, `queue_limit`) in
  `config/runtime.exs` if drops are spurious bursts. Be careful — larger
  windows trade memory for tolerance.
- Disconnect and reconnect the peer if its ACK path is permanently broken
  (e.g. ACKs are arriving but for stale msg_ids).

## 8. Whole-cluster partition

**Detection**

- All nodes simultaneously report each other as `:peer_down`.
- Region- or AZ-wide outage.

**Diagnosis**

Network-layer fault outside MeshX. Investigate at the cloud / network
provider level.

**Recovery**

MeshX's job during a partition is to **survive and resume**:

- Outbox queues fill on each node — they are durable across the
  partition (CubDB persists).
- Peers replay queued packets to each other on reconnect.
- Dedupe ensures replays are not delivered twice to the application.

When the partition heals, expect a burst of:

- `[:router, :peer, :up]`
- `[:outbox, :replay, :stop]`

If the burst causes backpressure (scenario 7), that is the signal to
increase queue limits and / or stagger reconnects.
