defmodule MeshxMobileApp.BLE.LocalFetchTransportValidationPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalFetchTransportValidationPlan

  test "snapshot keeps full message resolution blocked until real transport evidence exists" do
    snapshot = LocalFetchTransportValidationPlan.snapshot()

    assert snapshot.boundary == :full_message_resolution_transport_validation_plan
    assert snapshot.current_validated_fetch_transport == :none

    assert snapshot.current_known_bad_pair.failure ==
             :android_gatt_status_133_before_service_discovery

    refute snapshot.full_message_resolution_claim_allowed?
    refute snapshot.beacon_refs_resolvable_by_real_transport?
    refute snapshot.gatt_fetch_enabled_by_default?
    assert snapshot.gate_count == 7
    assert snapshot.satisfied_gate_count == 1
    assert snapshot.blocked_gate_count == 6

    assert [
             %{id: :current_gatt_blocker_recorded, status: :satisfied},
             %{id: :candidate_transport_decision, status: :blocked},
             %{id: :standalone_interop_matrix, status: :blocked},
             %{id: :constrained_fetch_exchange, status: :blocked},
             %{id: :canonical_replay_resolution, status: :blocked},
             %{id: :negative_failure_matrix, status: :blocked},
             %{id: :release_artifact_linkage, status: :blocked}
           ] = snapshot.gates
  end

  test "gates require transport decision interop fetch replay and negative evidence" do
    snapshot = LocalFetchTransportValidationPlan.snapshot()

    assert gate(snapshot, :candidate_transport_decision).missing_evidence
           |> Enum.any?(&String.contains?(&1, "candidate transport decision"))

    assert gate(snapshot, :standalone_interop_matrix).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Known-good hardware pair"))

    assert gate(snapshot, :constrained_fetch_exchange).missing_evidence
           |> Enum.any?(&String.contains?(&1, "request_id"))

    assert gate(snapshot, :canonical_replay_resolution).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Replay-normalized fixture"))

    assert gate(snapshot, :negative_failure_matrix).missing_evidence
           |> Enum.any?(&String.contains?(&1, "negative fixtures"))
  end

  test "JSON snapshot preserves disabled GATT and blocked resolution claims" do
    snapshot = LocalFetchTransportValidationPlan.json_snapshot()

    assert snapshot["boundary"] == "full_message_resolution_transport_validation_plan"
    assert snapshot["current_validated_fetch_transport"] == "none"
    assert snapshot["full_message_resolution_claim_allowed?"] == false
    assert snapshot["beacon_refs_resolvable_by_real_transport?"] == false
    assert snapshot["gatt_fetch_enabled_by_default?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "constrained_fetch_exchange" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
