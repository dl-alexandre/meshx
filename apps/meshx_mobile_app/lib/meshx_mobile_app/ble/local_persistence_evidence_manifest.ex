defmodule MeshxMobileApp.BLE.LocalPersistenceEvidenceManifest do
  @moduledoc """
  Machine-readable local inbox persistence evidence manifest.

  The manifest packages the current opt-in durable local inbox persistence
  boundary and the blocked production-default lifecycle gates. It is an
  artifact shape only. It does not save, restore, migrate, prune, schedule
  work, write in the background, resolve beacon refs, route, ACK, retry,
  encrypt, authenticate, or run mobile lifecycle hooks.
  """

  alias MeshxMobileApp.BLE.{
    LocalInboxPersistenceLifecycle,
    LocalInboxPersistenceOperator,
    LocalInboxPersistenceProfile,
    LocalInboxDurableSnapshotSchemaPolicy,
    LocalPersistenceAcceptance,
    LocalPersistenceDefaultDecisionScenarioPlan,
    LocalPersistenceNegativeValidation,
    LocalPersistenceOperatorCapturePlan,
    LocalPersistenceProductionEvidenceReview,
    LocalPersistenceProductionLifecyclePlan
  }

  @required_commands [
    "mix meshx.mobile.local_persistence.lifecycle_plan --json --out <path>",
    "mix meshx.mobile.local_persistence.evidence --json --out <path>",
    "mix meshx.mobile.local_persistence.production_review --template --out <path>",
    "mix meshx.mobile.local_persistence.production_review --input <path> --json --out <path>",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_persistence_acceptance_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_inbox_store_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_inbox_durable_snapshot_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_inbox_durable_snapshot_schema_policy_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_persistence_production_lifecycle_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_persistence_negative_validation_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_persistence_operator_capture_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/ble/local_persistence_default_decision_scenario_plan_test.exs",
    "mix test apps/meshx_mobile_app/test/meshx_mobile_app/session_test.exs"
  ]

  @spec snapshot() :: map()
  def snapshot do
    acceptance = LocalPersistenceAcceptance.snapshot()
    lifecycle = LocalInboxPersistenceLifecycle.snapshot()
    production_plan = LocalPersistenceProductionLifecyclePlan.snapshot()
    negative_validation = LocalPersistenceNegativeValidation.snapshot()

    %{
      manifest_version: 1,
      boundary: :local_persistence_evidence_manifest,
      current_default_mode: :memory_only,
      opt_in_durable_snapshots_available?: true,
      production_default_persistence_allowed?: false,
      default_persistence_claim_allowed?: false,
      background_persistence_claim_allowed?: false,
      delivery_record_claim_allowed?: false,
      full_message_resolution_claim_allowed?: false,
      default_profile: lifecycle.default_profile,
      opt_in_profile: lifecycle.opt_in_profile,
      current_default_decision: lifecycle.default_decision,
      lifecycle: lifecycle,
      operator_controls: LocalInboxPersistenceOperator.snapshot(),
      acceptance: acceptance,
      production_lifecycle_plan: production_plan,
      default_decision_scenario_plan: LocalPersistenceDefaultDecisionScenarioPlan.snapshot(),
      operator_capture_plan: LocalPersistenceOperatorCapturePlan.snapshot(),
      durable_snapshot_schema_policy: LocalInboxDurableSnapshotSchemaPolicy.snapshot(),
      production_evidence_review: LocalPersistenceProductionEvidenceReview.review(%{}),
      negative_validation: negative_validation,
      negative_implementation_evidence:
        negative_implementation_evidence_summary(negative_validation),
      required_commands: @required_commands,
      required_artifacts: required_artifacts(),
      blocked_claims: blocked_claims(),
      open_production_gate_count: production_plan.blocked_gate_count,
      acceptance_blocked_count: acceptance.blocked_count,
      missing_production_evidence: missing_production_evidence(production_plan),
      notes: [
        "Current persistence is an opt-in durable read-model snapshot boundary.",
        "Default app sessions remain memory-only unless product requirements and production lifecycle gates change.",
        "Persisted beacon refs remain unresolved pointers and are not delivery records."
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
        id: :production_persistence_lifecycle_plan,
        command: "mix meshx.mobile.local_persistence.lifecycle_plan --json --out <path>",
        purpose:
          "Archive the production-default persistence lifecycle checklist before operator evidence review."
      },
      %{
        id: :persistence_evidence_manifest,
        command: "mix meshx.mobile.local_persistence.evidence --json --out <path>",
        purpose:
          "Archive opt-in persistence evidence, memory-only default policy, and blocked production lifecycle gates."
      },
      %{
        id: :production_persistence_evidence_template,
        command: "mix meshx.mobile.local_persistence.production_review --template --out <path>",
        purpose:
          "Generate incomplete operator metadata scaffold for production-default persistence lifecycle evidence, including default_lifecycle_decision decision_outcome."
      },
      %{
        id: :production_persistence_operator_capture_plan,
        source: "LocalPersistenceOperatorCapturePlan",
        purpose:
          "Archive the persistence operator capture checklist for default decision, migration, cleanup, writer, restore, and release evidence before operator evidence is attached."
      },
      %{
        id: :production_persistence_default_decision_scenario_plan,
        source: "LocalPersistenceDefaultDecisionScenarioPlan",
        purpose:
          "Archive the keep_memory_only_default and promote_durable_default decision scenarios, including required gates and blocked persistence claims."
      },
      %{
        id: :production_persistence_evidence_review,
        command:
          "mix meshx.mobile.local_persistence.production_review --input <path> --json --out <path>",
        purpose:
          "Review operator-supplied product decision outcome, migration, cleanup, writer, restore, and release evidence metadata."
      },
      %{
        id: :production_persistence_decision,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/persistence/decision.md",
        purpose:
          "Attach product/operator decision and decision_outcome if durable local inbox snapshots should stay memory-only by default or become default lifecycle behavior."
      },
      %{
        id: :on_device_restore_evidence,
        status: :operator_supplied_open,
        path: "artifacts/local-ble/<run-id>/persistence/restore/",
        purpose:
          "Attach restart/restore evidence for full, unresolved, gossiped, and stale local inbox read-model states."
      }
    ]
  end

  defp missing_production_evidence(production_plan) do
    Enum.map(production_plan.gates, fn gate ->
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
      :default_app_persistence,
      :background_persistence,
      :scheduled_cleanup,
      :delivery_record,
      :full_message_resolution,
      :trusted_message_delivery,
      :raw_hardware_evidence_archive
    ]
  end

  defp negative_implementation_evidence_summary(negative_validation) do
    cases_with_evidence =
      Enum.count(negative_validation.cases, &(map_size(&1.implementation_evidence) > 0))

    %{
      case_count: negative_validation.case_count,
      cases_with_implementation_evidence: cases_with_evidence,
      all_cases_have_implementation_evidence?:
        cases_with_evidence == negative_validation.case_count,
      evidence_sources:
        negative_validation.cases
        |> Enum.flat_map(&Map.get(&1.implementation_evidence, :source_modules, []))
        |> Enum.uniq()
        |> Enum.sort(),
      blocked_claims: negative_validation.blocked_claims
    }
  end

  @doc false
  @spec default_session_options() :: map()
  def default_session_options do
    LocalInboxPersistenceProfile.memory_only()
    |> Map.fetch!(:session_options)
    |> Map.new()
  end
end
