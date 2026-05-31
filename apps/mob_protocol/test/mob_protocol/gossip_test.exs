defmodule Mob.Protocol.GossipTest do
  use ExUnit.Case
  alias Mob.Protocol.{Gossip, Packet}

  test "gossip packet round-trip" do
    ids = [1, 2, 3, 4, 5]
    packet = Gossip.gossip_packet(ids)
    assert packet.type == :gossip
    decoded = Gossip.decode_gossip(packet)
    assert decoded == Enum.reverse(ids) |> Enum.take(20) |> Enum.reverse()
  end

  test "merge returns union" do
    a = [1, 2, 3]
    b = [3, 4, 5]
    assert Gossip.merge(a, b) |> Enum.sort() == [1, 2, 3, 4, 5]
  end

  test "missing returns remote-only ids" do
    local = [1, 2, 3]
    remote = [3, 4, 5]
    assert Gossip.missing(local, remote) |> Enum.sort() == [4, 5]
  end

  test "gossip truncates to max_ids" do
    ids = Enum.to_list(1..100)
    packet = Gossip.gossip_packet(ids, max_ids: 10)
    decoded = Gossip.decode_gossip(packet)
    assert length(decoded) == 10
  end

  test "decode_gossip ignores non-gossip packets" do
    packet = Packet.new(:data, 1, <<>>)
    assert Gossip.decode_gossip(packet) == []
  end
end
