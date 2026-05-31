# Mob.Noise

Noise protocol session support for MeshX.

`Mob.Noise.Session` wraps Decibel in a GenServer so each Noise state machine is
isolated in its own BEAM process. The app currently supports Noise XX session
setup, encryption, decryption, handshake hash access, remote key access, and a
dynamic supervisor for per-peer runtime sessions.
