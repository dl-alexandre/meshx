defmodule Mob.Node.Chat.E2ETCPTest do
  @moduledoc """
  End-to-end chat round-trip over real TCP transport.

  Proves the full chat send path:

      Composer.build_packet
        → Router.send_packet
          → TCP wire frame
            → decode_packet
              → MessageEnvelope.decode
                → text + channel + sender match what was sent

  This is the integration gap that `mob_node/test/mob_node/chat/*` unit
  tests don't cover — each unit-tested module in isolation, but no test
  that proves a chat message actually traverses the runtime end-to-end.

  Modelled on `Mob.Runtime.TCPRouterTest` — one BEAM, two `TCP.start_link`
  endpoints loopback-connected. Sender side is the full Router pipeline;
  receiver side is a raw TCP mailbox forwarding frames to `self()` (so we
  can decode and assert what arrived on the wire).
  """

  use ExUnit.Case

  @moduletag capture_log: true

  alias Mob.Node.BLE.MessageEnvelope
  alias Mob.Node.Chat.Composer
  alias Mob.Protocol.{Codec, Packet}
  alias Mob.Routing.TCP

  alias Mob.Runtime.{FragmentBuffer, Outbox, PeerRegistry, Router, SessionManager}

  alias Mob.Store.{Dedupe, RelayCache}
  alias Mob.Store.Outbox, as: StoreOutbox

  @localhost {127, 0, 0, 1}

  setup do
    Application.stop(:mob_runtime)
    {:ok, _apps} = Application.ensure_all_started(:mob_runtime)
    Router.reset()
    Outbox.reset()
    SessionManager.reset()
    FragmentBuffer.reset()
    PeerRegistry.reset()
    Dedupe.clear()
    RelayCache.clear()
    StoreOutbox.clear()
    Router.subscribe(self())

    {:ok, alice_tcp} = TCP.start_link(id: "alice", event_target: Router)
    :ok = Router.attach_transport(:tcp, TCP, alice_tcp)

    {:ok, bob_tcp} = TCP.start_link(id: "bob", event_target: self())
    :ok = TCP.connect(bob_tcp, @localhost, TCP.listen_port(alice_tcp))
    assert_receive {:mob_runtime, :peer_up, :tcp, %{id: "bob"}}, 1_000

    %{bob: bob_tcp}
  end

  test "alice's chat message arrives intact on bob over TCP" do
    flush_transport_events()

    channel = "general"
    text = "hello bob — from alice over real TCP"
    identity = %{peer_id: "alice-peer"}

    assert {:ok, packet, message_id} =
             Composer.build_packet(channel, text, identity: identity)

    assert byte_size(message_id) == 16
    assert packet.channel_id == channel
    assert Packet.flag_set?(packet.flags, Packet.flag_channel())

    assert :ok = Router.send_packet("bob", packet)

    assert_receive {:mob_routing, :tcp, {:frame, "alice", frame}}, 2_000
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)

    assert decoded.type == :data
    assert decoded.channel_id == channel
    assert decoded.msg_id == packet.msg_id
    assert Packet.flag_set?(decoded.flags, Packet.flag_channel())

    assert {:ok, envelope} = MessageEnvelope.parse(decoded.payload)
    assert envelope.payload_type == Composer.payload_type()
    assert envelope.payload == text
    assert envelope.sender_peer_id == "alice-peer"
    assert envelope.message_id == message_id
  end

  test "channel-filtered Router subscriber only receives matching channels", %{bob: bob_tcp} do
    flush_transport_events()

    # A subscriber process scoped to the "general" channel only. Router only
    # dispatches :packet to subscribers when it decodes an *inbound* frame
    # (send_packet is outbound and doesn't loop back) — so we drive this by
    # encoding two packets and injecting them as inbound frames from bob's
    # transport into alice's Router.
    test_pid = self()

    subscriber =
      spawn_link(fn ->
        Router.subscribe(self(), channels: ["general"])
        send(test_pid, :subscribed)
        forward_loop(test_pid)
      end)

    assert_receive :subscribed, 1_000

    {:ok, general_packet, _id1} =
      Composer.build_packet("general", "in-channel msg", identity: %{peer_id: "alice-peer"})

    {:ok, other_packet, _id2} =
      Composer.build_packet("trading", "wrong-channel msg", identity: %{peer_id: "alice-peer"})

    {:ok, general_frame} = Codec.encode_packet(general_packet)
    {:ok, other_frame} = Codec.encode_packet(other_packet)

    # Inject both frames inbound to alice via bob's TCP transport. Alice's
    # Router (the event_target) will decode + dispatch to subscribers.
    :ok = TCP.send_frame(bob_tcp, "alice", general_frame)
    :ok = TCP.send_frame(bob_tcp, "alice", other_frame)

    assert_receive {:fwd, %Packet{channel_id: "general", payload: payload}}, 2_000
    {:ok, env} = MessageEnvelope.parse(payload)
    assert env.payload == "in-channel msg"

    refute_receive {:fwd, %Packet{channel_id: "trading"}}, 200

    # Subscriber is spawn_link'd — it'll die naturally when the test pid exits.
    _ = subscriber
  end

  defp forward_loop(caller) do
    receive do
      {:mob_runtime, :packet, _transport, _from_peer, %Packet{} = pkt} ->
        send(caller, {:fwd, pkt})
        forward_loop(caller)

      _other ->
        forward_loop(caller)
    end
  end

  defp flush_transport_events do
    receive do
      {:mob_routing, _t, _e} -> flush_transport_events()
      {:mob_runtime, _kind, _t, _meta} -> flush_transport_events()
    after
      0 -> :ok
    end
  end
end
