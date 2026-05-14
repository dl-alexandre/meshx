defmodule MeshxMobileApp.BLE.AdvertGossipScenarioTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.AdvertGossipScenario

  @scenario_dir Path.expand("../../fixtures/advert_gossip_scenarios", __DIR__)

  test "all committed advert gossip scenarios pass their expected audits" do
    reports =
      @scenario_dir
      |> Path.join("*.json")
      |> Path.wildcard()
      |> Enum.sort()
      |> Enum.map(&AdvertGossipScenario.run_file!/1)

    assert Enum.map(reports, & &1.scenario) == [
             "line_three_nodes",
             "partitioned_four_nodes",
             "triangle_duplicate_seen"
           ]

    assert Enum.all?(reports, & &1.passed)
  end

  test "scenario audit reports mismatched expected counts" do
    path = Path.join(@scenario_dir, "line_three_nodes.json")
    scenario = path |> File.read!() |> :json.decode()

    bad =
      put_in(
        scenario,
        ["expected", "delivery_counts"],
        %{"delivered" => 99}
      )

    report = AdvertGossipScenario.run!(bad, Path.dirname(path))

    refute report.passed
    assert [failure] = report.failures
    assert failure =~ "delivery_counts mismatch"
  end
end
