defmodule Mix.Tasks.MeshxMobileLocalLifecycleValidationPlanTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalLifecycle.ValidationPlan

  setup do
    Mix.Task.reenable("meshx.mobile.local_lifecycle.validation_plan")
    File.rm_rf!("tmp/local-lifecycle-validation-plan-test")
    :ok
  end

  test "prints a concise lifecycle validation plan summary" do
    output =
      capture_io(fn ->
        ValidationPlan.run([])
      end)

    assert output =~
             "LOCAL_LIFECYCLE_VALIDATION_PLAN mobile_ble_lifecycle_hardware_validation_plan"

    assert output =~ "current_mode=foreground_manual"
    assert output =~ "background_allowed=false"
    assert output =~ "restart_allowed=false"
    assert output =~ "LIFECYCLE_VALIDATION_GATES blocked=8 total=8"
    assert output =~ "scheduled_retry_allowed=false"

    assert output =~
             "LIFECYCLE_VALIDATION_REQUIRED gates=target_device_matrix,android_foreground_service_backgrounding,android_background_ble_policy,ios_background_ble_policy,restart_and_cancellation,scheduled_retry_bounds,background_gossip_limits,negative_claim_review"

    assert output =~ "Android target matrix"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        ValidationPlan.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["plan_version"] == 1
    assert decoded["boundary"] == "mobile_ble_lifecycle_hardware_validation_plan"
    assert decoded["current_validated_mode"] == "foreground_manual"
    assert decoded["background_claims_allowed?"] == false
    assert decoded["blocked_gate_count"] == 8
    assert Enum.any?(decoded["gates"], &(&1["id"] == "android_foreground_service_backgrounding"))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-lifecycle-validation-plan-test/plan.json"

    output =
      capture_io(fn ->
        ValidationPlan.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "mobile_ble_lifecycle_hardware_validation_plan"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["restart_claims_allowed?"] == false
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> ValidationPlan.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> ValidationPlan.run(["--out"]) end)
    end
  end
end
