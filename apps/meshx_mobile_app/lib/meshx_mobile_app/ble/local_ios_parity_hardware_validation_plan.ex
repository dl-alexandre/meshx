defmodule MeshxMobileApp.BLE.LocalIOSParityHardwareValidationPlan do
  @moduledoc """
  Hardware validation plan for iOS advert-only local mesh parity.

  Android has validated legacy beacon observe/gossip evidence. iOS remains
  contract-only until native behavior and replay-normalized hardware evidence
  exist. This module records the evidence gates required before iOS can claim
  advert-only participation. It does not touch native code, scan, advertise,
  fetch, route, persist, ACK, retry, encrypt, or run background work.
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
        :target_ios_device_matrix,
        [
          "iPhone/iPad model, iOS version, BLE state, app build id, permission state, and foreground/background state for every run.",
          "A matching Android or second MeshX observer entry when validating cross-platform observe or gossip."
        ],
        [
          "iOS device matrix for legacy beacon observe, legacy beacon gossip, and full-envelope capability runs.",
          "Observer device metadata for every cross-platform hardware claim."
        ],
        [:ios_hardware_participation, :ios_parity_claim],
        ["iOS parity evidence must be device-specific and cannot reuse Android-only proof."]
      ),
      gate(
        :canonical_ingress_fixture,
        [
          "Native iOS event mapped into canonical received_message_beacon or received_message JSON.",
          "Replay fixture proving the iOS-origin event normalizes through the shared ingress path."
        ],
        [
          "iOS bridge fixture for canonical received_message_beacon.",
          "iOS bridge fixture for canonical received_message when full-envelope participation exists."
        ],
        [:ios_advert_only_validation, :ios_parity_claim],
        [
          "Canonical shape is necessary before any iOS hardware log becomes comparable to Android logs."
        ]
      ),
      gate(
        :legacy_beacon_observe_hardware,
        [
          "iOS hardware log showing a compact legacy message beacon observed from Android or another MeshX peer.",
          "Canonical received_message_beacon event with matching message_id_hash, sender_peer_hash, payload_kind, and envelope_version."
        ],
        [
          "iOS scan implementation evidence for legacy beacon decode.",
          "iOS hardware capture proving legacy beacon observation."
        ],
        [:ios_legacy_beacon_observed, :ios_advert_only_validation],
        ["Observing a beacon remains pointer/ref evidence, not full message delivery."]
      ),
      gate(
        :legacy_beacon_gossip_hardware,
        [
          "iOS hardware log showing compact legacy beacon emission or gossip.",
          "Second MeshX-capable observer log proving canonical received_message_beacon capture from the iOS device."
        ],
        [
          "iOS legacy beacon dispatcher or equivalent advert emission implementation.",
          "Observer capture and audit summary for iOS-origin legacy beacon gossip."
        ],
        [:ios_legacy_beacon_gossip, :ios_one_hop_gossip_hardware_proof],
        ["Gossip evidence must not claim routing, ACKs, retries, or delivery."]
      ),
      gate(
        :full_envelope_capability_probe,
        [
          "iOS BLE capability probe for full-envelope advert payload size and scan compatibility.",
          "Observer log containing canonical received_message if full-envelope advert is supported."
        ],
        [
          "iOS full-envelope payload budget evidence.",
          "Capability-proven iOS hardware pair or explicit negative capability ledger."
        ],
        [:ios_full_envelope_advert, :ios_full_message_observation],
        [
          "Full-envelope adverts remain capability-proven only; legacy beacons must not be promoted."
        ]
      ),
      gate(
        :hardware_replay_fixture,
        [
          "Committed iOS hardware JSONL fixture or validation ledger with raw capture reference.",
          "Replay test proving fixture normalizes through the same canonical replay path."
        ],
        [
          "Replay-normalized iOS hardware fixture.",
          "Artifact metadata with iOS model, version, capture command, and observer role."
        ],
        [:ios_hardware_replay_fixture, :ios_parity_claim],
        ["Replay normalization remains the canonical ingress proof for hardware captures."]
      ),
      gate(
        :ios_background_ble_boundary,
        [
          "Explicit foreground-only or background-capable policy for iOS advert-only participation.",
          "Core Bluetooth background capability and hardware evidence if background participation is claimed."
        ],
        [
          "iOS foreground/background participation decision.",
          "Background capability and hardware logs if iOS background BLE is required."
        ],
        [:ios_background_ble, :ios_background_scan, :ios_background_advertise],
        ["iOS advert-only foreground parity and iOS background BLE are separate claims."]
      ),
      gate(
        :negative_claim_review,
        [
          "Implementation-backed negative fixtures for bridge shell only, Android evidence reuse, missing dispatcher, unproven capability, and missing replay fixture.",
          "Release-note review preserving blocked iOS parity wording until every relevant gate passes."
        ],
        [
          "iOS implementation-backed negative fixture matrix.",
          "Operator review preventing Android evidence from satisfying iOS claims."
        ],
        [:ios_parity_claim, :ios_hardware_participation, :ios_advert_only_validation],
        ["Negative fixtures must replace pure claim gates before any iOS parity release claim."]
      )
    ]
  end

  @spec snapshot() :: map()
  def snapshot do
    gates = gates()

    %{
      plan_version: 1,
      boundary: :ios_advert_only_hardware_validation_plan,
      current_ios_mode: :contract_only,
      ios_participation_claims_allowed?: false,
      ios_hardware_claims_allowed?: false,
      ios_parity_claims_allowed?: false,
      ios_background_claims_allowed?: false,
      gate_count: length(gates),
      blocked_gate_count: Enum.count(gates, &(&1.status == :blocked)),
      gates: gates,
      blocked_claims: [
        :ios_hardware_participation,
        :ios_advert_only_validation,
        :ios_legacy_beacon_observed,
        :ios_legacy_beacon_gossip,
        :ios_full_envelope_advert,
        :ios_hardware_replay_fixture,
        :ios_background_ble,
        :ios_parity_claim
      ],
      notes: [
        "iOS remains contract-only until native advert-only behavior and hardware evidence exist.",
        "Android hardware evidence cannot satisfy iOS parity gates.",
        "This plan adds evidence gates only; it does not change iOS runtime behavior."
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
