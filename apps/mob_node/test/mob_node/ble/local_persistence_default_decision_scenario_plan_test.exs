defmodule Mob.Node.BLE.LocalPersistenceDefaultDecisionScenarioPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalPersistenceDefaultDecisionScenarioPlan

  test "snapshot exposes default decision scenarios without enabling persistence claims" do
    plan = LocalPersistenceDefaultDecisionScenarioPlan.snapshot()

    assert plan.boundary == :local_persistence_default_decision_scenario_plan
    assert plan.status == :open
    assert plan.current_default_mode == :memory_only
    assert plan.opt_in_mode == :opt_in_durable
    assert plan.selected_decision_outcome == :keep_memory_only_default
    refute plan.production_default_persistence_allowed?
    refute plan.default_persistence_claim_allowed?
    refute plan.background_persistence_claim_allowed?
    refute plan.delivery_record_claim_allowed?
    refute plan.full_message_resolution_claim_allowed?
  end

  test "decision scenarios cover memory-only and durable default outcomes" do
    plan = LocalPersistenceDefaultDecisionScenarioPlan.snapshot()
    outcomes = Enum.map(plan.decision_scenarios, & &1.decision_outcome)

    assert [:keep_memory_only_default, :promote_durable_default] -- outcomes == []
    assert plan.allowed_decision_outcomes == [:keep_memory_only_default, :promote_durable_default]

    memory = Enum.find(plan.decision_scenarios, &(&1.id == :keep_memory_only_default))
    durable = Enum.find(plan.decision_scenarios, &(&1.id == :promote_durable_default))

    assert memory.status == :selected_for_current_validated_mode
    assert memory.default_mode_after_decision == :memory_only
    refute memory.durable_default_enabled?

    assert durable.status == :blocked
    assert durable.default_mode_after_decision == :durable_local_inbox_snapshot
    refute durable.durable_default_enabled?
  end

  test "durable default scenario names every production lifecycle gate" do
    plan = LocalPersistenceDefaultDecisionScenarioPlan.snapshot()
    durable = Enum.find(plan.decision_scenarios, &(&1.id == :promote_durable_default))

    assert [
             :default_lifecycle_decision,
             :schema_migration_policy,
             :scheduled_cleanup_worker,
             :background_safe_writer,
             :on_device_restore_fixture,
             :release_artifact_evidence
           ] -- durable.required_gates == []

    assert durable.missing_evidence != []
    assert :default_app_persistence in durable.blocked_claims_called_out
    assert :delivery_record in durable.blocked_claims_called_out
  end

  test "memory-only scenario preserves release wording blockers" do
    plan = LocalPersistenceDefaultDecisionScenarioPlan.snapshot()
    memory = Enum.find(plan.decision_scenarios, &(&1.id == :keep_memory_only_default))

    assert Enum.any?(
             memory.required_operator_evidence,
             &String.contains?(&1, "memory-only default wording")
           )

    assert :default_app_persistence in memory.blocked_claims_called_out
    assert :background_persistence in memory.blocked_claims_called_out
    assert :delivery_record in memory.blocked_claims_called_out
  end

  test "JSON snapshot is archiveable" do
    plan = LocalPersistenceDefaultDecisionScenarioPlan.json_snapshot()

    assert plan["boundary"] == "local_persistence_default_decision_scenario_plan"
    assert plan["selected_decision_outcome"] == "keep_memory_only_default"
    assert length(plan["decision_scenarios"]) == 2
    assert plan["production_default_persistence_allowed?"] == false
  end
end
