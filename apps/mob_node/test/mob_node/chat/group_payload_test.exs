defmodule Mob.Node.Chat.GroupPayloadTest do
  use ExUnit.Case, async: true

  alias Mob.Node.Chat.GroupPayload

  test "encode/decode round-trips generation and blob" do
    blob = :crypto.strong_rand_bytes(40)
    assert {:ok, 7, ^blob} = GroupPayload.decode(GroupPayload.encode(7, blob))
  end

  test "supports an empty blob" do
    assert {:ok, 0, ""} = GroupPayload.decode(GroupPayload.encode(0, ""))
  end

  test "non-group bytes decode as :not_group_payload (caller can treat as cleartext)" do
    assert {:error, :not_group_payload} = GroupPayload.decode("hello world")
  end

  test "a truncated header is :malformed" do
    assert {:error, :malformed} = GroupPayload.decode(<<"G1", 1, 2>>)
  end
end
