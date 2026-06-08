defmodule Mob.Node.Chat.RouterIngressTest do
  use ExUnit.Case, async: false

  alias Mob.Node.BLE.Events.ReceivedMessage
  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.{Composer, RouterIngress}
  alias Mob.Protocol.Packet
  alias Mob.Runtime.Router

  setup do
    Application.stop(:mob_runtime)
    {:ok, _} = Application.ensure_all_started(:mob_runtime)
    Router.reset()
    Router.subscribe(self())
    :ok
  end

  test "forwards CHAT envelopes into the router as channel packets" do
    {:ok, envelope} =
      MessageEnvelope.build(
        sender_peer_id: :crypto.strong_rand_bytes(32),
        created_at: 1_700_000_000_000,
        payload_type: Composer.payload_type(),
        payload: "hello from ble"
      )

    event = %ReceivedMessage{
      message_id: envelope.message_id,
      sender_peer_id: envelope.sender_peer_id,
      recipient_peer_id: nil,
      received_device_id: "device-1",
      received_at: envelope.created_at,
      rssi: -48,
      envelope: envelope,
      raw_transport_metadata: %{}
    }

    assert :ok = RouterIngress.forward_received_message(event)

    assert_receive {:mob_runtime, :packet, :ble, _peer_id,
                    %Packet{channel_id: "#general"} = packet},
                   500

    assert {:ok, parsed} = MessageEnvelope.parse(packet.payload)
    assert parsed.payload == "hello from ble"
    assert parsed.payload_type == "CHAT"
  end

  test "skips non-CHAT envelopes" do
    {:ok, envelope} =
      MessageEnvelope.build(
        sender_peer_id: :crypto.strong_rand_bytes(32),
        created_at: 0,
        payload_type: "OTHER",
        payload: "nope"
      )

    event = %ReceivedMessage{
      message_id: envelope.message_id,
      sender_peer_id: envelope.sender_peer_id,
      recipient_peer_id: nil,
      received_device_id: "device-1",
      received_at: 0,
      rssi: 0,
      envelope: envelope,
      raw_transport_metadata: %{}
    }

    assert :skip = RouterIngress.forward_received_message(event)
    refute_receive {:mob_runtime, :packet, _, _, _}, 50
  end
end
