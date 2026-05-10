# Dialyzer warnings present in the codebase at the time CI was wired up.
# Each entry is {file, warning_type, line?}. Remove an entry once the
# underlying issue is fixed; the CI Dialyzer job will then catch any
# regression.
#
# These should be triaged and removed over time — they are NOT a permanent
# allowlist.
[
  # FlowControl: pattern guard against MapSet opaque type
  {"lib/meshx_runtime/flow_control.ex", :call, 107},
  {"lib/meshx_runtime/flow_control.ex", :call_without_opaque, 107},

  # Outbox: GenServer return value tuple shape
  {"lib/meshx_runtime/outbox.ex", :unmatched_return, 54},
  {"lib/meshx_runtime/outbox.ex", :unmatched_return, 97},

  # Router: queue_full branch unreachable given current FlowControl spec
  {"lib/meshx_runtime/router.ex", :pattern_match, 465},

  # Existing whole-file warnings (line-agnostic)
  {"lib/meshx_noise/session.ex", :unmatched_return},
  {"lib/meshx_runtime/discovery.ex", :unmatched_return},
  {"lib/meshx_runtime/telemetry.ex", :no_return},
  {"lib/meshx_runtime/telemetry.ex", :call},
  {"lib/meshx_runtime/topology.ex", :unmatched_return},
  {"lib/meshx_store/dedupe.ex", :unmatched_return},
  {"lib/meshx_store/relay_cache.ex", :unmatched_return},
  {"lib/meshx_store/trust.ex", :call},
  {"lib/meshx_transport/tcp.ex", :unmatched_return},
  {"lib/meshx_transport/tcp.ex", :pattern_match_cov},

  # Pre-existing warnings in modules not touched by the CubDB migration
  {"lib/meshx_runtime/mdns.ex", :call_without_opaque},
  {"lib/meshx_transport/udp.ex", :unmatched_return, 253},
  {"lib/meshx_transport/udp.ex", :unmatched_return},
  {"lib/meshx_transport_ble/port_bridge.ex", :unmatched_return}
]
