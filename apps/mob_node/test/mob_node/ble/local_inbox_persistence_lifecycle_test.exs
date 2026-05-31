defmodule Mob.Node.BLE.LocalInboxPersistenceLifecycleTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxPersistenceLifecycle

  test "snapshot records memory-only as the default lifecycle decision" do
    snapshot = LocalInboxPersistenceLifecycle.snapshot()

    assert snapshot.lifecycle_version == 1
    assert snapshot.mode == :advertisement_only_local_mesh
    assert snapshot.default_decision.decision_outcome == :keep_memory_only_default
    assert snapshot.default_decision.decision_status == :selected_for_current_validated_mode
    assert snapshot.default_decision.default_mode == :memory_only
    refute snapshot.default_decision.durable_default_enabled?
    assert snapshot.default_decision.opt_in_durable_allowed?
    refute snapshot.default_decision.restore_default_enabled?

    assert snapshot.default_decision.production_default_reconsideration_gate ==
             :production_default_local_inbox_persistence_plan
  end

  test "opt-in durable profile is available without becoming default" do
    snapshot = LocalInboxPersistenceLifecycle.snapshot()

    assert snapshot.default_profile.mode == :memory_only
    refute snapshot.default_profile.enabled?
    assert snapshot.default_profile.save_triggers == []

    assert snapshot.opt_in_profile.mode == :opt_in_durable
    assert snapshot.opt_in_profile.enabled?
    assert snapshot.opt_in_profile.restore_on_start?
    assert :received_full_message in snapshot.opt_in_profile.save_triggers
    assert :received_message_beacon in snapshot.opt_in_profile.save_triggers
  end

  test "production default gate stays blocked on lifecycle evidence" do
    snapshot = LocalInboxPersistenceLifecycle.snapshot()

    assert snapshot.production_default_gate.status == :blocked
    assert :migration_plan in snapshot.production_default_gate.required_before_default

    assert :scheduled_cleanup_execution in snapshot.production_default_gate.required_before_default

    assert :background_safe_write_policy in snapshot.production_default_gate.required_before_default

    assert Enum.any?(
             snapshot.production_default_gate.missing_evidence,
             &String.contains?(&1, "On-device restore validation")
           )
  end

  test "operator actions distinguish available opt-in use from manual cleanup" do
    snapshot = LocalInboxPersistenceLifecycle.snapshot()

    assert Enum.any?(
             snapshot.operator_actions,
             &(&1.id == :enable_opt_in_durable and &1.status == :available)
           )

    assert Enum.any?(
             snapshot.operator_actions,
             &(&1.id == :prune_expired_snapshots and &1.status == :manual_only)
           )

    assert snapshot.operator_controls.boundary == :operator_opt_in_local_inbox_persistence
    assert Enum.any?(snapshot.operator_controls.actions, &(&1.id == :clear_all))

    assert Enum.any?(
             snapshot.unsupported_claims,
             &String.contains?(&1, "delivery guarantees")
           )
  end

  test "json snapshot is machine readable" do
    snapshot = LocalInboxPersistenceLifecycle.json_snapshot()

    assert snapshot["lifecycle_version"] == 1
    assert snapshot["default_decision"]["decision_outcome"] == "keep_memory_only_default"

    assert snapshot["default_decision"]["decision_status"] ==
             "selected_for_current_validated_mode"

    assert snapshot["default_decision"]["default_mode"] == "memory_only"
    assert snapshot["default_decision"]["durable_default_enabled?"] == false
    assert snapshot["production_default_gate"]["status"] == "blocked"
  end
end
