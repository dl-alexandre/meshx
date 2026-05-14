defmodule MeshxMobileApp.BLE.LocalRoutingPolicyTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalRoutingPolicy}

  test "local observation is the only allowed routing-adjacent claim" do
    assert {:ok, capability} = LocalRoutingPolicy.get(:local_observation)

    assert capability.status == :allowed
    assert capability.required_before_allowed == []
    assert Enum.any?(capability.allowed_claims, &String.contains?(&1, "seen nearby"))
    assert Enum.any?(capability.blocked_claims, &String.contains?(&1, "Routed delivery"))
  end

  test "advert gossip planning remains simulation-only rather than production routing" do
    assert {:ok, capability} = LocalRoutingPolicy.get(:advert_gossip_planning)

    assert capability.status == :simulation_only
    assert :multi_hop_hardware_proof in capability.required_before_allowed
    assert Enum.any?(capability.blocked_claims, &String.contains?(&1, "route selection"))
  end

  test "route selection, forwarding, delivery semantics, and hardware routing are blocked" do
    blocked_ids = Enum.map(LocalRoutingPolicy.blocked(), & &1.id)

    assert :route_selection in blocked_ids
    assert :forwarding_service in blocked_ids
    assert :delivery_semantics in blocked_ids
    assert :multi_hop_hardware_routing in blocked_ids
  end

  test "snapshot exposes counts and blocks routing claims" do
    snapshot = LocalRoutingPolicy.snapshot()

    assert snapshot.decision_outcome == :keep_advert_only_non_routing
    assert snapshot.decision_status == :selected_for_current_validated_mode

    assert snapshot.production_routing_reconsideration_gate ==
             :production_routing_hardware_validation_plan

    assert snapshot.allowed_count == 1
    assert snapshot.simulation_only_count == 1
    assert snapshot.blocked_count == 4
    refute snapshot.routing_claims_allowed?
    refute snapshot.production_routing_claim_allowed?

    assert Enum.any?(
             snapshot.notes,
             &String.contains?(&1, "live routing claims are not")
           )
  end

  test "local inbox snapshot exposes routing policy" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.routing_policy.mode == :advertisement_only_local_mesh
    assert snapshot.routing_policy.blocked_count == 4
    refute snapshot.routing_policy.routing_claims_allowed?
  end
end
