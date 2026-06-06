defmodule Mob.Node.MeshStatusTest do
  use ExUnit.Case, async: true

  alias Mob.Node.MeshStatus

  setup do
    on_exit(fn ->
      Application.delete_env(:mob_node, :ble_transport_pid)
      Application.delete_env(:mob_node, :ble_adapter)
      Application.delete_env(:mob_node, :mesh_session_hint)
    end)

    :ok
  end

  defp wire_transport_and_bridge! do
    Application.put_env(:mob_node, :ble_transport_pid, self())
    Application.put_env(:mob_node, :ble_adapter, Mob.Node.NativeBridge.IOS)
  end

  describe "readiness/1" do
    test "not_ready when transport or bridge is missing" do
      r = MeshStatus.readiness(session: %{status: "Scanning", mode: :scan, peer_id: nil})
      assert r.state == :not_ready
      refute r.chat_enabled?
    end

    test "radio_off when session is waiting or stopped" do
      wire_transport_and_bridge!()

      r =
        MeshStatus.readiness(
          session: %{status: "Waiting for Bluetooth", mode: :scan, peer_id: nil}
        )

      assert r.state == :radio_off
      refute r.chat_enabled?
      assert r.detail =~ "Start Scanning"
    end

    test "listening when scanning or advertising" do
      wire_transport_and_bridge!()

      r = MeshStatus.readiness(session: %{status: "Scanning", mode: :scan, peer_id: nil})
      assert r.state == :listening
      assert r.chat_enabled?
      refute r.ready?
    end

    test "ready when peer is connected" do
      wire_transport_and_bridge!()

      r =
        MeshStatus.readiness(
          session: %{status: "Secure peer connected", mode: :scan, peer_id: "peer-1"}
        )

      assert r.state == :ready
      assert r.ready?
      assert r.chat_enabled?
      assert r.headline =~ "#general"
    end

    test "uses mesh_session_hint when session opt is omitted" do
      wire_transport_and_bridge!()
      :ok = MeshStatus.publish_session_hint(%{status: "Advertising", mode: :advertise, peer_id: nil})

      r = MeshStatus.readiness()
      assert r.state == :listening
    end
  end

  describe "ready_for_chat?/1" do
    test "enabled for listening and ready, not for radio_off" do
      wire_transport_and_bridge!()

      listening =
        MeshStatus.readiness(session: %{status: "Scanning", mode: :scan, peer_id: nil})

      assert MeshStatus.ready_for_chat?(listening)

      radio =
        MeshStatus.readiness(
          session: %{status: "Stopped", mode: :scan, peer_id: nil}
        )

      refute MeshStatus.ready_for_chat?(radio)
    end
  end
end