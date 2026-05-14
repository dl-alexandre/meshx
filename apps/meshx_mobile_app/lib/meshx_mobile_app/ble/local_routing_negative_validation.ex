defmodule MeshxMobileApp.BLE.LocalRoutingNegativeValidation do
  @moduledoc """
  Negative validation matrix for routing and delivery claims.

  Current advert-only MeshX can observe nearby messages and run replay/dry-run
  advert gossip policy. It cannot claim production route selection,
  forwarding, ACK/retry delivery, or multi-hop hardware routing. This module
  records the cases that must remain blocked. It does not route, forward,
  scan, advertise, persist, ACK, retry, fetch, encrypt, or run background work.
  """

  defmodule Case do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :input,
               :blocked_claims,
               :expected_decision,
               :required_before_allowed,
               :notes
             ]}
    @enforce_keys [
      :id,
      :input,
      :blocked_claims,
      :expected_decision,
      :required_before_allowed,
      :notes
    ]
    defstruct @enforce_keys
  end

  @cases [
    %{
      id: :peer_inventory_as_route_table,
      input: :passive_peer_inventory,
      blocked_claims: [:route_table_available, :route_selection_available, :routed_delivery],
      expected_decision: :observation_only,
      required_before_allowed: [
        :route_key_schema,
        :next_hop_reachability_state,
        :route_freshness_policy,
        :route_invalidation_policy
      ],
      notes: [
        "Peer inventory is an observation read model, not a forwardable routing table.",
        "Device sightings must not be promoted into next-hop reachability."
      ]
    },
    %{
      id: :stale_or_unreachable_next_hop,
      input: :candidate_next_hop,
      blocked_claims: [:route_selection_available, :live_forwarding_service, :routed_delivery],
      expected_decision: :route_rejected,
      required_before_allowed: [
        :deterministic_route_selection,
        :stale_route_rejection,
        :unreachable_peer_handling,
        :failure_surface
      ],
      notes: [
        "No production selector exists to reject or choose stale routes.",
        "A stale nearby observation is not a usable next hop."
      ]
    },
    %{
      id: :forwardable_candidate_as_forwarding_intent,
      input: :local_routing_table_forwardable_candidate,
      blocked_claims: [
        :live_forwarding_service,
        :forwarding_intent_enqueued,
        :routed_delivery
      ],
      expected_decision: :candidate_filter_only,
      required_before_allowed: [
        :forwarding_service_lifecycle,
        :outbound_forwarding_intent_ledger,
        :delivery_semantics_policy,
        :operator_visible_forwarding_status
      ],
      notes: [
        "LocalRoutingTable forwardable? means a candidate has no local observation blockers.",
        "It does not enqueue, execute, or prove a forwarding action."
      ]
    },
    %{
      id: :advert_gossip_replay_as_routing,
      input: :advert_gossip_simulation,
      blocked_claims: [
        :production_route_selection,
        :live_forwarding_service,
        :multi_hop_hardware_routing,
        :routed_delivery
      ],
      expected_decision: :simulation_only,
      required_before_allowed: [
        :production_routing_table,
        :forwarding_service_lifecycle,
        :three_or_more_physical_participants,
        :origin_relay_observer_logs
      ],
      notes: [
        "Replay gossip proves deterministic propagation policy only.",
        "Simulation evidence cannot satisfy live routing or multi-hop hardware claims."
      ]
    },
    %{
      id: :beacon_fetch_planning_as_routing,
      input: :beacon_fetch_candidate_plan,
      blocked_claims: [
        :production_route_selection,
        :live_forwarding_service,
        :routed_delivery
      ],
      expected_decision: :fetch_intent_only,
      required_before_allowed: [
        :production_routing_table,
        :forwarding_service_lifecycle,
        :delivery_semantics_policy,
        :route_failure_surface
      ],
      notes: [
        "Beacon fetch candidates are request intents for future envelope resolution, not routes.",
        "Fetch planning must not become forwarding, routed delivery, or a production routing table."
      ]
    },
    %{
      id: :missing_ack_retry_policy,
      input: :delivery_claim,
      blocked_claims: [:guaranteed_delivery, :ack_backed_delivery, :retry_backed_delivery],
      expected_decision: :delivery_claim_rejected,
      required_before_allowed: [
        :delivery_class_policy,
        :ack_policy,
        :retry_policy,
        :duplicate_policy,
        :expiry_and_failure_surface
      ],
      notes: [
        "Advertisement-only observation has no ACK or retry semantics.",
        "Seen nearby is not a delivery guarantee."
      ]
    },
    %{
      id: :two_device_one_hop_as_multi_hop,
      input: :one_hop_hardware_beacon_gossip,
      blocked_claims: [:multi_hop_hardware_routing, :routed_delivery],
      expected_decision: :one_hop_observation_only,
      required_before_allowed: [
        :three_or_more_physical_participants,
        :ttl_decrement_evidence,
        :loop_suppression_evidence,
        :canonical_log_replay
      ],
      notes: [
        "SM-T577U to SM-T390 proves one-hop legacy beacon gossip.",
        "It does not prove origin-relay-observer multi-hop routing."
      ]
    }
  ]

  @spec cases() :: [Case.t()]
  def cases, do: Enum.map(@cases, &struct!(Case, &1))

  @spec snapshot() :: map()
  def snapshot do
    cases = cases()

    %{
      validation_version: 1,
      boundary: :current_advert_only_non_routing_mode,
      cases: cases,
      case_count: length(cases),
      blocked_claims: blocked_claims(cases),
      route_selection_claims_allowed?: false,
      forwarding_claims_allowed?: false,
      delivery_claims_allowed?: false,
      notes: [
        "Current advert-only local mode is observation plus replay/dry-run gossip policy.",
        "Negative validation cases protect against presenting observation, candidate filters, or simulation as production routing.",
        "Future routing work must add positive implementation evidence and keep these negative cases covered."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp blocked_claims(cases) do
    cases
    |> Enum.flat_map(& &1.blocked_claims)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
