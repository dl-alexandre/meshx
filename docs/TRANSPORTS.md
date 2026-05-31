# Transport Integration

MeshX transports move already-framed protocol bytes and emit normalized events.
They do not parse application payloads or own routing policy.

## Transport Behaviour

Transport modules implement `Mob.Routing`:

```elixir
@callback send_frame(pid(), peer_id, binary(), keyword()) :: :ok | {:error, term()}
@callback broadcast_frame(pid(), binary(), keyword()) :: :ok | {:error, term()}
@callback peers(pid()) :: [Mob.Routing.Peer.t()]
```

Transport processes emit:

```elixir
{:mob_routing, name, {:peer_up, peer}}
{:mob_routing, name, {:peer_down, peer_id}}
{:mob_routing, name, {:frame, peer_id, frame}}
```

The runtime router consumes these events directly.

## Memory Transport

`Mob.Routing.Memory` is the deterministic simulator transport. Use it for
unit tests, runtime integration tests, and local simulations inside one BEAM VM.

```elixir
{:ok, local} = Mob.Routing.Memory.start_link(id: "local", event_target: Mob.Runtime.Router)
:ok = Mob.Runtime.Router.attach_transport(:memory, Mob.Routing.Memory, local)
{:ok, _remote} = Mob.Routing.Memory.start_link(id: "remote", event_target: self())
```

## TCP Transport

`Mob.Routing.TCP` is the first real node transport. It listens on a TCP port,
exchanges peer ID and metadata during a transport handshake, and sends
length-prefixed frame messages.

```elixir
{:ok, tcp} =
  Mob.Routing.TCP.start_link(
    id: "node-a",
    event_target: Mob.Runtime.Router,
    listen_port: 4040,
    metadata: Mob.Routing.Capabilities.to_metadata(
      Mob.Routing.Capabilities.new(mtu: 1024, relay: true)
    )
  )

:ok = Mob.Runtime.Router.attach_transport(:tcp, Mob.Routing.TCP, tcp)
:ok = Mob.Routing.TCP.connect(tcp, {127, 0, 0, 1}, 4041)
```

TCP peer IDs are provided by the remote endpoint. For production deployments,
use stable node IDs and pair them with secure sessions before sending private
payloads.

## Capabilities

Peers advertise optional capabilities in metadata:

```elixir
metadata =
  Mob.Routing.Capabilities.to_metadata(
    Mob.Routing.Capabilities.new(
      protocol_version: 1,
      mtu: 512,
      secure_required: true,
      relay: false,
      background_mode: :background
    )
  )
```

Runtime uses capabilities for:

- MTU-driven fragmentation.
- Secure-send enforcement when `secure_required` is true.
- Relay filtering when `relay` is false.

## Transport Implementation Checklist

A new transport should:

- Implement all `Mob.Routing` callbacks.
- Emit `peer_up` with a stable peer ID and capability metadata.
- Emit `peer_down` when the link closes or becomes unusable.
- Emit `frame` only for complete MeshX protocol frame binaries.
- Return `{:error, :peer_not_found}` or another explicit error for missing
  peers.
- Respect caller options such as MTU or transport-specific send hints when
  applicable.
- Avoid decoding MeshX application payloads; routing belongs in
  `Mob.Runtime.Router`.
- Include tests for peer discovery, send, broadcast, disconnect, malformed
  input, and adapter errors.
