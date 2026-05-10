defmodule MeshxRuntime.TCPRouterTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias MeshxProtocol.{Codec, Packet}
  alias MeshxRuntime.{FragmentBuffer, Outbox, PeerRegistry, Router, SessionManager}
  alias MeshxStore.{Dedupe, RelayCache}
  alias MeshxStore.Outbox, as: StoreOutbox
  alias MeshxTransport.TCP

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
    assert_receive {:meshx_runtime, :peer_up, :tcp, %{id: "remote"}}

    %{remote: remote}
  end

  test "sends direct runtime packets over TCP" do
    flush_transport_events()
    packet = Packet.new(:data, msg_id(), "tcp-direct")

    assert :ok = Router.send_packet("remote", packet)
    assert_receive {:meshx_transport, :tcp, {:frame, "local", frame}}
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
    assert_receive {:meshx_runtime, :packet, :tcp, "remote", received}

    assert received.msg_id == id
    assert received.payload == "from-tcp"
    assert Dedupe.seen?(id)
    assert RelayCache.get(id) == {id, "from-tcp", 0}
  end

  defp msg_id do
    System.unique_integer([:positive]) |> rem(4_000_000_000)
  end

  defp restart_runtime do
    Application.stop(:meshx_runtime)
    {:ok, _apps} = Application.ensure_all_started(:meshx_runtime)
    :ok
  end

  defp flush_transport_events do
    receive do
      {:meshx_transport, _transport, _event} -> flush_transport_events()
    after
      0 -> :ok
    end
  end
end
