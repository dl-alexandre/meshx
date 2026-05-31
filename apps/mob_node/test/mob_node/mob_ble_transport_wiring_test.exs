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

  test "starts the runtime transport with the mob_ble bridge and round-trips a peer_up event" do
    {:ok, transport} =
      Mob.Routing.BLE.start_link(
        bridge: Mob.Ble.bridge_module(),
        bridge_opts: [local_name: "wiring-test", native?: false]
      )

    on_exit(fn -> if Process.alive?(transport), do: GenServer.stop(transport) end)

    state = :sys.get_state(transport)
    assert state.bridge_module == MobileBridge
    assert is_pid(state.bridge)

    # Drive a native-style JSON event into the inner bridge — proves the
    # whole chain: BridgeProtocol decode → MobileBridge forward →
    # Mob.Routing.BLE normalize → test pid receives canonical event.
    payload = ~s({"v":1,"event":"peer_up","peer_id":"wire-peer","metadata":{"rssi":-33}})
    send(state.bridge, {MobileBridge, :bridge_event, payload})

    assert_receive {:mob_routing, :ble, {:peer_up, peer}}, 200
    assert peer.id == "wire-peer"
  end
end
