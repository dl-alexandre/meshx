defmodule Mix.Tasks.MeshxMobileLocalMultiHopHardwareEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalMultiHopHardware.Evidence

  setup do
    Mix.Task.reenable("meshx.mobile.local_multi_hop_hardware.evidence")
    File.rm_rf!("tmp/local-multi-hop-hardware-evidence-test")
    :ok
  end

  test "prints a concise multi-hop hardware evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~
             "LOCAL_MULTI_HOP_HARDWARE_EVIDENCE scope=one_hop_legacy_beacon_gossip_only"

    assert output =~ "multi_hop_present=false"
    assert output =~ "multi_hop_allowed=false"
    assert output =~ "MULTI_HOP_HARDWARE_GATES replay_policy=true one_hop_hardware=true blocked 6"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_multi_hop_hardware_evidence_manifest"
    assert decoded["multi_hop_physical_proof_present?"] == false
    assert decoded["blocked_gate_count"] == 6
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-multi-hop-hardware-evidence-test/multi-hop.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_multi_hop_hardware_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "multi_hop_hardware_evidence_manifest"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_multi_hop_hardware.evidence"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_multi_hop_hardware.review"))
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
