defmodule Mob.Node.Chat.MeshIntegrationTest do
  @moduledoc """
  End-to-end chat over the in-process mesh router + BLE transport adapter.

  Complements `Chat.E2ETCPTest` (TCP wire) and unit tests (isolated modules).
  Would have caught: router broadcast with zero transports, and missing
  ingress from BLE gossip into channel subscribers.
  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias Mob.Node.BLE.Events.ReceivedMessage
  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.{ChannelViewModel, Composer, RouterIngress}
  alias Mob.Node.TestSupport.RecordingBleBridge
  alias Mob.Protocol.{Codec, Packet}
  alias Mob.Runtime.Router

  setup do
    Application.ensure_all_started(:mob_store)
    ensure_db_started()
    Application.ensure_all_started(:mob_runtime)
    Router.reset()
    Router.subscribe(self())

    System.put_env("MOB_BLE_TRANSPORT", "1")

    {:ok, bridge} = RecordingBleBridge.start_link([])

    {:ok, transport} =
      Mob.Routing.BLE.start_link(
        bridge: RecordingBleBridge,
        bridge_opts: [event_target: self()],
        event_target: Router
      )

    :ok = Router.attach_transport(:ble, Mob.Routing.BLE, transport)
    Application.put_env(:mob_node, :ble_transport_pid, transport)

    on_exit(fn ->
      if Process.alive?(transport), do: GenServer.stop(transport)
      if Process.alive?(bridge), do: GenServer.stop(bridge)
      System.delete_env("MOB_BLE_TRANSPORT")
      Application.delete_env(:mob_node, :ble_transport_pid)
    end)

    vm = start_supervised!({ChannelViewModel, channel: "#general", router: Router})
    {:ok, _snapshot} = ChannelViewModel.subscribe(vm)

    %{vm: vm, bridge: bridge, transport: transport}
  end

  test "send_text reaches the BLE transport broadcast hook", %{vm: vm, transport: transport} do
    assert {:ok, _message_id} = ChannelViewModel.send_text(vm, "mesh hello")

    bridge_pid = :sys.get_state(transport).bridge
    assert is_binary(RecordingBleBridge.last_broadcast(bridge_pid))
    assert byte_size(RecordingBleBridge.last_broadcast(bridge_pid)) > 0
  end

  test "BLE gossip ingress delivers CHAT to channel subscribers", %{vm: vm} do
    {:ok, envelope} =
      MessageEnvelope.build(
        sender_peer_id: :crypto.strong_rand_bytes(32),
        created_at: System.system_time(:millisecond),
        payload_type: Composer.payload_type(),
        payload: "from gossip"
      )

    event = %ReceivedMessage{
      message_id: envelope.message_id,
      sender_peer_id: envelope.sender_peer_id,
      recipient_peer_id: nil,
      received_device_id: "peer-device",
      received_at: envelope.created_at,
      rssi: -40,
      envelope: envelope,
      raw_transport_metadata: %{}
    }

    assert :ok = RouterIngress.forward_received_message(event)

    assert_receive {ChannelViewModel, :updated,
                    %{messages: [%{body: "from gossip", direction: :in}], message_count: 1}}
  end

  test "transport frame round-trip reaches channel subscribers", %{transport: transport} do
    text = "over the wire frame"
    identity = %{peer_id: "sender", wire_peer_id: :crypto.strong_rand_bytes(32)}

    assert {:ok, packet, _id} = Composer.build_packet("#general", text, identity: identity)
    assert {:ok, frame} = Codec.encode_packet(packet)

    send(transport, {:ble_frame, "remote-peer", frame})

    assert_receive {:mob_runtime, :packet, :ble, "remote-peer", %Packet{} = received}, 500
    assert received.channel_id == "#general"

    assert_receive {ChannelViewModel, :updated,
                    %{messages: [%{body: ^text, direction: :in}], message_count: 1}}
  end

  defp ensure_db_started do
    case Mob.Store.DB.start_link([]) do
      {:ok, pid} ->
        Process.unlink(pid)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end
  end
end