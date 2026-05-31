defmodule Mob.Node.BLE.LocalPersistenceNegativeValidationTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalPersistenceNegativeValidation

  test "snapshot keeps default, delivery, and background persistence claims blocked" do
    snapshot = LocalPersistenceNegativeValidation.snapshot()

    assert snapshot.validation_version == 1
    assert snapshot.boundary == :current_opt_in_local_read_model_persistence
    assert snapshot.case_count == 6
    refute snapshot.default_persistence_claims_allowed?
    refute snapshot.delivery_record_claims_allowed?
    refute snapshot.background_persistence_claims_allowed?
  end

  test "opt-in snapshots do not become default lifecycle persistence" do
    validation =
      LocalPersistenceNegativeValidation.snapshot().cases
      |> Enum.find(&(&1.id == :opt_in_snapshot_as_default_lifecycle))

    assert validation.input == :opt_in_durable_session_snapshot
    assert validation.expected_decision == :operator_opt_in_only
    assert :default_app_persistence in validation.blocked_claims
    assert :migration_plan in validation.required_before_allowed
    assert :on_device_restore_validation in validation.required_before_allowed
    assert validation.implementation_evidence.default_mode == :memory_only
    refute validation.implementation_evidence.durable_default_enabled?
    assert validation.implementation_evidence.opt_in_enabled?
  end

  test "persisted beacon refs remain pointers rather than delivery records" do
    validation =
      LocalPersistenceNegativeValidation.snapshot().cases
      |> Enum.find(&(&1.id == :durable_beacon_ref_as_delivery_record))

    assert validation.expected_decision == :persisted_pointer_only
    assert :message_delivery_record in validation.blocked_claims
    assert :full_message_available in validation.blocked_claims
    assert :validated_full_message_resolution_transport in validation.required_before_allowed
    assert validation.implementation_evidence.persisted_kind == :unresolved_beacon_ref
    assert validation.implementation_evidence.delivery_state == :unresolved
    assert validation.implementation_evidence.has_message_id_hash?
    refute validation.implementation_evidence.has_envelope_wire?
    assert validation.implementation_evidence.full_message_count == 0
  end

  test "manual cleanup and foreground save hooks do not imply background lifecycle behavior" do
    snapshot = LocalPersistenceNegativeValidation.snapshot()
    cleanup = Enum.find(snapshot.cases, &(&1.id == :manual_prune_as_scheduled_cleanup))
    write = Enum.find(snapshot.cases, &(&1.id == :foreground_save_as_background_safe_write))

    assert cleanup.expected_decision == :manual_operator_cleanup_only
    assert :scheduled_cleanup in cleanup.blocked_claims
    assert :background_cleanup_worker in cleanup.blocked_claims
    refute cleanup.implementation_evidence.cleanup_scheduled?
    assert cleanup.implementation_evidence.cleanup_operator_command =~ "prune_expired"

    assert write.expected_decision == :foreground_or_session_bound_write
    assert :background_safe_write in write.blocked_claims
    assert :app_restart_restore_evidence in write.required_before_allowed
    assert write.implementation_evidence.has_session_stop_save_hook?
    refute write.implementation_evidence.has_background_save_trigger?
  end

  test "durable snapshots are not raw hardware evidence archives" do
    validation =
      LocalPersistenceNegativeValidation.snapshot().cases
      |> Enum.find(&(&1.id == :durable_snapshot_as_raw_evidence_archive))

    assert validation.expected_decision == :policy_approved_read_model_only
    assert :transport_metadata_persistence in validation.blocked_claims
    assert :hardware_evidence_manifest_attachment in validation.required_before_allowed
    assert :raw_transport_metadata in validation.implementation_evidence.excluded_fields
    refute validation.implementation_evidence.persists_raw_transport_metadata?
  end

  test "current schema normalization is not a production migration plan" do
    validation =
      LocalPersistenceNegativeValidation.snapshot().cases
      |> Enum.find(&(&1.id == :current_schema_policy_as_migration_plan))

    assert validation.input == :current_version_schema_normalization
    assert validation.expected_decision == :current_schema_only
    assert :automatic_schema_migration in validation.blocked_claims
    assert :production_upgrade_safe in validation.blocked_claims
    assert :versioned_migration_plan in validation.required_before_allowed
    assert :upgrade_and_rollback_fixtures in validation.required_before_allowed
    assert validation.implementation_evidence.current_schema_version == 1
    assert validation.implementation_evidence.supported_schema_versions == [1]
    assert validation.implementation_evidence.json_decoded_current_version_restore_supported?
    refute validation.implementation_evidence.future_schema_versions_supported?
    refute validation.implementation_evidence.production_default_persistence_allowed?
  end

  test "json snapshot is machine readable" do
    snapshot = LocalPersistenceNegativeValidation.json_snapshot()

    assert snapshot["validation_version"] == 1
    assert snapshot["default_persistence_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "durable_beacon_ref_as_delivery_record" and
                 &1["expected_decision"] == "persisted_pointer_only" and
                 &1["implementation_evidence"]["delivery_state"] == "unresolved")
           )

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "current_schema_policy_as_migration_plan" and
                 &1["expected_decision"] == "current_schema_only" and
                 &1["implementation_evidence"]["future_schema_versions_supported?"] == false)
           )
  end
end
