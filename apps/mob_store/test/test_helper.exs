ExUnit.start()
Logger.configure(level: :warning)

# Use an isolated temp database per test run.
db_path =
  Path.join(System.tmp_dir!(), "mob_store_test_#{System.unique_integer([:positive])}")

Application.put_env(:mob_store, :data_dir, db_path)

Application.stop(:mob_store)

Enum.each([Mob.Store.DB, Mob.Store.Dedupe, Mob.Store.RelayCache], fn module ->
  if pid = Process.whereis(module), do: GenServer.stop(pid)
end)

# Start the core processes manually. In umbrella test runs these may already be
# running because mob_runtime supervises them.
start_or_reuse = fn module ->
  case module.start_link([]) do
    {:ok, pid} ->
      Process.unlink(pid)
      pid

    {:error, {:already_started, pid}} ->
      pid
  end
end

start_or_reuse.(Mob.Store.DB)

defmodule Mob.Store.TestHelpers do
  @moduledoc false

  def ensure_db_started do
    case Mob.Store.DB.start_link([]) do
      {:ok, pid} ->
        Process.unlink(pid)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end
  end
end

# Clean up temp database and globally registered cache processes after all tests.
ExUnit.after_suite(fn _ ->
  Enum.each([Mob.Store.DB, Mob.Store.Dedupe, Mob.Store.RelayCache], fn module ->
    if pid = Process.whereis(module), do: GenServer.stop(pid)
  end)

  File.rm_rf(db_path)
end)
