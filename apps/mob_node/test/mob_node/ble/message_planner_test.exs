defmodule Mob.Node.BLE.MessagePlannerTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{MessageEnvelope, MessagePlanner, PeerCapabilities}
  alias Mob.Node.BLE.MessagePlanner.{BroadcastPlan, DirectedPlan}
  alias Mob.Node.BLE.PeerInventory.PeerSummary

  # ── fixture builders ────────────────────────────────────────────────────

  defp envelope(opts) do
    {:ok, e} =
      MessageEnvelope.build(
        Keyword.merge(
          [
            message_id: <<1::128>>,
            sender_peer_id: "mob-self",
            created_at: 0,
            ttl: 8,
            payload_type: "TX",
            payload: "hello"
          ],
          opts
        )
      )

    e
  end

  defp summary(overrides) do
    base = %PeerSummary{
      peer_id: nil,
      device_ids: ["AA:01"],
      display_name: "AA:01",
      identity_confidence: :unknown,
      identity_source: :none,
      capabilities: %PeerCapabilities{},
      presence: :active,
      first_seen_at: 0,
      last_seen_at: 100,
      last_rssi: -50,
      advertisement_seen_count: 1,
      collision_count: 0,
      last_conflicting_peer_id: nil,
      anonymous?: true,
      suspicious?: false
    }

    Enum.reduce(overrides, base, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp named_capable_summary(peer_id, opts \\ []) do
    summary(
      [
        peer_id: peer_id,
        display_name: peer_id,
        identity_confidence: :advertised,
        identity_source: :advertised_name,
        capabilities: %PeerCapabilities{
          protocol_version: 1,
          supports_replay_contract: true,
          supports_passive_presence: true,
          supports_churn: true
        },
        anonymous?: false
      ] ++ opts
    )
  end

  # ── directed ───────────────────────────────────────────────────────────

  describe "plan/3 — directed messages" do
    test "active named peer with sufficient caps and :advertised confidence is eligible" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0x07)
      peers = [named_capable_summary("meshx-alpha")]

      assert {:eligible, %DirectedPlan{} = plan} =
               MessagePlanner.plan(env, peers, now: 100)

      assert plan.envelope == env
      assert plan.recipient.peer_id == "meshx-alpha"
    end

    test "stale peer is rejected as :recipient_inactive" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0)
      peers = [named_capable_summary("meshx-alpha", last_seen_at: 0)]

      # now=20_000 puts last_seen 20s in the past → :stale under default policy.
      assert {:ineligible, :recipient_inactive} =
               MessagePlanner.plan(env, peers, now: 20_000)
    end

    test "expired peer is rejected as :recipient_inactive" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0)
      peers = [named_capable_summary("meshx-alpha", last_seen_at: 0)]

      assert {:ineligible, :recipient_inactive} =
               MessagePlanner.plan(env, peers, now: 100_000)
    end

    test "unknown recipient is rejected as :recipient_unknown" do
      env = envelope(recipient_peer_id: "ghost", capability_requirements: 0)
      peers = [named_capable_summary("meshx-alpha")]

      assert {:ineligible, :recipient_unknown} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "anonymous peer cannot be a directed recipient (peer_id is nil)" do
      env = envelope(recipient_peer_id: "AA:01", capability_requirements: 0)
      peers = [summary([])]

      assert {:ineligible, :recipient_unknown} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "capability requirements that the peer cannot satisfy → :capability_mismatch" do
      # Envelope demands bit 3 (supports_message_exchange), peer doesn't
      # advertise it.
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0x08)
      peers = [named_capable_summary("meshx-alpha")]

      assert {:ineligible, :capability_mismatch} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "zero capability_requirements always satisfies (no caps needed)" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0)
      # Peer with no advertised caps still satisfies the empty requirement.
      peers = [
        named_capable_summary("meshx-alpha", capabilities: %PeerCapabilities{})
      ]

      assert {:eligible, %DirectedPlan{}} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "low-confidence (:contested) recipient is rejected by default" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0)
      peers = [named_capable_summary("meshx-alpha", identity_confidence: :contested)]

      assert {:ineligible, :insufficient_identity_confidence} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "low-confidence recipient is accepted with allow_low_confidence: true" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0)
      peers = [named_capable_summary("meshx-alpha", identity_confidence: :contested)]

      assert {:eligible, %DirectedPlan{}} =
               MessagePlanner.plan(env, peers, now: 100, allow_low_confidence: true)
    end
  end

  # ── envelope-level rejection ────────────────────────────────────────────

  describe "plan/3 — envelope-level rejection" do
    test "ttl=0 is rejected as :ttl_exhausted before any peer is inspected" do
      env = envelope(recipient_peer_id: "meshx-alpha", ttl: 0)
      peers = [named_capable_summary("meshx-alpha")]

      assert {:ineligible, :ttl_exhausted} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "ttl=0 also fails for broadcast envelopes" do
      env = envelope(recipient_peer_id: nil, ttl: 0)
      peers = [named_capable_summary("meshx-alpha")]

      assert {:ineligible, :ttl_exhausted} =
               MessagePlanner.plan(env, peers, now: 100)
    end
  end

  # ── broadcast ──────────────────────────────────────────────────────────

  describe "plan/3 — broadcast messages" do
    test "broadcast returns deterministically-sorted active eligible peers" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0x04)

      peers = [
        named_capable_summary("meshx-charlie", last_seen_at: 300),
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200)
      ]

      assert {:eligible, %BroadcastPlan{candidates: c}} =
               MessagePlanner.plan(env, peers, now: 305)

      # Order: last_seen desc → charlie(300), bravo(200), alpha(100)
      assert Enum.map(c, & &1.peer_id) == ["meshx-charlie", "meshx-bravo", "meshx-alpha"]
    end

    test "ties on last_seen_at break by display_name ascending" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      peers = [
        named_capable_summary("meshx-bravo", last_seen_at: 100),
        named_capable_summary("meshx-alpha", last_seen_at: 100)
      ]

      assert {:eligible, %BroadcastPlan{candidates: c}} =
               MessagePlanner.plan(env, peers, now: 100)

      assert Enum.map(c, & &1.peer_id) == ["meshx-alpha", "meshx-bravo"]
    end

    test "broadcast excludes stale + expired peers" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      # Default policy: active window 10_000ms, stale window 30_000ms
      # (combined 40_000ms before expiration). At now=100_000:
      #   active: delta 500    → :active   (eligible)
      #   stale:  delta 20_000 → :stale    (excluded)
      #   expired: delta 99_999 → :expired (excluded)
      peers = [
        named_capable_summary("mob-active", last_seen_at: 99_500),
        named_capable_summary("mob-stale", last_seen_at: 80_000),
        named_capable_summary("mob-expired", last_seen_at: 1)
      ]

      assert {:eligible, %BroadcastPlan{candidates: c}} =
               MessagePlanner.plan(env, peers, now: 100_000)

      assert Enum.map(c, & &1.peer_id) == ["mob-active"]
    end

    test "broadcast with no eligible peers → :no_eligible_broadcast_peers" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0x08)

      # Peer is active and named, but doesn't advertise message_exchange.
      peers = [named_capable_summary("meshx-alpha")]

      assert {:ineligible, :no_eligible_broadcast_peers} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "broadcast with empty inventory → :no_eligible_broadcast_peers" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)
      assert {:ineligible, :no_eligible_broadcast_peers} = MessagePlanner.plan(env, [], now: 0)
    end

    test "broadcast excludes anonymous peers by default (low confidence)" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      peers = [
        # Anonymous BLE peripheral nearby, no MeshX caps either.
        summary([]),
        # Named peer who should be the only candidate.
        named_capable_summary("meshx-alpha")
      ]

      assert {:eligible, %BroadcastPlan{candidates: [%{peer_id: "meshx-alpha"}]}} =
               MessagePlanner.plan(env, peers, now: 100)
    end

    test "broadcast with allow_low_confidence: true includes contested peers" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      peers = [
        named_capable_summary("meshx-alpha", identity_confidence: :contested),
        named_capable_summary("meshx-bravo")
      ]

      assert {:eligible, %BroadcastPlan{candidates: c}} =
               MessagePlanner.plan(env, peers, now: 100, allow_low_confidence: true)

      assert MapSet.new(Enum.map(c, & &1.peer_id)) ==
               MapSet.new(["meshx-alpha", "meshx-bravo"])
    end
  end

  # ── determinism ────────────────────────────────────────────────────────

  describe "plan/3 — determinism" do
    test "same inputs always produce the same output" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0x07)

      peers = [
        named_capable_summary("meshx-charlie", last_seen_at: 300),
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200)
      ]

      assert MessagePlanner.plan(env, peers, now: 305) ==
               MessagePlanner.plan(env, peers, now: 305)
    end

    test "input list order does not affect output order (planner re-sorts)" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      peers_forward = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200)
      ]

      peers_reverse = Enum.reverse(peers_forward)

      assert MessagePlanner.plan(env, peers_forward, now: 250) ==
               MessagePlanner.plan(env, peers_reverse, now: 250)
    end
  end
end
