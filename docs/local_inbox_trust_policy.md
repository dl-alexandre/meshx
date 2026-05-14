# Advertisement-Only Local Inbox Trust Policy

M91-M95 makes the security posture of the advertisement-only local inbox
explicit in data.

BLE advertisement observations are useful local signals, but current
MeshX BLE beacon/message refs have no cryptographic proof of authorship,
no authenticated peer identity, and no replay protection. A hash inside
a legacy beacon is a pointer, not an identity claim.

## Classification

`MeshxMobileApp.BLE.LocalInboxTrust` classifies nearby inbox entries:

- full-envelope advertisements become `:unsigned_observation`;
- unresolved, gossiped, and stale beacon refs become
  `:untrusted_reference`;
- all current entries report `authorship: :unverified`;
- all current entries report `replay_protection: :none`.

`MeshxMobileApp.BLE.LocalTrustPolicy` turns that evidence into
presentation decisions:

- full-envelope advertisements may be displayed only as
  `:local_unsigned_message`;
- legacy beacon refs may be displayed only as
  `:local_untrusted_reference`;
- `trusted_message?` is false for every current local BLE observation;
- `delivery_claim_allowed?` is false for every current local BLE
  observation.

The policy is a product/API guardrail, not an implementation of
identity, signatures, replay protection, or trust transitions.

Full-envelope advertisements carry stronger integrity evidence than
beacon refs only because the local inbox has already validated the
canonical M14 `MessageEnvelope` bytes. That still does not prove who
authored the message.

Beacon refs are classified as `:hash_reference_only` because the full
envelope is absent. They remain unresolved pointers until a future
authenticated resolution path exists.

## Snapshot Surface

`LocalInbox.snapshot/1` now includes `trust_evidence` beside
`nearby_messages`. This gives UI, storage, and future sync consumers a
stable read model that prevents accidental wording like "trusted",
"verified", or "sent by" for passive BLE observations.

The snapshot also includes `security_identity_contract`, produced by
`MeshxMobileApp.BLE.LocalSecurityIdentityContract`. That contract lists
the proof categories required before any local BLE observation can be
promoted from unsigned/untrusted evidence:

- authenticated peer identity;
- message authorship proof;
- replay protection;
- trust policy;
- beacon ref authentication or authenticated full-envelope resolution.

These requirements are data only. They do not verify signatures, manage
keys, create a trust store, or change message handling.

## Non-Goals

This trust/security surface adds no crypto, signatures, Noise handshake,
authenticated identity binding, trust store, replay protection, fetch
transport, routing, persistence, GATT, ACKs, retries, background
service, or Android/iOS native behavior.
