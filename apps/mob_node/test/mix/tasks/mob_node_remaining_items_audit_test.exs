defmodule Mix.Tasks.Mob.NodeRemainingItemsAuditTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.RemainingItems.Audit

  setup do
    Mix.Task.reenable("mob.node.remaining_items.audit")
    File.rm_rf!("tmp/remaining-items-audit-test")
    :ok
  end

  test "prints concise focused audit summary" do
    output =
      capture_io(fn ->
        Audit.run([])
      end)

    assert output =~ "REMAINING_ITEMS complete=false completed=3 incomplete=1"
    assert output =~ "update_goal_allowed=false"
    assert output =~ "ROW id=extended_advertising_interop_aux_scan_response"
    assert output =~ "claim_allowed=false"
    assert output =~ "CHECKLIST count=6 objective_success_criteria=4"
    assert output =~ "CHECKLIST_ITEM id=completion_decision status=blocked"
    assert output =~ "rows=hardware_validation_of_full_ios_responder_path"
  end

  test "prints and writes machine-readable JSON" do
    path = "tmp/remaining-items-audit-test/focused.json"

    output =
      capture_io(fn ->
        Audit.run(["--json", "--out", path])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["complete"] == false
    assert decoded["completion_decision"]["update_goal_allowed"] == false
    assert length(decoded["completed_rows"]) == 3
    assert length(decoded["incomplete_rows"]) == 1
    assert File.exists?(path)
  end

  test "rejects unknown options" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> Audit.run(["--bad"]) end)
    end
  end
end
