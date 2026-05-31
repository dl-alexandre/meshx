defmodule Mob.Store.MessageTest do
  use ExUnit.Case
  alias Mob.Store.Message

  setup do
    Mob.Store.TestHelpers.ensure_db_started()
    Message.clear()
    :ok
  end

  test "insert validates required fields" do
    assert {:error, :missing_msg_id} = Message.insert(%{payload: "test payload"})
    assert {:error, :missing_payload} = Message.insert(%{msg_id: 99})
  end

  test "insert and retrieve a message" do
    attrs = %{
      msg_id: 99,
      sender: <<1, 2, 3>>,
      payload: "test payload",
      hops: 2,
      ttl: 60,
      received_at: DateTime.utc_now()
    }

    assert {:ok, msg} = Message.insert(attrs)

    assert msg.msg_id == 99
    assert msg.hops == 2

    retrieved = Message.get(99)
    assert retrieved.msg_id == 99
    assert retrieved.payload == "test payload"
  end
end
