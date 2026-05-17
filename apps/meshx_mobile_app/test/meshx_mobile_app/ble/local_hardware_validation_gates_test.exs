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

  test "iOS advert-only participation is partial with responder fetch evidence" do
    assert {:ok, gate} = LocalHardwareValidationGates.get(:ios_advert_only_participation)

    assert gate.status == :partial

    assert Enum.any?(
             gate.evidence,
             &String.contains?(&1, "android-fetch-ios-responder-rerun")
           )

    assert Enum.any?(
             gate.evidence,
             &String.contains?(&1, "android-aux-full-mx-ios-observe")
           )

    assert Enum.any?(
             gate.evidence,
             &String.contains?(&1, "android-aux-full-mx-ios-observe-rerun")
           )

    assert Enum.any?(
             gate.evidence,
             &String.contains?(&1, "aux-alternate-ios-target-check")
           )

    assert Enum.any?(
             gate.evidence,
             &String.contains?(&1, "external-blocker-recheck-1358")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "MeshxFetchGattResponder is hardware validated")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "did not surface the MX manufacturer data callback")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "no second iOS AUX receiver target")
           )

    assert Enum.any?(
             gate.notes,
             &String.contains?(&1, "upstream-pr-recheck-1358")
           )

    assert Enum.any?(
             gate.required_evidence,
             &String.contains?(&1, "Direct full-MX extended-advert receive remains blocked")
           )
  end

  test "multi-hop hardware proof and incomplete iOS participation remain open gates" do
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
