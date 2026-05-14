defmodule MeshxMobileApp.BLE.LocalRoutingDecisionScenarioPlan do
  @moduledoc """
  Scenario plan for local BLE routing decision outcomes.

  This plan makes the current advert-only non-routing decision explicit beside
  the blocked production-routing path. It is policy evidence only. It does not
  route, forward, scan, advertise, persist, ACK, retry, fetch, encrypt,
  authenticate, or run background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalRoutingHardwareValidationPlan,
    LocalRoutingPolicy,
    LocalRoutingProductionEvidenceReview
  }

  @allowed_decision_outcomes [
    :keep_advert_only_non_routing,
    :enable_production_routing
  ]

  @spec snapshot() :: map()
  def snapshot do
    decision = LocalRoutingPolicy.snapshot()
    validation_plan = LocalRoutingHardwareValidationPlan.snapshot()
    review = LocalRoutingProductionEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_routing_decision_scenario_plan,
      status: :open,
      current_routing_decision: current_decision(decision),
      selected_decision_outcome: decision.decision_outcome,
      allowed_decision_outcomes: @allowed_decision_outcomes,
      route_table_claim_allowed?: false,
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      guaranteed_delivery_claim_allowed?: false,
      multi_hop_hardware_claim_allowed?: false,
      validation_plan: validation_plan,
      decision_scenarios: decision_scenarios(review, validation_plan),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/routing/",
      notes: [
        "This scenario plan is not routing evidence by itself.",
        "keep_advert_only_non_routing is selected for the current advertisement-only local mesh mode.",
        "enable_production_routing remains blocked until every routing validation gate has operator-reviewed evidence.",
        "Route candidates and advert gossip planning remain read-model/simulation evidence, not forwarding or delivery."
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
      current_mode: :advert_only_non_routing,
      production_routing_enabled?: false,
      route_selection_enabled?: false,
      forwarding_service_enabled?: false,
      routed_delivery_enabled?: false,
      production_routing_reconsideration_gate: decision.production_routing_reconsideration_gate
    }
  end

  defp decision_scenarios(review, validation_plan) do
    [
      %{
        id: :keep_advert_only_non_routing,
        decision_outcome: :keep_advert_only_non_routing,
        status: :selected_for_current_validated_mode,
        routing_mode_after_decision: :advert_only_non_routing,
        production_routing_enabled?: false,
        route_selection_enabled?: false,
        forwarding_service_enabled?: false,
        routed_delivery_enabled?: false,
        required_operator_evidence: [
          "Operator/release note preserves advert-only non-routing wording.",
          "Release artifact references LocalRoutingEvidenceManifest.",
          "Route selection, forwarding, routed delivery, ACK/retry, guaranteed delivery, and multi-hop hardware routing claims remain blocked."
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :routing_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/routing/decision.md"
      },
      %{
        id: :enable_production_routing,
        decision_outcome: :enable_production_routing,
        status: :blocked,
        routing_mode_after_decision: :production_routing,
        production_routing_enabled?: false,
        route_selection_enabled?: false,
        forwarding_service_enabled?: false,
        routed_delivery_enabled?: false,
        required_operator_evidence: [
          "Product/routing decision explicitly selects enable_production_routing.",
          "Every LocalRoutingHardwareValidationPlan gate has supplied evidence.",
          "LocalRoutingProductionEvidenceReview returns ready for the supplied metadata.",
          "Release wording still blocks delivery, trust, background, guaranteed-delivery, and replay-only gossip overclaims."
        ],
        required_gates: Enum.map(validation_plan.gates, & &1.id),
        missing_evidence:
          validation_plan.gates |> Enum.flat_map(& &1.missing_evidence) |> Enum.uniq(),
        blocked_claims_called_out: review.required_blocked_claims(),
        review_section: :routing_attachments,
        artifact_path: "artifacts/local-ble/<run-id>/routing/decision.md"
      }
    ]
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_routing.production_review --template --out artifacts/local-ble/<run-id>/routing/evidence.json",
      "mix meshx.mobile.local_routing.production_review --input artifacts/local-ble/<run-id>/routing/evidence.json --json --out tmp/local-routing-production-review.json"
    ]
  end
end
