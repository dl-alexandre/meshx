# BLE Transport Strategy

M41 records the current transport decision after the M37-M40 Android
GATT validation work. M66 adds the concrete re-evaluation gate in
`docs/ble_transport_re_evaluation.md`.

## Decision

GATT fetch is blocked for the current Android hardware pair:

- Samsung SM-T577U, Android API 33
- Samsung SM-T390, Android API 28
- Failure: Android `gatt_status=133`, normalized as
  `android_gatt_error`, before service discovery
- Reproduced in both directions with the constrained MeshX fetch path
- Reproduced in both directions with the standalone M40 GATT interop
  harness, without `MessageEnvelope`, fetch protocol, legacy beacon,
  planner, ledger, replay, routing, crypto, or persistence
- Reconfirmed on May 12, 2026 after waking both devices and dismissing
  keyguard; current rerun logs live under `/tmp/mob-android-m40-current`

Conclusion: this is transport/platform behavior for this hardware pair,
not a MeshX protocol failure.

## Runtime Posture

The GATT fetch path is experimental and disabled by default. It is
reachable only through explicit Android debug/validation actions. When
attempted, Android logs `fetch_gatt_experimental_warning` with the local
device model/API, adapter state, target address, and known blocked-pair
diagnostic.

The M40 standalone GATT harness remains in the Android app as a
diagnostic tool. It is not part of MeshX message delivery.

## Transport Options

| Transport | Current Use | Strengths | Limits | Decision |
| --- | --- | --- | --- | --- |
| Full envelope advertisement | M14 `MessageEnvelope` in BLE advertisement on capable Android hardware | Single-hop, no connection, canonical full `received_message` possible | Requires extended advertisement support and observer compatibility; SM-T390 did not observe SM-T577U extended adverts | Use only when capability-proven for both sender and observer |
| Legacy beacon advertisement | 22-byte `received_message_beacon` reference | Works within legacy advertisement budget; preserves envelope contract by not faking delivery | Reference only; not full message delivery; requires later resolution path | Recommended path for old Android hardware |
| GATT fetch | M33-M36 constrained fetch spike | Could resolve a beacon into full envelope without fragmentation if hardware supports GATT | Blocked on SM-T577U/SM-T390 with status 133 before service discovery; connection behavior is platform-sensitive | Defer until a known-good hardware pair validates it |
| Future alternatives | TBD | Can be selected based on measured hardware behavior | Must avoid fake success and preserve canonical event distinction | Investigate only after current advertisement-first path is stable |

## Recommended Next Path

For older Android hardware, use advertisement-only message beacons as
the proof path. A legacy beacon is a pointer/reference, not message
delivery.

Use full-envelope advertisements only when the sender and observer have
capability-proven support for the required advertisement size and scan
compatibility.

Defer GATT fetch until tested on a known-good hardware pair. Keep the
offline/fake M33-M36 fetch contracts and tests intact so the pure
resolution pipeline remains deterministic while transport validation is
blocked.

## Current Local Mode

M42-M45 defines the current validated local mode as advertisement-only:

- legacy beacon advertisements populate an unresolved beacon inbox;
- full-envelope advertisements populate a full-message inbox only after
  the embedded M14 envelope validates;
- a unified local snapshot exposes full messages, unresolved beacon
  references, and advert-only capability notes;
- no GATT, ACKs, retries, persistence, routing, crypto, or background
  service behavior is involved.

This is enough for MeshX to show "messages seen nearby" from passive BLE
advertisement observations. Old Android devices remain useful through
beacon refs, while capability-proven hardware can surface full
advertisement messages.

## Opportunistic Gossip Planning

M50-M55 keeps advertisement-only local mesh as the validated mode and
adds a pure planning layer on top of `LocalInbox.snapshot/1`. The
planner can turn nearby full-message entries and unresolved beacon refs
into deterministic gossip intents, with an in-memory suppression ledger
to avoid immediate repeat planning.

Full messages default to legacy beacon gossip. Full-envelope gossip is
planned only when the caller explicitly marks that advertisement path as
capability-proven. A dry-run dispatcher emits auditable outcomes, but no
BLE radio call or native transport behavior is introduced.

## Constrained Gossip Execution

M56-M58 adds Android execution for the legacy beacon subset of gossip
intents. The runtime can now distinguish planning evidence from execution
evidence through canonical `advert_gossip_outcome` events.

The Android execution path accepts only compact beacon fields and emits a
22-byte legacy manufacturer-data advertisement. It does not require the
full `MessageEnvelope`, and it does not convert a beacon reference into a
fake full message. Full-envelope gossip is still skipped until a later
capability-proven milestone wires that path explicitly.

## Hardware Gossip Proof

M59-M61 validated the legacy beacon gossip path from SM-T577U to
SM-T390. The sender emitted `advert_gossip_outcome kind=gossiped` and
`legacy_beacon_gossip_started`; the observer logged matching canonical
`received_message_beacon` events for the same beacon payload and hashes.

Artifact summary:

```
/tmp/mob-android-m59-gossip-live/summary.json
```

This keeps the current transport recommendation unchanged:
advertisement-only local mesh is the validated local mode, and old
Android hardware participates through beacon references rather than
full-envelope or GATT fetch behavior.

## Consumer Surface

M62-M65 exposes the validated local mode to consumers through
`Session.snapshot/1`. The snapshot now carries `local_inbox`, preserving
the split between full nearby messages and unresolved beacon references.
The Mob screen renders that state as "Nearby Messages" with local
filters, sort controls, selectable rows, and detail text driven by the
native local inbox surface model.

This is still a local, in-memory observation surface. It does not make
beacon refs into delivered messages and does not add fetch, routing,
ACKs, retries, persistence, crypto, fragmentation, or background
behavior.

## Re-Evaluation Gate

GATT fetch remains experimental and disabled until the M66 gate is
satisfied. The gate requires a known-good hardware pair to first pass
the standalone GATT interop harness and then pass one constrained fetch
of a full canonical `MessageEnvelope`. The current SM-T577U/SM-T390
pair does not satisfy this gate because it already failed before service
discovery with Android status 133.

## Replay Gossip Simulation

M67-M70 adds a replay-only simulator for multi-hop advertisement gossip.
It uses local inbox snapshots and planned legacy beacon gossip intents to
model how refs would move across a topology, including TTL, hop count,
path provenance, loop suppression, duplicate suppression, and a
deterministic delivery ledger.

This is deliberately not a live routing or transport feature. It is the
protocol proving ground before any future hardware gossip expansion.

## Gossip Policy Gate

M71-M75 hardens that simulator with explicit policy defaults and
validation. Multi-hop advert gossip now has bounded `default_ttl`,
`max_hops`, per-neighbor cooldown, and malformed-provenance rejection in
the replay model. Future hardware gossip work should preserve these
same decisions as auditable outcomes rather than silently dropping or
forwarding refs.

## Scenario Audits

M76-M80 adds JSON scenario fixtures and a CLI audit task for the replay
gossip model. The fixtures pin expected delivery counts, node inbox
counts, and delivered paths for line, triangle, and partitioned
topologies. This is the regression gate for gossip policy changes before
any hardware expansion.

## Local Inbox UX States

M81-M85 adds a read-only local inbox view for product consumers. Nearby
items are classified as full messages, unresolved refs, gossiped refs,
or stale refs. These are display states over local observations, not new
transport semantics.

## Non-Goals

M41 does not add protocol behavior, routing, crypto, persistence, retry
loops, background services, or new BLE transport implementation. It is a
decision ledger and runtime warning layer over the existing diagnostic
code.
