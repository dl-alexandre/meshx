# Mob.Runtime

Top-level OTP runtime for MeshX nodes.

`mob_runtime` starts the store, dedupe cache, relay cache, Noise session
supervisor, session manager, fragment buffer, peer registry, router, opt-in
UDP/mDNS discovery, outbox replay worker, and topology gossip worker.

The router accepts normalized events from attached transports, decodes MeshX
frames, suppresses duplicates, reassembles fragments, handles ACKs, decrypts
secure packets, relays public packets while TTL remains, and queues offline
packets through the outbox when requested.

See [../../docs/RUNTIME_API.md](../../docs/RUNTIME_API.md) for startup,
transport attachment, subscriptions, sending, secure sessions, fragmentation,
and outbox replay.
