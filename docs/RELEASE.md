# Release Process

This document describes how MeshX releases are versioned, built, and
published.

## Current Status: GitHub-Only v0.1.0

MeshX is **not yet published to Hex**. The current release process is
GitHub-only: users install via `git` dependency in `mix.exs`.

Hex publishing is deferred until the umbrella dependency graph can be
resolved coherently on the Hex registry.

## Why Hex Is Deferred

MeshX is an **umbrella project** with eight child applications. Several of
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
6. **`meshx_transport_ble`** — depends on `meshx_transport`
7. **`meshx_runtime`** — depends on `meshx_protocol`, `meshx_noise`, `meshx_store`, `meshx_transport`, `meshx_transport_ble`, `meshx_mob`, `telemetry`
8. **`meshx_mobile_app`** — deployable Mob app; publish only if it is split into a reusable package

Once step 7 is complete, the full runtime is available on Hex. Step 8 is not
required for the core library release; it is the application shell that consumes
the published packages.

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
- [ ] `mix meshx.mobile.advert_gossip.audit apps/meshx_mobile_app/test/fixtures/advert_gossip_scenarios` passes
- [ ] `mix meshx.mobile.local_readiness.audit --allow-open --out tmp/local-readiness.json` archived for mobile advert-only status
- [ ] `mix meshx.mobile.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt` archived for plain-text open-objective review
- [ ] `mix meshx.mobile.local_completion.audit --allow-open --json --out tmp/local-completion-audit.json` archived for whole-project completion audit
- [ ] `mix meshx.mobile.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json` archived for whole-project blocker classification
- [ ] `mix meshx.mobile.local_release.artifact_bundle --json --out tmp/local-release-artifact-bundle.json` archived for release-candidate artifact checklist
- [ ] `tmp/local-release-artifact-bundle.json` reviewed for `required_commands`; generated and review command gates remain visible
- [ ] `mix meshx.mobile.local_release.manifest --json --out tmp/local-release.json` archived for mobile advert-only release boundary
- [ ] CI `Generate mobile local release manifests` step passes on the release commit
- [ ] Completion audit section in `tmp/local-release.json` reviewed; whole-project completion remains false unless every blocker is closed
- [ ] Hardware evidence section in `tmp/local-release.json` reviewed; open gates remain called out in release notes
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
- Advert gossip scenario audit
- BlueZ bridge self-test
- Credo static analysis
- Dialyzer type analysis
- Compile-time dependency cycle check

The CI configuration is in `.github/workflows/ci.yml`.

## Mobile Advertisement-Only Release Boundary

The current validated mobile BLE mode is advertisement-only local mesh.
For any release note or operator artifact that references this mode,
archive both machine-readable manifests:

```bash
mix meshx.mobile.local_readiness.audit --allow-open --out tmp/local-readiness.json
mix meshx.mobile.local_completion.audit --allow-open | tee tmp/local-completion-audit.txt
mix meshx.mobile.local_completion.audit --allow-open --json --out tmp/local-completion-audit.json
mix meshx.mobile.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json
mix meshx.mobile.local_release.artifact_bundle --json --out tmp/local-release-artifact-bundle.json
mix meshx.mobile.local_release.manifest --json --out tmp/local-release.json
```

The local release manifest is intentionally constrained. It may describe
"messages seen nearby" from passive BLE advertisement observations. It
must not claim whole-project completion, guaranteed delivery, trusted
message delivery, live routing, background mobile behavior, iOS
advert-only participation, or full message resolution from beacon refs.

The manifest's `completion_audit` section is the whole-project claim
gate. It maps the ten project-level objectives to readiness status,
required artifacts, current evidence, and missing evidence. A release
candidate can ship the validated advert-only mode with limitations, but
`completion_claim_allowed?` must remain false until blocked and partial
items are closed by real evidence. The plain-text completion audit output
must also list `OPEN_ITEMS 10` and one `OPEN_ITEM` line for each remaining
objective before the release candidate is accepted.

The standalone `tmp/local-completion-blocker-matrix.json` artifact classifies
remaining completion work by hardware, transport, product, implementation,
security, and release-evidence blockers. Hardware-blocked items must stay
separate from work that can progress through product or release decisions.

The manifest's `hardware_evidence` section is a release-candidate
checklist. It records which hardware gates have passed and which remain
open. It is not itself hardware proof; attach the referenced summaries,
logs, or validation ledgers when preparing a release candidate.

The manifest's `artifact_bundle` section is the operator packaging
checklist. It names generated files, embedded manifest sections, required
hardware attachments, blocked claims, and the `required_commands` list derived
from generated/review artifact sources. Use
`docs/local_ble_release_artifact_bundle.md` as the human release-candidate
checklist, and keep any open operator attachments visible in release notes.

Local inbox persistence is memory-only by default for this release
boundary. Opt-in durable snapshots may be enabled for local read models,
but durable persistence must not be described as default app lifecycle
behavior until migration, cleanup, background-safe write, operator
controls, and on-device restore evidence exist.

---

*Last updated: v0.1.0 (GitHub-only)*
