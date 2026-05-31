defmodule Mob.Node.BLE.LocalIOSParityContract do
  @moduledoc """
  Contract for iOS participation in the advertisement-only local mesh.

  Android has hardware-validated legacy beacon observation and one-hop
  gossip. iOS currently has a bridge shell and shared canonical ingress
  contracts, but no advert-only beacon/full-envelope implementation or
  hardware proof. This module records the missing iOS parity work as data
  only; it does not touch native code, scan, advertise, fetch, route,
  persist, ACK, retry, encrypt, or run background work.
  """

  defmodule Requirement do
    @moduledoc false

    @enforce_keys [:id, :status, :required_evidence, :current_gap, :notes]
    defstruct @enforce_keys

    @type id ::
            :canonical_ingress
            | :legacy_beacon_observe
            | :legacy_beacon_gossip
            | :full_envelope_advert
            | :hardware_replay_fixture

    @type status :: :contract_only | :not_implemented | :not_validated

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
      id: :canonical_ingress,
      status: :contract_only,
      required_evidence: [
        "iOS bridge events must normalize through BridgeProtocol into canonical received_message or received_message_beacon events.",
        "Replay fixtures must use the same canonical ingress shape as Android hardware captures."
      ],
      current_gap:
        "The shared canonical contract exists, but iOS advert-only hardware fixtures are absent.",
      notes: ["The iOS bridge shell does not by itself prove advert-only parity."]
    },
    %{
      id: :legacy_beacon_observe,
      status: :not_validated,
      required_evidence: [
        "An iOS device must observe a legacy beacon advertisement and emit canonical received_message_beacon.",
        "The capture must include device model/iOS version and replay-normalized event evidence."
      ],
      current_gap: "No iOS received_message_beacon hardware proof is recorded.",
      notes: ["Android SM-T390 observation proof cannot be reused as iOS proof."]
    },
    %{
      id: :legacy_beacon_gossip,
      status: :not_implemented,
      required_evidence: [
        "iOS must emit the compact legacy beacon/gossip payload behind the same adapter boundary.",
        "Another MeshX-capable observer must capture it as a canonical received_message_beacon."
      ],
      current_gap:
        "Foreground iOS MB beacon emit exists, but no iOS-origin cross-radio gossip proof is recorded.",
      notes: ["No autonomous iOS gossip behavior is added by this contract."]
    },
    %{
      id: :full_envelope_advert,
      status: :not_validated,
      required_evidence: [
        "Capability-proven iOS hardware must emit or observe a full MessageEnvelope advert.",
        "The observer must decode a canonical received_message matching the M14 envelope bytes."
      ],
      current_gap: "iOS full-envelope advert participation is contract-only and unvalidated.",
      notes: ["Full-envelope adverts remain hardware capability dependent."]
    },
    %{
      id: :hardware_replay_fixture,
      status: :not_implemented,
      required_evidence: [
        "iOS hardware captures must be committed as replay fixtures or referenced by validation ledgers.",
        "Replay must preserve the same canonical event shape across iOS, Android, and future simulators."
      ],
      current_gap: "No iOS advert-only beacon/gossip replay fixture is recorded.",
      notes: ["Replay determinism remains the ingress standard for future iOS parity work."]
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
        "Android has validated legacy beacon observe/gossip proof; iOS does not.",
        "iOS parity requires implementation plus hardware evidence normalized through replay.",
        "No iOS advert-only beacon/full-envelope behavior is claimed."
      ]
    }
  end
end
