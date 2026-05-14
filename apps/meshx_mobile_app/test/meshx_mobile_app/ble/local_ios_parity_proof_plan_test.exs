defmodule MeshxMobileApp.BLE.LocalIOSParityProofPlanTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalIOSParityProofPlan

  test "snapshot maps every iOS parity requirement to a proof gate" do
    snapshot = LocalIOSParityProofPlan.snapshot()
    ids = Enum.map(snapshot.gates, & &1.requirement_id)

    assert snapshot.plan_version == 1
    assert snapshot.proof_boundary == :future_ios_advert_only_parity
    assert snapshot.open_gate_count == 5
    assert snapshot.hardware_blocked_count == 3
    refute snapshot.ios_participation_claims_allowed?

    assert :canonical_ingress in ids
    assert :legacy_beacon_observe in ids
    assert :legacy_beacon_gossip in ids
    assert :full_envelope_advert in ids
    assert :hardware_replay_fixture in ids
  end

  test "canonical ingress gate requires BridgeProtocol normalization" do
    assert {:ok, gate} = LocalIOSParityProofPlan.get(:canonical_ingress)

    assert gate.status == :planned
    assert :ios_v1_wire_event_emission in gate.implementation_gates
    assert :bridge_protocol_normalization in gate.implementation_gates
    assert :received_message_beacon_mapping in gate.implementation_gates
    assert :ios_hardware_participation in gate.blocked_claims

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "BridgeProtocol"))
  end

  test "legacy beacon observe gate requires iOS hardware logs and replay fixture" do
    assert {:ok, gate} = LocalIOSParityProofPlan.get(:legacy_beacon_observe)

    assert gate.status == :hardware_blocked
    assert :ios_scanner_implementation in gate.implementation_gates
    assert :legacy_beacon_decode in gate.implementation_gates
    assert :replay_normalized_fixture in gate.implementation_gates
    assert :ios_legacy_beacon_observed in gate.blocked_claims

    assert Enum.any?(gate.validation_evidence, &String.contains?(&1, "iOS hardware log"))
  end

  test "legacy beacon gossip gate requires iOS dispatcher and observer capture" do
    assert {:ok, gate} = LocalIOSParityProofPlan.get(:legacy_beacon_gossip)

    assert gate.status == :planned
    assert :ios_legacy_beacon_dispatcher in gate.implementation_gates
    assert :compact_beacon_payload_encoder in gate.implementation_gates
    assert :observer_capture in gate.implementation_gates
    assert :ios_legacy_beacon_gossip in gate.blocked_claims
  end

  test "full envelope advert gate stays hardware capability dependent" do
    assert {:ok, gate} = LocalIOSParityProofPlan.get(:full_envelope_advert)

    assert gate.status == :hardware_blocked
    assert :ios_ble_capability_probe in gate.implementation_gates
    assert :full_envelope_payload_budget_check in gate.implementation_gates
    assert :capability_proven_hardware_pair in gate.implementation_gates
    assert :ios_full_envelope_advert in gate.blocked_claims
  end

  test "json snapshot is machine readable" do
    snapshot = LocalIOSParityProofPlan.json_snapshot()

    assert snapshot["plan_version"] == 1
    assert snapshot["open_gate_count"] == 5
    assert snapshot["hardware_blocked_count"] == 3
    assert snapshot["ios_participation_claims_allowed?"] == false
    assert Enum.any?(snapshot["gates"], &(&1["requirement_id"] == "legacy_beacon_observe"))
  end
end
