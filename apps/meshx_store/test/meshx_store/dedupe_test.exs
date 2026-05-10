defmodule MeshxStore.DedupeTest do
  use ExUnit.Case
  alias MeshxStore.Dedupe

  setup do
    start_dedupe!()
    Dedupe.clear()
    :ok
  end

  test "record?/1 detects duplicates" do
    assert Dedupe.record?(123) == false
    assert Dedupe.record?(123) == true
    assert Dedupe.record?(456) == false
  end

  test "seen?/1 checks without recording" do
    refute Dedupe.seen?(999)
    Dedupe.record(999)
    assert Dedupe.seen?(999)
  end

  test "ids/0 lists recorded message ids and clear/0 removes them" do
    Dedupe.record(10)
    Dedupe.record(20)

    assert Dedupe.ids() |> Enum.sort() == [10, 20]
    assert :ok = Dedupe.clear()
    assert Dedupe.ids() == []
  end

  test "cleanup removes expired entries" do
    :ets.insert(:meshx_dedupe, {777, System.monotonic_time(:millisecond) - 1})

    send(Process.whereis(Dedupe), :cleanup)
    assert_eventually(fn -> refute Dedupe.seen?(777) end)
  end

  test "start_link accepts custom ttl and cleanup interval" do
    restart_with(ttl_ms: 5, cleanup_interval_ms: 5)

    assert %{ttl_ms: 5, cleanup_interval_ms: 5} = :sys.get_state(Process.whereis(Dedupe))

    Dedupe.record(888)
    assert Dedupe.seen?(888)

    assert_eventually(fn -> refute Dedupe.seen?(888) end, 50)
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

  defp start_dedupe! do
    restart_with([])
  end

  defp restart_with(opts) do
    if pid = Process.whereis(Dedupe) do
      GenServer.stop(pid)
    end

    pid = start_link_unlinked!(opts)
    Process.unlink(pid)
    :ok
  end

  defp start_link_unlinked!(opts, attempts \\ 3)

  defp start_link_unlinked!(opts, attempts) when attempts > 0 do
    case Dedupe.start_link(opts) do
      {:ok, pid} ->
        pid

      {:error, {:already_started, pid}} ->
        GenServer.stop(pid)
        start_link_unlinked!(opts, attempts - 1)
    end
  end

  defp start_link_unlinked!(opts, 0) do
    {:ok, pid} = Dedupe.start_link(opts)
    Process.unlink(pid)
    pid
  end
end
