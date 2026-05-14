defmodule MeshxMobileApp.BLE.LocalIOSParityAcceptanceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalIOSParityAcceptance, LocalInbox}

  test "snapshot records contract-only gates and blocks iOS hardware parity claims" do
    acceptance = LocalIOSParityAcceptance.snapshot()

    assert acceptance.boundary == :current_ios_contract_only_mode
    assert acceptance.satisfied_count == 5
    assert acceptance.blocked_count == 5
    refute acceptance.ios_participation_claims_allowed?
    refute acceptance.ios_hardware_claims_allowed?
    refute acceptance.ios_parity_claims_allowed?
    refute acceptance.ios_background_claims_allowed?

    assert [
             %{id: :shared_canonical_contract, status: :satisfied},
             %{id: :future_ios_parity_contract, status: :satisfied},
             %{id: :ios_hardware_validation_plan, status: :satisfied},
             %{id: :negative_ios_parity_validation, status: :satisfied},
             %{id: :canonical_ingress, status: :satisfied},
             %{id: :legacy_beacon_observe, status: :blocked},
             %{id: :legacy_beacon_gossip, status: :blocked},
             %{id: :full_envelope_advert, status: :blocked},
             %{id: :hardware_replay_fixture, status: :blocked},
             %{id: :ios_background_ble, status: :blocked}
           ] = acceptance.gates
  end

  test "blocked iOS parity gates carry concrete missing evidence" do
    acceptance = LocalIOSParityAcceptance.snapshot()

    observe = Enum.find(acceptance.gates, &(&1.id == :legacy_beacon_observe))
    gossip = Enum.find(acceptance.gates, &(&1.id == :legacy_beacon_gossip))
    full = Enum.find(acceptance.gates, &(&1.id == :full_envelope_advert))
    fixture = Enum.find(acceptance.gates, &(&1.id == :hardware_replay_fixture))
    background = Enum.find(acceptance.gates, &(&1.id == :ios_background_ble))

    assert Enum.any?(observe.missing, &String.contains?(&1, "iOS device must observe"))
    assert Enum.any?(gossip.missing, &String.contains?(&1, "iOS must emit"))
    assert Enum.any?(full.missing, &String.contains?(&1, "Capability-proven iOS hardware"))
    assert Enum.any?(fixture.missing, &String.contains?(&1, "iOS hardware captures"))
    assert "Missing :ios_background_capability." in background.missing
  end

  test "local inbox snapshot exposes iOS parity acceptance without promoting parity" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert %{ios_parity_acceptance: acceptance} = snapshot
    assert acceptance.satisfied_count == 5
    assert acceptance.blocked_count == 5
    refute acceptance.ios_parity_claims_allowed?
  end

  test "JSON snapshot preserves blocked iOS claims" do
    snapshot = LocalIOSParityAcceptance.json_snapshot()

    assert snapshot["boundary"] == "current_ios_contract_only_mode"
    assert snapshot["ios_participation_claims_allowed?"] == false
    assert snapshot["ios_hardware_claims_allowed?"] == false
    assert snapshot["ios_parity_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "legacy_beacon_gossip" and &1["status"] == "blocked")
           )
  end
end
