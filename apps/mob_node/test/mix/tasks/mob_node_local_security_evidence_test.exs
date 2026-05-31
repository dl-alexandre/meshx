defmodule Mix.Tasks.Mob.NodeLocalSecurityEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalSecurity.Evidence

  setup do
    Mix.Task.reenable("mob.node.local_security.evidence")
    File.rm_rf!("tmp/local-security-evidence-test")
    :ok
  end

  test "prints a concise security evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~ "LOCAL_SECURITY_EVIDENCE complete=false"
    assert output =~ "trusted_message_allowed=false"
    assert output =~ "trusted_delivery_allowed=false"
    assert output =~ "SECURITY_GATES open 8"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_security_evidence_manifest"
    assert decoded["security_evidence_complete?"] == false
    assert decoded["trusted_delivery_claim_allowed?"] == false
    assert decoded["release_evidence_review"]["status"] == "open"
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-security-evidence-test/security.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_security_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["required_artifacts"] |> Enum.any?(&(&1["id"] == "security_manifest"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_security.validation_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_security.evidence"))
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
