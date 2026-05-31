defmodule Mob.Node.BLE.LocalRoutingEvidenceManifest do
  @moduledoc """
  Machine-readable local routing evidence manifest.

  The manifest packages current non-routing evidence: local observation policy,
  route candidates, routing acceptance, hardware validation gates, and negative
  validation. It is an artifact shape only. It does not route, forward, scan,
  advertise, persist, ACK, retry, fetch, encrypt, authenticate, or run
  background work.
  """

  alias Mob.Node.BLE.{
    LocalRoutingAcceptance,
    LocalRoutingContract,
    LocalRoutingDecisionScenarioPlan,
    LocalRoutingDryRun,
    LocalRoutingHardwareValidationPlan,
    LocalRoutingNegativeValidation,
    LocalRoutingOperatorCapturePlan,
    LocalRoutingPolicy,
    LocalRoutingProofPlan,
    LocalRoutingProductionEvidenceReview,
    LocalRoutingTable,
    PeerCapabilities
  }

  alias Mob.Node.BLE.PeerInventory.PeerSummary

  @required_commands [
    "mix mob.node.local_routing.validation_plan --json --out <path>",
    "mix mob.node.local_routing.evidence --json --out <path>",
    "mix mob.node.local_routing.production_review --template --out <path>",
    "mix mob.node.local_routing.production_review --input <path> --json --out <path>",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_acceptance_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_contract_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_decision_scenario_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_evidence_manifest_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_hardware_validation_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_negative_validation_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_operator_capture_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_policy_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_production_evidence_review_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_proof_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_table_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_routing_dry_run_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_routing_evidence_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_routing_production_review_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    candidates = fixture_candidates()
    table = LocalRoutingTable.snapshot(candidates)
    dry_run = LocalRoutingDryRun.snapshot([LocalRoutingTable.select(candidates, "meshx-alpha")])
    acceptance = LocalRoutingAcceptance.snapshot(candidates)
    hardware_plan = LocalRoutingHardwareValidationPlan.snapshot()

    %{
      manifest_version: 1,
      boundary: :local_routing_evidence_manifest,
      current_mode: :advert_only_non_routing,
      current_routing_decision: routing_decision(LocalRoutingPolicy.snapshot()),
      routing_decision_scenario_plan: LocalRoutingDecisionScenarioPlan.snapshot(),
      route_table_claim_allowed?: false,
      route_selection_claim_allowed?: false,
      forwarding_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      guaranteed_delivery_claim_allowed?: false,
      multi_hop_hardware_claim_allowed?: false,
      non_routing_scope: non_routing_scope(),
      policy: policy_summary(LocalRoutingPolicy.snapshot()),
      route_candidate_table: table,
      route_dry_run: dry_run,
      acceptance: acceptance,
      contract: contract_summary(LocalRoutingContract.snapshot()),
      proof_plan: LocalRoutingProofPlan.snapshot(),
      hardware_validation_plan: hardware_plan,
      operator_capture_plan: LocalRoutingOperatorCapturePlan.snapshot(),
      production_evidence_review: LocalRoutingProductionEvidenceReview.review(%{}),
      negative_validation: LocalRoutingNegativeValidation.snapshot(),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      candidate_count: table.entry_count,
      forwardable_candidate_count: table.forwardable_count,
      dry_run_would_select_candidate_count: dry_run.would_select_candidate_count,
      acceptance_blocked_count: acceptance.blocked_count,
      hardware_blocked_gate_count: hardware_plan.blocked_gate_count,
      missing_routing_evidence: missing_routing_evidence(hardware_plan),
      notes: [
        "Route candidates are read-model entries, not forwarding actions.",
        "Advert gossip replay remains simulation evidence, not production routing.",
        "Routing, forwarding, ACK/retry delivery, and multi-hop hardware claims remain blocked."
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
        id: :routing_validation_plan,
        command: "mix mob.node.local_routing.validation_plan --json --out <path>",
        purpose:
          "Archive the production routing hardware validation checklist before operator evidence review."
      },
      %{
        id: :routing_evidence_manifest,
        command: "mix mob.node.local_routing.evidence --json --out <path>",
        purpose:
          "Archive route-candidate evidence, non-routing policy, hardware gates, and blocked routing claims."
      },
      %{
        id: :routing_decision_scenario_plan,
        command: "mix mob.node.local_routing.evidence --json --out <path>",
        source: "LocalRoutingDecisionScenarioPlan",
        purpose:
          "Archive keep_advert_only_non_routing and enable_production_routing decision scenarios before any routing wording changes."
      },
      %{
        id: :production_routing_evidence_template,
        command: "mix mob.node.local_routing.production_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for production routing validation evidence."
      },
      %{
        id: :production_routing_operator_capture_plan,
        source: "LocalRoutingOperatorCapturePlan",
        purpose:
          "Archive the routing operator capture checklist for route table, route selection, forwarding, delivery semantics, multi-hop rig, TTL/loop, release, and negative evidence before operator evidence is attached."
      },
      %{
        id: :production_routing_evidence_review,
        command:
          "mix mob.node.local_routing.production_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied routing table, selection, forwarding, delivery, multi-hop, TTL/loop, release, and negative evidence metadata."
      },
      %{
        id: :multi_hop_routing_hardware_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/routing/",
        purpose:
          "Attach origin, relay, and observer logs before any physical multi-hop routing wording is considered."
      },
      %{
        id: :routing_release_note_review,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/routing/release-review.md",
        purpose:
          "Document that release wording keeps route selection, forwarding, delivery, ACK/retry, and multi-hop claims blocked."
      }
    ]
  end

  defp non_routing_scope do
    %{
      current_mode: :advert_only_non_routing,
      allowed_current_behavior: [
        :local_observation_display,
        :route_candidate_read_model,
        :deterministic_dry_run_selection,
        :advert_gossip_replay_simulation
      ],
      disallowed_current_behavior: [
        :live_forwarding_service,
        :production_route_selection,
        :routed_delivery,
        :ack_or_retry_delivery,
        :background_routing,
        :multi_hop_hardware_routing_claim
      ],
      not_evidence_of: [
        :message_delivery,
        :route_table_available,
        :forwarding_success,
        :guaranteed_delivery,
        :physical_multi_hop_propagation
      ],
      notes: [
        "Route candidates are derived read-model entries.",
        "Dry-run selection is deterministic planning evidence only.",
        "Replay gossip evidence does not prove physical multi-hop routing."
      ]
    }
  end

  defp policy_summary(policy) do
    %{
      mode: policy.mode,
      decision_outcome: policy.decision_outcome,
      decision_status: policy.decision_status,
      production_routing_reconsideration_gate: policy.production_routing_reconsideration_gate,
      capabilities: Enum.map(policy.capabilities, &capability_summary/1),
      allowed_count: policy.allowed_count,
      simulation_only_count: policy.simulation_only_count,
      blocked_count: policy.blocked_count,
      routing_claims_allowed?: policy.routing_claims_allowed?,
      production_routing_claim_allowed?: policy.production_routing_claim_allowed?,
      notes: policy.notes
    }
  end

  defp routing_decision(policy) do
    %{
      decision_outcome: policy.decision_outcome,
      decision_status: policy.decision_status,
      current_mode: :advert_only_non_routing,
      production_routing_enabled?: false,
      forwarding_service_enabled?: false,
      routed_delivery_enabled?: false,
      production_routing_reconsideration_gate: policy.production_routing_reconsideration_gate,
      rationale: [
        "The current validated mode is nearby observation from BLE advertisements.",
        "Replay gossip and route candidates are planning/read-model evidence, not live routing.",
        "Production routing needs route selection, forwarding, delivery semantics, and hardware evidence before claims change."
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

  defp missing_routing_evidence(hardware_plan) do
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
      :route_table_available,
      :route_selection_available,
      :live_forwarding_service,
      :routed_delivery,
      :guaranteed_delivery,
      :ack_backed_delivery,
      :retry_backed_delivery,
      :multi_hop_hardware_routing
    ]
  end

  defp fixture_candidates do
    [
      %PeerSummary{
        peer_id: "meshx-alpha",
        device_ids: ["AA:01"],
        display_name: "meshx-alpha",
        identity_confidence: :advertised,
        identity_source: :advertised_name,
        capabilities: %PeerCapabilities{protocol_version: 1, supports_passive_presence: true},
        presence: :active,
        first_seen_at: 1_000,
        last_seen_at: 1_000,
        last_rssi: -60,
        advertisement_seen_count: 1,
        collision_count: 0,
        last_conflicting_peer_id: nil,
        anonymous?: false,
        suspicious?: false
      },
      %PeerSummary{
        peer_id: "mob-stale",
        device_ids: ["AA:02"],
        display_name: "mob-stale",
        identity_confidence: :advertised,
        identity_source: :advertised_name,
        capabilities: %PeerCapabilities{protocol_version: 1, supports_passive_presence: true},
        presence: :stale,
        first_seen_at: 500,
        last_seen_at: 500,
        last_rssi: -85,
        advertisement_seen_count: 1,
        collision_count: 0,
        last_conflicting_peer_id: nil,
        anonymous?: false,
        suspicious?: false
      }
    ]
  end
end
