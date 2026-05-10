defmodule MeshxTransport.TCPTest do
  use ExUnit.Case

  alias MeshxTransport.{Capabilities, TCP}

  @localhost {127, 0, 0, 1}

  test "connects endpoints and advertises peer metadata" do
    metadata =
      Capabilities.to_metadata(Capabilities.new(mtu: 512, secure_required: true, relay: false))

    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b", metadata: metadata)

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b))

    peer_b = assert_peer_up("b")
    peer_a = assert_peer_up("a")

    assert peer_b.transport == :tcp
    assert peer_a.transport == :tcp

    capabilities = Capabilities.from_metadata(peer_b.metadata)
    assert capabilities.mtu == 512
    assert capabilities.secure_required?
    refute capabilities.relay?

    assert_eventually(fn -> peer_ids(TCP.peers(a)) == ["b"] end)
    assert_eventually(fn -> peer_ids(TCP.peers(b)) == ["a"] end)
  end

  test "connect accepts string hosts" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b")

    assert :ok = TCP.connect(a, "127.0.0.1", TCP.listen_port(b))

    assert_peer_up("b")
    assert_peer_up("a")
  end

  test "sends frames between connected endpoints" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b")

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b))
    flush_transport_events()

    assert :ok = TCP.send_frame(a, "b", "hello")
    assert_receive {:meshx_transport, :tcp, {:frame, "a", "hello"}}
  end

  test "broadcasts frames to every connected peer" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b")
    {:ok, c} = TCP.start_link(id: "c")

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b))
    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(c))
    flush_transport_events()

    assert :ok = TCP.broadcast_frame(a, "hello-all")
    assert_receive {:meshx_transport, :tcp, {:frame, "a", "hello-all"}}
    assert_receive {:meshx_transport, :tcp, {:frame, "a", "hello-all"}}
    refute_receive {:meshx_transport, :tcp, {:frame, "a", "hello-all"}}, 25
  end

  test "broadcast succeeds with no connected peers" do
    {:ok, a} = TCP.start_link(id: "a")

    assert :ok = TCP.broadcast_frame(a, "nobody")
    assert TCP.peers(a) == []
  end

  test "duplicate peer connections replace the old socket" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b1} = TCP.start_link(id: "b")
    {:ok, b2} = TCP.start_link(id: "b")

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b1))
    assert_peer_up("b")
    assert_peer_up("a")

    old_socket = :sys.get_state(a).peers["b"].socket

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b2))
    assert_peer_down("b")
    assert_peer_up("b")
    assert_peer_up("a")

    new_socket = :sys.get_state(a).peers["b"].socket
    refute new_socket == old_socket
  end

  test "returns an error for unknown peers" do
    {:ok, a} = TCP.start_link(id: "a")

    assert {:error, :peer_not_found} = TCP.send_frame(a, "missing", "hello")
    assert {:error, :peer_not_found} = TCP.disconnect(a, "missing")
  end

  test "returns an error when connect cannot reach a listener" do
    {:ok, a} = TCP.start_link(id: "a")

    assert {:error, reason} = TCP.connect(a, @localhost, 9, connect_timeout_ms: 50)
    assert reason in [:econnrefused, :timeout, :enetunreach, :ehostunreach]
  end

  test "drops connections that send malformed TCP payloads" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b")

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b))
    flush_transport_events()

    [peer] = TCP.peers(a)
    assert peer.id == "b"

    %{socket: socket} = :sys.get_state(a).peers["b"]
    :ok = :gen_tcp.send(socket, :erlang.term_to_binary({:bad_tag, "payload"}))

    assert_peer_down("b")
    assert_peer_down("a")
  end

  test "rejects accepted sockets with invalid hello payloads" do
    {:ok, b} = TCP.start_link(id: "b")

    {:ok, socket} = :gen_tcp.connect(@localhost, TCP.listen_port(b), socket_opts())
    :ok = :gen_tcp.send(socket, "not-a-term")

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 500)
    assert TCP.peers(b) == []
  end

  test "rejects accepted sockets with malformed hello terms" do
    {:ok, b} = TCP.start_link(id: "b")

    {:ok, socket} = :gen_tcp.connect(@localhost, TCP.listen_port(b), socket_opts())
    :ok = :gen_tcp.send(socket, :erlang.term_to_binary({:bad_hello, "a", %{}}))

    assert {:error, :closed} = :gen_tcp.recv(socket, 0, 500)
    assert TCP.peers(b) == []
  end

  test "ignores unknown messages and unknown socket closures" do
    {:ok, a} = TCP.start_link(id: "a")

    send(a, :ignored)
    send(a, {:tcp_closed, make_ref()})
    send(a, {:tcp_error, make_ref(), :closed})

    assert TCP.peers(a) == []
  end

  test "tcp_error removes an existing peer" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b")

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b))
    flush_transport_events()

    %{socket: socket} = :sys.get_state(a).peers["b"]
    send(a, {:tcp_error, socket, :closed})

    assert_peer_down("b")
    assert_eventually(fn -> TCP.peers(a) == [] end)
  end

  test "emits peer_down when a connection closes" do
    {:ok, a} = TCP.start_link(id: "a")
    {:ok, b} = TCP.start_link(id: "b")

    assert :ok = TCP.connect(a, @localhost, TCP.listen_port(b))
    flush_transport_events()

    assert :ok = TCP.disconnect(a, "b")
    assert_peer_down("b")
    assert_peer_down("a")

    assert_eventually(fn -> TCP.peers(a) == [] end)
    assert_eventually(fn -> TCP.peers(b) == [] end)
  end

  defp peer_ids(peers) do
    peers
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  defp assert_peer_up(peer_id) do
    assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: ^peer_id} = peer}}
    peer
  end

  defp assert_peer_down(peer_id) do
    assert_receive {:meshx_transport, :tcp, {:peer_down, ^peer_id}}
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: assert(fun.())

  defp flush_transport_events do
    receive do
      {:meshx_transport, _transport, _event} -> flush_transport_events()
    after
      0 -> :ok
    end
  end

  defp socket_opts do
    [:binary, packet: 4, active: false]
  end
end
