defmodule Mob.Node.BLE.LocalRoutingHardwareValidationPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalRoutingHardwareValidationPlan

  test "snapshot records blocked production routing validation gates" do
    snapshot = LocalRoutingHardwareValidationPlan.snapshot()

    assert snapshot.boundary == :production_routing_hardware_validation_plan
    assert snapshot.current_mode == :advert_only_non_routing
    refute snapshot.route_table_claim_allowed?
    refute snapshot.route_selection_claim_allowed?
    refute snapshot.forwarding_claim_allowed?
    refute snapshot.routed_delivery_claim_allowed?
    refute snapshot.multi_hop_hardware_claim_allowed?
    assert snapshot.gate_count == 8
    assert snapshot.blocked_gate_count == 8

    assert [
             %{id: :route_table_state_model, status: :blocked},
             %{id: :deterministic_route_selection, status: :blocked},
             %{id: :forwarding_service_boundary, status: :blocked},
             %{id: :delivery_semantics_policy, status: :blocked},
             %{id: :multi_hop_hardware_rig, status: :blocked},
             %{id: :ttl_loop_and_suppression_evidence, status: :blocked},
             %{id: :release_artifact_evidence, status: :blocked},
             %{id: :negative_claim_review, status: :blocked}
           ] = snapshot.gates
  end

  test "routing gates require route table forwarding delivery and multi-hop evidence" do
    snapshot = LocalRoutingHardwareValidationPlan.snapshot()

    assert gate(snapshot, :route_table_state_model).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Production routing table"))

    assert gate(snapshot, :deterministic_route_selection).missing_evidence
           |> Enum.any?(&String.contains?(&1, "deterministic fixtures"))

    assert gate(snapshot, :forwarding_service_boundary).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Forwarding service"))

    assert gate(snapshot, :delivery_semantics_policy).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Delivery semantics"))

    assert gate(snapshot, :multi_hop_hardware_rig).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Origin, relay, and observer"))
  end

  test "JSON snapshot preserves blocked routing claims" do
    snapshot = LocalRoutingHardwareValidationPlan.json_snapshot()

    assert snapshot["boundary"] == "production_routing_hardware_validation_plan"
    assert snapshot["routed_delivery_claim_allowed?"] == false
    assert snapshot["multi_hop_hardware_claim_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "ttl_loop_and_suppression_evidence" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
