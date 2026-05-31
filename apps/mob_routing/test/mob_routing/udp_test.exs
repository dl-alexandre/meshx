defmodule Mob.Routing.UDPTest do
  use ExUnit.Case

  alias Mob.Routing.{Capabilities, UDP}

  @localhost {127, 0, 0, 1}

  test "two endpoints learn about each other after a hello exchange" do
    metadata = Capabilities.to_metadata(Capabilities.new(mtu: 1200, relay: true))

    {:ok, a} = UDP.start_link(id: "a")
    {:ok, b} = UDP.start_link(id: "b", metadata: metadata)

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))

    assert_receive {:mob_routing, :udp, {:peer_up, %{id: "b"} = peer_b}}, 2_000
    assert_receive {:mob_routing, :udp, {:peer_up, %{id: "a"} = _peer_a}}, 2_000

    caps = Capabilities.from_metadata(peer_b.metadata)
    assert caps.mtu == 1200
    assert caps.relay?

    assert_eventually(fn -> peer_ids(UDP.peers(a)) == ["b"] end)
    assert_eventually(fn -> peer_ids(UDP.peers(b)) == ["a"] end)
  end

  test "connect accepts string and charlist hosts" do
    {:ok, a} = UDP.start_link(id: "a")
    {:ok, b} = UDP.start_link(id: "b")
    {:ok, c} = UDP.start_link(id: "c")

    assert :ok = UDP.connect(a, "127.0.0.1", UDP.listen_port(b))
    assert :ok = UDP.connect(a, ~c"127.0.0.1", UDP.listen_port(c))

    assert_peer_up("b")
    assert_peer_up("c")
    assert_peer_up("a")
    assert_peer_up("a")
  end

  test "frames flow in both directions over UDP" do
    {:ok, a} = UDP.start_link(id: "a")
    {:ok, b} = UDP.start_link(id: "b")

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))

    flush()

    assert :ok = UDP.send_frame(a, "b", "ping")
    assert_receive {:mob_routing, :udp, {:frame, "a", "ping"}}, 2_000

    assert :ok = UDP.send_frame(b, "a", "pong")
    assert_receive {:mob_routing, :udp, {:frame, "b", "pong"}}, 2_000
  end

  test "broadcasts frames to every connected peer" do
    {:ok, a} = UDP.start_link(id: "a")
    {:ok, b} = UDP.start_link(id: "b")
    {:ok, c} = UDP.start_link(id: "c")

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))
    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(c))
    flush()

    assert :ok = UDP.broadcast_frame(a, "hello-all")
    assert_receive {:mob_routing, :udp, {:frame, "a", "hello-all"}}, 2_000
    assert_receive {:mob_routing, :udp, {:frame, "a", "hello-all"}}, 2_000
    refute_receive {:mob_routing, :udp, {:frame, "a", "hello-all"}}, 25
  end

  test "broadcast succeeds with no peers and reports per-peer send failures" do
    {:ok, empty} = UDP.start_link(id: "empty")
    assert :ok = UDP.broadcast_frame(empty, "nobody")
    assert UDP.peers(empty) == []

    {:ok, a} = UDP.start_link(id: "a", max_datagram_bytes: 100)
    {:ok, b} = UDP.start_link(id: "b", max_datagram_bytes: 100)
    {:ok, c} = UDP.start_link(id: "c", max_datagram_bytes: 100)

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))
    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(c))
    flush()

    assert {:error, [{:error, :datagram_too_large}, {:error, :datagram_too_large}]} =
             UDP.broadcast_frame(a, :crypto.strong_rand_bytes(200))
  end

  test "peers can be listed and disconnected" do
    {:ok, a} = UDP.start_link(id: "a")
    {:ok, b} = UDP.start_link(id: "b")

    assert {:error, :peer_not_found} = UDP.disconnect(a, "missing")

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))
    assert_peer_up("b")
    assert_peer_up("a")

    assert_eventually(fn -> peer_ids(UDP.peers(a)) == ["b"] end)

    assert :ok = UDP.disconnect(a, "b")
    assert_peer_down("b")
    assert UDP.peers(a) == []
  end

  test "datagrams larger than the configured MTU are rejected" do
    {:ok, a} = UDP.start_link(id: "a", max_datagram_bytes: 200)
    {:ok, b} = UDP.start_link(id: "b", max_datagram_bytes: 200)

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))
    flush()

    too_big = :crypto.strong_rand_bytes(300)
    assert {:error, :datagram_too_large} = UDP.send_frame(a, "b", too_big)
  end

  test "send_frame to an unknown peer returns :peer_not_found" do
    {:ok, a} = UDP.start_link(id: "a")
    assert {:error, :peer_not_found} = UDP.send_frame(a, "nobody", "x")
  end

  test "connect to a port nobody is listening on times out" do
    {:ok, a} = UDP.start_link(id: "a")
    # Pick a high port unlikely to be in use; UDP has no RST so we rely on the
    # hello exchange not getting a reply.
    assert {:error, :timeout} =
             UDP.connect(a, @localhost, 1, hello_attempts: 2, hello_interval_ms: 50)
  end

  test "connect with a single hello attempt times out" do
    {:ok, a} = UDP.start_link(id: "a")

    assert {:error, :timeout} =
             UDP.connect(a, @localhost, 1, hello_attempts: 1, hello_interval_ms: 20)
  end

  test "connect retries more than once before timing out" do
    {:ok, a} = UDP.start_link(id: "a")

    assert {:error, :timeout} =
             UDP.connect(a, @localhost, 1, hello_attempts: 3, hello_interval_ms: 20)
  end

  test "returns a startup error when the UDP port is already bound" do
    original_trap_exit = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, original_trap_exit) end)

    {:ok, a} = UDP.start_link(id: "a")

    assert {:error, {:udp_open_failed, :eaddrinuse}} =
             UDP.start_link(id: "b", listen_port: UDP.listen_port(a))
  end

  test "garbage datagrams are silently dropped" do
    {:ok, server} = UDP.start_link(id: "server")
    port = UDP.listen_port(server)

    {:ok, sock} = :gen_udp.open(0, [:binary, ip: {127, 0, 0, 1}])
    :ok = :gen_udp.send(sock, @localhost, port, "this is not a valid term")
    :ok = :gen_udp.send(sock, @localhost, port, :erlang.term_to_binary({:bogus, 1}))

    refute_receive {:mob_routing, :udp, _}, 200
    assert Process.alive?(server)

    :gen_udp.close(sock)
  end

  test "frames from endpoints that have not completed hello are dropped" do
    {:ok, server} = UDP.start_link(id: "server")
    port = UDP.listen_port(server)

    {:ok, sock} = :gen_udp.open(0, [:binary, ip: @localhost])

    :ok =
      :gen_udp.send(
        sock,
        @localhost,
        port,
        :erlang.term_to_binary({:mob_udp_frame_v1, "intruder", "payload"})
      )

    refute_receive {:mob_routing, :udp, _}, 200
    assert UDP.peers(server) == []

    :gen_udp.close(sock)
  end

  test "keepalive from a rebound peer updates the reverse address lookup" do
    {:ok, server} = UDP.start_link(id: "server")
    port = UDP.listen_port(server)

    {:ok, first_sock} = :gen_udp.open(0, [:binary, ip: @localhost])

    :ok =
      :gen_udp.send(
        first_sock,
        @localhost,
        port,
        :erlang.term_to_binary({:mob_udp_hello_v1, "peer", %{}})
      )

    assert_peer_up("peer")
    old_addr = only_addr(server)

    {:ok, second_sock} = :gen_udp.open(0, [:binary, ip: @localhost])

    :ok =
      :gen_udp.send(
        second_sock,
        @localhost,
        port,
        :erlang.term_to_binary({:mob_udp_keepalive_v1, "peer"})
      )

    assert_eventually(fn ->
      state = :sys.get_state(server)
      Map.get(state.addrs, old_addr) == nil and map_size(state.addrs) == 1
    end)

    :gen_udp.close(first_sock)
    :gen_udp.close(second_sock)
  end

  test "keepalive ticks and ignored messages leave the transport alive" do
    {:ok, a} = UDP.start_link(id: "a", keepalive_ms: 1_000_000)
    {:ok, b} = UDP.start_link(id: "b", keepalive_ms: 1_000_000)

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))
    flush()

    send(a, :keepalive_tick)
    send(a, :ignored)

    assert_eventually(fn -> Process.alive?(a) and peer_ids(UDP.peers(a)) == ["b"] end)
  end

  test "idle peers are reaped when no traffic arrives within the timeout" do
    {:ok, a} = UDP.start_link(id: "a", peer_idle_timeout_ms: 200, keepalive_ms: 1_000_000)
    {:ok, b} = UDP.start_link(id: "b", peer_idle_timeout_ms: 200, keepalive_ms: 1_000_000)

    assert :ok = UDP.connect(a, @localhost, UDP.listen_port(b))
    assert_peer_up("b")
    assert_peer_up("a")

    # No keepalives are sent (interval is huge), so a should reap b.
    Process.sleep(220)
    send(a, :reaper_tick)

    assert_peer_down("b")
    assert_eventually(fn -> UDP.peers(a) == [] end)
  end

  test "stopped transports close cleanly" do
    {:ok, a} = UDP.start_link(id: "a")

    GenServer.stop(a)
    refute Process.alive?(a)
  end

  defp peer_ids(peers) do
    peers
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  defp assert_peer_up(peer_id) do
    assert_receive {:mob_routing, :udp, {:peer_up, %{id: ^peer_id} = peer}}, 2_000
    peer
  end

  defp assert_peer_down(peer_id) do
    assert_receive {:mob_routing, :udp, {:peer_down, ^peer_id}}, 2_000
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

  defp only_addr(transport) do
    assert_eventually(fn -> map_size(:sys.get_state(transport).addrs) == 1 end)
    [addr] = :sys.get_state(transport).addrs |> Map.keys()
    addr
  end

  defp flush do
    receive do
      {:mob_routing, _, _} -> flush()
    after
      0 -> :ok
    end
  end
end
