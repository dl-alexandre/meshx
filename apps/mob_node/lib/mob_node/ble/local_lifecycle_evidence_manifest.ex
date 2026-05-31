defmodule Mob.Node.BLE.LocalLifecycleEvidenceManifest do
  @moduledoc """
  Machine-readable local lifecycle evidence manifest.

  The manifest packages the current foreground/manual lifecycle evidence,
  policy gates, future lifecycle contracts, hardware validation gates, and
  negative validation. It is an artifact shape only. It does not start Android
  services, request iOS background modes, schedule retries, scan, advertise,
  gossip, route, persist, ACK, retry, fetch, encrypt, authenticate, or run
  background work.
  """

  alias Mob.Node.BLE.{
    LocalBackgroundLifecycleContract,
    LocalLifecycleAcceptance,
    LocalLifecycleDecisionScenarioPlan,
    LocalLifecycleHardwareEvidenceReview,
    LocalLifecycleHardwareValidationPlan,
    LocalLifecycleManualSession,
    LocalLifecycleNegativeValidation,
    LocalLifecycleOperatorCapturePlan,
    LocalLifecyclePolicy,
    LocalLifecycleProofPlan,
    LocalTransportLifecycleProfile
  }

  @required_commands [
    "mix mob.node.local_lifecycle.validation_plan --json --out <path>",
    "mix mob.node.local_lifecycle.evidence --json --out <path>",
    "mix mob.node.local_lifecycle.hardware_review --template --out <path>",
    "mix mob.node.local_lifecycle.hardware_review --input <path> --json --out <path>",
    "mix test apps/mob_node/test/mob_node/ble/local_background_lifecycle_contract_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_acceptance_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_decision_scenario_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_evidence_manifest_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_hardware_evidence_review_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_hardware_validation_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_manual_session_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_negative_validation_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_operator_capture_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_policy_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_lifecycle_proof_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_transport_lifecycle_profile_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_lifecycle_validation_plan_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_lifecycle_evidence_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_lifecycle_hardware_review_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    profile = LocalTransportLifecycleProfile.foreground_manual()
    policy = LocalLifecyclePolicy.snapshot()
    acceptance = LocalLifecycleAcceptance.snapshot(profile)
    hardware_plan = LocalLifecycleHardwareValidationPlan.snapshot()
    manual_session = LocalLifecycleManualSession.snapshot([manual_session_fixture()])

    %{
      manifest_version: 1,
      boundary: :local_lifecycle_evidence_manifest,
      current_mode: :foreground_manual,
      current_lifecycle_decision: lifecycle_decision(policy),
      lifecycle_decision_scenario_plan: LocalLifecycleDecisionScenarioPlan.snapshot(),
      android_foreground_service_claim_allowed?: false,
      android_background_ble_claim_allowed?: false,
      ios_background_claim_allowed?: false,
      background_ble_claim_allowed?: false,
      restart_claim_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      background_gossip_claim_allowed?: false,
      delivery_claim_allowed?: false,
      foreground_manual_scope: foreground_manual_scope(),
      profile: LocalTransportLifecycleProfile.snapshot(profile),
      policy: policy_summary(policy),
      acceptance: acceptance,
      manual_session_evidence: manual_session,
      background_contract: contract_summary(LocalBackgroundLifecycleContract.snapshot()),
      proof_plan: LocalLifecycleProofPlan.snapshot(),
      hardware_validation_plan: hardware_plan,
      operator_capture_plan: LocalLifecycleOperatorCapturePlan.snapshot(),
      hardware_evidence_review: LocalLifecycleHardwareEvidenceReview.review(%{}),
      negative_validation: LocalLifecycleNegativeValidation.snapshot(),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      acceptance_blocked_count: acceptance.blocked_count,
      foreground_manual_complete_session_count: manual_session.complete_session_count,
      hardware_blocked_gate_count: hardware_plan.blocked_gate_count,
      open_hardware_gate_count: hardware_plan.blocked_gate_count,
      missing_lifecycle_evidence: missing_lifecycle_evidence(hardware_plan),
      notes: [
        "Foreground/manual BLE is the only lifecycle mode validated today.",
        "Android foreground-service, Android/iOS background BLE, restart, scheduled retry, and background gossip claims remain blocked.",
        "Lifecycle evidence is device-specific and cannot be inferred from replay fixtures alone."
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
        id: :lifecycle_validation_plan,
        command: "mix mob.node.local_lifecycle.validation_plan --json --out <path>",
        purpose:
          "Archive the mobile BLE lifecycle hardware validation checklist before operator evidence review."
      },
      %{
        id: :lifecycle_evidence_manifest,
        command: "mix mob.node.local_lifecycle.evidence --json --out <path>",
        purpose:
          "Archive foreground/manual lifecycle evidence, open hardware gates, and blocked background claims."
      },
      %{
        id: :lifecycle_decision_scenario_plan,
        command: "mix mob.node.local_lifecycle.evidence --json --out <path>",
        source: "LocalLifecycleDecisionScenarioPlan",
        purpose:
          "Archive keep_foreground_manual and enable_background_lifecycle decision scenarios before any lifecycle wording changes."
      },
      %{
        id: :lifecycle_hardware_evidence_template,
        command: "mix mob.node.local_lifecycle.hardware_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for mobile lifecycle hardware evidence."
      },
      %{
        id: :lifecycle_operator_capture_plan,
        source: "LocalLifecycleOperatorCapturePlan",
        purpose:
          "Archive the lifecycle operator capture checklist for target devices, Android foreground service, Android/iOS background BLE, restart, retry, background gossip, and negative evidence before operator evidence is attached."
      },
      %{
        id: :lifecycle_hardware_evidence_review,
        command:
          "mix mob.node.local_lifecycle.hardware_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied target device, foreground service, Android/iOS background BLE, restart, retry, background gossip, and negative evidence metadata."
      },
      %{
        id: :android_foreground_service_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/lifecycle/android-foreground-service/",
        purpose:
          "Attach Android service/backgrounding logs before any Android foreground-service BLE wording is considered."
      },
      %{
        id: :ios_background_ble_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/lifecycle/ios-background-ble/",
        purpose:
          "Attach iOS background BLE logs before any iOS background participation wording is considered."
      },
      %{
        id: :restart_retry_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/lifecycle/restart-retry/",
        purpose:
          "Attach restart, cancellation, scheduled retry, and negative lifecycle logs before any lifecycle automation wording is considered."
      }
    ]
  end

  defp foreground_manual_scope do
    %{
      current_mode: :foreground_manual,
      allowed_current_behavior: [
        :operator_started_scan,
        :operator_started_advertise,
        :foreground_event_observation,
        :operator_stop
      ],
      disallowed_current_behavior: [
        :android_foreground_service_ble,
        :android_background_scan,
        :android_background_advertise,
        :ios_background_scan,
        :ios_background_advertise,
        :automatic_ble_restart,
        :scheduled_retry,
        :background_gossip,
        :background_delivery
      ],
      not_evidence_of: [
        :background_ble_operation,
        :restart_survival,
        :scheduled_retry_execution,
        :os_throttling_behavior,
        :background_delivery,
        :guaranteed_delivery
      ],
      notes: [
        "Foreground/manual evidence requires the app to be actively operated.",
        "Foreground/manual logs do not prove Android foreground-service or iOS background BLE behavior.",
        "Background lifecycle claims require device-specific hardware logs and negative evidence."
      ]
    }
  end

  defp policy_summary(policy) do
    %{
      mode: policy.mode,
      decision_outcome: policy.decision_outcome,
      decision_status: policy.decision_status,
      background_lifecycle_reconsideration_gate: policy.background_lifecycle_reconsideration_gate,
      capabilities: Enum.map(policy.capabilities, &capability_summary/1),
      allowed_count: policy.allowed_count,
      blocked_count: policy.blocked_count,
      background_claims_allowed?: policy.background_claims_allowed?,
      foreground_service_claim_allowed?: policy.foreground_service_claim_allowed?,
      restart_claims_allowed?: policy.restart_claims_allowed?,
      scheduled_retry_claim_allowed?: policy.scheduled_retry_claim_allowed?,
      background_gossip_claim_allowed?: policy.background_gossip_claim_allowed?,
      notes: policy.notes
    }
  end

  defp lifecycle_decision(policy) do
    %{
      decision_outcome: policy.decision_outcome,
      decision_status: policy.decision_status,
      current_mode: :foreground_manual,
      android_foreground_service_enabled?: false,
      android_background_ble_enabled?: false,
      ios_background_ble_enabled?: false,
      automatic_restart_enabled?: false,
      scheduled_retry_enabled?: false,
      background_gossip_enabled?: false,
      background_lifecycle_reconsideration_gate: policy.background_lifecycle_reconsideration_gate,
      rationale: [
        "The current validated mobile BLE mode is foreground/manual harness operation.",
        "Foreground/manual evidence is not Android foreground-service or iOS background behavior.",
        "Background lifecycle claims need device-specific service, backgrounding, restart, retry, and negative evidence before claims change."
      ]
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

  defp missing_lifecycle_evidence(hardware_plan) do
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
      :android_foreground_service_ble,
      :android_background_scan,
      :android_background_advertise,
      :ios_background_scan,
      :ios_background_advertise,
      :background_ble_operation,
      :automatic_ble_restart,
      :scheduled_retry,
      :retry_backed_delivery,
      :background_gossip,
      :background_forwarding,
      :background_delivery,
      :guaranteed_delivery
    ]
  end

  defp manual_session_fixture do
    %{
      device_id: "foreground-manual-fixture",
      app_state: :foreground,
      actions: [
        :operator_start_scan,
        :operator_start_advertise,
        :operator_observe_events,
        :operator_stop
      ]
    }
  end
end
