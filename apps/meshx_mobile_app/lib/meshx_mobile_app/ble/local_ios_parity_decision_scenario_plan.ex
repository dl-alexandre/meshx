defmodule MeshxMobileApp.BLE.LocalIOSParityDecisionScenarioPlan do
  @moduledoc """
  Scenario plan for iOS advert-only parity decision outcomes.

  This plan makes the current iOS contract-only decision explicit beside the
  blocked iOS advert-only participation path. It is policy evidence only. It
  does not touch native code, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, authenticate, or run background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalIOSAdvertCarrierDecision,
    LocalIOSParityHardwareEvidenceReview,
    LocalIOSParityHardwareValidationPlan,
    LocalIOSParityPolicy
  }

  @allowed_decision_outcomes [
    :keep_ios_contract_only,
    :enable_ios_advert_only_participation
  ]

  @spec snapshot() :: map()
  def snapshot do
    policy = LocalIOSParityPolicy.snapshot()
    carrier_decision = LocalIOSAdvertCarrierDecision.snapshot()
    validation_plan = LocalIOSParityHardwareValidationPlan.snapshot()
    review = LocalIOSParityHardwareEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_ios_parity_decision_scenario_plan,
      status: :open,
      current_ios_decision: current_decision(policy, carrier_decision),
      selected_decision_outcome: :keep_ios_contract_only,
      allowed_decision_outcomes: @allowed_decision_outcomes,
      ios_participation_claim_allowed?: false,
      ios_hardware_claim_allowed?: false,
      ios_legacy_beacon_observe_claim_allowed?: false,
      ios_legacy_beacon_gossip_claim_allowed?: false,
      ios_full_envelope_advert_claim_allowed?: false,
      ios_background_ble_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      validation_plan: validation_plan,
      decision_scenarios: decision_scenarios(review, validation_plan),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/ios/",
      notes: [
        "This scenario plan is not iOS hardware evidence by itself.",
        "keep_ios_contract_only is selected for the current advertisement-only local mesh mode.",
        "enable_ios_advert_only_participation remains blocked until every iOS validation gate has operator-reviewed evidence.",
        "Android advert-only hardware proof cannot satisfy iOS parity claims."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_decision(policy, carrier_decision) do
    %{
      decision_outcome: :keep_ios_contract_only,
      decision_status: :selected_for_current_validated_mode,
      current_ios_mode: :contract_only,
      policy_platform: policy.platform,
      current_ios_observe_carrier: carrier_decision.current_ios_observe_carrier,
      current_ios_emit_carrier: carrier_decision.current_ios_emit_carrier,
      ios_legacy_beacon_observe_implemented?:
        carrier_decision.ios_legacy_beacon_observe_implemented?,
      ios_legacy_beacon_gossip_implemented?:
        carrier_decision.ios_legacy_beacon_gossip_implemented?,
      ios_hardware_participation_enabled?: false,
      ios_legacy_beacon_observe_claim_allowed?: false,
      ios_legacy_beacon_gossip_claim_allowed?: false,
      ios_full_envelope_advert_claim_allowed?: false,
      ios_background_ble_claim_allowed?: false,
      ios_parity_claim_allowed?: false
    }
  end

  defp decision_scenarios(review, validation_plan) do
    [
      %{
        id: :keep_ios_contract_only,
        decision_outcome: :keep_ios_contract_only,
        status: :selected_for_current_validated_mode,
        ios_mode_after_decision: :contract_only,
        ios_hardware_participation_enabled?: false,
        ios_legacy_beacon_observe_claim_allowed?: false,
        ios_legacy_beacon_gossip_claim_allowed?: false,
        ios_full_envelope_advert_claim_allowed?: false,
        ios_background_ble_claim_allowed?: false,
        required_operator_evidence: [
          "Operator/release note preserves iOS contract-only wording.",
          "Release artifact references LocalIOSParityEvidenceManifest.",
          "iOS hardware participation, legacy beacon observe/gossip, full-envelope advert, hardware replay, background BLE, and parity claims remain blocked."
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :ios_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/ios/decision.md"
      },
      %{
        id: :enable_ios_advert_only_participation,
        decision_outcome: :enable_ios_advert_only_participation,
        status: :blocked,
        ios_mode_after_decision: :ios_advert_only_participation,
        ios_hardware_participation_enabled?: false,
        ios_legacy_beacon_observe_claim_allowed?: false,
        ios_legacy_beacon_gossip_claim_allowed?: false,
        ios_full_envelope_advert_claim_allowed?: false,
        ios_background_ble_claim_allowed?: false,
        required_operator_evidence: [
          "Product/platform decision explicitly selects enable_ios_advert_only_participation.",
          "Every LocalIOSParityHardwareValidationPlan gate has supplied evidence.",
          "LocalIOSParityHardwareEvidenceReview returns ready for the supplied metadata.",
          "Release wording still blocks delivery, trust, routing, background, and Android-evidence-reuse overclaims."
        ],
        required_gates: Enum.map(validation_plan.gates, & &1.id),
        missing_evidence:
          validation_plan.gates |> Enum.flat_map(& &1.missing_evidence) |> Enum.uniq(),
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :ios_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/ios/decision.md"
      }
    ]
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_ios_parity.hardware_review --template --out artifacts/local-ble/<run-id>/ios/evidence.json",
      "mix meshx.mobile.local_ios_parity.hardware_review --input artifacts/local-ble/<run-id>/ios/evidence.json --json --out tmp/local-ios-parity-hardware-review.json"
    ]
  end
end
