defmodule Mob.Node.BLE.Dispatcher.DryRunTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.AttemptLedger.Attempt
  alias Mob.Node.BLE.Dispatcher.DryRun

  defp attempt(opts) do
    base = %Attempt{
      attempt_id: "att-0",
      message_id: <<1::128>>,
      plan_type: :directed,
      target_peer_id: "meshx-alpha",
      target_device_ids: ["AA:01"],
      eligibility_snapshot: %{},
      planned_at: 100,
      status: :planned
    }

    Enum.reduce(opts, base, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  describe "dispatch/2" do
    test "valid attempt produces :would_dispatch with provenance fields preserved" do
      [outcome] = DryRun.dispatch([attempt([])], outcome_at: 200)

      assert outcome.kind == :would_dispatch
      assert outcome.reason == nil
      assert outcome.adapter == :dry_run
      assert outcome.attempt_id == "att-0"
      assert outcome.message_id == <<1::128>>
      assert outcome.target_peer_id == "meshx-alpha"
      assert outcome.target_device_ids == ["AA:01"]
      assert outcome.outcome_at == 200
    end

    test "empty target_peer_id → :invalid_attempt" do
      [outcome] = DryRun.dispatch([attempt(target_peer_id: "")], outcome_at: 200)
      assert outcome.kind == :invalid_attempt
      assert outcome.reason == :validation
    end

    test "empty target_device_ids → :invalid_attempt" do
      [outcome] = DryRun.dispatch([attempt(target_device_ids: [])], outcome_at: 200)
      assert outcome.kind == :invalid_attempt
    end

    test "empty attempt_id → :invalid_attempt" do
      [outcome] = DryRun.dispatch([attempt(attempt_id: "")], outcome_at: 200)
      assert outcome.kind == :invalid_attempt
    end

    test "skip? predicate produces :skipped with :skip_predicate reason" do
      skip = fn a -> a.target_peer_id == "meshx-alpha" end
      [outcome] = DryRun.dispatch([attempt([])], outcome_at: 200, skip?: skip)
      assert outcome.kind == :skipped
      assert outcome.reason == :skip_predicate
    end

    test "skip? predicate is evaluated AFTER validation" do
      # Invalid attempt should still surface as :invalid_attempt even
      # if the skip predicate would also have matched it.
      always_skip = fn _ -> true end

      [outcome] =
        DryRun.dispatch([attempt(target_peer_id: "")], outcome_at: 0, skip?: always_skip)

      assert outcome.kind == :invalid_attempt
    end

    test "produces one outcome per attempt, preserving input order" do
      attempts = [
        attempt(attempt_id: "a-0", target_peer_id: "meshx-alpha"),
        attempt(attempt_id: "a-1", target_peer_id: "meshx-bravo"),
        attempt(attempt_id: "a-2", target_peer_id: "meshx-charlie")
      ]

      outcomes = DryRun.dispatch(attempts, outcome_at: 0)
      assert length(outcomes) == 3
      assert Enum.map(outcomes, & &1.attempt_id) == ["a-0", "a-1", "a-2"]
    end

    test "is deterministic: same inputs → identical outputs" do
      attempts = [attempt([])]
      assert DryRun.dispatch(attempts, outcome_at: 5) == DryRun.dispatch(attempts, outcome_at: 5)
    end
  end
end
