# MeshxTransport

Transport behavior and concrete transports for MeshX.

All transports implement `MeshxTransport` and emit normalized events:

```elixir
{:meshx_transport, transport_name, {:peer_up, peer}}
{:meshx_transport, transport_name, {:peer_down, peer_id}}
{:meshx_transport, transport_name, {:frame, peer_id, frame}}
```

Implemented transports:

- `MeshxTransport.Memory` for deterministic in-memory tests and simulations.
- `MeshxTransport.TCP` for real node-to-node links over length-prefixed TCP
  connections.

TCP endpoints exchange peer IDs and metadata during connection setup, so runtime
nodes can route packets through the same peer registry used by the memory
transport.

See [../../docs/TRANSPORTS.md](../../docs/TRANSPORTS.md) for transport
implementation guidance and operational expectations.
