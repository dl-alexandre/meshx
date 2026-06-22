defmodule Mob.Noise.SenderKeyTest do
  use ExUnit.Case, async: true

  alias Mob.Noise.SenderKey

  test "create/0 starts at generation 0 with a 32-byte chain key" do
    sk = SenderKey.create()
    assert sk.generation == 0
    assert byte_size(sk.chain_key) == SenderKey.chain_key_size()
  end

  test "create/0 is random per call" do
    refute SenderKey.create().chain_key == SenderKey.create().chain_key
  end

  test "advance/1 returns the current generation's message key and advances the chain" do
    sk = SenderKey.create()
    {%{generation: g0, message_key: mk0}, sk1} = SenderKey.advance(sk)

    assert g0 == 0
    assert byte_size(mk0) == SenderKey.message_key_size()
    assert sk1.generation == 1
    refute sk1.chain_key == sk.chain_key
  end

  test "advance is deterministic for a given chain key (two holders agree)" do
    {:ok, a} = SenderKey.from(:binary.copy(<<7>>, 32), 0)
    {:ok, b} = SenderKey.from(:binary.copy(<<7>>, 32), 0)

    {%{message_key: mk_a}, _} = SenderKey.advance(a)
    {%{message_key: mk_b}, _} = SenderKey.advance(b)
    assert mk_a == mk_b
  end

  test "consecutive generations produce distinct message keys" do
    keys =
      Enum.map_reduce(0..9, SenderKey.create(), fn _i, chain ->
        {%{message_key: mk}, next} = SenderKey.advance(chain)
        {mk, next}
      end)
      |> elem(0)

    assert length(Enum.uniq(keys)) == 10
  end

  test "knowing a message key does not reveal the next chain key" do
    # message_key uses constant 0x01, chain advance uses 0x02 — distinct macs.
    sk = SenderKey.create()
    {%{message_key: mk}, next} = SenderKey.advance(sk)
    refute mk == next.chain_key
  end

  describe "from/2" do
    test "rejects a non-32-byte chain key" do
      assert {:error, :invalid_chain_key} = SenderKey.from(<<1, 2, 3>>, 0)
    end

    test "rejects a negative generation" do
      assert {:error, :invalid_generation} = SenderKey.from(:binary.copy(<<0>>, 32), -1)
    end

    test "accepts a valid key + generation" do
      assert {:ok, %SenderKey{generation: 5}} = SenderKey.from(:binary.copy(<<0>>, 32), 5)
    end
  end
end
