defmodule Mob.Node.BLE.LocalInboxUxDecisionScenarioPlan do
  @moduledoc """
  Scenario plan for Nearby Messages UX release decision outcomes.

  This plan makes the current pure-surface UX decision explicit beside the
  blocked production UX promotion path. It is decision evidence only. It does
  not render UI, drive devices, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, authenticate, or run background work.
  """

  alias Mob.Node.BLE.{
    LocalInboxUxEvidenceReview,
    LocalInboxUxTargetDeviceScenarioPlan,
    LocalInboxUxValidationPlan
  }

  @allowed_decision_outcomes [
    :keep_pure_surface_evidence_only,
    :promote_nearby_messages_production_ux
  ]

  @spec snapshot() :: map()
  def snapshot do
    validation_plan = LocalInboxUxValidationPlan.snapshot()
    target_device_scenario_plan = LocalInboxUxTargetDeviceScenarioPlan.snapshot()

    %{
      plan_version: 1,
      boundary: :nearby_messages_ux_decision_scenario_plan,
      status: :open,
      selected_decision_outcome: :keep_pure_surface_evidence_only,
      allowed_decision_outcomes: @allowed_decision_outcomes,
      current_ux_decision: current_decision(validation_plan),
      production_ux_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routing_claim_allowed?: false,
      background_operation_claim_allowed?: false,
      validation_plan: validation_plan,
      target_device_scenario_plan: target_device_scenario_plan,
      decision_scenarios: decision_scenarios(validation_plan, target_device_scenario_plan),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/ux/",
      notes: [
        "This scenario plan is not target-device UX evidence by itself.",
        "keep_pure_surface_evidence_only is selected for the current advertisement-only local mesh mode.",
        "promote_nearby_messages_production_ux remains blocked until target-device evidence satisfies LocalInboxUxEvidenceReview.",
        "Production UX evidence does not enable delivery, trust, routing, background operation, or fetch claims."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_decision(validation_plan) do
    %{
      decision_outcome: :keep_pure_surface_evidence_only,
      decision_status: :selected_for_current_validated_mode,
      open_validation_gate_count: validation_plan.open_gate_count,
      production_ux_claim_allowed?: false,
      delivery_claim_allowed?: false,
      trusted_delivery_claim_allowed?: false,
      routing_claim_allowed?: false,
      background_operation_claim_allowed?: false
    }
  end

  defp decision_scenarios(validation_plan, target_device_scenario_plan) do
    [
      %{
        id: :keep_pure_surface_evidence_only,
        decision_outcome: :keep_pure_surface_evidence_only,
        status: :selected_for_current_validated_mode,
        ux_mode_after_decision: :pure_surface_evidence_only,
        production_ux_enabled?: false,
        production_ux_claim_allowed?: false,
        delivery_claim_allowed?: false,
        trusted_delivery_claim_allowed?: false,
        routing_claim_allowed?: false,
        background_operation_claim_allowed?: false,
        required_operator_evidence: [
          "Operator/release note preserves Nearby Messages pure-surface wording.",
          "Release artifact references LocalInboxUxEvidenceManifest.",
          "Production UX, delivery, trusted delivery, routing, background, and fetch claims remain blocked."
        ],
        blocked_claims_called_out: blocked_claims(),
        review_section: :ux_review,
        artifact_path: "artifacts/local-ble/<run-id>/ux/decision.md"
      },
      %{
        id: :promote_nearby_messages_production_ux,
        decision_outcome: :promote_nearby_messages_production_ux,
        status: :blocked,
        ux_mode_after_decision: :production_nearby_messages_ux,
        production_ux_enabled?: false,
        production_ux_claim_allowed?: false,
        delivery_claim_allowed?: false,
        trusted_delivery_claim_allowed?: false,
        routing_claim_allowed?: false,
        background_operation_claim_allowed?: false,
        required_operator_evidence: [
          "Product decision explicitly selects promote_nearby_messages_production_ux.",
          "Every LocalInboxUxValidationPlan gate has supplied target-device evidence.",
          "LocalInboxUxEvidenceReview returns ready for the supplied metadata.",
          "Release wording still blocks delivery, trust, routing, background, fetch, and hardware overclaims."
        ],
        required_gates: Enum.map(validation_plan.gates, & &1.id),
        required_states: target_device_scenario_plan.required_states,
        required_interactions: target_device_scenario_plan.required_interactions,
        required_sorts: target_device_scenario_plan.required_sorts,
        missing_evidence:
          validation_plan.gates
          |> Enum.flat_map(& &1.required_evidence)
          |> Enum.uniq(),
        blocked_claims_called_out: blocked_claims(),
        review_section: :ux_review,
        artifact_path: "artifacts/local-ble/<run-id>/ux/decision.md"
      }
    ]
  end

  defp blocked_claims do
    [:production_nearby_messages_ux] ++ LocalInboxUxEvidenceReview.required_blocked_claims()
  end

  defp review_commands do
    [
      "mix mob.node.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json",
      "mix mob.node.local_inbox.ux_review --input artifacts/local-ble/<run-id>/ux/evidence.json --json --out tmp/local-inbox-ux-review.json"
    ]
  end
end
