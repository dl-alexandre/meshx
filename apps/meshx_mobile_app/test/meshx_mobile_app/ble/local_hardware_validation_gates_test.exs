defmodule MeshxMobileApp.BLE.LocalHardwareValidationGatesTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalHardwareValidationGates, LocalInbox}

  test "one-hop Android legacy beacon gossip gate is passed" do
    assert {:ok, gate} =
             LocalHardwareValidationGates.get(:android_legacy_beacon_gossip_one_hop)

    assert gate.status == :passed
    assert gate.required_evidence == []
    assert Enum.any?(gate.evidence, &String.contains?(&1, "m59"))
    assert Enum.any?(gate.evidence, &String.contains?(&1, "m26b"))
  end

  test "GATT known-good fetch gate remains blocked with explicit required evidence" do
    assert {:ok, gate} = LocalHardwareValidationGates.get(:gatt_known_good_fetch)

    assert gate.status == :blocked
    assert Enum.any?(gate.evidence, &String.contains?(&1, "ble_transport_re_evaluation"))
    assert "LocalFetchTransportValidationPlan" in gate.evidence
    assert Enum.any?(gate.evidence, &String.contains?(&1, "m40-current"))
    assert Enum.any?(gate.required_evidence, &String.contains?(&1, "standalone GATT connect"))
    assert Enum.any?(gate.required_evidence, &String.contains?(&1, "MessageEnvelope"))
  end

  test "multi-hop hardware proof and iOS advert-only participation remain open gates" do
    open_ids = LocalHardwareValidationGates.open_gates() |> Enum.map(& &1.id)

    assert {:ok, multi_hop} =
             LocalHardwareValidationGates.get(:advert_gossip_multi_hop_hardware)

    assert "LocalAdvertGossipHardwareValidationPlan" in multi_hop.evidence
    assert :advert_gossip_multi_hop_hardware in open_ids
    assert :ios_advert_only_participation in open_ids
    refute :android_legacy_beacon_gossip_one_hop in open_ids
  end

  test "snapshot summarizes passed and open hardware gates" do
    snapshot = LocalHardwareValidationGates.snapshot()

    assert snapshot.passed_gate_count == 1
    assert snapshot.open_gate_count == 4
    assert length(snapshot.gates) == 5
    assert Enum.any?(snapshot.notes, &String.contains?(&1, "Replay proof"))
  end

  test "local inbox snapshot exposes hardware validation gates" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.hardware_validation_gates.passed_gate_count == 1

    assert Enum.any?(
             snapshot.hardware_validation_gates.open_gates,
             &(&1.id == :gatt_known_good_fetch)
           )
  end
end
