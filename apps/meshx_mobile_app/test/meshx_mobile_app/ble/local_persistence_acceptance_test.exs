defmodule MeshxMobileApp.BLE.LocalPersistenceAcceptanceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalPersistenceAcceptance}

  test "snapshot records opt-in persistence gates and blocks default lifecycle claims" do
    snapshot = LocalPersistenceAcceptance.snapshot()

    assert snapshot.boundary == :opt_in_local_inbox_persistence
    assert snapshot.satisfied_count == 6
    assert snapshot.blocked_count == 1
    refute snapshot.default_persistence_claim_allowed?
    refute snapshot.background_persistence_claim_allowed?
    refute snapshot.delivery_record_claim_allowed?
    refute snapshot.production_default_persistence_allowed?

    assert [
             %{id: :durable_snapshot_policy, status: :satisfied},
             %{id: :store_boundary, status: :satisfied},
             %{id: :read_model_restore, status: :satisfied},
             %{id: :operator_controls, status: :satisfied},
             %{id: :production_lifecycle_plan, status: :satisfied},
             %{id: :negative_claim_validation, status: :satisfied},
             %{id: :production_default_lifecycle, status: :blocked}
           ] = snapshot.gates

    lifecycle_gate = List.last(snapshot.gates)

    assert Enum.any?(
             lifecycle_gate.missing,
             &String.contains?(&1, "Migration or schema-upgrade plan")
           )
  end

  test "operator control gate records explicit status save restore prune and clear actions" do
    snapshot = LocalPersistenceAcceptance.snapshot()

    assert %{id: :operator_controls, status: :satisfied, missing: []} =
             Enum.find(snapshot.gates, &(&1.id == :operator_controls))
  end

  test "local inbox snapshot exposes persistence acceptance without promoting defaults" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert %{persistence_acceptance: acceptance} = snapshot
    assert acceptance.satisfied_count == 6
    assert acceptance.blocked_count == 1
    refute acceptance.production_default_persistence_allowed?
  end

  test "JSON snapshot preserves blocked persistence claims" do
    snapshot = LocalPersistenceAcceptance.json_snapshot()

    assert snapshot["boundary"] == "opt_in_local_inbox_persistence"
    assert snapshot["default_persistence_claim_allowed?"] == false
    assert snapshot["background_persistence_claim_allowed?"] == false
    assert snapshot["production_default_persistence_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "production_default_lifecycle" and &1["status"] == "blocked")
           )
  end
end
