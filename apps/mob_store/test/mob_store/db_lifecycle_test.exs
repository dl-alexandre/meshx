defmodule Mob.Store.DBLifecycleTest do
  use ExUnit.Case

  test "stopping DB releases the CubDB file lock" do
    original_data_dir = Application.get_env(:mob_store, :data_dir)

    data_dir =
      Path.join(System.tmp_dir!(), "mob_store_lifecycle_#{System.unique_integer([:positive])}")

    on_exit(fn ->
      stop_named(Mob.Store.DB)
      Application.put_env(:mob_store, :data_dir, original_data_dir)
      File.rm_rf(data_dir)
      Mob.Store.TestHelpers.ensure_db_started()
    end)

    stop_named(Mob.Store.DB)
    Application.put_env(:mob_store, :data_dir, data_dir)

    {:ok, pid} = Mob.Store.DB.start_link([])
    cub = Mob.Store.DB.db()
    assert Process.alive?(cub)

    :ok = GenServer.stop(pid)
    assert_eventually(fn -> Process.whereis(Mob.Store.DB) == nil and not Process.alive?(cub) end)

    assert {:ok, pid} = Mob.Store.DB.start_link([])
    :ok = GenServer.stop(pid)
  end

  defp stop_named(module) do
    if pid = Process.whereis(module) do
      GenServer.stop(pid)
    end
  catch
    :exit, _ -> :ok
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(fun, 0), do: assert(fun.())
end
