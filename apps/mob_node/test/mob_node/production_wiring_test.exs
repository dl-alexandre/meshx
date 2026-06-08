defmodule Mob.Node.ProductionWiringTest do
  @moduledoc """
  Integration guardrails for production BLE + chat wiring.

  These tests exist because unit tests alone missed silent failures:
    * `:native_bridge` set but `:ble_adapter` left on `Noop` (UI never touched CoreBluetooth)
    * `Mob.Routing.BLE` started without `Router.attach_transport/3` (chat send was a no-op)
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias Mob.Node.BLE.Adapter
  alias Mob.Node.{BlePlatformConfig, BleTransport}
  alias Mob.Node.Chat.ChannelViewModel
  alias Mob.Runtime.Router

  setup do
    on_exit(fn ->
      Application.delete_env(:mob_node, :ble_adapter)
      Application.delete_env(:mob_node, :native_bridge)
      Application.delete_env(:mob_node, :ble_transport_pid)
      System.delete_env("MOB_BLE_TRANSPORT")
    end)

    Application.ensure_all_started(:mob_runtime)
    Router.reset()
    :ok
  end

  describe "BlePlatformConfig (regression: adapter env drift)" do
    test "apply_from_platform/2 sets both keys so Session uses the platform bridge" do
      :ok = BlePlatformConfig.apply_from_platform(:ios, true)

      assert Application.get_env(:mob_node, :native_bridge) == Mob.Node.NativeBridge.IOS
      assert Application.get_env(:mob_node, :ble_adapter) == Mob.Node.NativeBridge.IOS
      assert Adapter.configured() == Mob.Node.NativeBridge.IOS
    end
  end

  describe "BleTransport (regression: router not attached)" do
    test "start/1 attaches :ble to the runtime router" do
      System.put_env("MOB_BLE_TRANSPORT", "1")

      assert {:ok, transport_pid} =
               BleTransport.start(
                 local_name: "wiring-contract",
                 event_target: Router,
                 force?: true
               )

      assert BleTransport.attached?()

      assert %{adapter: Mob.Routing.BLE, pid: ^transport_pid} =
               :sys.get_state(Router).transports |> Map.fetch!(:ble)
    end

    test "chat broadcast fails when transport is not attached" do
      vm = start_supervised!({ChannelViewModel, channel: "#general", router: Router})

      assert {:error, {:broadcast_failed, :no_transports}} =
               ChannelViewModel.send_text(vm, "no transport")
    end
  end
end
