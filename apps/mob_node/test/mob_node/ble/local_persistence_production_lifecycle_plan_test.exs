defmodule Mob.Node.BLE.LocalPersistenceProductionLifecyclePlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalPersistenceProductionLifecyclePlan

  test "snapshot records blocked production default persistence lifecycle gates" do
    snapshot = LocalPersistenceProductionLifecyclePlan.snapshot()

    assert snapshot.boundary == :production_default_local_inbox_persistence_plan
    assert snapshot.current_default_mode == :memory_only
    assert snapshot.opt_in_durable_snapshots_available?
    refute snapshot.production_default_persistence_allowed?
    refute snapshot.default_lifecycle_claim_allowed?
    assert snapshot.gate_count == 6
    assert snapshot.blocked_gate_count == 6
    assert snapshot.schema_policy.boundary == :local_inbox_durable_snapshot_schema_policy
    assert snapshot.schema_policy.json_decoded_current_version_restore_supported?

    assert [
             %{id: :default_lifecycle_decision, status: :blocked},
             %{id: :schema_migration_policy, status: :blocked},
             %{id: :scheduled_cleanup_worker, status: :blocked},
             %{id: :background_safe_writer, status: :blocked},
             %{id: :on_device_restore_fixture, status: :blocked},
             %{id: :release_artifact_evidence, status: :blocked}
           ] = snapshot.gates
  end

  test "migration cleanup writer restore and release evidence remain missing" do
    snapshot = LocalPersistenceProductionLifecyclePlan.snapshot()

    schema_gate = gate(snapshot, :schema_migration_policy)

    assert schema_gate.missing_evidence
           |> Enum.any?(&String.contains?(&1, "Forward migration policy"))

    assert schema_gate.notes
           |> Enum.any?(&String.contains?(&1, "JSON-decoded v1 snapshots"))

    assert gate(snapshot, :scheduled_cleanup_worker).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Scheduled cleanup"))

    assert gate(snapshot, :background_safe_writer).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Background-safe write"))

    assert gate(snapshot, :on_device_restore_fixture).missing_evidence
           |> Enum.any?(&String.contains?(&1, "app restart"))

    assert gate(snapshot, :release_artifact_evidence).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Release-candidate artifact"))
  end

  test "JSON snapshot preserves blocked claims and gate ids" do
    snapshot = LocalPersistenceProductionLifecyclePlan.json_snapshot()

    assert snapshot["boundary"] == "production_default_local_inbox_persistence_plan"
    assert snapshot["production_default_persistence_allowed?"] == false
    assert snapshot["default_lifecycle_claim_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "background_safe_writer" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
