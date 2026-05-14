defmodule MeshxMobileApp.BLE.LocalRoutingDryRunTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalRoutingDryRun, LocalRoutingTable, PeerCapabilities}
  alias MeshxMobileApp.BLE.PeerInventory.PeerSummary

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

  test "selected candidates become dry-run outcomes without forwarding" do
    selection = LocalRoutingTable.select([peer([])], "meshx-alpha")

    outcome = LocalRoutingDryRun.evaluate(selection, evaluated_at: 1_700_000_000_000)

    assert outcome.boundary == :local_routing_dry_run
    assert outcome.status == :would_select_candidate
    assert outcome.destination_peer_id == "meshx-alpha"
    assert outcome.next_hop_peer_id == "meshx-alpha"
    assert outcome.target_device_ids == ["AA:01"]
    assert outcome.evaluated_at == 1_700_000_000_000
    refute outcome.route_selection_claim_allowed?
    refute outcome.forwarding_claim_allowed?
    refute outcome.routed_delivery_claim_allowed?
    refute outcome.executed?
    assert :live_forwarding_service in outcome.blocked_claims
  end

  test "non-forwardable selections stay explicit" do
    selection = LocalRoutingTable.select([peer(presence: :stale)], "meshx-alpha")

    outcome = LocalRoutingDryRun.evaluate(selection)

    assert outcome.status == :no_forwardable_route
    assert outcome.destination_peer_id == "meshx-alpha"
    assert outcome.next_hop_peer_id == nil
    assert outcome.target_device_ids == []
    assert :not_active in outcome.blocked_reasons
    refute outcome.executed?
  end

  test "invalid selections are rejected before dry-run evaluation" do
    outcome = LocalRoutingDryRun.evaluate(%{})

    assert outcome.status == :invalid_selection
    assert outcome.blocked_reasons == [:invalid_selection]
    refute outcome.forwarding_claim_allowed?
    refute outcome.routed_delivery_claim_allowed?
  end

  test "snapshot summarizes deterministic dry-run outcomes" do
    selected = LocalRoutingTable.select([peer([])], "meshx-alpha")
    missing = LocalRoutingTable.select([peer([])], "meshx-missing")

    snapshot = LocalRoutingDryRun.snapshot([selected, missing, :bad])

    assert snapshot.boundary == :local_routing_dry_run_snapshot
    assert snapshot.outcome_count == 3
    assert snapshot.would_select_candidate_count == 1
    assert snapshot.no_forwardable_route_count == 1
    assert snapshot.invalid_selection_count == 1
    refute snapshot.forwarding_claim_allowed?
    refute snapshot.routed_delivery_claim_allowed?

    json = LocalRoutingDryRun.json_snapshot([selected])
    assert json["boundary"] == "local_routing_dry_run_snapshot"
    assert json["forwarding_claim_allowed?"] == false
  end
end
