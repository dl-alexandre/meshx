defmodule MeshxMobileApp.BLE.LocalRoutingProofPlan do
  @moduledoc """
  Proof plan for future production routing claims.

  Advert gossip replay can prove bounded ref propagation policy, but it is
  not a routing table, route selector, forwarding service, ACK/retry system,
  or multi-hop hardware proof. This module maps each open routing contract
  requirement to concrete implementation gates and validation evidence. It
  does not route, forward, scan, advertise, persist, ACK, retry, fetch,
  encrypt, or run background work.
  """

  alias MeshxMobileApp.BLE.LocalRoutingContract

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :requirement_id,
               :status,
               :implementation_gates,
               :validation_evidence,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [
      :requirement_id,
      :status,
      :implementation_gates,
      :validation_evidence,
      :blocked_claims,
      :notes
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            requirement_id: LocalRoutingContract.Requirement.id(),
            status: :planned | :hardware_blocked,
            implementation_gates: [atom()],
            validation_evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @proof_gates %{
    routing_table: %{
      status: :planned,
      implementation_gates: [
        :route_key_schema,
        :next_hop_reachability_state,
        :route_freshness_policy,
        :route_invalidation_policy,
        :observation_vs_forwardable_state_boundary
      ],
      validation_evidence: [
        "Fixture proving local observations are not automatically forwardable routes.",
        "Fixture proving stale or invalidated routes are excluded.",
        "Deterministic route table snapshot test with peer/device rotation."
      ],
      blocked_claims: [:route_table_available, :routed_delivery],
      notes: ["Peer inventory remains an observation model until a routing table exists."]
    },
    route_selection: %{
      status: :planned,
      implementation_gates: [
        :destination_peer_lookup,
        :candidate_next_hop_selection,
        :deterministic_tie_breaks,
        :unreachable_peer_handling,
        :ttl_budget_check
      ],
      validation_evidence: [
        "Fixture proving deterministic next-hop selection from identical routing state.",
        "Negative fixture proving unreachable or stale next hops are rejected.",
        "Tie-break fixture proving input order does not affect selected route."
      ],
      blocked_claims: [:route_selection_available, :routed_delivery],
      notes: ["Advert gossip planning chooses refs to re-advertise, not destination paths."]
    },
    forwarding_service: %{
      status: :planned,
      implementation_gates: [
        :bounded_forward_intents,
        :single_forward_execution_boundary,
        :lifecycle_and_cancellation_policy,
        :concurrency_limit,
        :platform_power_limit
      ],
      validation_evidence: [
        "Dry-run fixture proving forward intents are bounded and immutable.",
        "Lifecycle test proving cancellation closes work without retries.",
        "Platform policy evidence before any background forwarding claim."
      ],
      blocked_claims: [:live_forwarding_service, :routed_delivery],
      notes: ["There is no production forwarding loop or background forwarding service."]
    },
    delivery_semantics: %{
      status: :planned,
      implementation_gates: [
        :delivery_class_policy,
        :ack_policy,
        :retry_policy,
        :duplicate_policy,
        :expiry_and_failure_surface
      ],
      validation_evidence: [
        "Contract test defining best-effort, at-least-once, or exactly-once wording.",
        "Negative tests proving missing ACK/retry policy blocks delivery guarantees.",
        "Failure-surface fixture for expired, duplicate, unreachable, and rejected deliveries."
      ],
      blocked_claims: [:guaranteed_delivery, :ack_backed_delivery, :retry_backed_delivery],
      notes: ["Nearby observation is not a delivery semantic."]
    },
    loop_and_ttl_hardware_validation: %{
      status: :hardware_blocked,
      implementation_gates: [
        :three_or_more_physical_participants,
        :origin_relay_observer_roles,
        :ttl_decrement_evidence,
        :loop_suppression_evidence,
        :canonical_log_replay
      ],
      validation_evidence: [
        "Hardware logs from origin, relay, and observer devices.",
        "Replay-normalized evidence showing TTL decrement and loop suppression.",
        "Summary artifact proving multi-hop behavior without fake delivery claims."
      ],
      blocked_claims: [:multi_hop_hardware_routing, :routed_delivery],
      notes: ["Replay topology proof remains separate from multi-device hardware proof."]
    }
  }

  @spec gates() :: [Gate.t()]
  def gates do
    LocalRoutingContract.open_requirements()
    |> Enum.map(&gate/1)
  end

  @spec get(LocalRoutingContract.Requirement.id()) :: {:ok, Gate.t()} | {:error, :not_found}
  def get(requirement_id) do
    case Enum.find(gates(), &(&1.requirement_id == requirement_id)) do
      %Gate{} = gate -> {:ok, gate}
      nil -> {:error, :not_found}
    end
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      proof_boundary: :future_production_routing,
      gates: gates,
      open_gate_count: length(gates),
      hardware_blocked_count: Enum.count(gates, &(&1.status == :hardware_blocked)),
      routing_claims_allowed?: false,
      notes: [
        "Every routing gate is planned or hardware-blocked, not implemented.",
        "Advert gossip replay remains simulation evidence, not production routing.",
        "Routed-delivery claims stay blocked until all routing gates have implementation and validation evidence."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp gate(%LocalRoutingContract.Requirement{id: id}) do
    data = Map.fetch!(@proof_gates, id)

    %Gate{
      requirement_id: id,
      status: data.status,
      implementation_gates: data.implementation_gates,
      validation_evidence: data.validation_evidence,
      blocked_claims: data.blocked_claims,
      notes: data.notes
    }
  end
end
