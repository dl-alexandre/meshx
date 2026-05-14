defmodule Mix.Tasks.MeshxMobileLocalPersistenceLifecyclePlanTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalPersistence.LifecyclePlan

  setup do
    Mix.Task.reenable("meshx.mobile.local_persistence.lifecycle_plan")
    File.rm_rf!("tmp/local-persistence-lifecycle-plan-test")
    :ok
  end

  test "prints a concise production persistence lifecycle plan summary" do
    output =
      capture_io(fn ->
        LifecyclePlan.run([])
      end)

    assert output =~
             "LOCAL_PERSISTENCE_LIFECYCLE_PLAN production_default_local_inbox_persistence_plan"

    assert output =~ "current_default=memory_only"
    assert output =~ "production_default_allowed=false"
    assert output =~ "PERSISTENCE_LIFECYCLE_GATES blocked=6 total=6"
    assert output =~ "default_lifecycle_allowed=false"

    assert output =~
             "PERSISTENCE_LIFECYCLE_REQUIRED gates=default_lifecycle_decision,schema_migration_policy,scheduled_cleanup_worker,background_safe_writer,on_device_restore_fixture,release_artifact_evidence"

    assert output =~ "Product approval for default durable local inbox lifecycle"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        LifecyclePlan.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["plan_version"] == 1
    assert decoded["boundary"] == "production_default_local_inbox_persistence_plan"
    assert decoded["current_default_mode"] == "memory_only"
    assert decoded["production_default_persistence_allowed?"] == false
    assert decoded["blocked_gate_count"] == 6
    assert Enum.any?(decoded["gates"], &(&1["id"] == "schema_migration_policy"))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-persistence-lifecycle-plan-test/plan.json"

    output =
      capture_io(fn ->
        LifecyclePlan.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "production_default_local_inbox_persistence_plan"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["default_lifecycle_claim_allowed?"] == false
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> LifecyclePlan.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> LifecyclePlan.run(["--out"]) end)
    end
  end
end
