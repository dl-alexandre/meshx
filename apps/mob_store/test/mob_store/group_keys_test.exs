defmodule Mob.Store.GroupKeysTest do
  use ExUnit.Case

  alias Mob.Store.GroupKeys

  setup do
    Mob.Store.TestHelpers.ensure_db_started()
    GroupKeys.clear()
    :ok
  end

  test "get returns nil for an unknown channel" do
    assert GroupKeys.get("#general") == nil
  end

  test "put then get round-trips an arbitrary session term" do
    session = %{sending: :some_chain, receiving: %{"peer" => :chain}}
    assert :ok = GroupKeys.put("#general", session)
    assert GroupKeys.get("#general") == session
  end

  test "channels lists only channels with stored state" do
    GroupKeys.put("#general", %{a: 1})
    GroupKeys.put("#ops", %{a: 2})
    assert Enum.sort(GroupKeys.channels()) == ["#general", "#ops"]
  end

  test "delete removes a single channel's state" do
    GroupKeys.put("#general", %{a: 1})
    GroupKeys.put("#ops", %{a: 2})
    assert :ok = GroupKeys.delete("#general")
    assert GroupKeys.get("#general") == nil
    assert GroupKeys.get("#ops") == %{a: 2}
    assert GroupKeys.channels() == ["#ops"]
  end

  test "update applies a read-modify-write atomically and returns the chosen value" do
    GroupKeys.put("#general", %{count: 0})

    result =
      GroupKeys.update("#general", fn session ->
        updated = %{session | count: session.count + 1}
        {updated.count, updated}
      end)

    assert result == 1
    assert GroupKeys.get("#general") == %{count: 1}
  end

  test "update on a missing channel sees nil and can initialize state" do
    result =
      GroupKeys.update("#new", fn
        nil -> {:created, %{count: 1}}
      end)

    assert result == :created
    assert GroupKeys.get("#new") == %{count: 1}
  end

  test "clear removes all group-key state" do
    GroupKeys.put("#a", %{})
    GroupKeys.put("#b", %{})
    assert :ok = GroupKeys.clear()
    assert GroupKeys.channels() == []
  end
end
