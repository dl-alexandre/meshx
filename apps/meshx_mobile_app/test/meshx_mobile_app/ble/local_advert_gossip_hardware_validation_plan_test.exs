defmodule MeshxMobileApp.BLE.LocalAdvertGossipHardwareValidationPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalAdvertGossipHardwareValidationPlan

  test "snapshot keeps multi-hop hardware gossip blocked until physical role evidence exists" do
    snapshot = LocalAdvertGossipHardwareValidationPlan.snapshot()

    assert snapshot.boundary == :advert_gossip_multi_hop_hardware_validation_plan
    assert snapshot.current_hardware_scope == :one_hop_legacy_beacon_gossip_only
    refute snapshot.multi_hop_hardware_gossip_claim_allowed?
    refute snapshot.routed_delivery_claim_allowed?
    refute snapshot.guaranteed_delivery_claim_allowed?
    refute snapshot.background_operation_claim_allowed?
    assert snapshot.gate_count == 6
    assert snapshot.blocked_gate_count == 6

    assert [
             %{id: :three_role_device_matrix, status: :blocked},
             %{id: :origin_relay_observer_capture, status: :blocked},
             %{id: :replay_normalized_fixture, status: :blocked},
             %{id: :ttl_and_suppression_evidence, status: :blocked},
             %{id: :one_hop_negative_review, status: :blocked},
             %{id: :release_artifact_linkage, status: :blocked}
           ] = snapshot.gates
  end

  test "gates require device matrix role logs replay normalization and negative evidence" do
    snapshot = LocalAdvertGossipHardwareValidationPlan.snapshot()

    assert gate(snapshot, :three_role_device_matrix).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Origin, relay, and observer device inventory"))

    assert gate(snapshot, :origin_relay_observer_capture).missing_evidence
           |> Enum.any?(&String.contains?(&1, "same message_id_hash"))

    assert gate(snapshot, :replay_normalized_fixture).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Replay-normalized fixture"))

    assert gate(snapshot, :ttl_and_suppression_evidence).missing_evidence
           |> Enum.any?(&String.contains?(&1, "TTL decrement"))

    assert gate(snapshot, :one_hop_negative_review).missing_evidence
           |> Enum.any?(&String.contains?(&1, "one-hop-as-multi-hop"))
  end

  test "JSON snapshot preserves blocked multi-hop delivery claims" do
    snapshot = LocalAdvertGossipHardwareValidationPlan.json_snapshot()

    assert snapshot["boundary"] == "advert_gossip_multi_hop_hardware_validation_plan"
    assert snapshot["multi_hop_hardware_gossip_claim_allowed?"] == false
    assert snapshot["routed_delivery_claim_allowed?"] == false
    assert snapshot["guaranteed_delivery_claim_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "origin_relay_observer_capture" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
