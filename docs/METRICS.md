# Metrics

MeshX emits `:telemetry` events under the `[:mob_runtime, ...]` prefix.
This document catalogs every event, what it measures, and what it means
for operators. Subscribe with `:telemetry.attach/4` or
`Telemetry.Metrics.Counter`/`Summary` for Prometheus/StatsD export.

## Event prefix

All events are prefixed `[:mob_runtime, ...]`. Examples below omit the
prefix for brevity.

## Router events

| Event | Measurements | Metadata | When emitted |
| --- | --- | --- | --- |
| `[:router, :peer, :up]` | `count: 1` | `transport`, `peer` | A transport announces a new peer |
| `[:router, :peer, :down]` | `count: 1` | `transport`, `peer_id` | A peer is reported gone |
| `[:router, :peer, :discovered]` | `count: 1` | `peer` | The discovery layer surfaces a new peer |
| `[:router, :send, :start]` | `count: 1` | `peer_id`, `msg_id`, `secure?` | Send call entered |
| `[:router, :send, :stop]` | `count: 1`, `duration` | `peer_id`, `msg_id` | Send completed successfully |
| `[:router, :send, :error]` | `count: 1` | `peer_id`, `reason` | Send failed |
| `[:router, :frame, :decode_error]` | `count: 1` | `transport`, `peer_id`, `reason` | Garbage on the wire |
| `[:router, :packet, :decrypt_error]` | `count: 1` | `peer_id`, `reason` | Encrypted packet failed Noise decrypt |
| `[:router, :packet, :duplicate]` | `count: 1` | `peer_id`, `msg_id` | Dedupe suppressed a re-delivered packet |
| `[:router, :ack, :received]` | `count: 1` | `peer_id`, `acked_msg_id` | ACK from peer cleared an outbox row |
| `[:router, :ack, :error]` | `count: 1` | `peer_id`, `reason` | Malformed ACK |
| `[:router, :fragment, :complete]` | `count: 1` | `peer_id`, `original_id` | All fragments arrived; reassembly succeeded |
| `[:router, :fragment, :partial]` | `count: 1` | `received`, `total` | Mid-flight fragment |
| `[:router, :fragment, :error]` | `count: 1` | `reason` | Reassembly failed |
| `[:router, :backpressure, :queued]` | `count: 1` | `peer_id`, `depth` | Send was deferred behind in-flight ACKs |
| `[:router, :backpressure, :dequeued]` | `count: 1` | `peer_id` | Deferred send resumed |
| `[:router, :backpressure, :dropped]` | `count: 1` | `peer_id`, `reason` | Send was dropped because the per-peer queue is full |
| `[:router, :noise, :established]` | `count: 1` | `peer_id` | Noise XX session established |
| `[:router, :noise, :error]` | `count: 1` | `peer_id`, `reason` | Noise handshake failed |

## Outbox (store-and-forward) events

| Event | Measurements | Metadata | When emitted |
| --- | --- | --- | --- |
| `[:outbox, :enqueue, :stop]` | `count: 1` | `peer_id`, `msg_id` | Packet stored for later delivery |
| `[:outbox, :enqueue, :error]` | `count: 1` | `reason` | Enqueue rejected (e.g. encode failure) |
| `[:outbox, :replay, :stop]` | `count: 1` | `peer_id`, `msg_id` | Stored packet successfully replayed |
| `[:outbox, :replay, :error]` | `count: 1` | `peer_id`, `reason` | Replay failed; row marked failed |
| `[:outbox, :retry, :start]` | `count: 1` | `peer_count` | Periodic retry tick |

## Noise / session events

| Event | Measurements | Metadata | When emitted |
| --- | --- | --- | --- |
| `[:noise, :handshake, :started]` | `count: 1` | `peer_id`, `role` | Initiator or responder began |
| `[:noise, :handshake, :established]` | `count: 1` | `peer_id` | Session keys derived |
| `[:noise, :handshake, :error]` | `count: 1` | `peer_id`, `reason` | Handshake failed |
| `[:noise, :session, :started]` | `count: 1` | `role` | New session record created |

## Discovery events

| Event | Measurements | Metadata | When emitted |
| --- | --- | --- | --- |
| `[:discovery, :announce]` | `bytes` | `transport`, `result`, `mdns_result` | Local node broadcast its presence over the UDP beacon and, when enabled, mDNS |
| `[:discovery, :peer, :up]` | `count: 1` | `peer_id`, `transport`, optional `source` | Discovery layer learned of a new peer |
| `[:discovery, :decode_error]` | `count: 1` | `reason`, optional `source` | Malformed discovery payload |

## Suggested SLOs

For an "always available" relay node:

- `peer_up - peer_down > 0` over 5 min (at least one connected peer)
- `outbox.enqueue.stop / outbox.replay.stop > 0.95` (most queued packets eventually deliver)
- `router.frame.decode_error / router.packet.* < 0.01` (low rate of garbage)
- p95 of `router.send.stop.duration < 50ms` for in-process routing
- `router.backpressure.dropped == 0` (any drop indicates a slow consumer or stuck ack path)

## Example: Prometheus exporter

```elixir
defmodule MyApp.MobMetrics do
  import Telemetry.Metrics

  def metrics do
    [
      counter("mob_runtime.router.peer.up.count"),
      counter("mob_runtime.router.peer.down.count"),
      counter("mob_runtime.router.send.error.count", tags: [:reason]),
      summary("mob_runtime.router.send.stop.duration",
        unit: {:native, :millisecond}
      ),
      counter("mob_runtime.outbox.replay.error.count", tags: [:reason]),
      counter("mob_runtime.router.backpressure.dropped.count")
    ]
  end
end
```

Wire it up with `TelemetryMetricsPrometheus` or a similar reporter in your
release supervision tree.
