defmodule Mob.Node.BLE.AdapterTest do
  use ExUnit.Case, async: false

  alias Mob.Node.BLE.Adapter

  setup do
    on_exit(fn ->
      Application.delete_env(:mob_node, :ble_adapter)
      Application.delete_env(:mob_node, :native_bridge)
    end)

    :ok
  end

  test "configured/0 prefers :ble_adapter over :native_bridge" do
    Application.put_env(:mob_node, :native_bridge, Mob.Node.NativeBridge.IOS)
    Application.put_env(:mob_node, :ble_adapter, Mob.Node.NativeBridge.Noop)

    assert Adapter.configured() == Mob.Node.NativeBridge.Noop
  end

  test "configured/0 falls back to :native_bridge when :ble_adapter is unset" do
    Application.put_env(:mob_node, :native_bridge, Mob.Node.NativeBridge.IOS)
    Application.delete_env(:mob_node, :ble_adapter)

    assert Adapter.configured() == Mob.Node.NativeBridge.IOS
  end

  test "regression: BlePlatformConfig must set :ble_adapter (Session reads this key)" do
    alias Mob.Node.BlePlatformConfig

    Application.delete_env(:mob_node, :ble_adapter)
    Application.delete_env(:mob_node, :native_bridge)

    :ok = BlePlatformConfig.apply_from_platform(:ios, true)

    assert Application.get_env(:mob_node, :ble_adapter) == Mob.Node.NativeBridge.IOS
    assert Adapter.configured() == Mob.Node.NativeBridge.IOS
  end
end
