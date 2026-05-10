# Operations

This document captures the current alpha operational model.

## Environments

Configuration is split by Mix environment:

- `config/dev.exs` stores CubDB data under `tmp/`.
- `config/test.exs` uses a temporary CubDB data directory.
- `config/prod.exs` reads `MESHX_STORE_DATA_DIR`.

Production defaults:

```bash
export MIX_ENV=prod
export MESHX_STORE_DATA_DIR=/var/lib/meshx/store
```

`MeshxStore.DB` creates the parent data directory on startup.

## Database

Run migrations before starting a production node:

```bash
# No migrations required — CubDB is schemaless
```

CubDB is local-first. For durable deployments:

- Put the data directory on persistent storage.
- Back up the data directory as a unit while the runtime is stopped, or use a filesystem snapshot.
- Monitor disk usage if store-and-forward queues can grow.
- Set outbox `max_attempts` to match the expected connectivity window.

## Node Process Model

Run one MeshX runtime node per BEAM VM. Public runtime modules are registered by
module name, so multiple independent runtime nodes in one VM are not currently
supported.

Use separate OS processes for local multi-node TCP testing:

```bash
iex --sname meshx_a -S mix
iex --sname meshx_b -S mix
```

Then attach `MeshxTransport.TCP` in each shell with different listen ports.

The repository also includes smoke-test scripts used by the test suite:

```bash
MIX_ENV=test \
MESHX_NODE_ID=receiver \
MESHX_READY_FILE=/tmp/meshx_receiver.port \
MESHX_PAYLOAD_FILE=/tmp/meshx_payload.term \
MESHX_STORE_DATA_DIR=/tmp/meshx_receiver_store \
mix run scripts/tcp_receiver.exs
```

After the receiver writes its port file, run:

```bash
MIX_ENV=test \
MESHX_NODE_ID=sender \
MESHX_RECEIVER_ID=receiver \
MESHX_RECEIVER_PORT="$(cat /tmp/meshx_receiver.port)" \
MESHX_PAYLOAD="hello from another BEAM" \
MESHX_STORE_DATA_DIR=/tmp/meshx_sender_store \
mix run scripts/tcp_sender.exs
```

## CI Gates

The repository CI runs:

```bash
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
mix test --cover
mix xref graph --format cycles --label compile-connected --fail-above 0
```

Coverage thresholds are configured per umbrella app. They intentionally focus on
behavior-heavy modules and can be raised as native transports and production
APIs settle.

## Logging

Runtime emits events to subscribed processes. Noise decode/decrypt failures are
logged as warnings and returned as errors to callers instead of crashing session
processes.

Runtime telemetry is emitted under the `[:meshx_runtime, ...]` prefix for
routing, send/drop/retry, fragmentation, ACK, discovery, backpressure, and Noise
lifecycle events. See `docs/METRICS.md` for event names and suggested
Prometheus/StatsD mappings.

## Operational Limits

Current alpha limits:

- One runtime node per BEAM VM.
- TCP and UDP are built-in transports. BLE is available through bridge modules;
  Linux deployments can use `MeshxTransportBLE.BluezBridge`, while iOS and
  Android deployments need platform-native bridge modules.
- Peer identity is transport-provided and should be paired with secure sessions
  before sending private data.
- Store-and-forward is at-least-once, not exactly-once.
- Dedupe and relay caches are in-memory TTL caches and do not survive restart.
- Outbox persistence survives restart, but replay only occurs when the runtime
  starts and peers are discovered or retry is triggered.
- No automatic database vacuum, pruning, or retention policy is currently
  enforced.
- No distributed cluster membership protocol is included.

## Release Checklist

Before tagging an alpha release:

- Run the CI gate commands locally.
- Confirm all child app READMEs and docs match current behavior.
- Verify `LICENSE` is present.
- Verify no local DB files, coverage output, nested app build directories, or
  backup files are present.
- Run at least two TCP nodes as separate BEAM OS processes and send a packet
  both directions.
- If shipping mobile/BLE support, run the native bridge checklist in
  `docs/BLE_BRIDGE.md`.
