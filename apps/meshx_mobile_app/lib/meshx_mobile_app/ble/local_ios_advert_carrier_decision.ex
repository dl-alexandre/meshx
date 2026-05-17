defmodule MeshxMobileApp.BLE.LocalIOSAdvertCarrierDecision do
  @moduledoc """
  iOS advert-only carrier decision for legacy beacon refs.

  Android can emit the compact legacy beacon as manufacturer data and iOS now
  has hardware proof for observing that manufacturer-data shape. The project
  has a foreground iOS MB beacon emission implementation. That emission is not
  enough to claim iOS beacon gossip or broad parity: the current iPad evidence
  does not include Android receipt of an iOS-origin beacon, and there is no
  autonomous iOS gossip dispatcher. Direct full MX envelope delivery over
  extended advertising remains blocked by iOS CoreBluetooth AUX delivery
  behavior. This module records that decision boundary as data only.

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
            | :full_mx_extended_advert_observe
            | :manufacturer_data_legacy_beacon_emit
            | :service_uuid_identity_advert
            | :service_data_beacon_ref
            | :local_name_encoded_beacon_ref

    @type direction :: :observe | :emit

    @type status ::
            :implemented_unvalidated
            | :hardware_validated
            | :phy_blocked
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
      status: :hardware_validated,
      evidence: [
        "meshx_mobile/Sources/MeshxMobile/BLE.swift",
        "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
        "apps/meshx_mobile_app/ios/meshx_ble_nif.m",
        "meshx_mobile/Tests/MeshxMobileTests/MessageAdvertisementTests.swift",
        "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26b-android-to-iphone-receive/summary.json"
      ],
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :ios_parity_claim
      ],
      notes: [
        "Foreground scanner code decodes MeshX 22-byte legacy beacon manufacturer data.",
        "Swift fixtures pin the parser shape.",
        "Hardware capture on 2026-05-15 proves Android SM-T577U to iPhone 13 legacy-beacon observation."
      ]
    },
    %{
      id: :full_mx_extended_advert_observe,
      direction: :observe,
      status: :phy_blocked,
      evidence: [
        "docs/BLE_BRIDGE.md#extended-advertising-aux-delivery-limitation",
        "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26b-android-to-iphone-receive/summary.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md"
      ],
      blocked_claims: [
        :ios_full_mx_direct_advert_receive,
        :ios_full_envelope_advert_direct,
        :ios_parity_claim
      ],
      notes: [
        "Production bridge code is wired for received_message MX decode, but iOS did not surface non-Apple AUX_ADV_IND manufacturer data to CoreBluetooth on tested hardware.",
        "Bluetooth logs showed MB legacy beacons during both test windows and zero MX magic packets.",
        "Use MB legacy beacon plus GATT fetch for full-envelope delivery to iOS."
      ]
    },
    %{
      id: :manufacturer_data_legacy_beacon_emit,
      direction: :emit,
      status: :implemented_unvalidated,
      evidence: [
        "meshx_mobile/Sources/MeshxMobile/BLE.swift",
        "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
        "meshx_mobile/Examples/MeshxMobileHarness/MeshxMobileHarness/BLEHarnessModel.swift",
        "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26-iphone-dispatch/summary.json",
        "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
      ],
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :ios_one_hop_gossip_hardware_proof,
        :ios_parity_claim
      ],
      notes: [
        "The foreground iOS bridge can advertise the 22-byte MB beacon reference payload through CBAdvertisementDataManufacturerDataKey.",
        "The app bridge uses this as the no-GATT fallback cue for the GATT fetch responder; the harness drives the same path with --meshx-auto-beacon.",
        "The latest iPad evidence records beacon dispatch but zero matched Android receive lines, so this remains unvalidated for iOS-origin gossip or parity claims."
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
      current_ios_emit_carrier: :manufacturer_data_legacy_beacon_emit,
      ios_legacy_beacon_observe_implemented?: true,
      ios_legacy_beacon_observe_hardware_validated?: true,
      ios_legacy_beacon_emit_implemented?: true,
      ios_legacy_beacon_emit_cross_radio_validated?: false,
      ios_full_mx_direct_advert_receive_allowed?: false,
      ios_legacy_beacon_gossip_implemented?: false,
      ios_legacy_beacon_gossip_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      carriers: carriers,
      recommended_next_step: :hardware_validate_observe_before_selecting_emit_carrier,
      blocked_claims: blocked_claims(carriers),
      notes: [
        "iOS observe and iOS emit are separate claims.",
        "The current validated cross-platform full-message mode is MB legacy beacon cue plus GATT fetch.",
        "Foreground iOS MB beacon emission exists, but iOS-origin cross-radio receipt remains unproven in the attached iPad run.",
        "Direct full-MX extended advertising remains disabled for iOS because hardware scans did not deliver AUX manufacturer data through CoreBluetooth.",
        "iOS gossip and parity claims stay blocked until iOS-origin emission is observer-captured, replay-normalized, and bounded by negative fixtures."
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
