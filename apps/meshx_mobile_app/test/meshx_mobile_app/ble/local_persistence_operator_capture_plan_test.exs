defmodule MeshxMobileApp.BLE.LocalPersistenceOperatorCapturePlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalPersistenceOperatorCapturePlan

  test "snapshot exposes persistence capture plan without enabling default persistence" do
    plan = LocalPersistenceOperatorCapturePlan.snapshot()

    assert plan.boundary == :local_persistence_operator_capture_plan
    assert plan.status == :open
    assert plan.current_default_mode == :memory_only
    assert plan.current_default_decision.decision_outcome == :keep_memory_only_default
    refute plan.production_default_persistence_allowed?
    refute plan.default_persistence_claim_allowed?
    refute plan.background_persistence_claim_allowed?
    refute plan.delivery_record_claim_allowed?
    refute plan.full_message_resolution_claim_allowed?
  end

  test "capture sections cover every production lifecycle review gate" do
    plan = LocalPersistenceOperatorCapturePlan.snapshot()
    section_ids = Enum.map(plan.capture_sections, & &1.id)

    assert [
             :default_lifecycle_decision,
             :schema_migration_policy,
             :scheduled_cleanup_worker,
             :background_safe_writer,
             :on_device_restore_fixture,
             :release_artifact_evidence
           ] -- section_ids == []

    assert plan.required_gates -- section_ids == []
    assert length(plan.capture_sections) == 6
  end

  test "default decision section requires decision outcome and blocked claim callouts" do
    plan = LocalPersistenceOperatorCapturePlan.snapshot()
    decision = Enum.find(plan.capture_sections, &(&1.id == :default_lifecycle_decision))

    assert decision.decision_outcome_required?

    assert decision.allowed_decision_outcomes == [
             :keep_memory_only_default,
             :promote_durable_default
           ]

    assert :decision_outcome in decision.required_entries
    assert :blocked_claims_called_out in decision.required_entries

    assert [
             :delivery_record,
             :trusted_message_delivery,
             :background_persistence,
             :full_message_resolution
           ] --
             decision.blocked_claims_called_out == []
  end

  test "restore and writer sections preserve lifecycle and delivery boundaries" do
    plan = LocalPersistenceOperatorCapturePlan.snapshot()
    writer = Enum.find(plan.capture_sections, &(&1.id == :background_safe_writer))
    restore = Enum.find(plan.capture_sections, &(&1.id == :on_device_restore_fixture))

    assert writer.evidence_type == :lifecycle_writer_test
    assert restore.evidence_type == :on_device_restore_fixture
    assert Enum.any?(writer.notes, &String.contains?(&1, "background message delivery"))
    assert Enum.any?(restore.notes, &String.contains?(&1, "unresolved"))
  end

  test "JSON snapshot is archiveable" do
    plan = LocalPersistenceOperatorCapturePlan.json_snapshot()

    assert plan["boundary"] == "local_persistence_operator_capture_plan"
    assert plan["status"] == "open"
    assert length(plan["capture_sections"]) == 6
    assert plan["production_default_persistence_allowed?"] == false
  end
end
