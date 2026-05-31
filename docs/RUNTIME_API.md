# Runtime API

This document describes the public APIs a developer uses to run a MeshX node.

## Start The Runtime

In development:

```bash
mix deps.get
# No migrations required — CubDB is schemaless
iex -S mix
```

In IEx, the umbrella starts `mob_runtime` automatically when the application
is started:

```elixir
{:ok, _apps} = Application.ensure_all_started(:mob_runtime)
```

## Attach A Transport

Every runtime transport must emit normalized `Mob.Routing.Event` messages to
`Mob.Runtime.Router`.

```elixir
{:ok, tcp} =
  Mob.Routing.TCP.start_link(
    id: "node-a",
    event_target: Mob.Runtime.Router,
    listen_port: 4040
  )

:ok = Mob.Runtime.Router.attach_transport(:tcp, Mob.Routing.TCP, tcp)
```

Connect to another TCP node:

```elixir
:ok = Mob.Routing.TCP.connect(tcp, {127, 0, 0, 1}, 4041)
```

Inspect visible peers:

```elixir
Mob.Runtime.PeerRegistry.list()
Mob.Runtime.PeerRegistry.capabilities("node-b")
```

## Discover LAN Peers

Discovery is disabled by default. Enable the proprietary UDP beacon, mDNS, or
both through runtime config:

```elixir
config :mob_runtime, discovery: [
  enabled?: true,
  mdns?: true,
  id: "node-a",
  transport: :tcp,
  address: {{192, 168, 1, 10}, 4040},
  metadata: %{mtu: 1200}
]
```

`Mob.Runtime.Discovery.announce/1` sends an immediate announcement. Incoming
UDP beacon or `_mob._udp.local` mDNS announcements are normalized into router
peer discovery events and recorded in `Mob.Runtime.PeerRegistry`.

## Subscribe To Runtime Events

Processes subscribe to delivered packets and routing events:

```elixir
:ok = Mob.Runtime.Router.subscribe(self())
```

Common events:

```elixir
{:mob_runtime, :peer_up, transport, peer}
{:mob_runtime, :peer_down, transport, peer_id}
{:mob_runtime, :packet, transport, peer_id, packet}
{:mob_runtime, :duplicate, transport, peer_id, msg_id}
{:mob_runtime, :ack, transport, peer_id, acked_msg_id, result}
{:mob_runtime, :delivery_ack, transport, peer_id, acked_msg_id, result}
{:mob_runtime, :read_receipt, transport, peer_id, acked_msg_id, result}
{:mob_runtime, :receipt, transport, peer_id, receipt, result}
{:mob_runtime, :decode_error, transport, peer_id, reason}
{:mob_runtime, :decrypt_error, transport, peer_id, reason}
{:mob_runtime, :noise_established, transport, peer_id}
```

## Send Packets

Build packets with `Mob.Protocol.Packet`:

```elixir
packet = Mob.Protocol.Packet.new(:data, System.unique_integer([:positive]), "hello")
:ok = Mob.Runtime.Router.send_packet("node-b", packet)
```

Queue for later if a peer is offline:

```elixir
{:queued, :unknown_peer, row} =
  Mob.Runtime.Router.send_packet("node-b", packet, store: true, max_attempts: 5)
```

When `store: true` sends to an online peer, the router sets
`ack_requested`, stores a pending delivery row after the first successful
send, and the outbox retries until a delivery ack or read receipt arrives.

Request encryption after a Noise session is established:

```elixir
:ok = Mob.Runtime.Router.ensure_secure_session("node-b")
:ok = Mob.Runtime.Router.send_packet("node-b", packet, secure: true)
```

Send a read receipt after local application state marks a message read:

```elixir
:ok = Mob.Runtime.Router.send_read_receipt("node-b", packet.msg_id)
```

Broadcast public packets:

```elixir
packet = %{Mob.Protocol.Packet.new(:gossip, 123, <<>>) | ttl: 3}
:ok = Mob.Runtime.Router.broadcast_packet(packet)
```

## Fragmentation And MTU

Router fragments when an explicit MTU is passed or the peer advertises
`metadata.mtu` through `Mob.Routing.Capabilities`.

```elixir
:ok = Mob.Runtime.Router.send_packet("node-b", packet, mtu: 128)
```

Fragments carry the encoded original frame. Reassembly preserves packet type,
flags, TTL, and encrypted payloads.

## Store And Forward

`Mob.Runtime.Outbox` handles replay:

```elixir
:ok = Mob.Runtime.Outbox.replay("node-b")
:ok = Mob.Runtime.Outbox.retry_now()
```

Durable rows live in `Mob.Store.Outbox`. Direct callers generally use the
runtime router rather than inserting rows manually.

## Reset Helpers

Several modules expose `reset/0` for tests and local simulations:

```elixir
Mob.Runtime.Router.reset()
Mob.Runtime.PeerRegistry.reset()
Mob.Runtime.FragmentBuffer.reset()
Mob.Runtime.SessionManager.reset()
Mob.Runtime.Outbox.reset()
```

Do not call these helpers in production request paths.
