defmodule Mix.Tasks.MeshxMobileLocalLifecycleEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalLifecycle.Evidence

  setup do
    Mix.Task.reenable("meshx.mobile.local_lifecycle.evidence")
    File.rm_rf!("tmp/local-lifecycle-evidence-test")
    :ok
  end

  test "prints a concise lifecycle evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~ "LOCAL_LIFECYCLE_EVIDENCE mode=foreground_manual"
    assert output =~ "background_allowed=false"
    assert output =~ "restart_allowed=false"
    assert output =~ "LIFECYCLE_GATES open 8"
    assert output =~ "LIFECYCLE_CAPTURE_PLAN sections=8"
    assert output =~ "artifacts/local-ble/<run-id>/lifecycle/"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_lifecycle_evidence_manifest"
    assert decoded["background_ble_claim_allowed?"] == false
    assert decoded["hardware_blocked_gate_count"] == 8
    assert decoded["operator_capture_plan"]["boundary"] == "local_lifecycle_operator_capture_plan"

    assert decoded["lifecycle_decision_scenario_plan"]["boundary"] ==
             "local_lifecycle_decision_scenario_plan"

    assert length(decoded["operator_capture_plan"]["capture_sections"]) == 8
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-lifecycle-evidence-test/lifecycle.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_lifecycle_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "lifecycle_validation_plan"))

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "lifecycle_evidence_manifest"))

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "lifecycle_decision_scenario_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_lifecycle.validation_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_lifecycle.evidence"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_lifecycle.hardware_review"))
  end

  test "rejects unknown options and missing output path" do
    assert_raise Mix.Error, ~r/unknown option/, fn ->
      capture_io(fn -> Evidence.run(["--bad"]) end)
    end

    assert_raise Mix.Error, ~r/missing path for --out/, fn ->
      capture_io(fn -> Evidence.run(["--out"]) end)
    end
  end
end
