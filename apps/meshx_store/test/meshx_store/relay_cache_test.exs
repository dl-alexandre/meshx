defmodule MeshxStore.RelayCacheTest do
  use ExUnit.Case
  alias MeshxStore.RelayCache

  setup do
    start_relay_cache!()
    RelayCache.clear()
    :ok
  end

  test "add/get/remove round-trip" do
    :ok = RelayCache.add(1, "payload_a", 2)
    assert RelayCache.get(1) == {1, "payload_a", 2}

    :ok = RelayCache.remove(1)
    assert RelayCache.get(1) == nil
  end

  test "all/0 returns entries" do
    :ok = RelayCache.add(10, "x", 0)
    :ok = RelayCache.add(20, "y", 1)

    entries = RelayCache.all() |> Enum.sort_by(fn {id, _, _} -> id end)
    assert entries == [{10, "x", 0}, {20, "y", 1}]
  end

  test "count/0 reflects entries" do
    before = RelayCache.count()
    :ok = RelayCache.add(99, "z", 0)
    assert RelayCache.count() == before + 1
    :ok = RelayCache.remove(99)
    assert RelayCache.count() == before
  end

  test "message_ids/0 lists cached message ids and clear/0 removes them" do
    RelayCache.add(11, "a")
    RelayCache.add(22, "b")

    assert RelayCache.message_ids() |> Enum.sort() == [11, 22]
    assert :ok = RelayCache.clear()
    assert RelayCache.all() == []
  end

  test "cleanup removes entries older than the configured ttl" do
    old_inserted_at = System.monotonic_time(:millisecond) - :timer.minutes(11)
    :ets.insert(:meshx_relay_cache, {123, "stale", 0, old_inserted_at})

    send(Process.whereis(RelayCache), :cleanup)
    assert_eventually(fn -> assert RelayCache.get(123) == nil end)
  end

  test "start_link accepts custom ttl and cleanup interval" do
    restart_with(ttl_ms: 5, cleanup_interval_ms: 5)

    assert %{ttl_ms: 5, cleanup_interval_ms: 5} = :sys.get_state(Process.whereis(RelayCache))

    RelayCache.add(321, "short-lived")
    assert RelayCache.get(321) == {321, "short-lived", 0}

    assert_eventually(fn -> assert RelayCache.get(321) == nil end, 50)
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    try do
      fun.()
    rescue
      ExUnit.AssertionError ->
        Process.sleep(10)
        assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: fun.()

  defp start_relay_cache! do
    restart_with([])
  end

  defp restart_with(opts) do
    if pid = Process.whereis(RelayCache) do
      GenServer.stop(pid)
    end

    pid = start_link_unlinked!(opts)
    Process.unlink(pid)
    :ok
  end

  defp start_link_unlinked!(opts, attempts \\ 3)

  defp start_link_unlinked!(opts, attempts) when attempts > 0 do
    case RelayCache.start_link(opts) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        GenServer.stop(pid)
        start_link_unlinked!(opts, attempts - 1)
    end
  end

  defp start_link_unlinked!(opts, 0) do
    {:ok, pid} = RelayCache.start_link(opts)
    Process.unlink(pid)
    pid
  end
end
