defmodule MeshxMobileApp.BLE.LocalRoutingOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for production routing evidence.

  The plan turns `LocalRoutingHardwareValidationPlan` gates into concrete
  artifact slots that can be filled before running
  `LocalRoutingProductionEvidenceReview`. It does not route, forward, scan,
  advertise, persist, ACK, retry, fetch, encrypt, authenticate, or run
  background work.
  """

  alias MeshxMobileApp.BLE.{
    LocalRoutingHardwareValidationPlan,
    LocalRoutingPolicy,
    LocalRoutingProductionEvidenceReview
  }

  @spec snapshot() :: map()
  def snapshot do
    policy = LocalRoutingPolicy.snapshot()
    review = LocalRoutingProductionEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_routing_operator_capture_plan,
      status: :open,
      current_routing_decision: current_routing_decision(policy),
      current_mode: :advert_only_non_routing,
      route_table_claim_allowed?: false,
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      guaranteed_delivery_claim_allowed?: false,
      multi_hop_hardware_claim_allowed?: false,
      hardware_validation_plan: LocalRoutingHardwareValidationPlan.snapshot(),
      required_gates: review.required_gates(),
      required_evidence_types: review.required_evidence_types(),
      required_blocked_claims: review.required_blocked_claims(),
      required_gate_blocked_claims: review.required_gate_blocked_claims(),
      capture_sections: capture_sections(review),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/routing/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "The current selected decision is keep_advert_only_non_routing.",
        "Route candidates and advert gossip remain observation/planning evidence, not production route selection.",
        "Routing, forwarding, routed delivery, ACK/retry, and multi-hop hardware claims remain blocked."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp current_routing_decision(policy) do
    %{
      decision_outcome: policy.decision_outcome,
      decision_status: policy.decision_status,
      production_routing_reconsideration_gate: policy.production_routing_reconsideration_gate,
      production_routing_enabled?: false,
      forwarding_service_enabled?: false,
      routed_delivery_enabled?: false
    }
  end

  defp capture_sections(review) do
    gate_claims = review.required_gate_blocked_claims()

    [
      section(
        review,
        gate_claims,
        :route_table_state_model,
        "artifacts/local-ble/<run-id>/routing/route-table.md",
        [
          "Attach the route key schema, reachability states, freshness policy, invalidation policy, and negative evidence that peer inventory is not a route table."
        ]
      ),
      section(
        review,
        gate_claims,
        :deterministic_route_selection,
        "artifacts/local-ble/<run-id>/routing/route-selection.md",
        [
          "Attach deterministic next-hop selection, tie-break, TTL budget, stale peer, unreachable peer, and loop-prone negative evidence."
        ]
      ),
      section(
        review,
        gate_claims,
        :forwarding_service_boundary,
        "artifacts/local-ble/<run-id>/routing/forwarding-service.md",
        [
          "Attach bounded forward-intent, execution boundary, lifecycle, cancellation, concurrency, and platform power-limit evidence."
        ]
      ),
      section(
        review,
        gate_claims,
        :delivery_semantics_policy,
        "artifacts/local-ble/<run-id>/routing/delivery-semantics.md",
        [
          "Attach the delivery class policy and ACK, retry, duplicate, expiry, and failure-surface evidence or explicit non-goal decision."
        ]
      ),
      section(
        review,
        gate_claims,
        :multi_hop_hardware_rig,
        "artifacts/local-ble/<run-id>/routing/multi-hop-rig/",
        [
          "Attach origin, relay, and observer role logs from three physical participants or an equivalent controlled rig."
        ]
      ),
      section(
        review,
        gate_claims,
        :ttl_loop_and_suppression_evidence,
        "artifacts/local-ble/<run-id>/routing/ttl-loop-suppression.md",
        [
          "Attach replay-normalized hardware evidence for TTL decrement, loop suppression, duplicate suppression, terminal expiry, and negative cases."
        ]
      ),
      section(
        review,
        gate_claims,
        :release_artifact_evidence,
        "artifacts/local-ble/<run-id>/routing/release-review.md",
        [
          "Attach release-candidate artifact references and operator wording review that keeps replay simulation distinct from physical routing proof."
        ]
      ),
      section(
        review,
        gate_claims,
        :negative_claim_review,
        "artifacts/local-ble/<run-id>/routing/negative-claims.md",
        [
          "Attach implementation-backed negative fixtures for peer inventory as route table, stale next hop, replay as routing, missing ACK/retry, and one-hop hardware as multi-hop."
        ]
      )
    ]
  end

  defp section(review, gate_claims, id, artifact_path, notes) do
    %{
      id: id,
      review_section: id,
      artifact_path: artifact_path,
      evidence_type: Map.fetch!(review.required_evidence_types(), id),
      required_entries: [
        :artifact_path,
        :summary,
        :test_command,
        :evidence_type,
        :blocked_claims_called_out
      ],
      blocked_claims_called_out: review.required_blocked_claims(),
      gate_specific_blocked_claims_called_out: Map.get(gate_claims, id, []),
      notes: notes
    }
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_routing.production_review --template --out artifacts/local-ble/<run-id>/routing/evidence.json",
      "mix meshx.mobile.local_routing.production_review --input artifacts/local-ble/<run-id>/routing/evidence.json --json --out tmp/local-routing-production-review.json"
    ]
  end
end
