defmodule Mob.Runtime.TCPRouterTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias Mob.Protocol.{Codec, Packet}
  alias Mob.Runtime.{FragmentBuffer, Outbox, PeerRegistry, Router, SessionManager}
  alias Mob.Store.{Dedupe, RelayCache}
  alias Mob.Store.Outbox, as: StoreOutbox
  alias Mob.Routing.TCP

  @localhost {127, 0, 0, 1}

  setup do
    restart_runtime()
    Router.reset()
    Outbox.reset()
    SessionManager.reset()
    FragmentBuffer.reset()
    PeerRegistry.reset()
    Dedupe.clear()
    RelayCache.clear()
    StoreOutbox.clear()
    Router.subscribe(self())

    {:ok, local} = TCP.start_link(id: "local", event_target: Router)
    :ok = Router.attach_transport(:tcp, TCP, local)
    {:ok, remote} = TCP.start_link(id: "remote", event_target: self())

    assert :ok = TCP.connect(remote, @localhost, TCP.listen_port(local))
    assert_receive {:mob_runtime, :peer_up, :tcp, %{id: "remote"}}

    %{remote: remote}
  end

  test "sends direct runtime packets over TCP" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "tcp-direct")

    assert :ok = Router.send_packet("remote", packet)
    assert_receive {:mob_routing, :tcp, {:frame, "local", frame}}
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert decoded.msg_id == packet.msg_id
    assert decoded.payload == "tcp-direct"
  end

  test "receives inbound TCP frames through the runtime router", %{remote: remote} do
    flush_transport_events()
    id = msg_id()
    packet = Packet.new(:data, id, "from-tcp")
    {:ok, frame} = Codec.encode_packet(packet)

    assert :ok = TCP.send_frame(remote, "local", frame)
    assert_receive {:mob_runtime, :packet, :tcp, "remote", received}

    assert received.msg_id == id
    assert received.payload == "from-tcp"
    assert Dedupe.seen?(id)
    assert RelayCache.get(id) == {id, "from-tcp", 0}
  end

  defp msg_id do
    System.unique_integer([:positive]) |> rem(4_000_000_000)
  end

  defp restart_runtime do
    Application.stop(:mob_runtime)
    {:ok, _apps} = Application.ensure_all_started(:mob_runtime)
    :ok
  end

  defp flush_transport_events do
    receive do
      {:mob_routing, _transport, _event} -> flush_transport_events()
    after
      0 -> :ok
    end
  end
end
