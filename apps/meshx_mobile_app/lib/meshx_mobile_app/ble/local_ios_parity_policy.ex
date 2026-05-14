defmodule MeshxMobileApp.BLE.LocalIOSParityPolicy do
  @moduledoc """
  Claim policy for iOS participation in the advertisement-only local mesh.

  Shared canonical contracts and a foreground legacy beacon observe path exist,
  but iOS advert-only participation is not hardware validated. iOS beacon
  emission/gossip is also not selected or implemented. This policy makes that
  boundary explicit for product, release, and audit consumers.

  It does not touch native code, scan, advertise, fetch, route, persist,
  ACK, retry, encrypt, or run background work.
  """

  defmodule Capability do
    @moduledoc false

    @enforce_keys [:id, :status, :allowed_claims, :blocked_claims, :required_before_allowed]
    defstruct @enforce_keys

    @type id ::
            :shared_canonical_contract
            | :ios_legacy_beacon_observe
            | :ios_legacy_beacon_gossip
            | :ios_full_envelope_advert
            | :ios_hardware_replay_fixtures
            | :ios_background_ble

    @type status :: :contract_only | :blocked

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
      id: :shared_canonical_contract,
      status: :contract_only,
      allowed_claims: [
        "iOS parity must normalize through the same canonical received_message and received_message_beacon event shapes."
      ],
      blocked_claims: [
        "iOS hardware participation.",
        "iOS advert-only validation."
      ],
      required_before_allowed: [:ios_hardware_fixtures]
    },
    %{
      id: :ios_legacy_beacon_observe,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "iOS observed legacy beacon proof.",
        "iOS received_message_beacon hardware validation."
      ],
      required_before_allowed: [:ios_scanner_implementation, :ios_device_capture, :replay_fixture]
    },
    %{
      id: :ios_legacy_beacon_gossip,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "iOS emitted legacy beacon gossip.",
        "iOS one-hop advert gossip hardware proof."
      ],
      required_before_allowed: [:ios_dispatcher_implementation, :observer_capture, :audit_summary]
    },
    %{
      id: :ios_full_envelope_advert,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "iOS full MessageEnvelope advertisement participation.",
        "iOS capability-proven full-envelope advert proof."
      ],
      required_before_allowed: [:ios_capability_probe, :full_envelope_capture, :canonical_replay]
    },
    %{
      id: :ios_hardware_replay_fixtures,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "Committed iOS advert-only hardware replay fixture.",
        "iOS hardware ledger equivalent to Android validation."
      ],
      required_before_allowed: [:device_model, :ios_version, :raw_capture, :normalized_fixture]
    },
    %{
      id: :ios_background_ble,
      status: :blocked,
      allowed_claims: [],
      blocked_claims: [
        "iOS background BLE local mesh participation.",
        "iOS background scan or advertise validation."
      ],
      required_before_allowed: [:ios_background_capability, :battery_policy, :hardware_logs]
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

  @spec contract_only() :: [Capability.t()]
  def contract_only, do: Enum.filter(capabilities(), &(&1.status == :contract_only))

  @spec blocked() :: [Capability.t()]
  def blocked, do: Enum.filter(capabilities(), &(&1.status == :blocked))

  @spec snapshot() :: map()
  def snapshot do
    %{
      mode: :advertisement_only_local_mesh,
      platform: :ios,
      capabilities: capabilities(),
      contract_only_count: length(contract_only()),
      blocked_count: length(blocked()),
      ios_participation_claims_allowed?: false,
      notes: [
        "Shared canonical ingress exists, but iOS advert-only hardware participation is not claimed.",
        "Android validation evidence cannot be reused as iOS parity evidence.",
        "iOS parity requires implementation, hardware capture, and replay-normalized fixtures."
      ]
    }
  end
end
