defmodule MeshxMobileApp.BLE.LocalRoutingPolicy do
  @moduledoc """
  Claim policy for routing-related local BLE behavior.

  The advertisement-only local mode may show nearby observations and may
  run replay/dry-run advert gossip planning. It must not present that as
  live routing, path selection, forwarding, ACK/retry delivery, or
  multi-hop hardware proof.

  This module is pure data. It does not route, forward, persist, ACK,
  retry, fetch, encrypt, scan, advertise, or run background work.
  """

  defmodule Capability do
    @moduledoc false

    @enforce_keys [:id, :status, :allowed_claims, :blocked_claims, :required_before_allowed]
    defstruct @enforce_keys

    @type id ::
            :local_observation
            | :advert_gossip_planning
            | :route_selection
            | :forwarding_service
            | :delivery_semantics
            | :multi_hop_hardware_routing

    @type status :: :allowed | :simulation_only | :blocked

    @type t :: %__MODULE__{
            id: id(),
            status: status(),
            allowed_claims: [binary()],
            blocked_claims: [binary()],
            required_before_allowed: [atom()]
          }
  end

  @capabilities [
    %{
      id: :local_observation,
      status: :allowed,
      allowed_claims: [
        "Messages and refs seen nearby from passive BLE advertisement observations."
      ],
      blocked_claims: [
        "Routed delivery.",
        "Forwarded delivery.",
        "Guaranteed delivery."
      ],
      required_before_allowed: []
    },
    %{
      id: :advert_gossip_planning,
      status: :simulation_only,
      allowed_claims: [
        "Replay and dry-run advert gossip planning with bounded TTL and suppression."
      ],
      blocked_claims: [
        "Production route selection.",
        "Live forwarding service.",
        "Hardware-proven multi-hop routing."
      ],
      required_before_allowed: [:multi_hop_hardware_proof, :forwarding_service_lifecycle]
    },
    %{
      id: :route_selection,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Choosing a next hop for a destination peer.",
        "Treating peer inventory as a routing table."
      ],
      required_before_allowed: [:routing_table, :route_selection_policy]
    },
    %{
      id: :forwarding_service,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Forwarding messages through another device.",
        "Running a production forwarding loop."
      ],
      required_before_allowed: [:foreground_or_background_service, :bounded_forwarding_intents]
    },
    %{
      id: :delivery_semantics,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "ACK-backed delivery.",
        "Retry-backed delivery.",
        "At-least-once or exactly-once delivery."
      ],
      required_before_allowed: [:ack_policy, :retry_policy, :duplicate_policy, :failure_surface]
    },
    %{
      id: :multi_hop_hardware_routing,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Three-device routed delivery.",
        "Hardware-proven loop suppression.",
        "Hardware-proven TTL propagation."
      ],
      required_before_allowed: [:three_or_more_devices, :origin_relay_observer_logs]
    }
  ]

  @spec capabilities() :: [Capability.t()]
  def capabilities, do: Enum.map(@capabilities, &struct!(Capability, &1))

  @spec get(Capability.id()) :: {:ok, Capability.t()} | {:error, :not_found}
  def get(id) do
    case Enum.find(capabilities(), &(&1.id == id)) do
      %Capability{} = capability -> {:ok, capability}
      nil -> {:error, :not_found}
    end
  end

  @spec allowed() :: [Capability.t()]
  def allowed, do: Enum.filter(capabilities(), &(&1.status == :allowed))

  @spec simulation_only() :: [Capability.t()]
  def simulation_only, do: Enum.filter(capabilities(), &(&1.status == :simulation_only))

  @spec blocked() :: [Capability.t()]
  def blocked, do: Enum.filter(capabilities(), &(&1.status == :blocked))

  @spec snapshot() :: map()
  def snapshot do
    %{
      mode: :advertisement_only_local_mesh,
      decision_outcome: :keep_advert_only_non_routing,
      decision_status: :selected_for_current_validated_mode,
      production_routing_reconsideration_gate: :production_routing_hardware_validation_plan,
      capabilities: capabilities(),
      allowed_count: length(allowed()),
      simulation_only_count: length(simulation_only()),
      blocked_count: length(blocked()),
      routing_claims_allowed?: false,
      production_routing_claim_allowed?: false,
      notes: [
        "Local observation is allowed; live routing claims are not.",
        "Advert gossip planning remains replay/dry-run or constrained advert behavior, not route selection.",
        "Multi-hop hardware routing requires three or more physical participants and explicit logs."
      ]
    }
  end
end
