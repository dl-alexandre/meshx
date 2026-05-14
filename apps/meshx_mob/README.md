# MeshxMob

Mobile platform boundary for MeshX.

`MeshxMob.Platform` captures platform state that affects transport behavior:
operating system, background mode, granted permissions, native bridge module,
and arbitrary metadata. Transports can convert this context into peer metadata
with `MeshxMob.Platform.to_metadata/1`.

The deployable mobile app lives in `apps/meshx_mobile_app` and is built with
Mob. This package remains the shared platform context used by runtime and
transport code for native bridge configuration, permission checks, background
scheduling, power constraints, and platform-specific transport policy.
