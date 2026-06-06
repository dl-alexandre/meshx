defmodule Mob.Node.MobBleTransportWiringTest do
  @moduledoc """
  Primary wiring test for the recommended production `mob_ble` path.

  Proves the end-to-end wire from `mob_node` through
  `Mob.Routing.BLE` into `Mob.Ble.MobileBridge` (the canonical impl of
  `Mob.Ble.Bridge`) works without device hardware.

  This is the canonical smoke test for `Mob.Node.App.maybe_start_mob_ble_transport/0`
  (now the default path post-Phase 2; opt-out with MOB_BLE_TRANSPORT=0).
  Uses the exact `bridge: Mob.Ble.bridge_module()` call shape, with `native?: false`
  to stay in pure Elixir for CI / host testing.
  """

  use ExUnit.Case, async: false

  alias Mob.Ble.MobileBridge
  alias Mob.Node.BleTransport
  alias Mob.Runtime.Router

  setup do
    Application.ensure_all_started(:mob_runtime)
    Router.reset()
    :ok
  end

  test "BleTransport.start attaches router (production contract)" do
    System.put_env("MOB_BLE_TRANSPORT", "1")

    assert {:ok, pid} = BleTransport.start(event_target: Router, force?: true)
    assert BleTransport.attached?()
    assert %{adapter: Mob.Routing.BLE, pid: ^pid} = :sys.get_state(Router).transports |> Map.fetch!(:ble)

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
  end

  test "starts the runtime transport with the mob_ble bridge and round-trips a peer_up event" do
    {:ok, transport} =
      Mob.Routing.BLE.start_link(
        bridge: Mob.Ble.bridge_module(),
        bridge_opts: [local_name: "wiring-test", native?: false, boot_native?: false],
        event_target: Router
      )

    :ok = Router.attach_transport(:ble, Mob.Routing.BLE, transport)
    :ok = Router.subscribe(self())

    on_exit(fn -> if Process.alive?(transport), do: GenServer.stop(transport) end)

    state = :sys.get_state(transport)
    assert state.bridge_module == MobileBridge
    assert is_pid(state.bridge)

    # Drive a normalized BLE event into the transport — proves Mob.Routing.BLE
    # forwards to the router, and router subscribers see runtime events.
    send(transport, {:ble_peer_up, "wire-peer", %{rssi: -33}})

    assert_receive {:mob_runtime, :peer_up, :ble, %{id: "wire-peer"}}, 500
  end
end
