# Key Rotation

MeshX uses **Noise XX** for end-to-end secrecy between peers. Each node
holds a static keypair plus per-session ephemeral keys derived during the
handshake. This document describes how to rotate the static keypair safely,
what the impact is on in-flight sessions, and how trust state in
`Mob.Store.Trust` interacts with rotation.

## Key material

| Material | Lifetime | Where it lives | Rotated by |
| --- | --- | --- | --- |
| Noise static keypair | Long (months) | `Mob.Store.Identity` in the CubDB store | This procedure |
| Noise ephemeral keys | Per-session | In-memory only | Automatic (every handshake) |
| Session symmetric keys | Per-session | In-memory only | Automatic (handshake / rekey) |
| Trust records | Long | `Mob.Store.Trust` in the CubDB store | Manual operator action |

You only ever need to rotate the **static keypair**. Ephemeral and session
material rotates automatically on every new handshake.

## Why rotate

- The CubDB data directory or exported identity was exposed (laptop loss, repo
  leak, container snapshot shared with an untrusted party).
- A team member with access leaves.
- Periodic policy (e.g. quarterly).
- After upgrading to a Noise pattern that requires fresh keys.

## Procedure

### 1. Generate a new keypair

```elixir
# In an IEx session on a stopped or drained node:
Mob.Store.Identity.clear()
{:ok, identity} = Mob.Store.Identity.ensure_local()
identity.public_key
```

The private key remains in the node's CubDB data directory. Treat that
directory as secret key material.

### 2. Distribute the new public key out-of-band

Peers that pin keys (most production deployments) need the **new public
half** before you swap. Push it via your config management tool, then ask
every peer to pin it for this node.

```elixir
# On each peer:
Mob.Store.Trust.pin("relay-east-1", <<...>>)
```

The current trust store keeps one key per peer, so coordinate rotation during a
maintenance window or deploy explicit multi-key trust support before using
overlapping keys.

### 3. Restart the node

On the node being rotated, restart the runtime so `SessionManager` loads the
new static key:

```bash
systemctl restart mob-runtime   # or your release's restart script
```

In-flight sessions are torn down by the restart. The runtime re-initiates
Noise XX on the next packet to each peer. Peers that already have the new
public key in `Trust` will accept the new handshake.

### 4. Retire the old key

After every peer has confirmed it has handshaken successfully against the
new key (visible as `[:mob_runtime, :noise, :handshake, :established]`
events), leave the new pinned key in place and retire any external record of
the old public key from your configuration management system.

## Impact on in-flight traffic

- **Sessions**: torn down at restart. Outbox packets remain queued and are
  replayed when the new session is established (default `max_attempts: 5`).
- **Encrypted packets in flight**: dropped if they were encrypted with the
  old session's keys after restart. The dedup table preserves msg_ids, so
  replay at the application layer is safe.
- **ACKs**: ACKs for pre-rotation packets that arrive after restart will be
  dropped (the corresponding outbox row is still pending and gets replayed).

## Emergency rotation (key compromise)

If you believe the static private key is in adversary hands:

1. Rotate immediately. Do not wait for the crossover window.
2. **Remove** the old public key from every peer's trust table at the same
   time you swap. Any handshake from the old key will be rejected.
3. Audit `[:mob_runtime, :noise, :handshake, :error]` events from the
   period of compromise — these may indicate active misuse attempts.
4. Re-key downstream secrets that flowed through MeshX during the window.
   MeshX's own session keys are forward-secret per session, but
   application-layer secrets you transported are not.

## Automation

The procedure above is scriptable, but MeshX does not currently ship a dedicated
rotation task. A typical playbook should:

- stop or drain the target runtime;
- run `Mob.Store.Identity.clear()` and `Mob.Store.Identity.ensure_local()`;
- capture and distribute the new `identity.public_key`;
- run `Mob.Store.Trust.pin/2` on peers that use pinned trust;
- restart the target runtime.

Wait at least one full reconnect cycle (~30s default) before retiring the
old key.
