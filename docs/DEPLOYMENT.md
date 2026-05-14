# Deployment

This document covers production deployment patterns for MeshX runtime nodes.
See [`OPERATIONS.md`](OPERATIONS.md) for environment configuration and
[`METRICS.md`](METRICS.md) for what to monitor.

## Topology Choices

MeshX is designed as a **mesh of independent BEAM nodes**. There is no
"primary" node — each node owns its own CubDB store, dedup state, and
outbox. Pick a topology based on connectivity:

| Topology | When to use | Notes |
| --- | --- | --- |
| Point-to-point TCP | Two known endpoints with stable network paths | Simplest; configure each node with the other's `(host, port)` |
| Star (relay hub) | One always-on node that gossiped peers connect through | The hub advertises `relay: true` in its capabilities |
| Full mesh TCP | Small fleet (≤ 16 nodes) on the same network | Each node opens TCP to every other; relay still helps for partitions |
| UDP + relay | Mobile / NAT-heavy clients that reach a small set of relays | UDP keepalives keep NAT mappings warm |

## Mix Releases

MeshX is shipped as an umbrella with a single runtime app
(`meshx_runtime`). Build a release per node role:

```bash
MIX_ENV=prod mix release meshx_runtime
```

The release boots `meshx_runtime`, which transitively starts `meshx_store`,
`meshx_transport`, `meshx_noise`, and `meshx_mob`. Override any per-app
env via `RELEASE_*` variables or `runtime.exs`.

## Mobile Deploys

The deployable mobile app is `apps/meshx_mobile_app`, generated from Mob and
configured for iOS. It runs the MeshX runtime inside the app's on-device BEAM:

```bash
cd apps/meshx_mobile_app
mix deps.get
mix mob.deploy --native
```

Mob deploys need a local `mob.exs` with machine-specific paths. Keep that file
untracked and use `mob.example.exs` as the template. BLE hardware behavior still
depends on the native bridge implementation selected by
`config :meshx_mobile_app, :native_bridge`.

For physical iOS devices, run `mix mob.provision` from the mobile app directory
before `mix mob.deploy --native --device <device-id>` so Xcode creates a
development provisioning profile for the app bundle.

### Required environment

| Variable | Purpose | Example |
| --- | --- | --- |
| `MESHX_STORE_DATA_DIR` | CubDB data directory | `/var/lib/meshx/store` |
| `MESHX_NODE_ID` | This node's identifier on the wire | `relay-east-1` |
| `MESHX_TCP_LISTEN_PORT` | Port for `MeshxTransport.TCP` | `4040` |
| `MESHX_UDP_LISTEN_PORT` | Port for `MeshxTransport.UDP` (optional) | `4041` |

### Migrations

No migration step is currently required because the store is CubDB-backed and
schemaless:

```bash
MIX_ENV=prod _build/prod/rel/meshx_runtime/bin/meshx_runtime eval \
  # No migrations required — CubDB is schemaless
```

Keep the data directory on persistent storage across releases.

## Containers

A minimal `Dockerfile`:

```dockerfile
FROM hexpm/elixir:1.19.5-erlang-28.0-debian-bookworm-20251008-slim AS build
ENV MIX_ENV=prod
WORKDIR /app

COPY mix.exs mix.lock ./
COPY config/ config/
COPY apps/ apps/

RUN mix local.hex --force && mix local.rebar --force \
 && mix deps.get --only prod \
 && mix release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y openssl libstdc++6 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/_build/prod/rel/meshx_runtime ./
ENV REPLACE_OS_VARS=true
CMD ["/app/bin/meshx_runtime", "start"]
```

### Health checks

Expose a small HTTP/TCP endpoint or use the runtime API:

```elixir
case MeshxRuntime.PeerRegistry.list() do
  [_ | _] -> :ok           # at least one peer connected
  [] -> {:error, :no_peers}
end
```

For Kubernetes liveness, prefer a process check (BEAM is alive) plus a
metrics gate on `[:meshx_runtime, :router, :peer, :up]` events seen in the
last N minutes.

## Networking

### Ports

| Port | Purpose | Protocol |
| --- | --- | --- |
| 4040 | TCP transport | TCP |
| 4041 | UDP transport | UDP |
| 4443 | QUIC transport | UDP |

Open these in firewalls, security groups, and any service mesh sidecar
allow-lists. UDP-based transports need symmetric NAT traversal — keepalives
maintain mappings but cannot punch through restrictive carrier-grade NAT.

### MTU

The router fragments packets when peers advertise an MTU in their
capabilities. Set the MTU explicitly per transport:

- **TCP**: no fragmentation needed; let the OS handle it.
- **UDP**: cap at 1200 bytes (`max_datagram_bytes:` opt) to fit safely
  inside typical Internet MTUs after IP/UDP headers.
- **BLE**: 185 bytes after ATT headers on most mobile devices.

## Observability Stack

Recommended stack:

- **Logs**: structured JSON via `Logger.add_handlers(:default)` or your
  preferred logger backend.
- **Metrics**: subscribe to `[:meshx_runtime, ...]` telemetry events with
  `telemetry_metrics` and ship to Prometheus / StatsD.
- **Traces**: instrument `Router.handle_call/3` boundaries with OpenTelemetry
  if you need per-request tracing.

See [`METRICS.md`](METRICS.md) for the full event catalog.
