defmodule MeshxRuntime.TCPStoreForwardTest do
  @moduledoc """
  Exercises store-and-forward over the TCP transport: a packet enqueued
  while a peer is offline must be replayed when the peer reconnects.
  """

  use ExUnit.Case

  @moduletag capture_log: true

  alias MeshxProtocol.{Codec, Packet}
  alias MeshxRuntime.{FragmentBuffer, Outbox, PeerRegistry, Router, SessionManager}
  alias MeshxStore.{Dedupe, RelayCache}
  alias MeshxStore.Outbox, as: StoreOutbox
  alias MeshxTransport.TCP

  @localhost {127, 0, 0, 1}

  setup do
    Application.stop(:meshx_runtime)
    {:ok, _} = Application.ensure_all_started(:meshx_runtime)
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

    %{local: local, remote: remote, local_port: TCP.listen_port(local)}
  end

  test "queued packet is replayed after the peer reconnects",
       %{local: local, remote: remote, local_port: local_port} do
    # 1. Initial connection, then drop it so "remote" is offline from local's view.
    assert :ok = TCP.connect(remote, @localhost, local_port)
    assert_receive {:meshx_runtime, :peer_up, :tcp, %{id: "remote"}}, 2_000

    :ok = TCP.disconnect(local, "remote")
    assert_receive {:meshx_runtime, :peer_down, :tcp, "remote"}, 2_000
    flush_transport_events()

    # 2. Enqueue while offline.
    msg_id = System.unique_integer([:positive]) |> rem(4_000_000_000)
    packet = Packet.new(:data, msg_id, "deferred-payload")

    assert {:queued, :unknown_peer, %StoreOutbox{} = record} =
             Router.send_packet("remote", packet, store: true, max_attempts: 3)

    assert record.msg_id == msg_id
    assert StoreOutbox.pending_for_destination("remote", 10) |> Enum.any?()

    # 3. Reconnect — Outbox must replay onto the wire.
    assert :ok = TCP.connect(remote, @localhost, local_port)
    assert_receive {:meshx_runtime, :peer_up, :tcp, %{id: "remote"}}, 2_000

    assert_receive {:meshx_transport, :tcp, {:frame, "local", frame}}, 5_000
    assert {:ok, decoded, <<>>} = Codec.decode_packet(frame)
    assert decoded.msg_id == msg_id
    assert decoded.payload == "deferred-payload"
    # Outbox sets ack-requested when enqueuing for replay.
    assert Packet.flag_set?(decoded.flags, Packet.flag_ack_requested())
  end

  defp flush_transport_events do
    receive do
      {:meshx_transport, _, _} -> flush_transport_events()
    after
      0 -> :ok
    end
  end
end
