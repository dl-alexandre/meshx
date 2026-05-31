defmodule Mix.Tasks.Mob.NodeLocalInboxUxValidationPlanTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalInbox.UxValidationPlan

  setup do
    Mix.Task.reenable("mob.node.local_inbox.ux_validation_plan")
    File.rm_rf!("tmp/local-inbox-ux-validation-plan-test")
    :ok
  end

  test "prints a concise on-device UX validation plan summary" do
    output =
      capture_io(fn ->
        UxValidationPlan.run([])
      end)

    assert output =~ "LOCAL_INBOX_UX_VALIDATION_PLAN nearby_messages_on_device_ux_validation"
    assert output =~ "production_ux_allowed=false"
    assert output =~ "UX_VALIDATION_GATES open=5 satisfied=0"
    assert output =~ "production_nearby_messages_ux,delivery,trusted_delivery,routing"

    assert output =~
             "UX_VALIDATION_REQUIRED gates=target_device_matrix,state_coverage_screenshots,interaction_coverage,blocked_claim_copy_review,visual_density_review"

    assert output =~ "Device model, OS/API version"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        UxValidationPlan.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["plan_version"] == 1
    assert decoded["boundary"] == "nearby_messages_on_device_ux_validation"
    assert decoded["production_ux_claim_allowed?"] == false
    assert decoded["open_gate_count"] == 5
    assert Enum.any?(decoded["gates"], &(&1["id"] == "blocked_claim_copy_review"))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-inbox-ux-validation-plan-test/plan.json"

    output =
      capture_io(fn ->
        UxValidationPlan.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "nearby_messages_on_device_ux_validation"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["production_ux_claim_allowed?"] == false
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> UxValidationPlan.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> UxValidationPlan.run(["--out"]) end)
    end
  end
end
