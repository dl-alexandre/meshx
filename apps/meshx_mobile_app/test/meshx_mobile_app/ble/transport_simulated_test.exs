defmodule MeshxMobileApp.BLE.Transport.SimulatedTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.AttemptLedger.Attempt
  alias MeshxMobileApp.BLE.Transport.Simulated

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

  describe "dispatch/2 — success path" do
    test "valid attempt → :delivered_simulated with adapter :simulated" do
      [outcome] = Simulated.dispatch([attempt([])], outcome_at: 200)

      assert outcome.kind == :delivered_simulated
      assert outcome.reason == nil
      assert outcome.adapter == :simulated
      assert outcome.attempt_id == "att-0"
      assert outcome.target_peer_id == "meshx-alpha"
      assert outcome.outcome_at == 200
    end

    test "broadcast fanout: every attempt is delivered when no failures configured" do
      attempts =
        for id <- ["alpha", "bravo", "charlie"] do
          attempt(
            attempt_id: "att-#{id}",
            target_peer_id: "meshx-#{id}",
            target_device_ids: ["AA:#{id}"],
            plan_type: :broadcast
          )
        end

      outcomes = Simulated.dispatch(attempts, outcome_at: 200)
      assert length(outcomes) == 3
      assert Enum.all?(outcomes, &(&1.kind == :delivered_simulated))

      assert Enum.map(outcomes, & &1.target_peer_id) ==
               ["meshx-alpha", "meshx-bravo", "meshx-charlie"]
    end
  end

  describe "dispatch/2 — transport unavailable" do
    test "every attempt fails with :transport_unavailable when adapter is off" do
      attempts = [
        attempt(target_peer_id: "meshx-alpha"),
        attempt(target_peer_id: "meshx-bravo")
      ]

      outcomes = Simulated.dispatch(attempts, outcome_at: 200, transport_unavailable: true)
      assert length(outcomes) == 2
      assert Enum.all?(outcomes, &(&1.kind == :failed_simulated))
      assert Enum.all?(outcomes, &(&1.reason == :transport_unavailable))
    end

    test "transport_unavailable takes priority over peer_failures" do
      # Configured per-peer failure shouldn't matter when the whole
      # transport is down.
      [outcome] =
        Simulated.dispatch([attempt([])],
          outcome_at: 0,
          transport_unavailable: true,
          peer_failures: %{"meshx-alpha" => :gatt_error}
        )

      assert outcome.kind == :failed_simulated
      assert outcome.reason == :transport_unavailable
    end
  end

  describe "dispatch/2 — per-peer failures" do
    test "peers in peer_failures → :failed_simulated with the supplied reason" do
      attempts = [
        attempt(attempt_id: "a-0", target_peer_id: "meshx-alpha"),
        attempt(attempt_id: "a-1", target_peer_id: "meshx-bravo")
      ]

      outcomes =
        Simulated.dispatch(attempts,
          outcome_at: 200,
          peer_failures: %{"meshx-bravo" => :gatt_write_failed}
        )

      [alpha_outcome, bravo_outcome] = outcomes
      assert alpha_outcome.kind == :delivered_simulated
      assert bravo_outcome.kind == :failed_simulated
      assert bravo_outcome.reason == :gatt_write_failed
    end
  end

  describe "dispatch/2 — invalid attempt + skip" do
    test "validation rejects empty target_peer_id even on the success path" do
      [outcome] = Simulated.dispatch([attempt(target_peer_id: "")], outcome_at: 0)
      assert outcome.kind == :invalid_attempt
      assert outcome.reason == :validation
    end

    test "skip? predicate suppresses delivery with :skipped" do
      skip = fn a -> a.target_peer_id == "meshx-bravo" end

      attempts = [
        attempt(target_peer_id: "meshx-alpha"),
        attempt(attempt_id: "a-1", target_peer_id: "meshx-bravo")
      ]

      outcomes = Simulated.dispatch(attempts, outcome_at: 0, skip?: skip)
      assert Enum.at(outcomes, 0).kind == :delivered_simulated
      assert Enum.at(outcomes, 1).kind == :skipped
      assert Enum.at(outcomes, 1).reason == :skip_predicate
    end
  end

  describe "dispatch/2 — determinism" do
    test "same inputs always produce the same output" do
      attempts = [
        attempt(target_peer_id: "meshx-alpha"),
        attempt(attempt_id: "a-1", target_peer_id: "meshx-bravo")
      ]

      opts = [outcome_at: 200, peer_failures: %{"meshx-bravo" => :timeout}]
      assert Simulated.dispatch(attempts, opts) == Simulated.dispatch(attempts, opts)
    end
  end
end
