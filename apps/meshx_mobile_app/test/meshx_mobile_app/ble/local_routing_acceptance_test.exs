defmodule MeshxMobileApp.BLE.LocalRoutingAcceptanceTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalRoutingAcceptance, PeerCapabilities}
  alias MeshxMobileApp.BLE.PeerInventory.PeerSummary

  defp caps, do: %PeerCapabilities{protocol_version: 1, supports_passive_presence: true}

  defp peer(attrs \\ []) do
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

  test "snapshot records current satisfied routing gates and blocked production gates" do
    acceptance = LocalRoutingAcceptance.snapshot([peer()])

    assert acceptance.boundary == :current_advert_only_non_routing_mode
    assert acceptance.satisfied_count == 5
    assert acceptance.blocked_count == 5
    refute acceptance.route_selection_claim_allowed?
    refute acceptance.forwarding_claim_allowed?
    refute acceptance.routed_delivery_claim_allowed?
    refute acceptance.multi_hop_hardware_claim_allowed?

    assert [
             %{id: :observation_policy, status: :satisfied},
             %{id: :route_candidate_table, status: :satisfied},
             %{id: :future_routing_contract, status: :satisfied},
             %{id: :routing_hardware_validation_plan, status: :satisfied},
             %{id: :negative_routing_validation, status: :satisfied},
             %{id: :routing_table, status: :blocked},
             %{id: :route_selection, status: :blocked},
             %{id: :forwarding_service, status: :blocked},
             %{id: :delivery_semantics, status: :blocked},
             %{id: :loop_and_ttl_hardware_validation, status: :blocked}
           ] = acceptance.gates
  end

  test "blocked production routing gates carry concrete missing evidence" do
    acceptance = LocalRoutingAcceptance.snapshot([peer()])

    routing_table = Enum.find(acceptance.gates, &(&1.id == :routing_table))
    route_selection = Enum.find(acceptance.gates, &(&1.id == :route_selection))
    forwarding = Enum.find(acceptance.gates, &(&1.id == :forwarding_service))
    delivery = Enum.find(acceptance.gates, &(&1.id == :delivery_semantics))
    hardware = Enum.find(acceptance.gates, &(&1.id == :loop_and_ttl_hardware_validation))

    assert Enum.any?(routing_table.missing, &String.contains?(&1, "production routing table"))

    assert Enum.any?(
             route_selection.missing,
             &String.contains?(&1, "deterministic route selection")
           )

    assert Enum.any?(forwarding.missing, &String.contains?(&1, "live service"))
    assert Enum.any?(delivery.missing, &String.contains?(&1, "ACK, retry"))

    assert Enum.any?(
             hardware.missing,
             &String.contains?(&1, "Three or more physical participants")
           )
  end

  test "local inbox snapshot exposes routing acceptance without promoting routing" do
    snapshot = LocalInbox.new() |> LocalInbox.snapshot()

    assert %{routing_acceptance: acceptance} = snapshot
    assert acceptance.satisfied_count == 5
    assert acceptance.blocked_count == 5
    refute acceptance.routed_delivery_claim_allowed?
  end

  test "JSON snapshot preserves blocked routing claims" do
    snapshot = LocalRoutingAcceptance.json_snapshot([peer()])

    assert snapshot["boundary"] == "current_advert_only_non_routing_mode"
    assert snapshot["route_selection_claim_allowed?"] == false
    assert snapshot["forwarding_claim_allowed?"] == false
    assert snapshot["routed_delivery_claim_allowed?"] == false

    assert Enum.any?(
             snapshot["gates"],
             &(&1["id"] == "forwarding_service" and &1["status"] == "blocked")
           )
  end

  test "negative validation gate calls out fetch planning as non-routing evidence" do
    acceptance = LocalRoutingAcceptance.snapshot([peer()])
    gate = Enum.find(acceptance.gates, &(&1.id == :negative_routing_validation))

    assert Enum.any?(gate.evidence, &String.contains?(&1, "fetch-planning-as-routing"))
    assert Enum.any?(gate.evidence, &String.contains?(&1, "forwardable-candidate-as-forwarding"))
    assert :production_route_selection in gate.blocked_claims
    assert :live_forwarding_service in gate.blocked_claims
    assert :forwarding_intent_enqueued in gate.blocked_claims
  end
end
