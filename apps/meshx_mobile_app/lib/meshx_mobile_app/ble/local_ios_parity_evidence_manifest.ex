defmodule MeshxMobileApp.BLE.LocalIOSParityEvidenceManifest do
  @moduledoc """
  Machine-readable iOS parity evidence manifest.

  The manifest packages the current iOS foreground legacy-beacon observe
  implementation state, parity policy, acceptance gates, future proof plan,
  hardware validation plan, and negative validation. It is an artifact shape
  only. It does not touch hardware, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, authenticate, or run background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalIOSParityAcceptance,
    LocalIOSAdvertCarrierDecision,
    LocalIOSParityContract,
    LocalIOSParityDecisionScenarioPlan,
    LocalIOSParityHardwareValidationPlan,
    LocalIOSParityNegativeValidation,
    LocalIOSParityOperatorCapturePlan,
    LocalIOSParityPolicy,
    LocalIOSParityProofPlan,
    LocalIOSNativeSourceInventory
  }

  @required_commands [
    "mix meshx.mobile.local_ios_parity.evidence --json --out <path>",
    "mix meshx.mobile.local_ios_parity.hardware_review --template --out <path>",
    "mix meshx.mobile.local_ios_parity.hardware_review --input <path> --json --out <path>",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_advert_carrier_decision_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_acceptance_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_contract_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_decision_scenario_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_evidence_manifest_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_hardware_evidence_review_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_hardware_validation_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_negative_validation_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_operator_capture_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_native_source_inventory_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_policy_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_ios_parity_proof_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_ios_parity_evidence_test.exs",
    "mix test apps/meshx_mobile_app/test/mix/tasks/meshx_mobile_local_ios_parity_hardware_review_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    policy = LocalIOSParityPolicy.snapshot()
    acceptance = LocalIOSParityAcceptance.snapshot()
    hardware_plan = LocalIOSParityHardwareValidationPlan.snapshot()

    %{
      manifest_version: 1,
      boundary: :local_ios_parity_evidence_manifest,
      current_ios_mode: :contract_only,
      native_foreground_legacy_beacon_observe_present?: true,
      ios_participation_claim_allowed?: false,
      ios_hardware_claim_allowed?: false,
      ios_parity_claim_allowed?: false,
      ios_legacy_beacon_observe_claim_allowed?: false,
      ios_legacy_beacon_gossip_claim_allowed?: false,
      ios_full_envelope_advert_claim_allowed?: false,
      ios_background_ble_claim_allowed?: false,
      contract_only_scope: contract_only_scope(),
      policy: policy_summary(policy),
      acceptance: acceptance,
      advert_carrier_decision: LocalIOSAdvertCarrierDecision.snapshot(),
      ios_parity_decision_scenario_plan: LocalIOSParityDecisionScenarioPlan.snapshot(),
      contract: contract_summary(LocalIOSParityContract.snapshot()),
      native_source_inventory: LocalIOSNativeSourceInventory.snapshot(),
      implementation_evidence: implementation_evidence(),
      proof_plan: LocalIOSParityProofPlan.snapshot(),
      hardware_validation_plan: hardware_plan,
      operator_capture_plan: LocalIOSParityOperatorCapturePlan.snapshot(),
      negative_validation: LocalIOSParityNegativeValidation.snapshot(),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      acceptance_blocked_count: acceptance.blocked_count,
      hardware_blocked_gate_count: hardware_plan.blocked_gate_count,
      open_hardware_gate_count: hardware_plan.blocked_gate_count,
      missing_ios_evidence: missing_ios_evidence(hardware_plan),
      notes: [
        "iOS has a foreground scanner decode path for legacy beacon manufacturer advertisements, but no iOS hardware proof is recorded.",
        "iOS observe and iOS emit remain separate claims; no iOS beacon gossip carrier is selected.",
        "iOS remains claim-blocked until native behavior is captured on hardware and replay-normalized.",
        "Android legacy beacon proof cannot satisfy iOS parity claims.",
        "iOS hardware captures must normalize through the same replay path before iOS participation is claimed."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp required_artifacts do
    [
      %{
        id: :ios_parity_evidence_manifest,
        command: "mix meshx.mobile.local_ios_parity.evidence --json --out <path>",
        purpose:
          "Archive iOS contract-only state, open hardware gates, and blocked iOS parity claims."
      },
      %{
        id: :ios_parity_decision_scenario_plan,
        command: "mix meshx.mobile.local_ios_parity.evidence --json --out <path>",
        source: "LocalIOSParityDecisionScenarioPlan",
        purpose:
          "Archive keep_ios_contract_only and enable_ios_advert_only_participation decision scenarios before any iOS parity wording changes."
      },
      %{
        id: :ios_parity_hardware_evidence_template,
        command: "mix meshx.mobile.local_ios_parity.hardware_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for iOS advert-only hardware evidence."
      },
      %{
        id: :ios_parity_operator_capture_plan,
        source: "LocalIOSParityOperatorCapturePlan",
        purpose:
          "Archive the iOS parity operator capture checklist for target devices, canonical ingress, legacy beacon observe/gossip, full-envelope capability, replay fixture, background boundary, and negative evidence."
      },
      %{
        id: :ios_parity_hardware_evidence_review,
        command:
          "mix meshx.mobile.local_ios_parity.hardware_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied iOS hardware metadata before any iOS participation wording changes."
      },
      %{
        id: :ios_legacy_beacon_observe_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ios/legacy-beacon-observe/",
        purpose:
          "Attach iOS scan logs before any iOS legacy beacon observation wording is considered."
      },
      %{
        id: :ios_legacy_beacon_gossip_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ios/legacy-beacon-gossip/",
        purpose:
          "Attach iOS emission and observer logs before any iOS legacy beacon gossip wording is considered."
      },
      %{
        id: :ios_hardware_replay_fixture,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/ios/replay/",
        purpose:
          "Attach replay-normalized iOS hardware fixtures or ledgers before any iOS advert-only parity wording is considered."
      }
    ]
  end

  defp contract_only_scope do
    %{
      current_mode: :contract_only,
      implemented_unvalidated_behavior: [
        :foreground_legacy_beacon_manufacturer_data_decode,
        :canonical_received_message_beacon_wire_map,
        :swift_parser_fixture
      ],
      not_selected_behavior: [
        :ios_legacy_beacon_gossip_emit,
        :ios_full_envelope_advert_emit,
        :ios_background_ble_scan,
        :ios_background_ble_advertise
      ],
      not_evidence_of: [
        :ios_hardware_participation,
        :ios_legacy_beacon_observed_on_device,
        :ios_legacy_beacon_gossip,
        :ios_full_envelope_advert,
        :ios_parity_claim
      ],
      notes: [
        "iOS source code and parser fixtures are implementation evidence, not hardware evidence.",
        "iOS observe and iOS emit remain separate claims.",
        "Android one-hop legacy beacon proof cannot satisfy any iOS hardware gate."
      ]
    }
  end

  defp implementation_evidence do
    [
      %{
        id: :ios_foreground_legacy_beacon_scan_decode,
        status: :implemented_unvalidated,
        files: [
          "meshx_mobile/Sources/MeshxMobile/BLE.swift",
          "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
          "apps/meshx_mobile_app/ios/meshx_ble_nif.m"
        ],
        notes: [
          "CoreBluetooth scan results inspect manufacturer data for MeshX 22-byte legacy beacon payloads.",
          "Observed beacons are emitted to Elixir as canonical received_message_beacon v1 wire maps.",
          "This is foreground implementation evidence only; iOS hardware parity remains blocked until capture logs exist."
        ]
      }
    ]
  end

  defp policy_summary(policy) do
    %{
      mode: policy.mode,
      platform: policy.platform,
      capabilities: Enum.map(policy.capabilities, &capability_summary/1),
      contract_only_count: policy.contract_only_count,
      blocked_count: policy.blocked_count,
      ios_participation_claims_allowed?: policy.ios_participation_claims_allowed?,
      notes: policy.notes
    }
  end

  defp capability_summary(capability) do
    %{
      id: capability.id,
      status: capability.status,
      allowed_claims: capability.allowed_claims,
      blocked_claims: capability.blocked_claims,
      required_before_allowed: capability.required_before_allowed
    }
  end

  defp contract_summary(contract) do
    %{
      requirements: Enum.map(contract.requirements, &requirement_summary/1),
      open_requirements: Enum.map(contract.open_requirements, &requirement_summary/1),
      open_requirement_count: contract.open_requirement_count,
      notes: contract.notes
    }
  end

  defp requirement_summary(requirement) do
    %{
      id: requirement.id,
      status: requirement.status,
      required_evidence: requirement.required_evidence,
      current_gap: requirement.current_gap,
      notes: requirement.notes
    }
  end

  defp missing_ios_evidence(hardware_plan) do
    Enum.map(hardware_plan.gates, fn gate ->
      %{
        gate_id: gate.id,
        required_evidence: gate.required_evidence,
        missing_evidence: gate.missing_evidence,
        blocked_claims: gate.blocked_claims
      }
    end)
  end

  defp blocked_claims do
    [
      :ios_hardware_participation,
      :ios_advert_only_validation,
      :ios_legacy_beacon_observed,
      :ios_legacy_beacon_gossip,
      :ios_full_envelope_advert,
      :ios_full_message_observation,
      :ios_hardware_replay_fixture,
      :ios_background_ble,
      :ios_background_scan,
      :ios_background_advertise,
      :ios_parity_claim
    ]
  end
end
