# Mob.Routing

Transport behavior and concrete transports for MeshX.

All transports implement `Mob.Routing` and emit normalized events:

```elixir
{:mob_routing, transport_name, {:peer_up, peer}}
{:mob_routing, transport_name, {:peer_down, peer_id}}
{:mob_routing, transport_name, {:frame, peer_id, frame}}
```

Implemented transports:

- `Mob.Routing.Memory` for deterministic in-memory tests and simulations.
- `Mob.Routing.TCP` for real node-to-node links over length-prefixed TCP
  connections.

TCP endpoints exchange peer IDs and metadata during connection setup, so runtime
nodes can route packets through the same peer registry used by the memory
transport.

See [../../docs/TRANSPORTS.md](../../docs/TRANSPORTS.md) for transport
implementation guidance and operational expectations.
