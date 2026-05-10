# Release Process

This document describes how MeshX releases are versioned, built, and
published.

## Current Status: GitHub-Only v0.1.0

MeshX is **not yet published to Hex**. The current release process is
GitHub-only: users install via `git` dependency in `mix.exs`.

Hex publishing is deferred until the umbrella dependency graph can be
resolved coherently on the Hex registry.

## Why Hex Is Deferred

MeshX is an **umbrella project** with seven child applications. Several of
them depend on sibling apps via `in_umbrella: true`. Hex does not allow
`in_umbrella` dependencies in published packages — only Hex-resolvable
version constraints are accepted.

This means the child apps must be published to Hex **in dependency order**,
and subsequent apps must reference their already-published siblings by version
rather than by umbrella path.

## Planned Hex Publish Order

The following order resolves the dependency graph from leaves to root:

1. **`meshx_protocol`** — no internal deps; pure library
2. **`meshx_transport`** — depends on `meshx_protocol`
3. **`meshx_noise`** — no internal deps; pure library (uses `decibel`)
4. **`meshx_store`** — no internal deps; pure library (uses `cubdb`)
5. **`meshx_mob`** — no internal deps; pure library
6. **`meshx_runtime`** — depends on `meshx_protocol`, `meshx_noise`, `meshx_store`, `meshx_transport`, `meshx_transport_ble`, `meshx_mob`, `telemetry`
7. **`meshx_transport_ble`** — depends on `meshx_transport`

Once step 6 is complete, the full runtime is available on Hex. Step 7
provides the BLE bridge for platforms that need it.

## Platform-Specific Dependencies

### Python — Not a Core Dependency

**Python is not required for MeshX core, protocol, store, noise, or TCP/UDP
transports.** It is only needed when using the BLE transport on Linux.

`meshx_transport_ble` ships a BlueZ-backed bridge at
`priv/bin/meshx_bluez_bridge` (a Python 3 script) that communicates with
Elixir via stdin/stdout. Using the BLE transport on Linux requires:

- **Python 3** (tested on 3.10+)
- **`dbus-next`** (install via `pip install dbus-next`)
- **BlueZ** with `bluetoothd` running and permission to access the adapter

See [`docs/BLE_BRIDGE.md`](BLE_BRIDGE.md) for operational details and the
`--health-check` command to validate a target host before deployment.

## Version Policy

All child apps share the same version number. A release bumps every app's
`version` field in its `mix.exs` simultaneously. This keeps the umbrella
coherent and avoids cross-version compatibility issues.

- **Patch bumps** (0.1.x): bug fixes, documentation updates, dependency bumps
- **Minor bumps** (0.x.0): new features, contract additions, new transports
- **Major bumps** (x.0.0): breaking contract changes, v2 conversations

See [`docs/CONTRACTS.md`](docs/CONTRACTS.md) §10 for compatibility guarantees
that apply within a major version line.

## Release Checklist

Before any version bump:

- [ ] `mix format --check-formatted` passes
- [ ] `mix test` passes (all 200 tests)
- [ ] `mix credo --format=oneline` passes
- [ ] `mix dialyzer --format short` passes
- [ ] `mix xref graph --format cycles --label compile-connected --fail-above 0` passes
- [ ] Per-app `mix hex.build` succeeds for all publishable packages
- [ ] `CHANGELOG.md` updated with the new version section
- [ ] Git tag `vX.Y.Z` created and pushed to origin
- [ ] GitHub Release notes published (auto-generated or manual)

For Hex publishes:
- [ ] Publish in the order defined above
- [ ] Update sibling deps from `in_umbrella: true` to `~> X.Y.Z` after each publish
- [ ] Verify `mix hex.build` still succeeds for downstream apps after each step

## Git Installation (Current)

Until Hex publishing is complete, install MeshX via git:

```elixir
defp deps do
  [
    {:meshx_runtime, git: "https://github.com/dl-alexandre/meshx.git", tag: "v0.1.0"}
  ]
end
```

Using a `tag` is recommended for reproducible builds. Omitting `tag` pins
to the latest `master` commit, which may include unreleased changes.

## CI/CD

GitHub Actions runs the full validation pipeline on every push:

- Format check
- Compile with `--warnings-as-errors`
- Test suite
- BlueZ bridge self-test
- Credo static analysis
- Dialyzer type analysis
- Compile-time dependency cycle check

The CI configuration is in `.github/workflows/ci.yml`.

---

*Last updated: v0.1.0 (GitHub-only)*
