defmodule Mob.Node.BLE.LocalPersistenceEvidenceManifestTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalPersistenceEvidenceManifest

  test "snapshot packages opt-in persistence while keeping production defaults blocked" do
    manifest = LocalPersistenceEvidenceManifest.snapshot()

    assert manifest.manifest_version == 1
    assert manifest.boundary == :local_persistence_evidence_manifest
    assert manifest.current_default_mode == :memory_only
    assert manifest.opt_in_durable_snapshots_available?
    refute manifest.production_default_persistence_allowed?
    refute manifest.default_persistence_claim_allowed?
    refute manifest.background_persistence_claim_allowed?
    refute manifest.delivery_record_claim_allowed?
    refute manifest.full_message_resolution_claim_allowed?
  end

  test "manifest embeds acceptance, lifecycle, production plan, and negative validation" do
    manifest = LocalPersistenceEvidenceManifest.snapshot()

    assert manifest.acceptance.boundary == :opt_in_local_inbox_persistence
    assert manifest.lifecycle.default_decision.default_mode == :memory_only
    assert manifest.lifecycle.storage_scope.default_storage_mode == :memory_only

    assert manifest.lifecycle.storage_scope.opt_in_storage_mode ==
             :durable_local_read_model_snapshot

    assert :unresolved_beacon_ref_read_models in manifest.lifecycle.storage_scope.stored_when_opted_in

    assert :raw_transport_metadata in manifest.lifecycle.storage_scope.never_stored
    assert :message_delivery in manifest.lifecycle.storage_scope.not_evidence_of

    assert manifest.current_default_decision.decision_outcome == :keep_memory_only_default

    assert manifest.current_default_decision.decision_status ==
             :selected_for_current_validated_mode

    assert manifest.production_lifecycle_plan.boundary ==
             :production_default_local_inbox_persistence_plan

    assert manifest.default_decision_scenario_plan.boundary ==
             :local_persistence_default_decision_scenario_plan

    assert length(manifest.default_decision_scenario_plan.decision_scenarios) == 2
    assert manifest.operator_capture_plan.boundary == :local_persistence_operator_capture_plan
    assert length(manifest.operator_capture_plan.capture_sections) == 6

    assert manifest.production_evidence_review.boundary ==
             :production_default_persistence_evidence_review

    assert manifest.production_evidence_review.status == :open
    assert manifest.negative_validation.boundary == :current_opt_in_local_read_model_persistence

    assert Enum.any?(
             manifest.negative_validation.cases,
             &(&1.id == :current_schema_policy_as_migration_plan and
                 &1.expected_decision == :current_schema_only)
           )

    assert manifest.negative_implementation_evidence.case_count ==
             manifest.negative_validation.case_count

    assert manifest.negative_implementation_evidence.all_cases_have_implementation_evidence?

    assert "LocalInboxPersistencePolicy" in manifest.negative_implementation_evidence.evidence_sources

    assert "LocalInboxDurableSnapshotSchemaPolicy" in manifest.negative_implementation_evidence.evidence_sources

    assert manifest.open_production_gate_count == 6
    assert manifest.acceptance_blocked_count == 1
  end

  test "manifest lists missing production lifecycle evidence" do
    manifest = LocalPersistenceEvidenceManifest.snapshot()
    gate_ids = Enum.map(manifest.missing_production_evidence, & &1.gate_id)

    assert :default_lifecycle_decision in gate_ids
    assert :schema_migration_policy in gate_ids
    assert :scheduled_cleanup_worker in gate_ids
    assert :background_safe_writer in gate_ids
    assert :on_device_restore_fixture in gate_ids
    assert :release_artifact_evidence in gate_ids
  end

  test "required commands include direct store and durable snapshot tests" do
    manifest = LocalPersistenceEvidenceManifest.snapshot()

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_persistence.lifecycle_plan")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_inbox_store_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_inbox_durable_snapshot_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_persistence_operator_capture_plan_test.exs")
           )

    assert Enum.any?(
             manifest.required_commands,
             &String.contains?(&1, "local_persistence_default_decision_scenario_plan_test.exs")
           )
  end

  test "JSON snapshot preserves blocked persistence claims" do
    manifest = LocalPersistenceEvidenceManifest.json_snapshot()

    assert manifest["boundary"] == "local_persistence_evidence_manifest"
    assert manifest["current_default_mode"] == "memory_only"
    assert manifest["current_default_decision"]["decision_outcome"] == "keep_memory_only_default"

    assert manifest["current_default_decision"]["decision_status"] ==
             "selected_for_current_validated_mode"

    assert manifest["lifecycle"]["storage_scope"]["default_storage_mode"] == "memory_only"

    assert "raw_transport_metadata" in manifest["lifecycle"]["storage_scope"]["never_stored"]
    assert "trusted_message" in manifest["lifecycle"]["storage_scope"]["not_evidence_of"]

    assert manifest["production_default_persistence_allowed?"] == false
    assert manifest["delivery_record_claim_allowed?"] == false
    assert "default_app_persistence" in manifest["blocked_claims"]

    assert manifest["production_evidence_review"]["production_default_persistence_allowed?"] ==
             false

    assert manifest["negative_implementation_evidence"][
             "all_cases_have_implementation_evidence?"
           ] == true

    assert "LocalInboxPersistencePolicy" in manifest["negative_implementation_evidence"][
             "evidence_sources"
           ]

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_persistence.production_review")
           )

    assert Enum.any?(
             manifest["required_commands"],
             &String.contains?(&1, "local_persistence.production_review --template")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "production_persistence_lifecycle_plan")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "production_persistence_evidence_template" and
                 String.contains?(&1["purpose"], "decision_outcome"))
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "production_persistence_operator_capture_plan")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "production_persistence_default_decision_scenario_plan")
           )

    assert Enum.any?(
             manifest["required_artifacts"],
             &(&1["id"] == "production_persistence_decision" and
                 String.contains?(&1["purpose"], "decision_outcome"))
           )

    assert manifest["operator_capture_plan"]["boundary"] ==
             "local_persistence_operator_capture_plan"

    assert manifest["default_decision_scenario_plan"]["boundary"] ==
             "local_persistence_default_decision_scenario_plan"
  end
end
