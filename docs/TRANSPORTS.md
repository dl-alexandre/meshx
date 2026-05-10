# Transport Integration

MeshX transports move already-framed protocol bytes and emit normalized events.
They do not parse application payloads or own routing policy.

## Transport Behaviour

Transport modules implement `MeshxTransport`:

```elixir
@callback send_frame(pid(), peer_id, binary(), keyword()) :: :ok | {:error, term()}
@callback broadcast_frame(pid(), binary(), keyword()) :: :ok | {:error, term()}
@callback peers(pid()) :: [MeshxTransport.Peer.t()]
```

Transport processes emit:

```elixir
{:meshx_transport, name, {:peer_up, peer}}
{:meshx_transport, name, {:peer_down, peer_id}}
{:meshx_transport, name, {:frame, peer_id, frame}}
```

The runtime router consumes these events directly.

## Memory Transport

`MeshxTransport.Memory` is the deterministic simulator transport. Use it for
unit tests, runtime integration tests, and local simulations inside one BEAM VM.

```elixir
{:ok, local} = MeshxTransport.Memory.start_link(id: "local", event_target: MeshxRuntime.Router)
:ok = MeshxRuntime.Router.attach_transport(:memory, MeshxTransport.Memory, local)
{:ok, _remote} = MeshxTransport.Memory.start_link(id: "remote", event_target: self())
```

## TCP Transport

`MeshxTransport.TCP` is the first real node transport. It listens on a TCP port,
exchanges peer ID and metadata during a transport handshake, and sends
length-prefixed frame messages.

```elixir
{:ok, tcp} =
  MeshxTransport.TCP.start_link(
    id: "node-a",
    event_target: MeshxRuntime.Router,
    listen_port: 4040,
    metadata: MeshxTransport.Capabilities.to_metadata(
      MeshxTransport.Capabilities.new(mtu: 1024, relay: true)
    )
  )

:ok = MeshxRuntime.Router.attach_transport(:tcp, MeshxTransport.TCP, tcp)
:ok = MeshxTransport.TCP.connect(tcp, {127, 0, 0, 1}, 4041)
```

TCP peer IDs are provided by the remote endpoint. For production deployments,
use stable node IDs and pair them with secure sessions before sending private
payloads.

## Capabilities

Peers advertise optional capabilities in metadata:

```elixir
metadata =
  MeshxTransport.Capabilities.to_metadata(
    MeshxTransport.Capabilities.new(
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

- Implement all `MeshxTransport` callbacks.
- Emit `peer_up` with a stable peer ID and capability metadata.
- Emit `peer_down` when the link closes or becomes unusable.
- Emit `frame` only for complete MeshX protocol frame binaries.
- Return `{:error, :peer_not_found}` or another explicit error for missing
  peers.
- Respect caller options such as MTU or transport-specific send hints when
  applicable.
- Avoid decoding MeshX application payloads; routing belongs in
  `MeshxRuntime.Router`.
- Include tests for peer discovery, send, broadcast, disconnect, malformed
  input, and adapter errors.
