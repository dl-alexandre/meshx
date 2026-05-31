defmodule Mob.Protocol.FragmentTest do
  use ExUnit.Case
  alias Mob.Protocol.Fragment

  test "fragment and reassemble round-trip" do
    original_id = 1234
    payload = :crypto.strong_rand_bytes(500)
    frags = Fragment.fragment(original_id, payload, max_chunk_size: 100)

    assert length(frags) == 5
    assert Enum.all?(frags, fn p -> p.type == :fragment end)

    assert {:ok, ^original_id, reassembled} = Fragment.reassemble(frags)
    assert reassembled == payload
  end

  test "reassemble reports incomplete" do
    original_id = 999
    payload = :crypto.strong_rand_bytes(300)
    frags = Fragment.fragment(original_id, payload, max_chunk_size: 100)

    incomplete = Enum.take(frags, 2)
    assert {:incomplete, 2, 3} = Fragment.reassemble(incomplete)
  end

  test "complete?/1" do
    payload = :crypto.strong_rand_bytes(250)
    frags = Fragment.fragment(1, payload, max_chunk_size: 100)

    assert Fragment.complete?(frags)
    refute Fragment.complete?(Enum.take(frags, 1))
  end

  test "fragment assigns unique msg_ids" do
    frags = Fragment.fragment(1, :crypto.strong_rand_bytes(300), max_chunk_size: 100)
    ids = Enum.map(frags, & &1.msg_id)
    assert length(Enum.uniq(ids)) == length(ids)
  end

  test "single chunk when payload fits" do
    payload = <<1, 2, 3>>
    frags = Fragment.fragment(1, payload, max_chunk_size: 100)
    assert length(frags) == 1
    assert {:ok, 1, ^payload} = Fragment.reassemble(frags)
  end
end
