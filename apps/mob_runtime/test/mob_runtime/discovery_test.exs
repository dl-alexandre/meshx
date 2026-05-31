defmodule Mob.Runtime.DiscoveryTest do
  use ExUnit.Case

  alias Mob.Runtime.{Discovery, MDNS, PeerRegistry, Router}
  alias Mob.Store.Identity

  setup do
    restart_runtime()
    Router.reset()
    PeerRegistry.reset()
    Identity.clear()
    Router.subscribe(self())
    :ok
  end

  test "supervised discovery is disabled by default" do
    assert {:error, :disabled} = Discovery.announce()
    assert Discovery.listen_port() == nil
  end

  test "forwards UDP announcements into router peer discovery" do
    {:ok, beacon} =
      Discovery.start_link(
        name: :mob_test_discovery,
        enabled?: true,
        id: "local",
        router: Router,
        listen_port: 0,
        target_port: :self,
        broadcast_ip: {127, 0, 0, 1},
        auto_start?: false
      )

    port = Discovery.listen_port(beacon)
    payload = Discovery.encode_announcement("peer-a", :tcp, {"127.0.0.1", 4040}, %{mtu: 256})

    {:ok, socket} = :gen_udp.open(0, [:binary])
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, port, payload)

    assert_receive {:mob_runtime, :peer_up, :discovery, peer}
    assert peer.id == "peer-a"
    assert peer.transport == :tcp
    assert peer.address == {"127.0.0.1", 4040}
    assert peer.metadata == %{mtu: 256}
    assert PeerRegistry.get("peer-a") == peer

    :gen_udp.close(socket)
  end

  test "encodes and decodes mDNS MeshX service announcements" do
    payload = MDNS.encode_announcement("peer-mdns", :tcp, {{127, 0, 0, 1}, 4040}, %{mtu: 512})

    assert {:announcements, [announcement]} = MDNS.decode_packet(payload)
    assert announcement.node_id == "peer-mdns"
    assert announcement.transport == :tcp
    assert announcement.address == {{127, 0, 0, 1}, 4040}
    assert announcement.metadata == %{mtu: 512}

    assert :query = MDNS.decode_packet(MDNS.encode_query())
  end

  test "forwards mDNS announcements into router peer discovery" do
    {:ok, discovery} =
      Discovery.start_link(
        name: :mob_test_mdns_discovery,
        enabled?: true,
        mdns?: true,
        mdns_port: 0,
        mdns_join?: false,
        id: "local",
        router: Router,
        listen_port: 0,
        target_port: :self,
        broadcast_ip: {127, 0, 0, 1},
        auto_start?: false
      )

    mdns_port = Discovery.mdns_port(discovery)
    payload = MDNS.encode_announcement("peer-mdns", :udp, {{127, 0, 0, 1}, 5050}, %{relay?: true})

    {:ok, socket} = :gen_udp.open(0, [:binary])
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, mdns_port, payload)

    assert_receive {:mob_runtime, :peer_up, :discovery, peer}
    assert peer.id == "peer-mdns"
    assert peer.transport == :udp
    assert peer.address == {{127, 0, 0, 1}, 5050}
    assert peer.metadata == %{relay?: true}
    assert PeerRegistry.get("peer-mdns") == peer

    :gen_udp.close(socket)
  end

  test "ignores self announcements" do
    {:ok, beacon} =
      Discovery.start_link(
        name: :mob_test_self_discovery,
        enabled?: true,
        id: "local",
        router: Router,
        listen_port: 0,
        target_port: :self,
        broadcast_ip: {127, 0, 0, 1},
        auto_start?: false
      )

    port = Discovery.listen_port(beacon)
    payload = Discovery.encode_announcement("local", :tcp, {"127.0.0.1", 4040}, %{})

    {:ok, socket} = :gen_udp.open(0, [:binary])
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, port, payload)

    refute_receive {:mob_runtime, :peer_up, :discovery, _peer}, 50
    assert PeerRegistry.list() == []

    :gen_udp.close(socket)
  end

  test "announces over UDP and emits telemetry" do
    attach_telemetry([[:mob_runtime, :discovery, :announce]])

    {:ok, beacon} =
      Discovery.start_link(
        name: :mob_test_announce_discovery,
        enabled?: true,
        id: "local",
        router: Router,
        listen_port: 0,
        target_port: :self,
        broadcast_ip: {127, 0, 0, 1},
        auto_start?: false
      )

    assert :ok = Discovery.announce(beacon)

    assert_receive {:telemetry, [:mob_runtime, :discovery, :announce], %{bytes: bytes},
                    %{node_id: "local", transport: :tcp, result: :ok}}

    assert bytes > 0
    refute_receive {:mob_runtime, :peer_up, :discovery, _peer}, 50
  end

  test "uses persistent identity when no explicit id is provided" do
    {:ok, beacon} =
      Discovery.start_link(
        name: :mob_test_identity_discovery,
        enabled?: true,
        router: self(),
        listen_port: 0,
        target_port: :self,
        broadcast_ip: {127, 0, 0, 1},
        auto_start?: false
      )

    assert {:ok, _peer_id} = Identity.local_peer_id()
    assert is_integer(Discovery.listen_port(beacon))
  end

  test "emits telemetry for invalid announcements" do
    attach_telemetry([
      [:mob_runtime, :discovery, :decode_error],
      [:mob_runtime, :discovery, :peer, :up]
    ])

    {:ok, beacon} =
      Discovery.start_link(
        name: :mob_test_invalid_discovery,
        enabled?: true,
        id: "local",
        router: Router,
        listen_port: 0,
        target_port: :self,
        broadcast_ip: {127, 0, 0, 1},
        auto_start?: false
      )

    port = Discovery.listen_port(beacon)
    {:ok, socket} = :gen_udp.open(0, [:binary])

    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, port, "not-a-term")
    assert_receive {:telemetry, [:mob_runtime, :discovery, :decode_error], %{count: 1}, _}

    invalid = :erlang.term_to_binary({:bad_tag, "peer-a"})
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, port, invalid)
    assert_receive {:telemetry, [:mob_runtime, :discovery, :decode_error], %{count: 1}, _}

    valid = Discovery.encode_announcement("peer-a", :tcp, nil, %{})
    :ok = :gen_udp.send(socket, {127, 0, 0, 1}, port, valid)
    assert_receive {:telemetry, [:mob_runtime, :discovery, :peer, :up], %{count: 1}, _}

    :gen_udp.close(socket)
  end

  defp restart_runtime do
    Application.stop(:mob_runtime)
    {:ok, _apps} = Application.ensure_all_started(:mob_runtime)
    :ok
  end

  defp attach_telemetry(events) do
    id = {__MODULE__, self(), System.unique_integer([:positive])}

    :ok =
      :telemetry.attach_many(
        id,
        events,
        fn event, measurements, metadata, test_pid ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(id) end)
  end
end
