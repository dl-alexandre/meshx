defmodule Mob.ProtocolTest do
  use ExUnit.Case
  doctest Mob.Protocol

  test "version/0 returns expected protocol version" do
    assert Mob.Protocol.version() == 0x01
  end
end
