defmodule MeshxMobileApp.BLE.LocalRoutingAcceptance do
  @moduledoc """
  Acceptance boundary for local BLE routing claims.

  The current advertisement-only local mode can derive route candidates from
  peer observations and can replay/dry-run advert gossip policy, but it has no
  production routing table, live route selection, forwarding service, delivery
  semantics, ACK/retry behavior, or multi-hop hardware routing proof. This
  module records the satisfied claim gates and the blocked production-routing
  gates as data only. It does not route, forward, scan, advertise, persist,
  ACK, retry, fetch, encrypt, authenticate, or run background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalRoutingContract,
    LocalRoutingHardwareValidationPlan,
    LocalRoutingNegativeValidation,
    LocalRoutingPolicy,
    LocalRoutingProofPlan,
    LocalRoutingTable
  }

  defmodule Gate do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :status,
               :evidence,
               :missing,
               :blocked_claims,
               :notes
             ]}
    @enforce_keys [:id, :status, :evidence, :missing, :blocked_claims, :notes]
    defstruct @enforce_keys

    @type status :: :satisfied | :blocked

    @type t :: %__MODULE__{
            id: atom(),
            status: status(),
            evidence: [binary()],
            missing: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @blocked_claims [
    :route_table_available,
    :route_selection_available,
    :live_forwarding_service,
    :routed_delivery,
    :guaranteed_delivery,
    :ack_backed_delivery,
    :retry_backed_delivery,
    :multi_hop_hardware_routing
  ]

  @spec gates([term()]) :: [Gate.t()]
  def gates(candidates_or_summaries \\ []) do
    policy = LocalRoutingPolicy.snapshot()
    table = LocalRoutingTable.snapshot(candidates_or_summaries)
    contract = LocalRoutingContract.snapshot()
    proof_plan = LocalRoutingProofPlan.snapshot()
    negative = LocalRoutingNegativeValidation.snapshot()

    [
      observation_policy_gate(policy),
      candidate_table_gate(table),
      future_contract_gate(contract, proof_plan),
      hardware_validation_plan_gate(),
      negative_validation_gate(negative),
      production_route_table_gate(contract),
      route_selection_gate(contract),
      forwarding_service_gate(contract),
      delivery_semantics_gate(contract),
      multi_hop_hardware_gate(contract)
    ]
  end

  @spec snapshot([term()]) :: map()
  def snapshot(candidates_or_summaries \\ []) do
    gates = gates(candidates_or_summaries)

    %{
      acceptance_version: 1,
      boundary: :current_advert_only_non_routing_mode,
      gates: gates,
      satisfied_count: Enum.count(gates, &(&1.status == :satisfied)),
      blocked_count: Enum.count(gates, &(&1.status == :blocked)),
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      multi_hop_hardware_claim_allowed?: false,
      blocked_claims: @blocked_claims,
      notes: [
        "Local observations may produce direct-route candidates, but candidates are not forwarding actions.",
        "Advert gossip replay and dry-run evidence is not production route selection.",
        "Routed delivery remains blocked until routing table, route selection, forwarding, delivery semantics, and hardware gates have implementation-backed evidence."
      ]
    }
  end

  @spec json_snapshot([term()]) :: map()
  def json_snapshot(candidates_or_summaries \\ []) do
    candidates_or_summaries
    |> snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp observation_policy_gate(policy) do
    satisfied? =
      policy.allowed_count == 1 and
        policy.simulation_only_count == 1 and
        policy.blocked_count == 4 and
        policy.routing_claims_allowed? == false

    gate(
      :observation_policy,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalRoutingPolicy allows nearby observation and simulation-only advert gossip while blocking live routing claims."
      ],
      if(satisfied?,
        do: [],
        else: ["Routing policy no longer preserves the advert-only claim boundary."]
      ),
      [:routed_delivery, :live_forwarding_service, :multi_hop_hardware_routing],
      ["Observation and replay planning are not production routing."]
    )
  end

  defp candidate_table_gate(table) do
    satisfied? =
      table.routing_claim_allowed? == false and
        table.forwarding_service_available? == false and
        table.delivery_semantics_available? == false

    gate(
      :route_candidate_table,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalRoutingTable derives deterministic direct-route candidates while keeping routing, forwarding, and delivery claims disabled."
      ],
      if(satisfied?,
        do: [],
        else: ["Route candidate table enabled a routing, forwarding, or delivery claim."]
      ),
      [:route_table_available, :route_selection_available, :routed_delivery],
      ["A candidate is a read-model entry, not a live next-hop action."]
    )
  end

  defp future_contract_gate(contract, proof_plan) do
    complete? = contract.open_requirement_count == proof_plan.open_gate_count

    gate(
      :future_routing_contract,
      if(complete?, do: :satisfied, else: :blocked),
      [
        "LocalRoutingContract and LocalRoutingProofPlan enumerate the same open routing proof categories."
      ],
      if(complete?, do: [], else: ["Routing contract and proof plan gate counts diverge."]),
      @blocked_claims,
      ["The contract/proof plan is necessary evidence, not implementation."]
    )
  end

  defp hardware_validation_plan_gate do
    plan = LocalRoutingHardwareValidationPlan.snapshot()

    required_gates = [
      :route_table_state_model,
      :deterministic_route_selection,
      :forwarding_service_boundary,
      :delivery_semantics_policy,
      :multi_hop_hardware_rig,
      :ttl_loop_and_suppression_evidence,
      :release_artifact_evidence,
      :negative_claim_review
    ]

    present_gates = Enum.map(plan.gates, & &1.id)
    missing_gates = Enum.reject(required_gates, &(&1 in present_gates))

    satisfied? =
      missing_gates == [] and
        plan.route_table_claim_allowed? == false and
        plan.route_selection_claim_allowed? == false and
        plan.forwarding_claim_allowed? == false and
        plan.routed_delivery_claim_allowed? == false and
        plan.multi_hop_hardware_claim_allowed? == false

    gate(
      :routing_hardware_validation_plan,
      if(satisfied?, do: :satisfied, else: :blocked),
      [
        "LocalRoutingHardwareValidationPlan records route table, route selection, forwarding, delivery semantics, multi-hop rig, TTL/loop, release evidence, and negative claim review gates."
      ],
      Enum.map(missing_gates, &"Missing routing validation gate #{inspect(&1)}."),
      @blocked_claims,
      ["The plan structures routing evidence without enabling routing behavior."]
    )
  end

  defp negative_validation_gate(negative) do
    blocked? =
      negative.route_selection_claims_allowed? == false and
        negative.forwarding_claims_allowed? == false and
        negative.delivery_claims_allowed? == false

    gate(
      :negative_routing_validation,
      if(blocked?, do: :satisfied, else: :blocked),
      [
        "LocalRoutingNegativeValidation blocks peer-inventory, stale-hop, forwardable-candidate-as-forwarding, replay-as-routing, fetch-planning-as-routing, missing-ACK/retry, and one-hop-as-multi-hop claims."
      ],
      if(blocked?,
        do: [],
        else: ["Routing negative validation allows route, forwarding, or delivery claims."]
      ),
      negative.blocked_claims,
      [
        "Negative validation must be replaced by implementation-backed positive and negative fixtures in future work."
      ]
    )
  end

  defp production_route_table_gate(contract), do: requirement_gate(contract, :routing_table)
  defp route_selection_gate(contract), do: requirement_gate(contract, :route_selection)
  defp forwarding_service_gate(contract), do: requirement_gate(contract, :forwarding_service)
  defp delivery_semantics_gate(contract), do: requirement_gate(contract, :delivery_semantics)

  defp multi_hop_hardware_gate(contract) do
    requirement_gate(contract, :loop_and_ttl_hardware_validation)
  end

  defp requirement_gate(contract, id) do
    requirement = Enum.find(contract.requirements, &(&1.id == id))

    gate(
      id,
      :blocked,
      [],
      requirement.required_evidence ++ [requirement.current_gap],
      blocked_claims_for(id),
      requirement.notes
    )
  end

  defp blocked_claims_for(:routing_table),
    do: [:route_table_available, :route_selection_available, :routed_delivery]

  defp blocked_claims_for(:route_selection),
    do: [:route_selection_available, :routed_delivery]

  defp blocked_claims_for(:forwarding_service),
    do: [:live_forwarding_service, :routed_delivery]

  defp blocked_claims_for(:delivery_semantics),
    do: [:guaranteed_delivery, :ack_backed_delivery, :retry_backed_delivery]

  defp blocked_claims_for(:loop_and_ttl_hardware_validation),
    do: [:multi_hop_hardware_routing, :routed_delivery]

  defp gate(id, status, evidence, missing, blocked_claims, notes) do
    %Gate{
      id: id,
      status: status,
      evidence: evidence,
      missing: missing,
      blocked_claims: blocked_claims,
      notes: notes
    }
  end
end
