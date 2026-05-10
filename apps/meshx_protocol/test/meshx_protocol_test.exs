defmodule MeshxProtocolTest do
  use ExUnit.Case
  doctest MeshxProtocol

  test "version/0 returns expected protocol version" do
    assert MeshxProtocol.version() == 0x01
  end
end
