defmodule Mix.Tasks.Mob.NodeLocalRoutingEvidenceTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalRouting.Evidence

  setup do
    Mix.Task.reenable("mob.node.local_routing.evidence")
    File.rm_rf!("tmp/local-routing-evidence-test")
    :ok
  end

  test "prints a concise routing evidence summary" do
    output =
      capture_io(fn ->
        Evidence.run([])
      end)

    assert output =~ "LOCAL_ROUTING_EVIDENCE mode=advert_only_non_routing"
    assert output =~ "route_selection_allowed=false"
    assert output =~ "forwarding_allowed=false"
    assert output =~ "ROUTING_GATES candidates 2"
    assert output =~ "ROUTING_CAPTURE_PLAN sections=8"
    assert output =~ "artifacts/local-ble/<run-id>/routing/"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        Evidence.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["manifest_version"] == 1
    assert decoded["boundary"] == "local_routing_evidence_manifest"
    assert decoded["routed_delivery_claim_allowed?"] == false
    assert decoded["hardware_blocked_gate_count"] == 8
    assert decoded["operator_capture_plan"]["boundary"] == "local_routing_operator_capture_plan"

    assert decoded["routing_decision_scenario_plan"]["boundary"] ==
             "local_routing_decision_scenario_plan"

    assert length(decoded["operator_capture_plan"]["capture_sections"]) == 8
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-routing-evidence-test/routing.json"

    output =
      capture_io(fn ->
        Evidence.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "local_routing_evidence_manifest"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "routing_evidence_manifest"))

    assert decoded_file["required_artifacts"]
           |> Enum.any?(&(&1["id"] == "routing_decision_scenario_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_routing.validation_plan"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_routing.evidence"))

    assert decoded_file["required_commands"]
           |> Enum.any?(&String.contains?(&1, "local_routing.production_review"))
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
