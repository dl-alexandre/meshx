defmodule Mob.Node.BLE.LocalIOSParityPolicyTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalIOSParityPolicy, LocalInbox}

  test "shared canonical contract is contract-only rather than hardware validation" do
    assert {:ok, capability} = LocalIOSParityPolicy.get(:shared_canonical_contract)

    assert capability.status == :contract_only
    assert Enum.any?(capability.allowed_claims, &String.contains?(&1, "canonical"))
    assert Enum.any?(capability.blocked_claims, &String.contains?(&1, "iOS hardware"))
    assert :ios_hardware_fixtures in capability.required_before_allowed
  end

  test "iOS advert-only participation claims are blocked" do
    blocked_ids = Enum.map(LocalIOSParityPolicy.blocked(), & &1.id)

    assert :ios_legacy_beacon_observe in blocked_ids
    assert :ios_legacy_beacon_gossip in blocked_ids
    assert :ios_full_envelope_advert in blocked_ids
    assert :ios_hardware_replay_fixtures in blocked_ids
    assert :ios_background_ble in blocked_ids
  end

  test "snapshot blocks iOS participation claims until hardware proof exists" do
    snapshot = LocalIOSParityPolicy.snapshot()

    assert snapshot.platform == :ios
    assert snapshot.contract_only_count == 1
    assert snapshot.blocked_count == 5
    refute snapshot.ios_participation_claims_allowed?

    assert Enum.any?(
             snapshot.notes,
             &String.contains?(&1, "Android validation evidence cannot be reused")
           )
  end

  test "local inbox snapshot exposes iOS parity policy" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert snapshot.ios_parity_policy.platform == :ios
    assert snapshot.ios_parity_policy.blocked_count == 5
    refute snapshot.ios_parity_policy.ios_participation_claims_allowed?
  end
end
