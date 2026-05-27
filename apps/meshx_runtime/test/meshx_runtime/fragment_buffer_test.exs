defmodule MeshxRuntime.FragmentBufferTest do
  use ExUnit.Case, async: true

  alias MeshxProtocol.Fragment
  alias MeshxRuntime.FragmentBuffer

  describe "eviction (pure)" do
    test "put_fragment preserves first_seen across adds and accumulates fragments" do
      b = FragmentBuffer.put_fragment(%{}, 7, 0, :p0, 1_000)
      b = FragmentBuffer.put_fragment(b, 7, 1, :p1, 5_000)

      assert b[7].first_seen_ms == 1_000
      assert map_size(b[7].fragments) == 2
    end

    test "evict_expired drops entries at/after the TTL and keeps fresh ones" do
      buffers = %{
        1 => %{fragments: %{0 => :p}, first_seen_ms: 0},
        2 => %{fragments: %{0 => :p}, first_seen_ms: 20_000}
      }

      {kept, dropped} = FragmentBuffer.evict_expired(buffers, 40_000, 30_000)

      assert dropped == [1]
      assert Map.keys(kept) == [2]
    end

    test "enforce_max drops the oldest entries beyond the cap" do
      big = for i <- 1..4, into: %{}, do: {i, %{fragments: %{}, first_seen_ms: i}}

      {kept, dropped} = FragmentBuffer.enforce_max(big, 2)

      assert Enum.sort(dropped) == [1, 2]
      assert Enum.sort(Map.keys(kept)) == [3, 4]
    end

    test "enforce_max is a no-op under the cap" do
      big = for i <- 1..3, into: %{}, do: {i, %{fragments: %{}, first_seen_ms: i}}
      assert {^big, []} = FragmentBuffer.enforce_max(big, 10)
    end
  end

  describe "reassembly contract (GenServer)" do
    setup do
      # Unnamed instance + direct GenServer.call so the test never collides with
      # the app-supervised FragmentBuffer that add/1 targets by module name.
      pid = start_supervised!({FragmentBuffer, name: nil, auto_sweep?: false, max_entries: 8})
      %{buffer: pid}
    end

    test "reassembles a fragmented frame and matches the original payload", %{buffer: buffer} do
      payload = :crypto.strong_rand_bytes(600)
      frags = Fragment.fragment(12_345, payload, max_chunk_size: 185)

      results = Enum.map(frags, &GenServer.call(buffer, {:add, &1}))

      assert {:complete, 12_345, ^payload} = List.last(results)
      assert Enum.all?(Enum.drop(results, -1), &match?({:partial, _, _}, &1))
    end

    test "rejects malformed fragments", %{buffer: buffer} do
      packet = %MeshxProtocol.Packet{type: :fragment, msg_id: 0, payload: <<>>}
      assert {:error, :malformed_fragment} = GenServer.call(buffer, {:add, packet})
    end
  end
end
