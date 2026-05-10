# MeshxMob

Mobile platform boundary for MeshX.

`MeshxMob.Platform` captures platform state that affects transport behavior:
operating system, background mode, granted permissions, native bridge module,
and arbitrary metadata. Transports can convert this context into peer metadata
with `MeshxMob.Platform.to_metadata/1`.

Future production mobile work should build on this boundary for native bridge
configuration, permission checks, background scheduling, power constraints, and
platform-specific transport policy.
