# Advertisement-Only Local Inbox Persistence Policy

M86-M90 defines the persistence policy for MeshX's advertisement-only
local inbox. M106-M110 adds a small durable store boundary that writes
only this policy-approved shape. M111-M115 adds a restored read model
for querying saved snapshots.

## Current Scope

`Mob.Node.BLE.LocalInboxPersistencePolicy` converts a
`LocalInbox.snapshot/1` value into a JSON-safe durable snapshot candidate
with an injected `persisted_at` timestamp.

The snapshot may contain:

- full messages as canonical M14 `MessageEnvelope` wire bytes plus
  observation counters;
- unresolved legacy beacon references as hashes plus observation
  counters;
- the advert-only transport profile and capability notes;
- the policy version and retention settings that produced the snapshot.

`Mob.Node.BLE.LocalInboxStore` can save, load, delete, and clear
these durable snapshot candidates through `Mob.Store.DB`. Callers still
own when to invoke it; there is no automatic write loop, background
worker, sync, migration, or cleanup scheduler.

`Mob.Node.BLE.LocalInboxDurableSnapshot` can restore a saved
durable snapshot into a read-only shape with `nearby_messages`,
`trust_evidence`, and `resolution_statuses`. This lets product/API code
query saved snapshots with `LocalInboxQuery` without replaying raw BLE
events or rebuilding the live in-memory inbox.

`Mob.Node.BLE.LocalPersistenceNegativeValidation` records the
current blocked claim matrix for this boundary. Opt-in snapshots cannot
be promoted to default lifecycle persistence, persisted beacon refs
cannot become delivery records, manual prune calls cannot become
scheduled cleanup, foreground/session save hooks cannot become
background-safe writes, and durable read models cannot become raw
hardware evidence archives.

## Durable Full Messages

Full messages may be persisted only when they came from validated
`FullEnvelopeInbox.Entry` values. Before a full message is emitted into
the durable snapshot, the policy re-encodes and parses the embedded
`MessageEnvelope` and checks that message id, sender peer id, and
recipient peer id match the inbox entry.

The durable full-message shape stores:

- `kind: :full_message`;
- no-padding base64 `message_id`;
- `sender_peer_id`;
- optional `recipient_peer_id`;
- `envelope_version`;
- `payload_kind`;
- canonical no-padding base64 `envelope_wire`;
- `first_seen_at`;
- `last_seen_at`;
- `seen_count`;
- `source_device_count`;
- `last_rssi`.

Raw transport metadata is never persistable.

## Durable Beacon References

Legacy beacons remain references, not delivered messages. The durable
beacon-ref shape stores:

- `kind: :unresolved_beacon_ref`;
- `delivery_state: :unresolved`;
- no-padding base64 `message_id_hash`;
- no-padding base64 `sender_peer_hash`;
- `envelope_version`;
- `payload_kind`;
- `first_seen_at`;
- `last_seen_at`;
- `seen_count`;
- `source_device_count`;
- `last_rssi`;
- `observed_via`.

Persisting a beacon ref does not imply authorship, trust, delivery,
resolution, fetch success, or payload access.

## Retention

The default policy is conservative:

- full messages: retain for 7 days from `last_seen_at`;
- beacon refs: retain for 24 hours from `last_seen_at`;
- source device ids: excluded by default;
- raw transport metadata: always excluded.

Source device ids can be included only through an explicit diagnostic
policy option. Raw transport metadata cannot be opted in because it may
contain platform-specific identifiers and unbounded adapter details.

## Non-Goals

M86-M90 adds the policy and M106-M110 adds the explicit store adapter.
M111-M115 adds restored read models over saved snapshots. Together they
still add no background writer, no automatic app lifecycle hook, no
migration system, no cleanup process, no sync, no routing, no fetch
transport, no GATT, no ACKs, no retries, no crypto, no replay
protection, and no Android/iOS native behavior.
