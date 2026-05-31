defmodule Mob.Node.BLE.AttemptLedgerTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    AttemptLedger,
    MessageEnvelope,
    MessagePlanner,
    PeerCapabilities
  }

  alias Mob.Node.BLE.AttemptLedger.Attempt
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
            payload: "hi"
          ],
          opts
        )
      )

    e
  end

  defp named_capable_summary(peer_id, opts \\ []) do
    base = %PeerSummary{
      peer_id: peer_id,
      device_ids: ["AA:#{peer_id}"],
      display_name: peer_id,
      identity_confidence: :advertised,
      identity_source: :advertised_name,
      capabilities: %PeerCapabilities{
        protocol_version: 1,
        supports_replay_contract: true,
        supports_passive_presence: true,
        supports_churn: true
      },
      presence: :active,
      first_seen_at: 0,
      last_seen_at: 100,
      last_rssi: -50,
      advertisement_seen_count: 1,
      collision_count: 0,
      last_conflicting_peer_id: nil,
      anonymous?: false,
      suspicious?: false
    }

    Enum.reduce(opts, base, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp deterministic_id_fun, do: fn i -> "attempt-#{i}" end

  # ── directed ───────────────────────────────────────────────────────────

  describe "record/2 — directed plan" do
    test "produces exactly one :planned attempt with all fields populated" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0x07)
      peers = [named_capable_summary("meshx-alpha")]

      outcome = MessagePlanner.plan(env, peers, now: 100)

      assert {:ok, [%Attempt{} = a]} =
               AttemptLedger.record(outcome,
                 planned_at: 1_000,
                 id_fun: deterministic_id_fun()
               )

      assert a.attempt_id == "attempt-0"
      assert a.message_id == env.message_id
      assert a.plan_type == :directed
      assert a.target_peer_id == "meshx-alpha"
      assert a.target_device_ids == ["AA:meshx-alpha"]
      assert a.eligibility_snapshot == hd(peers)
      assert a.planned_at == 1_000
      assert a.status == :planned
    end

    test "eligibility_snapshot captures the recipient summary at planning time" do
      env = envelope(recipient_peer_id: "meshx-alpha")

      snapshot =
        named_capable_summary("meshx-alpha",
          last_rssi: -42,
          advertisement_seen_count: 17
        )

      outcome = MessagePlanner.plan(env, [snapshot], now: 100)

      assert {:ok, [%Attempt{eligibility_snapshot: ^snapshot}]} =
               AttemptLedger.record(outcome,
                 planned_at: 999,
                 id_fun: deterministic_id_fun()
               )
    end
  end

  # ── broadcast fanout ────────────────────────────────────────────────────

  describe "record/2 — broadcast plan" do
    test "produces one attempt per candidate, preserving the planner's order" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      peers = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200),
        named_capable_summary("meshx-charlie", last_seen_at: 300)
      ]

      outcome = MessagePlanner.plan(env, peers, now: 305)

      assert {:ok, attempts} =
               AttemptLedger.record(outcome,
                 planned_at: 1_000,
                 id_fun: deterministic_id_fun()
               )

      # Planner sorts last_seen desc: charlie, bravo, alpha. Ledger
      # must preserve that order.
      assert Enum.map(attempts, & &1.target_peer_id) ==
               ["meshx-charlie", "meshx-bravo", "meshx-alpha"]

      assert Enum.map(attempts, & &1.attempt_id) == ["attempt-0", "attempt-1", "attempt-2"]
      assert Enum.all?(attempts, &(&1.plan_type == :broadcast))
      assert Enum.all?(attempts, &(&1.status == :planned))
      assert Enum.all?(attempts, &(&1.message_id == env.message_id))
    end

    test "each attempt's eligibility_snapshot points at its own candidate" do
      env = envelope(recipient_peer_id: nil)

      a = named_capable_summary("meshx-alpha", last_seen_at: 100)
      b = named_capable_summary("meshx-bravo", last_seen_at: 200)

      outcome = MessagePlanner.plan(env, [a, b], now: 250)

      assert {:ok, [att_b, att_a]} =
               AttemptLedger.record(outcome,
                 planned_at: 1_000,
                 id_fun: deterministic_id_fun()
               )

      # Last_seen desc → bravo first.
      assert att_b.target_peer_id == "meshx-bravo"
      assert att_b.eligibility_snapshot == b
      assert att_a.target_peer_id == "meshx-alpha"
      assert att_a.eligibility_snapshot == a
    end
  end

  # ── ineligible ─────────────────────────────────────────────────────────

  describe "record/2 — ineligible planner result" do
    test "passes the planner's reason through verbatim" do
      env = envelope(recipient_peer_id: "ghost")
      peers = [named_capable_summary("meshx-alpha")]

      outcome = MessagePlanner.plan(env, peers, now: 100)
      assert outcome == {:ineligible, :recipient_unknown}

      assert {:error, :recipient_unknown} =
               AttemptLedger.record(outcome, planned_at: 0, id_fun: deterministic_id_fun())
    end

    test "ineligible broadcast surfaces :no_eligible_broadcast_peers" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0x08)
      peers = [named_capable_summary("meshx-alpha")]

      outcome = MessagePlanner.plan(env, peers, now: 100)

      assert {:error, :no_eligible_broadcast_peers} =
               AttemptLedger.record(outcome, planned_at: 0, id_fun: deterministic_id_fun())
    end

    test "ttl_exhausted at the planner level surfaces unchanged" do
      env = envelope(recipient_peer_id: "meshx-alpha", ttl: 0)
      peers = [named_capable_summary("meshx-alpha")]

      outcome = MessagePlanner.plan(env, peers, now: 100)

      assert {:error, :ttl_exhausted} =
               AttemptLedger.record(outcome, planned_at: 0, id_fun: deterministic_id_fun())
    end
  end

  # ── determinism ────────────────────────────────────────────────────────

  describe "record/2 — determinism" do
    test "identical planner outcome + identical id_fun produces identical attempts" do
      env = envelope(recipient_peer_id: nil)

      peers = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200)
      ]

      outcome = MessagePlanner.plan(env, peers, now: 250)

      assert AttemptLedger.record(outcome, planned_at: 1_000, id_fun: deterministic_id_fun()) ==
               AttemptLedger.record(outcome, planned_at: 1_000, id_fun: deterministic_id_fun())
    end

    test "default random id_fun produces unique attempt_ids per call" do
      env = envelope(recipient_peer_id: nil)
      peers = [named_capable_summary("meshx-alpha")]
      outcome = MessagePlanner.plan(env, peers, now: 100)

      assert {:ok, [a1]} = AttemptLedger.record(outcome, planned_at: 0)
      assert {:ok, [a2]} = AttemptLedger.record(outcome, planned_at: 0)
      refute a1.attempt_id == a2.attempt_id
      # Sanity: default id is 16 lowercase hex chars (8 bytes encoded).
      assert byte_size(a1.attempt_id) == 16
      assert a1.attempt_id =~ ~r/^[0-9a-f]{16}$/
    end

    test "broadcast attempt_ids are unique within a single call when id_fun varies by index" do
      env = envelope(recipient_peer_id: nil)

      peers = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200),
        named_capable_summary("meshx-charlie", last_seen_at: 300)
      ]

      outcome = MessagePlanner.plan(env, peers, now: 305)

      assert {:ok, attempts} =
               AttemptLedger.record(outcome,
                 planned_at: 1_000,
                 id_fun: deterministic_id_fun()
               )

      ids = Enum.map(attempts, & &1.attempt_id)
      assert ids == Enum.uniq(ids)
      assert length(ids) == 3
    end
  end
end
