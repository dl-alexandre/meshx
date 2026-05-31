defmodule Mob.Node.BLE.Dispatcher.AndroidTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.AttemptLedger.Attempt
  alias Mob.Node.BLE.Dispatcher.Android

  defp attempt(opts \\ []) do
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

  describe "dispatch/2 — adapter identity" do
    test "every outcome carries adapter :ble_android" do
      send_ok = fn _a -> {:ok, :ack} end
      [out] = Android.dispatch([attempt()], outcome_at: 200, native_send: send_ok)
      assert out.adapter == :ble_android
    end
  end

  describe "dispatch/2 — native bridge ok/error" do
    test "{:ok, _} from the native bridge → :dispatched, reason nil" do
      send_ok = fn _a -> {:ok, %{written_bytes: 42}} end
      [out] = Android.dispatch([attempt()], outcome_at: 200, native_send: send_ok)

      assert out.kind == :dispatched
      assert out.reason == nil
      assert out.attempt_id == "att-0"
      assert out.message_id == <<1::128>>
      assert out.target_peer_id == "meshx-alpha"
      assert out.target_device_ids == ["AA:01"]
      assert out.outcome_at == 200
    end

    test "{:error, reason} from the native bridge → :failed with reason" do
      send_fail = fn _a -> {:error, :gatt_write_failed} end
      [out] = Android.dispatch([attempt()], outcome_at: 200, native_send: send_fail)

      assert out.kind == :failed
      assert out.reason == :gatt_write_failed
    end

    test "default native_send returns :native_bridge_unavailable on hosts without the bridge" do
      [out] = Android.dispatch([attempt()], outcome_at: 200)
      assert out.kind == :failed
      assert out.reason == :native_bridge_unavailable
    end

    test "never produces :delivered_simulated or :failed_simulated — those are reserved" do
      send_ok = fn _a -> {:ok, :ack} end
      send_fail = fn _a -> {:error, :anything} end

      [ok_out] = Android.dispatch([attempt()], outcome_at: 0, native_send: send_ok)
      [fail_out] = Android.dispatch([attempt()], outcome_at: 0, native_send: send_fail)

      refute ok_out.kind in [:delivered_simulated, :failed_simulated]
      refute fail_out.kind in [:delivered_simulated, :failed_simulated]
    end
  end

  describe "dispatch/2 — validation + skip + dry_run" do
    test "empty target_peer_id → :invalid_attempt without invoking the bridge" do
      invoked = :counters.new(1, [])

      counting_send = fn _a ->
        :counters.add(invoked, 1, 1)
        {:ok, :ack}
      end

      [out] =
        Android.dispatch([attempt(target_peer_id: "")],
          outcome_at: 0,
          native_send: counting_send
        )

      assert out.kind == :invalid_attempt
      assert out.reason == :validation
      assert :counters.get(invoked, 1) == 0
    end

    test "skip? predicate → :skipped without invoking the bridge" do
      invoked = :counters.new(1, [])

      counting_send = fn _a ->
        :counters.add(invoked, 1, 1)
        {:ok, :ack}
      end

      [out] =
        Android.dispatch([attempt()],
          outcome_at: 0,
          native_send: counting_send,
          skip?: fn _ -> true end
        )

      assert out.kind == :skipped
      assert out.reason == :skip_predicate
      assert :counters.get(invoked, 1) == 0
    end

    test "dry_run: true → :would_dispatch without invoking the bridge" do
      invoked = :counters.new(1, [])

      counting_send = fn _a ->
        :counters.add(invoked, 1, 1)
        {:ok, :ack}
      end

      [out] =
        Android.dispatch([attempt()],
          outcome_at: 0,
          native_send: counting_send,
          dry_run: true
        )

      assert out.kind == :would_dispatch
      assert out.adapter == :ble_android
      assert :counters.get(invoked, 1) == 0
    end

    test "validation runs before skip? before dry_run before bridge" do
      # Invalid attempt with skip? and dry_run both set: still
      # surfaces as :invalid_attempt.
      [out] =
        Android.dispatch([attempt(target_peer_id: "")],
          outcome_at: 0,
          skip?: fn _ -> true end,
          dry_run: true
        )

      assert out.kind == :invalid_attempt
    end
  end

  describe "dispatch/2 — fanout + ordering" do
    test "one outcome per attempt, in input order, each invoking the bridge once" do
      attempts =
        for id <- ["a", "b", "c"] do
          attempt(attempt_id: "att-#{id}", target_peer_id: "mob-#{id}")
        end

      invoked = :counters.new(1, [])

      counting_send = fn a ->
        :counters.add(invoked, 1, 1)
        # Pretend bravo fails so the fanout has mixed outcomes.
        if a.target_peer_id == "mob-b", do: {:error, :gatt_busy}, else: {:ok, :ack}
      end

      outcomes = Android.dispatch(attempts, outcome_at: 100, native_send: counting_send)

      assert Enum.map(outcomes, & &1.attempt_id) == ["att-a", "att-b", "att-c"]
      assert Enum.at(outcomes, 0).kind == :dispatched
      assert Enum.at(outcomes, 1).kind == :failed
      assert Enum.at(outcomes, 1).reason == :gatt_busy
      assert Enum.at(outcomes, 2).kind == :dispatched
      assert :counters.get(invoked, 1) == 3
    end
  end

  describe "dispatch/2 — determinism" do
    test "same inputs (incl. native_send) produce identical outcomes" do
      send = fn _ -> {:ok, :ack} end
      attempts = [attempt()]
      opts = [outcome_at: 200, native_send: send]
      assert Android.dispatch(attempts, opts) == Android.dispatch(attempts, opts)
    end
  end
end
