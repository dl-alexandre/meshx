defmodule MeshxMobileApp.BLE.LocalLifecycleDecisionScenarioPlan do
  @moduledoc """
  Scenario plan for mobile BLE lifecycle decision outcomes.

  This plan makes the current foreground/manual lifecycle decision explicit
  beside the blocked background-lifecycle path. It is policy evidence only.
  It does not start Android services, request iOS background modes, schedule
  retries, scan, advertise, gossip, route, persist, ACK, retry, fetch, encrypt,
  authenticate, or run background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalLifecycleHardwareEvidenceReview,
    LocalLifecycleHardwareValidationPlan,
    LocalLifecyclePolicy
  }

  @allowed_decision_outcomes [
    :keep_foreground_manual,
    :enable_background_lifecycle
  ]

  @spec snapshot() :: map()
  def snapshot do
    decision = LocalLifecyclePolicy.snapshot()
    validation_plan = LocalLifecycleHardwareValidationPlan.snapshot()
    review = LocalLifecycleHardwareEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_lifecycle_decision_scenario_plan,
      status: :open,
      current_lifecycle_decision: current_decision(decision),
      selected_decision_outcome: decision.decision_outcome,
      allowed_decision_outcomes: @allowed_decision_outcomes,
      android_foreground_service_claim_allowed?: false,
      android_background_ble_claim_allowed?: false,
      ios_background_ble_claim_allowed?: false,
      background_ble_claim_allowed?: false,
      restart_claim_allowed?: false,
      scheduled_retry_claim_allowed?: false,
      background_gossip_claim_allowed?: false,
      background_delivery_claim_allowed?: false,
      validation_plan: validation_plan,
      decision_scenarios: decision_scenarios(review, validation_plan),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/lifecycle/",
      notes: [
        "This scenario plan is not lifecycle hardware evidence by itself.",
        "keep_foreground_manual is selected for the current advertisement-only local mesh mode.",
        "enable_background_lifecycle remains blocked until every lifecycle validation gate has operator-reviewed evidence.",
        "Foreground/manual validation is not Android foreground-service, Android/iOS background BLE, restart, scheduled retry, or background gossip evidence."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_decision(decision) do
    %{
      decision_outcome: decision.decision_outcome,
      decision_status: decision.decision_status,
      current_mode: :foreground_manual,
      android_foreground_service_enabled?: false,
      android_background_ble_enabled?: false,
      ios_background_ble_enabled?: false,
      automatic_restart_enabled?: false,
      scheduled_retry_enabled?: false,
      background_gossip_enabled?: false,
      background_lifecycle_reconsideration_gate:
        decision.background_lifecycle_reconsideration_gate
    }
  end

  defp decision_scenarios(review, validation_plan) do
    [
      %{
        id: :keep_foreground_manual,
        decision_outcome: :keep_foreground_manual,
        status: :selected_for_current_validated_mode,
        lifecycle_mode_after_decision: :foreground_manual,
        android_foreground_service_enabled?: false,
        android_background_ble_enabled?: false,
        ios_background_ble_enabled?: false,
        automatic_restart_enabled?: false,
        scheduled_retry_enabled?: false,
        background_gossip_enabled?: false,
        required_operator_evidence: [
          "Operator/release note preserves foreground/manual lifecycle wording.",
          "Release artifact references LocalLifecycleEvidenceManifest.",
          "Android foreground-service, Android/iOS background BLE, restart, scheduled retry, background gossip, and background delivery claims remain blocked."
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :lifecycle_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/lifecycle/decision.md"
      },
      %{
        id: :enable_background_lifecycle,
        decision_outcome: :enable_background_lifecycle,
        status: :blocked,
        lifecycle_mode_after_decision: :background_lifecycle,
        android_foreground_service_enabled?: false,
        android_background_ble_enabled?: false,
        ios_background_ble_enabled?: false,
        automatic_restart_enabled?: false,
        scheduled_retry_enabled?: false,
        background_gossip_enabled?: false,
        required_operator_evidence: [
          "Product/lifecycle decision explicitly selects enable_background_lifecycle.",
          "Every LocalLifecycleHardwareValidationPlan gate has supplied evidence.",
          "LocalLifecycleHardwareEvidenceReview returns ready for the supplied metadata.",
          "Release wording still blocks delivery, trust, routing, guaranteed-delivery, and foreground-only overclaims."
        ],
        required_gates: Enum.map(validation_plan.gates, & &1.id),
        missing_evidence:
          validation_plan.gates |> Enum.flat_map(& &1.missing_evidence) |> Enum.uniq(),
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :lifecycle_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/lifecycle/decision.md"
      }
    ]
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_lifecycle.hardware_review --template --out artifacts/local-ble/<run-id>/lifecycle/evidence.json",
      "mix meshx.mobile.local_lifecycle.hardware_review --input artifacts/local-ble/<run-id>/lifecycle/evidence.json --json --out tmp/local-lifecycle-hardware-review.json"
    ]
  end
end
