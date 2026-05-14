defmodule MeshxMobileApp.BLE.LifecycleTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.Lifecycle

  test "valid_state? recognizes the closed set" do
    for s <- Lifecycle.states(), do: assert(Lifecycle.valid_state?(s))
    refute Lifecycle.valid_state?(:nope)
  end

  test "permitted transitions" do
    assert {:ok, :scanning} = Lifecycle.transition(:starting, :scanning)
    assert {:ok, :advertising} = Lifecycle.transition(:starting, :advertising)

    assert {:ok, :scanning_and_advertising} =
             Lifecycle.transition(:scanning, :scanning_and_advertising)

    assert {:ok, :stopping} = Lifecycle.transition(:scanning, :stopping)
    assert {:ok, :idle} = Lifecycle.transition(:stopping, :idle)
  end

  test "error is reachable from anywhere" do
    for s <- Lifecycle.states() do
      assert {:ok, :error} = Lifecycle.transition(s, :error)
    end
  end

  test "invalid transitions are rejected" do
    assert {:error, {:invalid_transition, :idle, :scanning}} =
             Lifecycle.transition(:idle, :scanning)

    assert {:error, {:invalid_transition, :idle, :advertising}} =
             Lifecycle.transition(:idle, :advertising)
  end

  test "same-state transitions are allowed (idempotency)" do
    assert {:ok, :scanning} = Lifecycle.transition(:scanning, :scanning)
  end
end
