defmodule Mix.Tasks.MeshxMobileLocalIosParityEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalIosParity.Evidence

  setup do
    Mix.Task.reenable("meshx.mobile.local_ios_parity.evidence")
    File.rm_rf!("tmp/local-ios-parity-evidence-test")
    :ok
  end

  test "prints a concise iOS parity evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~ "LOCAL_IOS_PARITY_EVIDENCE mode=contract_only"
    assert output =~ "participation_allowed=false"
    assert output =~ "hardware_allowed=false"
    assert output =~ "IOS_PARITY_GATES open 8"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_ios_parity_evidence_manifest"
    assert decoded["ios_parity_claim_allowed?"] == false
    assert decoded["hardware_blocked_gate_count"] == 8
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-ios-parity-evidence-test/ios.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_ios_parity_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_evidence_manifest"))

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "ios_parity_decision_scenario_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_ios_parity.evidence"))
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
