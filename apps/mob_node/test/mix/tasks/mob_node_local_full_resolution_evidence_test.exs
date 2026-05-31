defmodule Mix.Tasks.Mob.NodeLocalFullResolutionEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalFullResolution.Evidence

  setup do
    Mix.Task.reenable("mob.node.local_full_resolution.evidence")
    File.rm_rf!("tmp/local-full-resolution-evidence-test")
    :ok
  end

  test "prints a concise full resolution evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~
             "LOCAL_FULL_RESOLUTION_EVIDENCE mode=beacon_refs_unresolved_without_real_transport"

    assert output =~ "real_transport_validated=false"
    assert output =~ "resolution_allowed=false"
    assert output =~ "FULL_RESOLUTION_GATES satisfied 1 blocked 6"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_full_message_resolution_evidence_manifest"
    assert decoded["real_fetch_transport_validated?"] == false
    assert decoded["blocked_transport_gate_count"] == 6
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-full-resolution-evidence-test/full-resolution.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_full_message_resolution_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "full_message_resolution_evidence_manifest"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_full_resolution.evidence"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_full_resolution.transport_review"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_known_good_transport.review"))
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
