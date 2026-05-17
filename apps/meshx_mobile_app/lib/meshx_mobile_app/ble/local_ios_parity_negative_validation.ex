defmodule MeshxMobileApp.BLE.LocalIOSParityNegativeValidation do
  @moduledoc """
  Negative validation matrix for iOS advert-only parity claims.

  iOS currently has a bridge shell and shared canonical contracts, but no
  advert-only BLE implementation or hardware proof. This module records the
  cases that must remain blocked from iOS participation claims. It does not
  touch native code, scan, advertise, fetch, route, persist, ACK, retry,
  encrypt, or run background work.
  """

  defmodule Case do
    @moduledoc false

    @derive {JSON.Encoder,
             only: [
               :id,
               :input,
               :blocked_claims,
               :expected_decision,
               :required_before_allowed,
               :notes
             ]}
    @enforce_keys [
      :id,
      :input,
      :blocked_claims,
      :expected_decision,
      :required_before_allowed,
      :notes
    ]
    defstruct @enforce_keys
  end

  @cases [
    %{
      id: :ios_bridge_shell_as_hardware_participation,
      input: :ios_native_bridge_shell,
      blocked_claims: [
        :ios_hardware_participation,
        :ios_advert_only_validation,
        :ios_parity_claim
      ],
      expected_decision: :contract_only,
      required_before_allowed: [
        :ios_v1_wire_event_emission,
        :bridge_protocol_normalization,
        :ios_hardware_fixture
      ],
      notes: [
        "The iOS bridge shell is adapter structure, not BLE hardware evidence.",
        "Shared canonical ingress is necessary but not sufficient for parity."
      ]
    },
    %{
      id: :android_beacon_proof_as_ios_observe,
      input: :android_legacy_beacon_hardware_evidence,
      blocked_claims: [
        :ios_legacy_beacon_observed,
        :ios_received_message_beacon_validation,
        :ios_parity_claim
      ],
      expected_decision: :wrong_platform_evidence,
      required_before_allowed: [
        :ios_scanner_implementation,
        :ios_device_capture,
        :device_model_and_ios_version_capture,
        :replay_normalized_fixture
      ],
      notes: [
        "Android SM-T390 observation proof cannot satisfy iOS parity.",
        "iOS must produce its own canonical received_message_beacon evidence."
      ]
    },
    %{
      id: :missing_ios_dispatcher_as_gossip,
      input: :ios_legacy_beacon_gossip_claim,
      blocked_claims: [
        :ios_legacy_beacon_gossip,
        :ios_one_hop_gossip_hardware_proof,
        :ios_parity_claim
      ],
      expected_decision: :not_implemented,
      required_before_allowed: [
        :ios_legacy_beacon_dispatcher,
        :compact_beacon_payload_encoder,
        :observer_capture,
        :audit_summary
      ],
      notes: [
        "Foreground iOS MB beacon emit exists, but iOS-origin cross-radio gossip proof is still missing.",
        "Any autonomous gossip behavior must stay behind the same adapter boundary."
      ]
    },
    %{
      id: :unproven_ios_full_envelope_capability,
      input: :ios_full_envelope_advert_claim,
      blocked_claims: [
        :ios_full_envelope_advert,
        :ios_full_message_observation,
        :ios_parity_claim
      ],
      expected_decision: :hardware_blocked,
      required_before_allowed: [
        :ios_ble_capability_probe,
        :full_envelope_payload_budget_check,
        :canonical_received_message_event,
        :capability_proven_hardware_pair
      ],
      notes: [
        "Full-envelope adverts are hardware capability dependent.",
        "No iOS full-envelope advert capability proof is recorded."
      ]
    },
    %{
      id: :missing_ios_replay_fixture,
      input: :ios_advert_only_validation_claim,
      blocked_claims: [
        :ios_hardware_replay_fixture,
        :ios_advert_only_validation,
        :ios_parity_claim
      ],
      expected_decision: :missing_replay_evidence,
      required_before_allowed: [
        :raw_ios_hardware_capture,
        :device_model_and_ios_version_metadata,
        :canonical_jsonl_fixture,
        :replay_test_coverage,
        :validation_ledger_reference
      ],
      notes: [
        "No iOS advert-only hardware fixture is committed or referenced.",
        "Replay-normalized evidence is the parity proof boundary."
      ]
    }
  ]

  @spec cases() :: [Case.t()]
  def cases, do: Enum.map(@cases, &struct!(Case, &1))

  @spec snapshot() :: map()
  def snapshot do
    cases = cases()

    %{
      validation_version: 1,
      boundary: :current_ios_contract_only_mode,
      cases: cases,
      case_count: length(cases),
      blocked_claims: blocked_claims(cases),
      ios_participation_claims_allowed?: false,
      ios_hardware_claims_allowed?: false,
      ios_parity_claims_allowed?: false,
      notes: [
        "iOS has partial hardware evidence for foreground legacy-beacon observe and Android fetch from iOS responder, but broad parity remains blocked.",
        "Negative validation cases protect against reusing Android evidence or bridge shells as iOS parity.",
        "Future iOS work must add replay-normalized hardware evidence and keep these negative cases covered."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp blocked_claims(cases) do
    cases
    |> Enum.flat_map(& &1.blocked_claims)
    |> Enum.uniq()
    |> Enum.sort()
  end
end
