defmodule Mob.Node.BLE.LocalIOSParityHardwareValidationPlanTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalIOSParityHardwareValidationPlan

  test "snapshot records blocked iOS advert-only hardware validation gates" do
    snapshot = LocalIOSParityHardwareValidationPlan.snapshot()

    assert snapshot.boundary == :ios_advert_only_hardware_validation_plan
    assert snapshot.current_ios_mode == :contract_only
    refute snapshot.ios_participation_claims_allowed?
    refute snapshot.ios_hardware_claims_allowed?
    refute snapshot.ios_parity_claims_allowed?
    refute snapshot.ios_background_claims_allowed?
    assert snapshot.gate_count == 8
    assert snapshot.blocked_gate_count == 8

    assert [
             %{id: :target_ios_device_matrix, status: :blocked},
             %{id: :canonical_ingress_fixture, status: :blocked},
             %{id: :legacy_beacon_observe_hardware, status: :blocked},
             %{id: :legacy_beacon_gossip_hardware, status: :blocked},
             %{id: :full_envelope_capability_probe, status: :blocked},
             %{id: :hardware_replay_fixture, status: :blocked},
             %{id: :ios_background_ble_boundary, status: :blocked},
             %{id: :negative_claim_review, status: :blocked}
           ] = snapshot.gates
  end

  test "hardware gates require iOS-specific captures and replay fixtures" do
    snapshot = LocalIOSParityHardwareValidationPlan.snapshot()

    assert gate(snapshot, :target_ios_device_matrix).missing_evidence
           |> Enum.any?(&String.contains?(&1, "iOS device matrix"))

    assert gate(snapshot, :legacy_beacon_observe_hardware).missing_evidence
           |> Enum.any?(&String.contains?(&1, "iOS hardware capture"))

    assert gate(snapshot, :legacy_beacon_gossip_hardware).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Observer capture"))

    full_envelope_gate = gate(snapshot, :full_envelope_capability_probe)

    assert full_envelope_gate.missing_evidence
           |> Enum.any?(&String.contains?(&1, "negative capability ledger remains blocked"))

    assert full_envelope_gate.required_evidence
           |> Enum.any?(&String.contains?(&1, "Negative capability ledger"))

    assert full_envelope_gate.notes
           |> Enum.any?(&String.contains?(&1, "iOS did not surface the callback"))

    assert gate(snapshot, :hardware_replay_fixture).missing_evidence
           |> Enum.any?(&String.contains?(&1, "Replay-normalized"))
  end

  test "JSON snapshot preserves blocked iOS claims" do
    snapshot = LocalIOSParityHardwareValidationPlan.json_snapshot()

    assert snapshot["boundary"] == "ios_advert_only_hardware_validation_plan"
    assert snapshot["ios_parity_claims_allowed?"] == false
    assert snapshot["ios_background_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "legacy_beacon_gossip_hardware" and &1["status"] == "blocked")
           )
  end

  defp gate(snapshot, id), do: Enum.find(snapshot.gates, &(&1.id == id))
end
