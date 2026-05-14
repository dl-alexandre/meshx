defmodule MeshxMobileApp.BLE.LocalIOSParityNegativeValidationTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalIOSParityNegativeValidation

  test "snapshot blocks iOS participation and parity claims" do
    snapshot = LocalIOSParityNegativeValidation.snapshot()

    assert snapshot.validation_version == 1
    assert snapshot.boundary == :current_ios_contract_only_mode
    assert snapshot.case_count == 5
    refute snapshot.ios_participation_claims_allowed?
    refute snapshot.ios_hardware_claims_allowed?
    refute snapshot.ios_parity_claims_allowed?
  end

  test "iOS bridge shell remains contract-only evidence" do
    snapshot = LocalIOSParityNegativeValidation.snapshot()

    validation =
      Enum.find(snapshot.cases, &(&1.id == :ios_bridge_shell_as_hardware_participation))

    assert validation.input == :ios_native_bridge_shell
    assert validation.expected_decision == :contract_only
    assert :ios_hardware_participation in validation.blocked_claims
    assert :ios_hardware_fixture in validation.required_before_allowed
  end

  test "Android hardware evidence cannot satisfy iOS observe proof" do
    snapshot = LocalIOSParityNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :android_beacon_proof_as_ios_observe))

    assert validation.expected_decision == :wrong_platform_evidence
    assert :ios_legacy_beacon_observed in validation.blocked_claims
    assert :ios_device_capture in validation.required_before_allowed
    assert :replay_normalized_fixture in validation.required_before_allowed
  end

  test "missing dispatcher and unproven capability block iOS gossip and full envelope claims" do
    snapshot = LocalIOSParityNegativeValidation.snapshot()
    gossip = Enum.find(snapshot.cases, &(&1.id == :missing_ios_dispatcher_as_gossip))
    full = Enum.find(snapshot.cases, &(&1.id == :unproven_ios_full_envelope_capability))

    assert gossip.expected_decision == :not_implemented
    assert full.expected_decision == :hardware_blocked
    assert :ios_legacy_beacon_dispatcher in gossip.required_before_allowed
    assert :ios_ble_capability_probe in full.required_before_allowed
  end

  test "json snapshot is machine readable" do
    snapshot = LocalIOSParityNegativeValidation.json_snapshot()

    assert snapshot["validation_version"] == 1
    assert snapshot["ios_parity_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "missing_ios_replay_fixture" and
                 &1["expected_decision"] == "missing_replay_evidence")
           )
  end
end
