defmodule MeshxMobileApp.BLE.LocalRoutingProofPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalRoutingProofPlan

  test "snapshot maps every routing requirement to a proof gate" do
    snapshot = LocalRoutingProofPlan.snapshot()
    ids = Enum.map(snapshot.gates, & &1.requirement_id)

    assert snapshot.plan_version == 1
    assert snapshot.proof_boundary == :future_production_routing
    assert snapshot.open_gate_count == 5
    assert snapshot.hardware_blocked_count == 1
    refute snapshot.routing_claims_allowed?

    assert :routing_table in ids
    assert :route_selection in ids
    assert :forwarding_service in ids
    assert :delivery_semantics in ids
    assert :loop_and_ttl_hardware_validation in ids
  end

  test "routing table gate keeps observations separate from forwardable routes" do
    assert {:ok, gate} = LocalRoutingProofPlan.get(:routing_table)

    assert gate.status == :planned
    assert :observation_vs_forwardable_state_boundary in gate.implementation_gates
    assert :route_invalidation_policy in gate.implementation_gates
    assert :route_table_available in gate.blocked_claims

    assert Enum.any?(
             gate.validation_evidence,
             &String.contains?(&1, "local observations are not automatically forwardable")
           )
  end

  test "route selection gate requires deterministic next-hop policy" do
    assert {:ok, gate} = LocalRoutingProofPlan.get(:route_selection)

    assert :candidate_next_hop_selection in gate.implementation_gates
    assert :deterministic_tie_breaks in gate.implementation_gates
    assert :ttl_budget_check in gate.implementation_gates
    assert :route_selection_available in gate.blocked_claims

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "input order"))
  end

  test "delivery semantics gate blocks ACK and retry claims" do
    assert {:ok, gate} = LocalRoutingProofPlan.get(:delivery_semantics)

    assert :delivery_class_policy in gate.implementation_gates
    assert :ack_policy in gate.implementation_gates
    assert :retry_policy in gate.implementation_gates
    assert :guaranteed_delivery in gate.blocked_claims
    assert :ack_backed_delivery in gate.blocked_claims
    assert :retry_backed_delivery in gate.blocked_claims
  end

  test "multi-hop hardware gate remains hardware-blocked" do
    assert {:ok, gate} = LocalRoutingProofPlan.get(:loop_and_ttl_hardware_validation)

    assert gate.status == :hardware_blocked
    assert :three_or_more_physical_participants in gate.implementation_gates
    assert :origin_relay_observer_roles in gate.implementation_gates
    assert :canonical_log_replay in gate.implementation_gates
    assert :multi_hop_hardware_routing in gate.blocked_claims
  end

  test "json snapshot is machine readable" do
    snapshot = LocalRoutingProofPlan.json_snapshot()

    assert snapshot["plan_version"] == 1
    assert snapshot["open_gate_count"] == 5
    assert snapshot["hardware_blocked_count"] == 1
    assert snapshot["routing_claims_allowed?"] == false
    assert Enum.any?(snapshot["gates"], &(&1["requirement_id"] == "route_selection"))
  end
end
