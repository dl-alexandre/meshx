defmodule Mob.Runtime.TopologyTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias Mob.Protocol.{Codec, Gossip}
  alias Mob.Runtime.{PeerRegistry, Router, Topology}
  alias Mob.Store.{Dedupe, Identity, RelayCache, Trust}
  alias Mob.Routing.{Memory, Memory.Hub}

  setup do
    restart_runtime()
    Router.reset()
    PeerRegistry.reset()
    Hub.reset()
    Identity.clear()
    Trust.clear()
    Dedupe.clear()
    RelayCache.clear()
    Router.subscribe(self())

    {:ok, local} = Memory.start_link(id: "local", event_target: Router)
    :ok = Router.attach_transport(:memory, Memory, local)
    {:ok, _remote} = Memory.start_link(id: "remote", event_target: self())
    assert_receive {:mob_runtime, :peer_up, :memory, %{id: "remote"}}
    flush_transport_events()
    :ok
  end

  test "announces relay cache message IDs as gossip" do
    RelayCache.add(101, "a", 0)
    RelayCache.add(202, "b", 0)

    assert :ok = Topology.announce()
    assert_receive {:mob_routing, :memory, {:frame, "local", frame}}
    assert {:ok, packet, <<>>} = Codec.decode_packet(frame)
    assert packet.type == :gossip

    ids = packet |> Gossip.decode_gossip() |> Enum.sort()
    assert 101 in ids
    assert 202 in ids
  end

  test "scheduled announce broadcasts and reschedules when auto-started" do
    RelayCache.add(303, "c", 0)

    send(Process.whereis(Topology), :announce)

    assert_receive {:mob_routing, :memory, {:frame, "local", frame}}
    assert {:ok, packet, <<>>} = Codec.decode_packet(frame)
    assert 303 in Gossip.decode_gossip(packet)
  end

  defp flush_transport_events do
    receive do
      {:mob_routing, _transport, _event} -> flush_transport_events()
    after
      0 -> :ok
    end
  end

  defp restart_runtime do
    Application.stop(:mob_runtime)
    {:ok, _apps} = Application.ensure_all_started(:mob_runtime)
    :ok
  end
end
