defmodule MeshxMobileApp.BLE.LocalIOSAdvertCarrierDecision do
  @moduledoc """
  iOS advert-only carrier decision for legacy beacon refs.

  Android can emit the compact legacy beacon as manufacturer data and has
  one-hop hardware proof. iOS now has a foreground observe path for that
  manufacturer-data shape, but the project still has no validated iOS emission
  carrier for beacon gossip. This module records that decision boundary as
  data only.

  It does not touch native code, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, authenticate, fragment, or run background work.
  """

  defmodule Carrier do
    @moduledoc false

    @derive {JSON.Encoder, only: [:id, :direction, :status, :evidence, :blocked_claims, :notes]}
    @enforce_keys [:id, :direction, :status, :evidence, :blocked_claims, :notes]
    defstruct @enforce_keys

    @type id ::
            :manufacturer_data_legacy_beacon_observe
            | :manufacturer_data_legacy_beacon_emit
            | :service_uuid_identity_advert
            | :service_data_beacon_ref
            | :local_name_encoded_beacon_ref

    @type direction :: :observe | :emit

    @type status ::
            :implemented_unvalidated
            | :not_selected
            | :insufficient_for_beacon_ref
            | :candidate_unvalidated
            | :rejected

    @type t :: %__MODULE__{
            id: id(),
            direction: direction(),
            status: status(),
            evidence: [binary()],
            blocked_claims: [atom()],
            notes: [binary()]
          }
  end

  @carriers [
    %{
      id: :manufacturer_data_legacy_beacon_observe,
      direction: :observe,
      status: :implemented_unvalidated,
      evidence: [
        "meshx_mobile/Sources/MeshxMobile/BLE.swift",
        "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
        "apps/meshx_mobile_app/ios/meshx_ble_nif.m",
        "meshx_mobile/Tests/MeshxMobileTests/MessageAdvertisementTests.swift"
      ],
      blocked_claims: [
        :ios_hardware_participation,
        :ios_legacy_beacon_observed,
        :ios_parity_claim
      ],
      notes: [
        "Foreground scanner code decodes MeshX 22-byte legacy beacon manufacturer data.",
        "Swift fixtures pin the parser shape.",
        "No iOS hardware capture or replay-normalized fixture is recorded."
      ]
    },
    %{
      id: :manufacturer_data_legacy_beacon_emit,
      direction: :emit,
      status: :not_selected,
      evidence: [
        "meshx_mobile/Sources/MeshxMobile/BLE.swift",
        "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift"
      ],
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :ios_one_hop_gossip_hardware_proof,
        :ios_parity_claim
      ],
      notes: [
        "The current iOS peripheral bridge advertises MeshX service identity, not the 22-byte beacon reference payload.",
        "No implementation path in the repo emits the Android-compatible manufacturer-data beacon from iOS.",
        "This carrier cannot be treated as selected until implementation and observer hardware evidence exist."
      ]
    },
    %{
      id: :service_uuid_identity_advert,
      direction: :emit,
      status: :insufficient_for_beacon_ref,
      evidence: ["meshx_mobile/Sources/MeshxMobile/BLE.swift"],
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :message_reference_delivery,
        :ios_parity_claim
      ],
      notes: [
        "The current iOS peripheral advertises the MeshX service UUID for peer discovery.",
        "A service UUID alone does not carry message_id_hash, sender_peer_hash, payload_kind, or envelope_version.",
        "It is not a beacon gossip carrier."
      ]
    },
    %{
      id: :service_data_beacon_ref,
      direction: :emit,
      status: :candidate_unvalidated,
      evidence: ["LocalIOSAdvertCarrierDecision"],
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :ios_hardware_participation,
        :ios_parity_claim
      ],
      notes: [
        "A future iOS-specific advertisement carrier may be evaluated if product requirements need iOS beacon emission.",
        "It must preserve the BeaconRef fields and normalize through received_message_beacon.",
        "No code or hardware evidence for this carrier exists yet."
      ]
    },
    %{
      id: :local_name_encoded_beacon_ref,
      direction: :emit,
      status: :rejected,
      evidence: ["LocalIOSAdvertCarrierDecision"],
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :ios_parity_claim
      ],
      notes: [
        "Encoding beacon refs into the advertised local name is rejected for this project boundary.",
        "It would be fragile, user-visible, and inconsistent with the canonical manufacturer-data/replay ingress.",
        "Do not use local name text as a message reference transport."
      ]
    }
  ]

  @spec carriers() :: [Carrier.t()]
  def carriers, do: Enum.map(@carriers, &struct!(Carrier, &1))

  @spec snapshot() :: map()
  def snapshot do
    carriers = carriers()

    %{
      decision_version: 1,
      boundary: :ios_advert_only_carrier_decision,
      current_ios_observe_carrier: :manufacturer_data_legacy_beacon_observe,
      current_ios_emit_carrier: :none,
      ios_legacy_beacon_observe_implemented?: true,
      ios_legacy_beacon_gossip_implemented?: false,
      ios_legacy_beacon_gossip_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      carriers: carriers,
      recommended_next_step: :hardware_validate_observe_before_selecting_emit_carrier,
      blocked_claims: blocked_claims(carriers),
      notes: [
        "iOS observe and iOS emit are separate claims.",
        "The current validated local mode remains Android one-hop legacy beacon gossip plus advert-only local inbox.",
        "iOS emission should stay disabled until a carrier is selected, implemented, hardware-captured, and replay-normalized."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp blocked_claims(carriers) do
    carriers
    |> Enum.flat_map(& &1.blocked_claims)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
