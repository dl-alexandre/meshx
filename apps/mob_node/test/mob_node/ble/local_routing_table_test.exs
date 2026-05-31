defmodule Mob.Node.BLE.LocalRoutingTableTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{LocalRoutingTable, PeerCapabilities}
  alias Mob.Node.BLE.PeerInventory.PeerSummary

  defp caps, do: %PeerCapabilities{protocol_version: 1, supports_passive_presence: true}

  defp peer(attrs) do
    struct!(
      PeerSummary,
      Keyword.merge(
        [
          peer_id: "meshx-alpha",
          device_ids: ["AA:01"],
          display_name: "meshx-alpha",
          identity_confidence: :advertised,
          identity_source: :advertised_name,
          capabilities: caps(),
          presence: :active,
          first_seen_at: 1_000,
          last_seen_at: 1_000,
          last_rssi: -60,
          advertisement_seen_count: 1,
          collision_count: 0,
          last_conflicting_peer_id: nil,
          anonymous?: false,
          suspicious?: false
        ],
        attrs
      )
    )
  end

  test "entries classify forwardable direct candidates from peer observations" do
    assert [
             %LocalRoutingTable.Entry{
               destination_peer_id: "meshx-alpha",
               next_hop_peer_id: "meshx-alpha",
               target_device_ids: ["AA:01"],
               forwardable?: true,
               blocked_reasons: []
             }
           ] = LocalRoutingTable.entries([peer([])])
  end

  test "entries reject anonymous stale suspicious or non-MeshX candidates" do
    anonymous = peer(peer_id: nil, identity_confidence: :unknown, anonymous?: true)
    stale = peer(peer_id: "mob-stale", presence: :stale)
    suspicious = peer(peer_id: "mob-bad", suspicious?: true, collision_count: 1)
    non_mob = peer(peer_id: "mob-plain", capabilities: %PeerCapabilities{})

    entries = LocalRoutingTable.entries([anonymous, stale, suspicious, non_mob])

    assert Enum.any?(entries, &(:anonymous_peer in &1.blocked_reasons))
    assert Enum.any?(entries, &(:not_active in &1.blocked_reasons))
    assert Enum.any?(entries, &(:identity_contested in &1.blocked_reasons))
    assert Enum.any?(entries, &(:missing_mob_capability in &1.blocked_reasons))
    assert Enum.all?(entries, &(not &1.forwardable?))
  end

  test "select deterministically chooses active MeshX candidate without allowing routing claims" do
    older = peer(peer_id: "meshx-alpha", device_ids: ["AA:01"], last_seen_at: 1_000)
    newer = peer(peer_id: "meshx-alpha", device_ids: ["AA:02"], last_seen_at: 2_000)

    selection = LocalRoutingTable.select([older, newer], "meshx-alpha")

    assert selection.status == :selected
    assert selection.selected.target_device_ids == ["AA:02"]
    assert selection.candidates |> Enum.map(& &1.target_device_ids) == [["AA:02"], ["AA:01"]]
    refute selection.routing_claim_allowed?
  end

  test "select preserves blockers when no forwardable candidate exists" do
    stale = peer(peer_id: "meshx-alpha", presence: :stale)

    selection = LocalRoutingTable.select([stale], "meshx-alpha")

    assert selection.status == :no_forwardable_route
    assert selection.selected == nil
    assert :not_active in selection.blocked_reasons
    refute selection.routing_claim_allowed?
  end

  test "missing destination is explicit and not an error" do
    selection = LocalRoutingTable.select([peer(peer_id: "meshx-alpha")], "mob-missing")

    assert selection.status == :no_forwardable_route
    assert selection.candidates == []
    assert selection.blocked_reasons == [:no_observed_candidate]
  end

  test "snapshot and json snapshot remain claim-gated" do
    snapshot = LocalRoutingTable.snapshot([peer([])])

    assert snapshot.boundary == :local_observation_route_candidates
    assert snapshot.entry_count == 1
    assert snapshot.forwardable_count == 1
    refute snapshot.routing_claim_allowed?
    refute snapshot.forwarding_service_available?
    refute snapshot.delivery_semantics_available?

    json = LocalRoutingTable.json_snapshot([peer([])])
    assert json["boundary"] == "local_observation_route_candidates"
    assert json["routing_claim_allowed?"] == false
  end
end
