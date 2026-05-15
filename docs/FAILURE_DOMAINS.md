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

## 8. BLE Transport — Platform-Specific Failure Modes

BLE introduces failure modes that don't apply to TCP or UDP because the
transport is a constrained radio with platform-specific scan, advertise,
and connection state managed by the OS. These are recorded here so
operators can diagnose them from logcat / device state instead of from
behavior alone — most surface as **silent degradation** rather than
explicit errors at the Elixir layer.

### Android scan-frequency throttle

Android limits an app to **5 `BluetoothLeScanner.startScan` calls per
30 seconds**. Crossing the threshold puts the app into "opportunistic
scanning" mode for the next ~30 minutes: `startScan` returns
successfully, `onScanFailed` is *not* called, but `onScanResult`
delivers far fewer (often zero) callbacks. The throttle state is
per-app and persists across:

- BluetoothAdapter disable/enable
- App force-stop and relaunch
- Device reboot (in some cases — observed on API 33 hardware)

Detection signal: `start_scan` returns `:ok` to the BEAM, MeshX
runtime logs `meshx_runtime started`, but the scanner produces no
`DeviceDiscovered` / `AdvertisementReceived` events over a long
window. The only reliable diagnostic is comparing logcat
`BtGatt.GattService onScanResult` lines for the app's scanner-id
against `MeshxBle` event lines.

Mitigation: don't restart scans rapidly during development. The
`BleSelfTest` probe keeps a single scan open for the entire session
to avoid this. Production code should hold one scan registration per
session and use callback dedup (next section) rather than start/stop
cycles.

### `CALLBACK_TYPE_ALL_MATCHES` inflates message counts

`ScanSettings.CALLBACK_TYPE_ALL_MATCHES` (the mode `BleScanner` uses
for low-latency mesh discovery) delivers a callback for every
advertising event in a peer's advertise window — typically 15–50
callbacks per 5-second legacy beacon at the default ~100–300 ms
advertising interval.

Reliability claims expressed as "messages received" must dedup on
`{sender_peer_id_hash, message_id_hash}` (for beacons) or
`{sender_peer_id, message_id}` (for full envelopes). `BleSelfTest`'s
`distinct_msgs` counter is this canonical metric; the
`beacon_callbacks` counter is kept only for diagnostic context.

### Async `BluetoothAdapter.setName`

`adapter.name = localName` is asynchronous on Android. An advertiser
that does `setName` then immediately calls `startAdvertising` with
`setIncludeDeviceName(true)` will broadcast the *previous* adapter
name in the first advertising packet — the rename propagates only on
later packets. MeshX's `BleAdvertiser` carries `localName` as
manufacturer data (company id `0xFFFF`) so it lands in the first
packet synchronously; the device-name path is kept only as a
fallback for scanners that filter by name.

### Extended advertising scan support is per-device

BLE 5 extended advertising allows advertising payloads up to ~1024
bytes (vs. 24 bytes for legacy manufacturer data). A device whose
controller supports *sending* extended advertisements may still be
unable to *scan* them. The Galaxy Tab Active 2 (API 28, 2018) is an
observed example: it can send legacy beacons fine and scans legacy
fine, but it cannot decode extended advertisements at all.

`BleDispatcher` exposes `forceLegacyBeacon: true` for this case. The
MeshX mobile-app self-test uses it so the message-reference exchange
is symmetric across the fleet. Full payloads that won't fit a legacy
beacon need the GATT-fetch path, not extended advertising, if older
devices must participate.

### Concurrent advertising sets degrade unequally

`isMultipleAdvertisementSupported` returns `true` on most Android
devices since API 26, but the *quality* of multi-set time-slicing
varies by silicon generation:

- 2021+ controllers (Galaxy Tab Active 3, etc.) handle 3–5 concurrent
  advertising sets with even slot allocation.
- 2018-era controllers often implement "multiple advertising" in
  firmware or host software; two concurrent sets means the radio is
  literally duty-cycling between them with non-uniform slot widths.

This shows up as *asymmetric delivery rates* in two-device tests.
MeshX runs a continuous name beacon plus 5-second dispatch bursts;
on older hardware the dispatch beacon gets less air time, and its
scanner concurrently sees fewer of the peer's adverts. The
asymmetry compounds. The fix isn't code — it's understanding that
the older device will report fewer messages received than the newer
device sees, and that *both* directions still work.

### Permission gates

Per-API runtime permission set the adapter must hold:

| Android version | Required runtime permissions |
|---|---|
| ≤ API 30 | `ACCESS_FINE_LOCATION` (scan), `BLUETOOTH` and `BLUETOOTH_ADMIN` (install-time) |
| API 31+ | `BLUETOOTH_SCAN` (with `neverForLocation`), `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` |

`BluetoothLeScanner.startScan` and `BluetoothLeAdvertiser.startAdvertising`
throw `SecurityException` when a permission is missing. `BleScanner`
catches and emits a canonical `BleEvent.Error(kind = :unauthorized)`;
the Elixir side sees it as `%MeshxMobileApp.BLE.Events.Error{kind: :unauthorized}`.

App reinstall (`mix mob.deploy --native`) revokes runtime grants on
API 31+. Re-grant via `adb shell pm grant <pkg> android.permission.<perm>`
or in-app permission flow.

### `decodeScanRecord` decode errors

`MeshxMessageAdvertisement.decodeScanRecord` returns:

- `NotMessageAdvertisement` — the advert has no MeshX manufacturer
  entry (most ambient devices). Surfaced as `DeviceDiscovered` /
  `AdvertisementReceived`.
- `Received(ReceivedMessage)` — full v1 envelope, magic `MX`.
- `ReceivedBeacon(ReceivedMessageBeacon)` — 22-byte legacy beacon,
  magic `MB`.
- `Error(BleEvent.Error)` — manufacturer entry has MeshX company id
  and magic but the payload doesn't parse. Truncated advert
  structures and unsupported envelope versions land here. The error
  surfaces as `%MeshxMobileApp.BLE.Events.Error{}` with
  `detail` carrying the parse reason.

The Elixir `BridgeProtocol.decode` JSON-wire path was previously
strict-validating the base64 form of binary fields (notably
`message_id_hash`), so a correctly-formatted beacon could *cross the
air, decode in Kotlin, and reach the BEAM* yet still be rejected at
the Elixir boundary with `{:received_message_beacon_invalid_field,
:message_id_hash}`. The fix is to base64-decode known binary fields
in `atomize_top_level` and `atomize_metadata` (commit `cd5b473`).
Any future binary field added to a v1 event MUST be added to
`@b64_top_level_fields` or `@b64_metadata_fields`.

### Legacy beacon size budget

`BleDispatcher.MAX_LEGACY_MANUFACTURER_PAYLOAD = 24` bytes. The MeshX
v1 envelope header alone is 26+ bytes (4 magic + 16 message_id + 8
created_at + ttl + length-prefixed fields), so a *full envelope*
never fits in legacy advertising — it requires either extended
advertising or the legacy-beacon fallback (`MB` magic, 22 bytes:
6-byte header + 8-byte message-id hash + 8-byte sender-peer-id hash).

The beacon carries a message *reference*, not the payload bytes.
Subscribers that need the full payload retrieve it via the GATT-fetch
protocol (`MeshxFetchGatt`) keyed on the message-id hash. A subscriber
that only sees `ReceivedMessageBeacon` events and never the
corresponding `ReceivedMessage` is observing the advert-only
transport profile working as designed.

### Doze / background mode

Android Doze (entered after ~1 hour of screen-off + stationary)
**suspends** non-foreground BLE scan and advertise. The MeshX mobile
app holds a `BeamForegroundService` (from the Mob template) to keep
the BEAM resident, but the BLE adapter itself is subject to OS
constraints regardless of the BEAM running.

Observable effects:
- `start_scan` continues to return `:ok` but `onScanResult` stops firing.
- `BleAdvertiser.start` succeeds but the radio is idled.
- On wake, both resume without re-registration — the OS holds the
  scanner/advertiser handles across Doze cycles.

The Elixir runtime sees this as a partition (no peer-discovery
events) rather than a transport failure. The Outbox holds pending
sends across the Doze window and replays on wake when peers
reappear (per the Transport Failure section above).

### Triggers (BLE-specific)

- Scan-frequency throttle from too many `startScan` cycles
- Async `setName` not propagated before first advertise
- Concurrent advertising set contention on older controllers
- Doze / background mode suspension
- Runtime permission revocation (app reinstall, user revoke)
- Adapter power-down / airplane mode

### Guarantees

- A scan that returns `:ok` and is not throttled delivers every
  scan result the OS surfaces to the app.
- A successful `BleDispatcher.dispatch(DISPATCHED)` indicates the
  BLE stack accepted the advertise; it does *not* guarantee the peer
  received the packet (no ACK at the BLE layer).
- Beacon dedup by `{sender_peer_id_hash, message_id_hash}` is
  collision-resistant within the runtime's replay window
  (8-byte hash space, ~10^19 keys).

### Non-Guarantees

- No delivery confirmation at the BLE layer (advert-only profile).
- No ordering guarantee between two beacons advertised by the same
  sender (scan callback order does not correlate with advertise
  order across separate windows).
- No symmetry of delivery rate between two peers of different
  hardware generations.
- No persistence of MeshX BLE state across app reinstall (runtime
  permissions reset, scan throttle state may or may not reset
  depending on Android version).

### Application Recovery

- Permissions: catch `%Events.Error{kind: :unauthorized}` and trigger
  the platform permission prompt.
- Scan throttle: avoid rapid scan start/stop cycles in production;
  hold one scan registration per session.
- Doze: rely on the outbox + peer-reappearance replay path. No
  application action required.
- Adapter off: catch `%Events.Error{kind: :bluetooth_off}` and surface
  a UI prompt; resume happens automatically when the adapter is
  enabled (peers re-discover on next scan window).

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
| BLE platform | Outbox (pending) | Scan/Advertise registration, dedup window | On Doze wake / re-grant | Permission flow on revoke |

---

*This document is normative for MeshX v1. Updates that change a
failure guarantee are v2 conversations.*
