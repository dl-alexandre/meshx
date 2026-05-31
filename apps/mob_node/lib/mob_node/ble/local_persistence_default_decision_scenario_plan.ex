defmodule Mob.Node.BLE.LocalPersistenceDefaultDecisionScenarioPlan do
  @moduledoc """
  Scenario plan for the local inbox persistence default decision.

  This plan makes the default lifecycle decision alternatives explicit for
  operator review. It preserves the current memory-only default while naming
  the evidence required before durable snapshots could become production
  default behavior. It does not save, restore, migrate, prune, schedule work,
  write in the background, resolve beacon refs, route, ACK, retry, encrypt,
  authenticate, or run mobile lifecycle hooks.
  """

  alias Mob.Node.BLE.{
    LocalInboxPersistenceLifecycle,
    LocalPersistenceProductionEvidenceReview,
    LocalPersistenceProductionLifecyclePlan
  }

  @spec snapshot() :: map()
  def snapshot do
    lifecycle = LocalInboxPersistenceLifecycle.snapshot()
    review = LocalPersistenceProductionEvidenceReview
    production_plan = LocalPersistenceProductionLifecyclePlan.snapshot()

    %{
      plan_version: 1,
      boundary: :local_persistence_default_decision_scenario_plan,
      status: :open,
      current_decision: lifecycle.default_decision,
      current_default_mode: lifecycle.default_profile.mode,
      opt_in_mode: lifecycle.opt_in_profile.mode,
      selected_decision_outcome: lifecycle.default_decision.decision_outcome,
      allowed_decision_outcomes: review.allowed_decision_outcomes(),
      production_default_persistence_allowed?: false,
      default_persistence_claim_allowed?: false,
      background_persistence_claim_allowed?: false,
      delivery_record_claim_allowed?: false,
      full_message_resolution_claim_allowed?: false,
      production_lifecycle_plan: production_plan,
      decision_scenarios: decision_scenarios(lifecycle, review, production_plan),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/persistence/",
      notes: [
        "This scenario plan is not operator evidence by itself.",
        "keep_memory_only_default is selected for the current validated advertisement-only local mesh mode.",
        "promote_durable_default remains blocked until every production lifecycle gate has operator-reviewed evidence.",
        "Persisted snapshots remain local read models and cannot be described as message delivery records."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp decision_scenarios(lifecycle, review, production_plan) do
    blocked_claims = [:default_app_persistence | review.required_blocked_claims()]

    [
      %{
        id: :keep_memory_only_default,
        decision_outcome: :keep_memory_only_default,
        status: :selected_for_current_validated_mode,
        default_mode_after_decision: :memory_only,
        durable_default_enabled?: false,
        opt_in_durable_allowed?: lifecycle.default_decision.opt_in_durable_allowed?,
        required_operator_evidence: [
          "Operator/release note preserves memory-only default wording.",
          "Release artifact references LocalPersistenceEvidenceManifest.",
          "Production-default persistence, background persistence, and delivery-record claims remain blocked."
        ],
        blocked_claims_called_out: blocked_claims,
        review_section: :default_lifecycle_decision,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/decision.md"
      },
      %{
        id: :promote_durable_default,
        decision_outcome: :promote_durable_default,
        status: :blocked,
        default_mode_after_decision: :durable_local_inbox_snapshot,
        durable_default_enabled?: false,
        opt_in_durable_allowed?: true,
        required_operator_evidence: [
          "Product decision explicitly selects promote_durable_default.",
          "Every LocalPersistenceProductionLifecyclePlan gate has supplied evidence.",
          "LocalPersistenceProductionEvidenceReview returns ready for the supplied metadata.",
          "Release wording still blocks delivery, trust, routing, background, and full-message-resolution overclaims."
        ],
        required_gates: Enum.map(production_plan.gates, & &1.id),
        missing_evidence:
          production_plan.gates |> Enum.flat_map(& &1.missing_evidence) |> Enum.uniq(),
        blocked_claims_called_out: blocked_claims,
        review_section: :default_lifecycle_decision,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/decision.md"
      }
    ]
  end

  defp review_commands do
    [
      "mix mob.node.local_persistence.production_review --template --out artifacts/local-ble/<run-id>/persistence/evidence.json",
      "mix mob.node.local_persistence.production_review --input artifacts/local-ble/<run-id>/persistence/evidence.json --json --out tmp/local-persistence-production-review.json"
    ]
  end
end
