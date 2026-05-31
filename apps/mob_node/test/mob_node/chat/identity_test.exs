defmodule Mob.Node.Chat.IdentityTest do
  use ExUnit.Case, async: false

  alias Mob.Node.Chat.Identity

  setup do
    Application.ensure_all_started(:mob_store)
    ensure_db_started()
    Identity.clear_nickname()

    on_exit(fn -> Identity.clear_nickname() end)

    :ok
  end

  test "get/0 returns the local peer_id with a default nickname when unset" do
    assert {:ok, %{peer_id: peer_id, nickname: nickname}} = Identity.get()
    assert is_binary(peer_id) and byte_size(peer_id) > 0
    assert nickname == Identity.default_nickname(peer_id)
    assert String.starts_with?(nickname, "anon-")
  end

  test "default_nickname/1 prefixes anon- and takes the first 8 chars" do
    assert Identity.default_nickname("abcdefghijkl") == "anon-abcdefgh"
    # short peer_id gracefully uses whatever bytes are available
    assert Identity.default_nickname("xyz") == "anon-xyz"
  end

  test "set_nickname/1 trims whitespace and persists across calls" do
    assert {:ok, %{nickname: "Alice"}} = Identity.set_nickname("  Alice  ")
    assert {:ok, %{nickname: "Alice"}} = Identity.get()
  end

  test "set_nickname/1 rejects empty or whitespace-only input" do
    assert {:error, :empty_nickname} = Identity.set_nickname("")
    assert {:error, :empty_nickname} = Identity.set_nickname("   ")

    # the previous (default) nickname is unaffected by a rejected attempt
    {:ok, before} = Identity.get()
    _ = Identity.set_nickname("")
    {:ok, after_attempt} = Identity.get()
    assert before == after_attempt
  end

  test "peer_id is stable across set_nickname calls (overlay leaves identity unchanged)" do
    {:ok, %{peer_id: peer_id}} = Identity.get()
    {:ok, %{peer_id: peer_id_after}} = Identity.set_nickname("Bob")
    assert peer_id == peer_id_after
  end

  defp ensure_db_started do
    case Mob.Store.DB.start_link([]) do
      {:ok, pid} ->
        Process.unlink(pid)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end
  end
end
