defmodule Mix.Tasks.Mob.NodeLocalRoutingValidationPlanTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.Mob.Node.LocalRouting.ValidationPlan

  setup do
    Mix.Task.reenable("mob.node.local_routing.validation_plan")
    File.rm_rf!("tmp/local-routing-validation-plan-test")
    :ok
  end

  test "prints a concise routing validation plan summary" do
    output =
      capture_io(fn ->
        ValidationPlan.run([])
      end)

    assert output =~ "LOCAL_ROUTING_VALIDATION_PLAN production_routing_hardware_validation_plan"
    assert output =~ "current_mode=advert_only_non_routing"
    assert output =~ "route_selection_allowed=false"
    assert output =~ "routed_delivery_allowed=false"
    assert output =~ "ROUTING_VALIDATION_GATES blocked=8 total=8"
    assert output =~ "forwarding_allowed=false"

    assert output =~
             "ROUTING_VALIDATION_REQUIRED gates=route_table_state_model,deterministic_route_selection,forwarding_service_boundary,delivery_semantics_policy,multi_hop_hardware_rig,ttl_loop_and_suppression_evidence,release_artifact_evidence,negative_claim_review"

    assert output =~ "Production routing table state model"
  end

  test "prints machine-readable JSON" do
    output =
      capture_io(fn ->
        ValidationPlan.run(["--json"])
      end)

    assert {:ok, decoded} = JSON.decode(output)
    assert decoded["plan_version"] == 1
    assert decoded["boundary"] == "production_routing_hardware_validation_plan"
    assert decoded["current_mode"] == "advert_only_non_routing"
    assert decoded["routed_delivery_claim_allowed?"] == false
    assert decoded["blocked_gate_count"] == 8
    assert Enum.any?(decoded["gates"], &(&1["id"] == "forwarding_service_boundary"))
  end

  test "writes machine-readable JSON artifact" do
    path = "tmp/local-routing-validation-plan-test/plan.json"

    output =
      capture_io(fn ->
        ValidationPlan.run(["--json", "--out", path])
      end)

    assert {:ok, decoded_output} = JSON.decode(output)
    assert decoded_output["boundary"] == "production_routing_hardware_validation_plan"
    assert File.exists?(path)
    assert {:ok, decoded_file} = path |> File.read!() |> JSON.decode()
    assert decoded_file["forwarding_claim_allowed?"] == false
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
