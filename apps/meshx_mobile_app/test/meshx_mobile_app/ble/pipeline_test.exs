defmodule MeshxMobileApp.BLE.PipelineTest do
  @moduledoc """
  End-to-end offline send pipeline:

      MessageEnvelope.build
        → MessagePlanner.plan
        → AttemptLedger.record
        → Transport.Simulated.dispatch (or Dispatcher.DryRun.dispatch)
        → [%AttemptOutcome{}]

  No real BLE, no processes, no clocks. Every stage takes its clock
  and id functions as inputs, so the entire pipeline is byte-deterministic.
  """

  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    AttemptLedger,
    Dispatcher,
    MessageEnvelope,
    MessagePlanner,
    PeerCapabilities,
    Transport
  }

  alias MeshxMobileApp.BLE.PeerInventory.PeerSummary

  defp envelope(opts) do
    {:ok, e} =
      MessageEnvelope.build(
        Keyword.merge(
          [
            message_id: <<7::128>>,
            sender_peer_id: "meshx-self",
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

  defp named_capable_summary(peer_id, overrides \\ []) do
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

    Enum.reduce(overrides, base, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  defp id_fun, do: fn i -> "att-#{i}" end

  describe "directed pipeline → simulated transport" do
    test "delivered outcome when peer is active and capable" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0x07)
      inventory = [named_capable_summary("meshx-alpha")]

      outcomes = pipeline(env, inventory, now: 100)

      assert [outcome] = outcomes
      assert outcome.kind == :delivered_simulated
      assert outcome.adapter == :simulated
      assert outcome.attempt_id == "att-0"
      assert outcome.message_id == env.message_id
      assert outcome.target_peer_id == "meshx-alpha"
      assert outcome.target_device_ids == ["AA:meshx-alpha"]
    end

    test "ineligible at the planner stage short-circuits before dispatch" do
      env = envelope(recipient_peer_id: "ghost")
      inventory = [named_capable_summary("meshx-alpha")]

      planner_outcome = MessagePlanner.plan(env, inventory, now: 100)

      assert {:ineligible, :recipient_unknown} = planner_outcome
      # AttemptLedger surfaces the planner reason; dispatcher is never
      # reached because there are no attempts to dispatch.
      assert {:error, :recipient_unknown} =
               AttemptLedger.record(planner_outcome,
                 planned_at: 100,
                 id_fun: id_fun()
               )
    end

    test "per-peer failure surfaces as :failed_simulated end-to-end" do
      env = envelope(recipient_peer_id: "meshx-alpha", capability_requirements: 0)
      inventory = [named_capable_summary("meshx-alpha")]

      outcomes =
        pipeline(env, inventory,
          now: 100,
          peer_failures: %{"meshx-alpha" => :gatt_write_failed}
        )

      assert [outcome] = outcomes
      assert outcome.kind == :failed_simulated
      assert outcome.reason == :gatt_write_failed
    end
  end

  describe "broadcast pipeline → simulated transport" do
    test "fanout produces one outcome per candidate, all delivered" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      inventory = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200),
        named_capable_summary("meshx-charlie", last_seen_at: 300)
      ]

      outcomes = pipeline(env, inventory, now: 305)

      assert length(outcomes) == 3
      assert Enum.all?(outcomes, &(&1.kind == :delivered_simulated))
      # Planner sorts last_seen desc; outcomes inherit that order.
      assert Enum.map(outcomes, & &1.target_peer_id) ==
               ["meshx-charlie", "meshx-bravo", "meshx-alpha"]

      assert Enum.map(outcomes, & &1.attempt_id) == ["att-0", "att-1", "att-2"]
    end

    test "mixed broadcast outcomes: one delivered, one failed, one skipped" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      inventory = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200),
        named_capable_summary("meshx-charlie", last_seen_at: 300)
      ]

      outcomes =
        pipeline(env, inventory,
          now: 305,
          peer_failures: %{"meshx-bravo" => :timeout},
          skip?: fn a -> a.target_peer_id == "meshx-alpha" end
        )

      by_peer = Map.new(outcomes, &{&1.target_peer_id, &1})

      assert by_peer["meshx-charlie"].kind == :delivered_simulated
      assert by_peer["meshx-bravo"].kind == :failed_simulated
      assert by_peer["meshx-bravo"].reason == :timeout
      assert by_peer["meshx-alpha"].kind == :skipped
      assert by_peer["meshx-alpha"].reason == :skip_predicate
    end

    test "transport unavailable: every broadcast candidate fails the same way" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      inventory = [
        named_capable_summary("meshx-alpha"),
        named_capable_summary("meshx-bravo")
      ]

      outcomes = pipeline(env, inventory, now: 200, transport_unavailable: true)

      assert length(outcomes) == 2
      assert Enum.all?(outcomes, &(&1.kind == :failed_simulated))
      assert Enum.all?(outcomes, &(&1.reason == :transport_unavailable))
    end
  end

  describe "dry-run pipeline" do
    test "every eligible attempt becomes :would_dispatch and nothing else" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0)

      inventory = [
        named_capable_summary("meshx-alpha"),
        named_capable_summary("meshx-bravo")
      ]

      planner_outcome = MessagePlanner.plan(env, inventory, now: 100)
      {:ok, attempts} = AttemptLedger.record(planner_outcome, planned_at: 100, id_fun: id_fun())
      outcomes = Dispatcher.DryRun.dispatch(attempts, outcome_at: 100)

      assert length(outcomes) == 2
      assert Enum.all?(outcomes, &(&1.kind == :would_dispatch))
      assert Enum.all?(outcomes, &(&1.adapter == :dry_run))
      assert Enum.all?(outcomes, &(&1.reason == nil))
    end
  end

  describe "full-pipeline determinism" do
    test "envelope → outcomes is byte-deterministic across two runs" do
      env = envelope(recipient_peer_id: nil, capability_requirements: 0x07)

      inventory = [
        named_capable_summary("meshx-alpha", last_seen_at: 100),
        named_capable_summary("meshx-bravo", last_seen_at: 200)
      ]

      assert pipeline(env, inventory, now: 250) == pipeline(env, inventory, now: 250)
    end
  end

  # ── helper: full pipeline ───────────────────────────────────────────────

  defp pipeline(env, inventory, opts) do
    now = Keyword.fetch!(opts, :now)

    sim_opts =
      opts
      |> Keyword.take([:transport_unavailable, :peer_failures, :skip?])
      |> Keyword.put(:outcome_at, now)

    planner_outcome = MessagePlanner.plan(env, inventory, now: now)
    {:ok, attempts} = AttemptLedger.record(planner_outcome, planned_at: now, id_fun: id_fun())
    Transport.Simulated.dispatch(attempts, sim_opts)
  end
end
