defmodule MeshxMobileApp.BLE.LocalRoutingNegativeValidationTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.LocalRoutingNegativeValidation

  test "snapshot blocks routing, forwarding, and delivery claims" do
    snapshot = LocalRoutingNegativeValidation.snapshot()

    assert snapshot.validation_version == 1
    assert snapshot.boundary == :current_advert_only_non_routing_mode
    assert snapshot.case_count == 7
    refute snapshot.route_selection_claims_allowed?
    refute snapshot.forwarding_claims_allowed?
    refute snapshot.delivery_claims_allowed?
  end

  test "peer inventory cannot be treated as a routing table" do
    snapshot = LocalRoutingNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :peer_inventory_as_route_table))

    assert validation.input == :passive_peer_inventory
    assert validation.expected_decision == :observation_only
    assert :route_table_available in validation.blocked_claims
    assert :next_hop_reachability_state in validation.required_before_allowed
  end

  test "stale or unreachable next hops are rejected until route selection exists" do
    snapshot = LocalRoutingNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :stale_or_unreachable_next_hop))

    assert validation.expected_decision == :route_rejected
    assert :route_selection_available in validation.blocked_claims
    assert :stale_route_rejection in validation.required_before_allowed
    assert :unreachable_peer_handling in validation.required_before_allowed
  end

  test "forwardable candidates do not prove forwarding intents or delivery" do
    snapshot = LocalRoutingNegativeValidation.snapshot()

    validation =
      Enum.find(snapshot.cases, &(&1.id == :forwardable_candidate_as_forwarding_intent))

    assert validation.input == :local_routing_table_forwardable_candidate
    assert validation.expected_decision == :candidate_filter_only
    assert :live_forwarding_service in validation.blocked_claims
    assert :forwarding_intent_enqueued in validation.blocked_claims
    assert :routed_delivery in validation.blocked_claims
    assert :outbound_forwarding_intent_ledger in validation.required_before_allowed
    assert Enum.any?(validation.notes, &String.contains?(&1, "no local observation blockers"))
  end

  test "replay gossip and one-hop hardware do not satisfy multi-hop routing" do
    snapshot = LocalRoutingNegativeValidation.snapshot()
    replay = Enum.find(snapshot.cases, &(&1.id == :advert_gossip_replay_as_routing))
    one_hop = Enum.find(snapshot.cases, &(&1.id == :two_device_one_hop_as_multi_hop))

    assert replay.expected_decision == :simulation_only
    assert one_hop.expected_decision == :one_hop_observation_only
    assert :multi_hop_hardware_routing in replay.blocked_claims
    assert :multi_hop_hardware_routing in one_hop.blocked_claims
    assert :origin_relay_observer_logs in replay.required_before_allowed
    assert :three_or_more_physical_participants in one_hop.required_before_allowed
  end

  test "beacon fetch planning cannot be treated as route selection or forwarding" do
    snapshot = LocalRoutingNegativeValidation.snapshot()
    validation = Enum.find(snapshot.cases, &(&1.id == :beacon_fetch_planning_as_routing))

    assert validation.input == :beacon_fetch_candidate_plan
    assert validation.expected_decision == :fetch_intent_only
    assert :production_route_selection in validation.blocked_claims
    assert :live_forwarding_service in validation.blocked_claims
    assert :delivery_semantics_policy in validation.required_before_allowed
    assert Enum.any?(validation.notes, &String.contains?(&1, "request intents"))
  end

  test "json snapshot is machine readable" do
    snapshot = LocalRoutingNegativeValidation.json_snapshot()

    assert snapshot["validation_version"] == 1
    assert snapshot["delivery_claims_allowed?"] == false

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "missing_ack_retry_policy" and
                 &1["expected_decision"] == "delivery_claim_rejected")
           )

    assert Enum.any?(
             snapshot["cases"],
             &(&1["id"] == "forwardable_candidate_as_forwarding_intent" and
                 &1["expected_decision"] == "candidate_filter_only")
           )
  end
end
