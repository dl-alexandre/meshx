# Runtime API

This document describes the public APIs a developer uses to run a MeshX node.

## Start The Runtime

In development:

```bash
mix deps.get
# No migrations required — CubDB is schemaless
iex -S mix
```

In IEx, the umbrella starts `meshx_runtime` automatically when the application
is started:

```elixir
{:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
```

## Attach A Transport

Every runtime transport must emit normalized `MeshxTransport.Event` messages to
`MeshxRuntime.Router`.

```elixir
{:ok, tcp} =
  MeshxTransport.TCP.start_link(
    id: "node-a",
    event_target: MeshxRuntime.Router,
    listen_port: 4040
  )

:ok = MeshxRuntime.Router.attach_transport(:tcp, MeshxTransport.TCP, tcp)
```

Connect to another TCP node:

```elixir
:ok = MeshxTransport.TCP.connect(tcp, {127, 0, 0, 1}, 4041)
```

Inspect visible peers:

```elixir
MeshxRuntime.PeerRegistry.list()
MeshxRuntime.PeerRegistry.capabilities("node-b")
```

## Discover LAN Peers

Discovery is disabled by default. Enable the proprietary UDP beacon, mDNS, or
both through runtime config:

```elixir
config :meshx_runtime, discovery: [
  enabled?: true,
  mdns?: true,
  id: "node-a",
  transport: :tcp,
  address: {{192, 168, 1, 10}, 4040},
  metadata: %{mtu: 1200}
]
```

`MeshxRuntime.Discovery.announce/1` sends an immediate announcement. Incoming
UDP beacon or `_meshx._udp.local` mDNS announcements are normalized into router
peer discovery events and recorded in `MeshxRuntime.PeerRegistry`.

## Subscribe To Runtime Events

Processes subscribe to delivered packets and routing events:

```elixir
:ok = MeshxRuntime.Router.subscribe(self())
```

Common events:

```elixir
{:meshx_runtime, :peer_up, transport, peer}
{:meshx_runtime, :peer_down, transport, peer_id}
{:meshx_runtime, :packet, transport, peer_id, packet}
{:meshx_runtime, :duplicate, transport, peer_id, msg_id}
{:meshx_runtime, :ack, transport, peer_id, acked_msg_id, result}
{:meshx_runtime, :delivery_ack, transport, peer_id, acked_msg_id, result}
{:meshx_runtime, :read_receipt, transport, peer_id, acked_msg_id, result}
{:meshx_runtime, :receipt, transport, peer_id, receipt, result}
{:meshx_runtime, :decode_error, transport, peer_id, reason}
{:meshx_runtime, :decrypt_error, transport, peer_id, reason}
{:meshx_runtime, :noise_established, transport, peer_id}
```

## Send Packets

Build packets with `MeshxProtocol.Packet`:

```elixir
packet = MeshxProtocol.Packet.new(:data, System.unique_integer([:positive]), "hello")
:ok = MeshxRuntime.Router.send_packet("node-b", packet)
```

Queue for later if a peer is offline:

```elixir
{:queued, :unknown_peer, row} =
  MeshxRuntime.Router.send_packet("node-b", packet, store: true, max_attempts: 5)
```

When `store: true` sends to an online peer, the router sets
`ack_requested`, stores a pending delivery row after the first successful
send, and the outbox retries until a delivery ack or read receipt arrives.

Request encryption after a Noise session is established:

```elixir
:ok = MeshxRuntime.Router.ensure_secure_session("node-b")
:ok = MeshxRuntime.Router.send_packet("node-b", packet, secure: true)
```

Send a read receipt after local application state marks a message read:

```elixir
:ok = MeshxRuntime.Router.send_read_receipt("node-b", packet.msg_id)
```

Broadcast public packets:

```elixir
packet = %{MeshxProtocol.Packet.new(:gossip, 123, <<>>) | ttl: 3}
:ok = MeshxRuntime.Router.broadcast_packet(packet)
```

## Fragmentation And MTU

Router fragments when an explicit MTU is passed or the peer advertises
`metadata.mtu` through `MeshxTransport.Capabilities`.

```elixir
:ok = MeshxRuntime.Router.send_packet("node-b", packet, mtu: 128)
```

Fragments carry the encoded original frame. Reassembly preserves packet type,
flags, TTL, and encrypted payloads.

## Store And Forward

`MeshxRuntime.Outbox` handles replay:

```elixir
:ok = MeshxRuntime.Outbox.replay("node-b")
:ok = MeshxRuntime.Outbox.retry_now()
```

Durable rows live in `MeshxStore.Outbox`. Direct callers generally use the
runtime router rather than inserting rows manually.

## Reset Helpers

Several modules expose `reset/0` for tests and local simulations:

```elixir
MeshxRuntime.Router.reset()
MeshxRuntime.PeerRegistry.reset()
MeshxRuntime.FragmentBuffer.reset()
MeshxRuntime.SessionManager.reset()
MeshxRuntime.Outbox.reset()
```

Do not call these helpers in production request paths.
