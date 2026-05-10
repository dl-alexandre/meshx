# MeshxStore

Local persistence and caches for MeshX.

`meshx_store` contains the CubDB-backed message, identity, trust, and outbox records plus ETS
workers for duplicate suppression and relay cache state. Runtime code uses this
app to queue offline packets, track delivery attempts, process ACKs, suppress
duplicate packets, and advertise cached message IDs through gossip.
