defmodule Mob.Runtime.GroupKeyControlTest do
  use ExUnit.Case, async: true

  alias Mob.Noise.{SenderKey, SenderKeyDistribution}
  alias Mob.Runtime.GroupKeyControl

  test "distribution round-trips channel and SKDM bytes" do
    skdm = SenderKeyDistribution.encode(SenderKey.create())
    encoded = GroupKeyControl.distribution("#general", skdm)

    assert {:ok, {:distribution, "#general", ^skdm}} = GroupKeyControl.decode(encoded)
  end

  test "request round-trips channel and sender id" do
    encoded = GroupKeyControl.request("#general", "alice-id")
    assert {:ok, {:request, "#general", "alice-id"}} = GroupKeyControl.decode(encoded)
  end

  test "decode of a non-group-key payload is :unknown (lets callers fall through)" do
    assert {:error, :unknown} = GroupKeyControl.decode("MXN1...handshake")
    assert {:error, :unknown} = GroupKeyControl.decode(<<0, 1, 2>>)
  end

  test "decode of a truncated distribution is :malformed" do
    # channel_len says 5 but no channel/skdm follows
    assert {:error, :malformed} = GroupKeyControl.decode(<<"MXG1", 5::8, "ab">>)
  end

  test "decode of a distribution with empty SKDM is :malformed" do
    assert {:error, :malformed} = GroupKeyControl.decode(<<"MXG1", 3::8, "abc">>)
  end

  test "decode of a truncated request is :malformed" do
    assert {:error, :malformed} = GroupKeyControl.decode(<<"MXGR", 3::8, "abc", 9::8, "x">>)
  end
end
