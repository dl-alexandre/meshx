defmodule MeshxMobileApp.BLE.LocalRoutingHardwareValidationPlan do
  @moduledoc """
  Hardware and fixture validation plan for future production routing.

  The current validated mode is advertisement-only local observation. Route
  candidates are read-model entries, not forwarding actions. This module
  records the evidence gates required before MeshX can claim a production
  routing table, route selection, forwarding, routed delivery, or multi-hop
  hardware routing. It does not route, forward, scan, advertise, persist,
  ACK, retry, fetch, encrypt, authenticate, or run background work.
  """

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :required_evidence,
               :missing_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :id,
      :status,
      :required_evidence,
      :missing_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type status :: :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            required_evidence: [binary()],
            missing_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @spec gates() :: [Gate.t()]
  def gates do
    [
      gate(
        :route_table_state_model,
        [
          "Route key schema, next-hop reachability state, freshness policy, and invalidation policy.",
          "Fixture proving peer inventory and local inbox observations do not become forwardable routes automatically."
        ],
        [
          "Production routing table state model.",
          "Fixtures for fresh, stale, invalidated, and unreachable route states."
        ],
        [:route_table_available, :routed_delivery],
        [
          "A route candidate remains an observation read model until a production routing table exists."
        ]
      ),
      gate(
        :deterministic_route_selection,
        [
          "Deterministic next-hop selection policy with tie breaks and TTL budget handling.",
          "Negative fixture rejecting stale, unreachable, expired, or loop-prone next hops."
        ],
        [
          "Route selection implementation and deterministic fixtures.",
          "Tie-break, unreachable-peer, and TTL budget evidence."
        ],
        [:route_selection_available, :routed_delivery],
        ["Advert gossip planning chooses refs to re-advertise, not destination paths."]
      ),
      gate(
        :forwarding_service_boundary,
        [
          "Bounded immutable forward intents and one execution boundary per intent.",
          "Lifecycle, cancellation, concurrency, and platform power-limit evidence."
        ],
        [
          "Forwarding service implementation boundary.",
          "Cancellation, concurrency, and platform policy tests."
        ],
        [:live_forwarding_service, :background_forwarding, :routed_delivery],
        ["Forwarding must be explicit and bounded before it can become runtime behavior."]
      ),
      gate(
        :delivery_semantics_policy,
        [
          "Delivery class policy defining best-effort or stronger semantics.",
          "ACK, retry, duplicate, expiry, and failure-surface policy if delivery claims require them."
        ],
        [
          "Delivery semantics contract.",
          "ACK/retry/duplicate/expiry policy fixtures or explicit non-goal decision."
        ],
        [:guaranteed_delivery, :ack_backed_delivery, :retry_backed_delivery],
        ["Nearby observation and beacon gossip remain non-delivery evidence."]
      ),
      gate(
        :multi_hop_hardware_rig,
        [
          "Three or more physical participants or equivalent controlled rig with origin, relay, and observer roles.",
          "Role logs proving hop propagation without fake delivery claims."
        ],
        [
          "Origin, relay, and observer hardware logs.",
          "Run summary proving actual multi-hop propagation."
        ],
        [:multi_hop_hardware_routing, :routed_delivery],
        ["Replay topology proof remains separate from physical multi-hop proof."]
      ),
      gate(
        :ttl_loop_and_suppression_evidence,
        [
          "Replay-normalized hardware evidence showing TTL decrement, loop suppression, duplicate suppression, and terminal expiry.",
          "Failure logs for loop-prone and expired route cases."
        ],
        [
          "Hardware capture for TTL decrement and loop suppression.",
          "Negative fixture for duplicate, loop, expired, and stale-route cases."
        ],
        [:multi_hop_hardware_routing, :guaranteed_delivery],
        ["TTL and loop evidence must be attached before multi-hop routing wording is allowed."]
      ),
      gate(
        :release_artifact_evidence,
        [
          "Release manifest entries for route table, route selection, forwarding, delivery semantics, and multi-hop hardware evidence.",
          "Operator review preserving blocked routing and delivery wording until every relevant gate passes."
        ],
        [
          "Release-candidate artifact bundle with routing validation evidence.",
          "Operator release-note review for routing, forwarding, and delivery claims."
        ],
        [:routing_or_forwarding_claim, :routed_delivery, :guaranteed_delivery],
        ["Release evidence must distinguish replay simulation from physical routing proof."]
      ),
      gate(
        :negative_claim_review,
        [
          "Implementation-backed negative fixtures for peer inventory as route table, stale next hop, replay as routing, missing ACK/retry, and one-hop hardware as multi-hop.",
          "Regression evidence that blocked claims remain blocked after routing implementation begins."
        ],
        [
          "Implementation-backed routing negative fixture matrix.",
          "Regression evidence for stale routes, unreachable next hops, missing ACK/retry, replay-only gossip, and one-hop-only hardware."
        ],
        [:route_selection_available, :live_forwarding_service, :routed_delivery],
        ["Negative validation must become implementation-backed before routing claims can move."]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :production_routing_hardware_validation_plan,
      current_mode: :advert_only_non_routing,
      route_table_claim_allowed?: false,
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      multi_hop_hardware_claim_allowed?: false,
      gate_count: length(gates),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :route_table_available,
        :route_selection_available,
        :live_forwarding_service,
        :routed_delivery,
        :guaranteed_delivery,
        :ack_backed_delivery,
        :retry_backed_delivery,
        :multi_hop_hardware_routing
      ],
      notes: [
        "Current route candidates are observation read models, not forwarding actions.",
        "Replay advert gossip is simulation evidence, not production routing.",
        "This plan adds evidence gates only; it does not enable routing behavior."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(id, required_evidence, missing_evidence, blocked_claims, notes) do
    %Gate{
      id: id,
      status: :blocked,
      required_evidence: required_evidence,
      missing_evidence: missing_evidence,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
