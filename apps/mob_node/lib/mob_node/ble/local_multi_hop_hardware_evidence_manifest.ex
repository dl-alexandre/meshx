defmodule Mob.Node.BLE.LocalMultiHopHardwareEvidenceManifest do
  @moduledoc """
  Machine-readable evidence manifest for physical multi-hop advert gossip.

  Replay fixtures prove deterministic gossip policy, and current Android
  hardware evidence proves one-hop legacy beacon gossip. This manifest packages
  that current evidence plus the still-blocked physical origin/relay/observer
  gates. It does not scan, advertise, relay, route, fetch, persist, ACK, retry,
  encrypt, authenticate, or run background work.
  """

  alias Mob.Node.BLE.{
    LocalAdvertGossipHardwareValidationPlan,
    LocalMultiHopHardwareEvidenceReview
  }

  @scenario_fixture_path "apps/mob_node/test/fixtures/advert_gossip_scenarios"

  @required_commands [
    "mix mob.node.local_multi_hop_hardware.evidence --json --out <path>",
    "mix mob.node.local_multi_hop_hardware.review --template --out <path>",
    "mix mob.node.local_multi_hop_hardware.review --input <path> --json --out <path>",
    "mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios",
    "mix test apps/mob_node/test/mob_node/ble/local_advert_gossip_hardware_validation_plan_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_hardware_validation_gates_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_multi_hop_hardware_evidence_manifest_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/local_multi_hop_hardware_evidence_review_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_multi_hop_hardware_evidence_test.exs",
    "mix test apps/mob_node/test/mix/tasks/mob_node_local_multi_hop_hardware_review_test.exs",
    "mix test apps/mob_node/test/mob_node/ble/advert_gossip_scenario_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    plan = LocalAdvertGossipHardwareValidationPlan.snapshot()

    %{
      manifest_version: 1,
      boundary: :local_multi_hop_hardware_evidence_manifest,
      current_hardware_scope: :one_hop_legacy_beacon_gossip_only,
      replay_policy_evidence_present?: true,
      one_hop_hardware_evidence_present?: true,
      multi_hop_physical_proof_present?: false,
      multi_hop_hardware_gossip_claim_allowed?: false,
      routed_delivery_claim_allowed?: false,
      guaranteed_delivery_claim_allowed?: false,
      background_operation_claim_allowed?: false,
      validation_plan: plan,
      replay_evidence: replay_evidence(),
      current_hardware_evidence: current_hardware_evidence(),
      blocked_gate_count: plan.blocked_gate_count,
      open_hardware_evidence: open_hardware_evidence(plan),
      hardware_evidence_review: LocalMultiHopHardwareEvidenceReview.review(%{}),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      notes: [
        "Replay topology fixtures remain protocol-policy evidence, not physical multi-hop proof.",
        "The current Android hardware proof is one-hop legacy beacon gossip only.",
        "Physical multi-hop proof requires origin, relay, and observer evidence tied to the same beacon ref."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp replay_evidence do
    %{
      fixture_path: @scenario_fixture_path,
      scenarios: [
        :line_three_nodes,
        :partitioned_four_nodes,
        :triangle_duplicate_seen
      ],
      audit_command:
        "mix mob.node.advert_gossip.audit apps/mob_node/test/fixtures/advert_gossip_scenarios",
      supports: [
        :deterministic_gossip_policy,
        :ttl_and_loop_suppression_policy,
        :partition_behavior_policy
      ],
      does_not_support: [
        :physical_multi_hop_hardware_claim,
        :routed_delivery,
        :guaranteed_delivery
      ]
    }
  end

  defp current_hardware_evidence do
    %{
      validated_scope: :one_hop_legacy_beacon_gossip,
      participants_required_for_current_scope: 2,
      participants_required_for_multi_hop_scope: 3,
      current_known_pair: [:sm_t577u, :sm_t390],
      evidence_summary:
        "SM-T577U to SM-T390 proves one-hop legacy beacon gossip only; it does not prove relay behavior.",
      blocked_upgrade:
        "Need origin, relay, and observer captures from three or more physical roles or an equivalent controlled rig."
    }
  end

  defp open_hardware_evidence(plan) do
    Enum.map(plan.gates, fn gate ->
      %{
        gate_id: gate.id,
        required_evidence: gate.required_evidence,
        missing_evidence: gate.missing_evidence,
        blocked_claims: gate.blocked_claims
      }
    end)
  end

  defp required_artifacts do
    [
      %{
        id: :multi_hop_hardware_evidence_manifest,
        command: "mix mob.node.local_multi_hop_hardware.evidence --json --out <path>",
        purpose:
          "Archive replay evidence, one-hop hardware scope, and blocked physical multi-hop gates."
      },
      %{
        id: :multi_hop_hardware_evidence_template,
        command: "mix mob.node.local_multi_hop_hardware.review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for physical multi-hop hardware evidence."
      },
      %{
        id: :origin_relay_observer_logs,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/multi-hop/origin-relay-observer/",
        purpose:
          "Attach origin, relay, and observer logs before any physical multi-hop wording is considered."
      },
      %{
        id: :multi_hop_replay_fixture,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/multi-hop/replay/",
        purpose: "Attach replay-normalized fixture generated from the physical multi-hop capture."
      },
      %{
        id: :multi_hop_release_review,
        command:
          "mix mob.node.local_multi_hop_hardware.review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied origin/relay/observer metadata before any physical multi-hop wording changes."
      }
    ]
  end

  defp blocked_claims do
    [
      :multi_hop_hardware_gossip,
      :multi_hop_hardware_delivery,
      :routed_delivery,
      :guaranteed_delivery,
      :trusted_delivery,
      :background_operation,
      :whole_project_complete
    ]
  end
end
