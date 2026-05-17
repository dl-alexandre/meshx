defmodule MeshxMobileApp.BLE.LocalIOSParityPolicy do
  @moduledoc """
  Claim policy for iOS participation in the advertisement-only local mesh.

  Shared canonical contracts, foreground legacy-beacon observe hardware
  evidence, and Android fetch from the iOS responder now exist, but broad iOS
  advert-only parity remains blocked. iOS beacon emission/gossip is not
  selected, direct full-MX extended advertising is PHY-blocked on tested
  hardware, and background participation is not validated. This policy makes
  that boundary explicit for product, release, and audit consumers.

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
        "Broad iOS parity from legacy beacon observation alone.",
        "iOS received_message_beacon hardware validation as delivery proof."
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
        "Shared canonical ingress, iOS legacy-beacon observe hardware evidence, and Android fetch from iOS responder evidence exist, but broad iOS parity is not claimed.",
        "Android validation evidence cannot be reused as iOS parity evidence.",
        "iOS parity still requires iOS-origin cross-radio gossip proof, direct full-envelope capability policy, background policy if needed, and replay-normalized fixtures."
      ]
    }
  end
end
