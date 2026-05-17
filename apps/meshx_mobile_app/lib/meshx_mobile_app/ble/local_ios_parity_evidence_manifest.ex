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
      ios_legacy_beacon_observe_hardware_validated?: true,
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
        "iOS has foreground scanner decode and hardware proof for Android-to-iPhone legacy beacon observation.",
        "SM-T577U -> iPad12,1 direct full-MX AUX scan-response probing is archived as negative evidence; it does not enable the full-envelope advert claim.",
        "iOS observe, foreground MB beacon emit, and autonomous beacon gossip remain separate claims; iOS-origin cross-radio gossip proof is still missing.",
        "Direct full-MX extended advertising remains blocked on tested iOS hardware; use MB legacy beacon plus GATT fetch for full-envelope delivery.",
        "iOS parity remains claim-blocked until emission, full-envelope, background, and replay-normalized gates are satisfied as required.",
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
          "Archive partial iOS hardware evidence, open hardware gates, and blocked iOS parity claims."
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
      hardware_validated_behavior: [
        :foreground_legacy_beacon_manufacturer_data_observe
      ],
      implemented_unvalidated_behavior: [
        :canonical_received_message_beacon_wire_map,
        :swift_parser_fixture,
        :foreground_legacy_beacon_manufacturer_data_emit
      ],
      not_selected_behavior: [
        :ios_legacy_beacon_gossip_emit,
        :ios_full_envelope_advert_emit,
        :ios_background_ble_scan,
        :ios_background_ble_advertise
      ],
      not_evidence_of: [
        :ios_legacy_beacon_gossip,
        :ios_full_mx_direct_advert_receive,
        :ios_full_envelope_advert,
        :ios_parity_claim
      ],
      notes: [
        "iOS source code, parser fixtures, and the 2026-05-15 iPhone 13 capture prove foreground legacy-beacon observation.",
        "Foreground iOS MB beacon emission code exists, but the 2026-05-17 iPad run records zero matched Android receive lines.",
        "The 2026-05-17 SM-T577U -> iPad12,1 AUX probe and 11:19 rerun are negative capability evidence only.",
        "iOS observe and iOS emit remain separate claims.",
        "The iOS observe proof does not satisfy iOS beacon gossip, direct full-MX advertising, background BLE, or parity gates."
      ]
    }
  end

  defp implementation_evidence do
    [
      %{
        id: :ios_foreground_legacy_beacon_scan_decode,
        status: :hardware_validated,
        files: [
          "meshx_mobile/Sources/MeshxMobile/BLE.swift",
          "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
          "apps/meshx_mobile_app/ios/meshx_ble_nif.m"
        ],
        hardware_evidence: [
          "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26b-android-to-iphone-receive/summary.json"
        ],
        notes: [
          "CoreBluetooth scan results inspect manufacturer data for MeshX 22-byte legacy beacon payloads.",
          "Observed beacons are emitted to Elixir as canonical received_message_beacon v1 wire maps.",
          "Hardware evidence proves Android-to-iPhone legacy-beacon observation only; iOS parity remains blocked."
        ]
      },
      %{
        id: :ios_foreground_legacy_beacon_emit,
        status: :implemented_unvalidated,
        files: [
          "meshx_mobile/Sources/MeshxMobile/BLE.swift",
          "apps/meshx_mobile_app/ios/MeshxBLEBridge.swift",
          "meshx_mobile/Examples/MeshxMobileHarness/MeshxMobileHarness/BLEHarnessModel.swift"
        ],
        hardware_evidence: [
          "artifacts/local-ble/2026-05-15-iphone13-sm-t577u/hardware/i26-iphone-dispatch/summary.json",
          "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/summary.json"
        ],
        notes: [
          "Foreground iOS code can advertise an MB beacon cue through CBAdvertisementDataManufacturerDataKey.",
          "The current iPad evidence records local dispatch but zero matched Android receive lines.",
          "This does not satisfy iOS legacy beacon gossip, one-hop hardware proof, or parity claims."
        ]
      },
      %{
        id: :ios_direct_full_mx_aux_scan_response_probe,
        status: :negative_hardware_evidence,
        files: [
          "apps/meshx_mobile_app/android/app/src/androidTest/java/dev/meshx/mob/ble/IOSAuxFullMxAdvertSmokeTest.kt",
          "meshx_mobile/Sources/MeshxMobile/MessageAdvertisementObserver.swift",
          "docs/BLE_BRIDGE.md"
        ],
        hardware_evidence: [
          "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe/summary.md",
          "artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/android-aux-full-mx-ios-observe-rerun/summary.md"
        ],
        notes: [
          "Android emitted 80-byte full-MX scan-response extended adverts from SM-T577U in the original probe and rerun.",
          "iPad12,1 observed MB legacy beacons during the scan sessions, but no direct full-MX received_message, decode-error, candidate discovery callback, or FF FF 4D 58 MX callback evidence.",
          "This keeps ios_full_envelope_advert_claim_allowed? false."
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
