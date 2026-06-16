defmodule Mob.Noise.SenderKeyDistributionTest do
  use ExUnit.Case, async: true

  alias Mob.Noise.{SenderKey, SenderKeyDistribution}

  test "encode/decode round-trips a sender key" do
    {:ok, sk} = SenderKey.from(:binary.copy(<<9>>, 32), 42)
    {:ok, decoded} = SenderKeyDistribution.decode(SenderKeyDistribution.encode(sk))

    assert decoded.generation == 42
    assert decoded.chain_key == sk.chain_key
  end

  test "encoded size is fixed at 40 bytes" do
    blob = SenderKeyDistribution.encode(SenderKey.create())
    assert byte_size(blob) == SenderKeyDistribution.encoded_size()
    assert byte_size(blob) == 40
  end

  test "rejects bytes without the magic" do
    assert {:error, :missing_magic} = SenderKeyDistribution.decode(<<0, 1, 2, 3>>)
  end

  test "rejects an unsupported version" do
    <<magic::binary-size(3), _v, rest::binary>> = SenderKeyDistribution.encode(SenderKey.create())

    assert {:error, :unsupported_version} =
             SenderKeyDistribution.decode(<<magic::binary, 9, rest::binary>>)
  end

  test "rejects a truncated body" do
    <<head::binary-size(10), _::binary>> = SenderKeyDistribution.encode(SenderKey.create())
    assert {:error, :malformed} = SenderKeyDistribution.decode(head)
  end
end
