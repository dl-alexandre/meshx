# Mob.Noise

Noise protocol session support for MeshX.

`Mob.Noise.Session` wraps Decibel in a GenServer so each Noise state machine is
isolated in its own BEAM process. The app currently supports Noise XX session
setup, encryption, decryption, handshake hash access, remote key access, and a
dynamic supervisor for per-peer runtime sessions.

## Group (channel) encryption — Sender Keys

For broadcast/group chat where pairwise Noise sessions don't apply, this app
also provides a Signal-style **Sender Keys** stack:

- `Mob.Noise.SenderKey` — HMAC symmetric ratchet (message key = `HMAC(ck, 0x01)`,
  next chain key = `HMAC(ck, 0x02)`).
- `Mob.Noise.GroupCipher` — ChaCha20-Poly1305 (`:crypto`) with a single-use
  nonce derived from each message key.
- `Mob.Noise.GroupSession` — one sending chain plus per-sender receiving chains,
  with a skipped-key cache for out-of-order delivery, replay rejection, and a
  `max_skip` guard.
- `Mob.Noise.SenderKeyDistribution` — the 40-byte SKDM wire format used to share
  a sender's chain key with the group.

**Threat model.** Group chat is *confidential to current key-holders*. Forward
secrecy comes from the one-way ratchet (a joiner cannot read history), but there
is **no enforced member removal**. Sender Keys are symmetric, so **any current
key-holder can forge a message as another member** — authenticity is at the
group level, not per-author. Closing this requires per-message signatures
(SKDM v2), which is not yet implemented. Do not use this stack where
per-sender non-repudiation within a group is a requirement.
