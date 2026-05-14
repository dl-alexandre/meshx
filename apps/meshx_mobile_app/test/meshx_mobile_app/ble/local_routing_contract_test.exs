defmodule MeshxMobileApp.BLE.LocalRoutingContractTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalRoutingContract}

  test "route selection requirement distinguishes gossip planning from routing" do
    assert {:ok, requirement} = LocalRoutingContract.get(:route_selection)

    assert requirement.status == :not_implemented
    assert Enum.any?(requirement.required_evidence, &String.contains?(&1, "next hops"))
    assert requirement.current_gap =~ "not paths to a destination"
  end

  test "loop and ttl proof remains replay-only until hardware validation exists" do
    assert {:ok, requirement} = LocalRoutingContract.get(:loop_and_ttl_hardware_validation)

    assert requirement.status == :replay_only

    assert Enum.any?(
             requirement.required_evidence,
             &String.contains?(&1, "physical participants")
           )

    assert requirement.current_gap =~ "hardware proof is still one-hop only"
  end

  test "snapshot lists all open routing requirements" do
    snapshot = LocalRoutingContract.snapshot()
    ids = Enum.map(snapshot.open_requirements, & &1.id)

    assert snapshot.open_requirement_count == 5
    assert :routing_table in ids
    assert :route_selection in ids
    assert :forwarding_service in ids
    assert :delivery_semantics in ids
    assert :loop_and_ttl_hardware_validation in ids
  end

  test "local inbox snapshot exposes routing contract" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.routing_contract.open_requirement_count == 5

    assert Enum.any?(
             snapshot.routing_contract.notes,
             &String.contains?(&1, "not production routing")
           )
  end
end
