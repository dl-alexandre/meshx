defmodule MeshxMobileApp.BLE.LocalPersistenceOperatorCapturePlan do
  @moduledoc """
  Operator capture plan for local inbox persistence lifecycle evidence.

  The plan turns `LocalPersistenceProductionLifecyclePlan` gates into concrete
  artifact slots that can be filled before running
  `LocalPersistenceProductionEvidenceReview`. It does not save, restore,
  migrate, prune, schedule work, write in the background, resolve beacon refs,
  route, ACK, retry, encrypt, authenticate, or run mobile lifecycle hooks.
  """

  alias MeshxMobileApp.BLE.{
    LocalInboxPersistenceLifecycle,
    LocalPersistenceProductionEvidenceReview,
    LocalPersistenceProductionLifecyclePlan
  }

  @spec snapshot() :: map()
  def snapshot do
    lifecycle = LocalInboxPersistenceLifecycle.snapshot()
    review = LocalPersistenceProductionEvidenceReview

    %{
      plan_version: 1,
      boundary: :local_persistence_operator_capture_plan,
      status: :open,
      current_default_decision: lifecycle.default_decision,
      current_default_mode: lifecycle.default_profile.mode,
      opt_in_mode: lifecycle.opt_in_profile.mode,
      production_default_persistence_allowed?: false,
      default_persistence_claim_allowed?: false,
      background_persistence_claim_allowed?: false,
      delivery_record_claim_allowed?: false,
      full_message_resolution_claim_allowed?: false,
      production_lifecycle_plan: LocalPersistenceProductionLifecyclePlan.snapshot(),
      required_gates: review.required_gates(),
      required_evidence_types: review.required_evidence_types(),
      allowed_decision_outcomes: review.allowed_decision_outcomes(),
      required_blocked_claims: review.required_blocked_claims(),
      capture_sections: capture_sections(review),
      review_commands: review_commands(),
      artifact_root: "artifacts/local-ble/<run-id>/persistence/",
      notes: [
        "This plan is an operator capture checklist, not evidence by itself.",
        "The current selected decision is keep_memory_only_default.",
        "Promoting durable snapshots to default lifecycle behavior requires a separate product decision and production evidence review.",
        "Persisted snapshots remain read models and cannot be described as delivery records."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp capture_sections(review) do
    [
      %{
        id: :default_lifecycle_decision,
        review_section: :default_lifecycle_decision,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/decision.md",
        evidence_type: review.required_evidence_types().default_lifecycle_decision,
        decision_outcome_required?: true,
        allowed_decision_outcomes: review.allowed_decision_outcomes(),
        required_entries: [
          :artifact_path,
          :summary,
          :test_command,
          :evidence_type,
          :decision_outcome,
          :blocked_claims_called_out
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        notes: [
          "Record whether the release keeps memory-only default or proposes durable snapshots as default lifecycle behavior."
        ]
      },
      %{
        id: :schema_migration_policy,
        review_section: :schema_migration_policy,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/schema-migration.md",
        evidence_type: review.required_evidence_types().schema_migration_policy,
        decision_outcome_required?: false,
        required_entries: [
          :artifact_path,
          :summary,
          :test_command,
          :evidence_type,
          :blocked_claims_called_out
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        notes: [
          "Attach migration/incompatible-version evidence before default lifecycle restore is considered."
        ]
      },
      %{
        id: :scheduled_cleanup_worker,
        review_section: :scheduled_cleanup_worker,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/cleanup.md",
        evidence_type: review.required_evidence_types().scheduled_cleanup_worker,
        decision_outcome_required?: false,
        required_entries: [
          :artifact_path,
          :summary,
          :test_command,
          :evidence_type,
          :blocked_claims_called_out
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        notes: [
          "Attach bounded cleanup evidence if durable persistence becomes default."
        ]
      },
      %{
        id: :background_safe_writer,
        review_section: :background_safe_writer,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/writer.md",
        evidence_type: review.required_evidence_types().background_safe_writer,
        decision_outcome_required?: false,
        required_entries: [
          :artifact_path,
          :summary,
          :test_command,
          :evidence_type,
          :blocked_claims_called_out
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        notes: [
          "Writer evidence must not imply Android foreground service, iOS background BLE, or background message delivery."
        ]
      },
      %{
        id: :on_device_restore_fixture,
        review_section: :on_device_restore_fixture,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/restore/",
        evidence_type: review.required_evidence_types().on_device_restore_fixture,
        decision_outcome_required?: false,
        required_entries: [
          :artifact_path,
          :summary,
          :test_command,
          :evidence_type,
          :blocked_claims_called_out
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        notes: [
          "Restore evidence must cover full, unresolved, gossiped, and stale read-model states without treating refs as resolved messages."
        ]
      },
      %{
        id: :release_artifact_evidence,
        review_section: :release_artifact_evidence,
        artifact_path: "artifacts/local-ble/<run-id>/persistence/release-review.md",
        evidence_type: review.required_evidence_types().release_artifact_evidence,
        decision_outcome_required?: false,
        required_entries: [
          :artifact_path,
          :summary,
          :test_command,
          :evidence_type,
          :blocked_claims_called_out
        ],
        blocked_claims_called_out: review.required_blocked_claims(),
        notes: [
          "Release evidence must preserve memory-only/default-persistence wording and blocked delivery claims."
        ]
      }
    ]
  end

  defp review_commands do
    [
      "mix meshx.mobile.local_persistence.production_review --template --out artifacts/local-ble/<run-id>/persistence/evidence.json",
      "mix meshx.mobile.local_persistence.production_review --input artifacts/local-ble/<run-id>/persistence/evidence.json --json --out tmp/local-persistence-production-review.json"
    ]
  end
end
