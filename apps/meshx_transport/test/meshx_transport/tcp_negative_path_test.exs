defmodule MeshxTransport.TCPNegativePathTest do
  @moduledoc """
  Negative-path tests for the TCP transport: malformed frames, disconnect
  storms, peer churn (rapid connect/disconnect cycles), and slow receivers.
  These exercise failure modes the happy-path tests do not cover.
  """

  use ExUnit.Case

  @moduletag capture_log: true
  @moduletag timeout: 30_000

  alias MeshxTransport.TCP

  @localhost {127, 0, 0, 1}
  @hello_tag :meshx_tcp_hello_v1
  @frame_tag :meshx_tcp_frame_v1

  describe "malformed input" do
    test "an unparseable hello payload causes the connection to be closed silently" do
      {:ok, server} = TCP.start_link(id: "server")
      port = TCP.listen_port(server)

      {:ok, sock} = :gen_tcp.connect(@localhost, port, [:binary, packet: 4, active: false])
      :ok = :gen_tcp.send(sock, "this is not a valid term-encoded hello")

      # The server's accept loop closes the socket after a bad hello.
      assert {:error, :closed} = :gen_tcp.recv(sock, 0, 2_000)

      # Server itself stays alive and serves new connections.
      {:ok, b} = TCP.start_link(id: "b", event_target: self())
      assert :ok = TCP.connect(b, @localhost, port)
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000
    end

    test "a hello with the wrong tag is rejected without crashing the server" do
      {:ok, server} = TCP.start_link(id: "server")
      port = TCP.listen_port(server)

      {:ok, sock} = :gen_tcp.connect(@localhost, port, [:binary, packet: 4, active: false])
      bad = :erlang.term_to_binary({:not_a_hello_tag, "bad", %{}})
      :ok = :gen_tcp.send(sock, bad)
      assert {:error, :closed} = :gen_tcp.recv(sock, 0, 2_000)

      assert Process.alive?(server)
    end

    test "a malformed frame after a valid handshake closes that peer only" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      port = TCP.listen_port(server)

      # Hand-rolled "well-behaved" client: completes handshake, then sends garbage.
      {:ok, sock} = :gen_tcp.connect(@localhost, port, [:binary, packet: 4, active: false])
      hello = :erlang.term_to_binary({@hello_tag, "rude", %{}})
      :ok = :gen_tcp.send(sock, hello)

      assert {:ok, server_hello_bin} = :gen_tcp.recv(sock, 0, 2_000)
      assert {@hello_tag, "server", _} = :erlang.binary_to_term(server_hello_bin, [:safe])
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "rude"}}}, 2_000

      # Send garbage that decodes as a non-frame term.
      :ok = :gen_tcp.send(sock, :erlang.term_to_binary({:not_a_frame_tag, "lol"}))

      # Server should drop the rude peer.
      assert_receive {:meshx_transport, :tcp, {:peer_down, "rude"}}, 2_000
      assert Process.alive?(server)

      # New peers can still join.
      {:ok, c} = TCP.start_link(id: "c", event_target: self())
      assert :ok = TCP.connect(c, @localhost, port)
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000
    end
  end

  describe "disconnect storms and peer churn" do
    test "rapid connect/disconnect cycles do not leak peers" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      port = TCP.listen_port(server)

      for i <- 1..20 do
        {:ok, c} = TCP.start_link(id: "client-#{i}", event_target: self())
        :ok = TCP.connect(c, @localhost, port)
        assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000
        :ok = TCP.disconnect(c, "server")
        GenServer.stop(c)
      end

      # Drain every event the server emitted; we want to be sure the server's
      # peers map is empty at the end.
      drain_events()
      assert eventually(fn -> TCP.peers(server) == [] end, 200)
    end

    test "many simultaneous client disconnects all produce peer_down events" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      port = TCP.listen_port(server)

      n = 10

      clients =
        for i <- 1..n do
          {:ok, c} = TCP.start_link(id: "burst-#{i}", event_target: self())
          :ok = TCP.connect(c, @localhost, port)
          {i, c}
        end

      # Wait for all peer_ups before tearing down.
      for _ <- 1..n do
        assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000
      end

      drain_events()

      # Tear them all down at once.
      Enum.each(clients, fn {_i, c} -> GenServer.stop(c) end)

      # Server emits one peer_down per client.
      observed =
        Enum.reduce(1..n, MapSet.new(), fn _, acc ->
          assert_receive {:meshx_transport, :tcp, {:peer_down, peer_id}}, 5_000
          MapSet.put(acc, peer_id)
        end)

      assert MapSet.size(observed) == n
      assert eventually(fn -> TCP.peers(server) == [] end, 200)
    end

    test "reconnect with the same peer id replaces the previous socket" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      port = TCP.listen_port(server)

      {:ok, c1} = TCP.start_link(id: "dup", event_target: self())
      :ok = TCP.connect(c1, @localhost, port)
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000

      {:ok, c2} = TCP.start_link(id: "dup", event_target: self())
      :ok = TCP.connect(c2, @localhost, port)
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000

      assert eventually(
               fn ->
                 ids = server |> TCP.peers() |> Enum.map(& &1.id)
                 ids == ["dup"]
               end,
               200
             )
    end
  end

  describe "slow receivers" do
    test "server keeps accepting connections while one peer never reads" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      port = TCP.listen_port(server)

      # A "slow" peer: completes handshake, then never recv's. Client OS buffer
      # eventually fills, but server's inbound work is unaffected.
      {:ok, slow} = :gen_tcp.connect(@localhost, port, [:binary, packet: 4, active: false])
      :ok = :gen_tcp.send(slow, :erlang.term_to_binary({@hello_tag, "slow", %{}}))
      {:ok, _} = :gen_tcp.recv(slow, 0, 2_000)
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "slow"}}}, 2_000

      # New peers should still come up.
      {:ok, fast} = TCP.start_link(id: "fast", event_target: self())
      assert :ok = TCP.connect(fast, @localhost, port)
      assert_receive {:meshx_transport, :tcp, {:peer_up, %{id: "server"}}}, 2_000

      # And the server should still be able to send to the fast peer.
      assert :ok = TCP.send_frame(server, "fast", "ping")
      assert_receive {:meshx_transport, :tcp, {:frame, "server", "ping"}}, 2_000

      :gen_tcp.close(slow)
    end

    test "send_frame to a non-connected peer returns :peer_not_found" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      assert {:error, :peer_not_found} = TCP.send_frame(server, "nobody", "hello")
    end

    test "disconnect of an unknown peer returns :peer_not_found" do
      {:ok, server} = TCP.start_link(id: "server", event_target: self())
      assert {:error, :peer_not_found} = TCP.disconnect(server, "ghost")
    end
  end

  defp drain_events do
    receive do
      {:meshx_transport, _, _} -> drain_events()
    after
      0 -> :ok
    end
  end

  defp eventually(_fun, 0), do: false

  defp eventually(fun, attempts) do
    if fun.() do
      true
    else
      Process.sleep(10)
      eventually(fun, attempts - 1)
    end
  end

  # Silence unused-attribute warning if the constants aren't all used by every test.
  _ = @frame_tag
end
