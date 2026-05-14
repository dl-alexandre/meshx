defmodule Mix.Tasks.MeshxMobileLocalPersistenceEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Meshx.Mobile.LocalPersistence.Evidence

  setup do
    Mix.Task.reenable("meshx.mobile.local_persistence.evidence")
    File.rm_rf!("tmp/local-persistence-evidence-test")
    :ok
  end

  test "prints a concise persistence evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~ "LOCAL_PERSISTENCE_EVIDENCE default=memory_only"
    assert output =~ "opt_in_durable=true"
    assert output =~ "production_default_allowed=false"
    assert output =~ "PERSISTENCE_GATES open 6"
    assert output =~ "PERSISTENCE_CAPTURE_PLAN sections=6"
    assert output =~ "artifacts/local-ble/<run-id>/persistence/"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_persistence_evidence_manifest"
    assert decoded["current_default_mode"] == "memory_only"
    assert decoded["production_default_persistence_allowed?"] == false

    assert decoded["operator_capture_plan"]["boundary"] ==
             "local_persistence_operator_capture_plan"

    assert length(decoded["operator_capture_plan"]["capture_sections"]) == 6
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-persistence-evidence-test/persistence.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_persistence_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "persistence_evidence_manifest"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_persistence.evidence"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_persistence.lifecycle_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_persistence.production_review"))
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
