defmodule MeshxMobileApp.BLE.LocalPlatformParityTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalPlatformParity}

  test "android legacy beacon observe and gossip are hardware validated" do
    assert {:ok, observe} = LocalPlatformParity.get(:android, :legacy_beacon_observe)
    assert observe.status == :hardware_validated
    assert Enum.any?(observe.evidence, &String.contains?(&1, "m26b"))

    assert {:ok, gossip} = LocalPlatformParity.get(:android, :legacy_beacon_gossip)
    assert gossip.status == :hardware_validated
    assert Enum.any?(gossip.evidence, &String.contains?(&1, "m59"))
  end

  test "ios advert-only parity is explicit and not claimed as validated" do
    assert {:ok, observe} = LocalPlatformParity.get(:ios, :legacy_beacon_observe)
    assert observe.status == :implemented_unvalidated
    assert Enum.any?(observe.evidence, &String.contains?(&1, "BLE.swift"))

    assert {:ok, gossip} = LocalPlatformParity.get(:ios, :legacy_beacon_gossip)
    assert gossip.status == :not_implemented

    assert {:ok, full} = LocalPlatformParity.get(:ios, :full_envelope_advert)
    assert full.status == :contract_only
  end

  test "blocked current hardware includes GATT fetch and background gaps" do
    blockers = LocalPlatformParity.blockers()

    assert Enum.any?(blockers, &(&1.platform == :android and &1.capability == :gatt_fetch))
    assert Enum.any?(blockers, &(&1.platform == :ios and &1.capability == :gatt_fetch))
    assert Enum.any?(blockers, &(&1.platform == :android and &1.capability == :background_ble))
    assert Enum.any?(blockers, &(&1.platform == :ios and &1.capability == :background_ble))
  end

  test "local inbox snapshot carries platform parity matrix" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert %{entries: entries, blockers: blockers, notes: notes} = snapshot.platform_parity
    assert length(entries) == 10
    assert Enum.any?(blockers, &(&1.platform == :ios and &1.capability == :legacy_beacon_gossip))
    assert Enum.any?(notes, &String.contains?(&1, "iOS advert-only"))
  end
end
