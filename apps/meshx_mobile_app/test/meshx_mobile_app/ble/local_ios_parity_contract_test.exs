defmodule MeshxMobileApp.BLE.LocalIOSParityContractTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalIOSParityContract, LocalInbox}

  test "canonical ingress is contract-only until iOS hardware fixtures exist" do
    assert {:ok, requirement} = LocalIOSParityContract.get(:canonical_ingress)

    assert requirement.status == :contract_only
    assert Enum.any?(requirement.required_evidence, &String.contains?(&1, "BridgeProtocol"))
    assert requirement.current_gap =~ "hardware fixtures are absent"
  end

  test "legacy beacon gossip remains unproven on iOS" do
    assert {:ok, requirement} = LocalIOSParityContract.get(:legacy_beacon_gossip)

    assert requirement.status == :not_implemented

    assert Enum.any?(
             requirement.required_evidence,
             &String.contains?(&1, "compact legacy beacon")
           )

    assert requirement.current_gap =~ "no iOS-origin cross-radio gossip proof"
  end

  test "snapshot lists all open iOS parity requirements" do
    snapshot = LocalIOSParityContract.snapshot()
    ids = Enum.map(snapshot.open_requirements, & &1.id)

    assert snapshot.open_requirement_count == 5
    assert :canonical_ingress in ids
    assert :legacy_beacon_observe in ids
    assert :legacy_beacon_gossip in ids
    assert :full_envelope_advert in ids
    assert :hardware_replay_fixture in ids
  end

  test "local inbox snapshot exposes iOS parity contract" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.ios_parity_contract.open_requirement_count == 5

    assert Enum.any?(
             snapshot.ios_parity_contract.notes,
             &String.contains?(&1, "iOS does not")
           )
  end
end
