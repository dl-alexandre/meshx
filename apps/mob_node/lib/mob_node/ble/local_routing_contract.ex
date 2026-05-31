defmodule Mob.Node.BLE.LocalRoutingContract do
  @moduledoc """
  Contract for production routing work beyond advert-only local observation.

  Replay gossip can demonstrate policy behavior, but live routing needs
  additional contracts before MeshX can claim forwarding, route
  selection, delivery semantics, ACKs, retries, or background service
  behavior. This module records those missing contracts as data only.
  """

  defmodule Requirement do
    @moduledoc false

    @enforce_keys [:id, :status, :required_evidence, :current_gap, :notes]
    defstruct @enforce_keys

    @type id ::
            :routing_table
            | :route_selection
            | :forwarding_service
            | :delivery_semantics
            | :loop_and_ttl_hardware_validation

    @type status :: :not_implemented | :replay_only

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            required_evidence: [binary()],
            current_gap: binary(),
            notes: [binary()]
          }
  end

  @requirements [
    %{
      id: :routing_table,
      status: :not_implemented,
      required_evidence: [
        "A production routing table must define route keys, peer/device reachability, freshness, and invalidation.",
        "The table must distinguish local observations from forwardable next hops."
      ],
      current_gap:
        "Peer inventory and local inbox are observation read models, not routing state.",
      notes: ["The current validated mode is nearby-message observation."]
    },
    %{
      id: :route_selection,
      status: :not_implemented,
      required_evidence: [
        "A deterministic route selection policy must choose next hops from routing table state.",
        "The policy must define tie-breaks, stale routes, and unreachable peers."
      ],
      current_gap:
        "Advert gossip planner chooses beacon refs to re-advertise, not paths to a destination.",
      notes: ["No live route choice is made by the mobile BLE path."]
    },
    %{
      id: :forwarding_service,
      status: :not_implemented,
      required_evidence: [
        "A live service must consume route intents and perform bounded forwarding.",
        "The service must define lifecycle, concurrency, cancellation, and platform limits."
      ],
      current_gap:
        "There is no production forwarding process or mobile background forwarding service.",
      notes: ["Foreground/manual BLE validation does not imply a forwarding service."]
    },
    %{
      id: :delivery_semantics,
      status: :not_implemented,
      required_evidence: [
        "The system must define whether routed messages are best-effort, at-least-once, or exactly-once.",
        "ACK, retry, expiry, duplicate handling, and failure surfaces must be explicit."
      ],
      current_gap:
        "Advertisement-only local mesh has no ACKs, retries, or guaranteed delivery semantics.",
      notes: ["Current 'seen nearby' UX is observation, not routed delivery."]
    },
    %{
      id: :loop_and_ttl_hardware_validation,
      status: :replay_only,
      required_evidence: [
        "Three or more physical participants must prove loop suppression and TTL behavior outside replay.",
        "Hardware logs must include origin, relay, and observer evidence."
      ],
      current_gap:
        "Replay topology fixtures prove policy behavior; hardware proof is still one-hop only.",
      notes: ["Replay determinism is useful evidence, but not a live routing proof."]
    }
  ]

  @spec requirements() :: [Requirement.t()]
  def requirements, do: Enum.map(@requirements, &struct!(Requirement, &1))

  @spec get(Requirement.id()) :: {:ok, Requirement.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(requirements(), &(&1.id == id)) do
      %Requirement{} = requirement -> {:ok, requirement}
      nil -> {:error, :not_found}
    end
  end

  @spec open_requirements() :: [Requirement.t()]
  def open_requirements, do: requirements()

  @spec snapshot() :: map()
  def snapshot do
    %{
      requirements: requirements(),
      open_requirements: open_requirements(),
      open_requirement_count: length(open_requirements()),
      notes: [
        "Advert gossip replay is not production routing.",
        "Advertisement-only local mesh shows nearby observations, not routed delivery.",
        "No route table, route selection, forwarding service, ACK, retry, or delivery guarantee exists in the mobile BLE path."
      ]
    }
  end
end
