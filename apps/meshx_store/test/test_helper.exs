ExUnit.start()
Logger.configure(level: :warning)

# Use an isolated temp database per test run.
db_path =
  Path.join(System.tmp_dir!(), "meshx_store_test_#{System.unique_integer([:positive])}")

Application.put_env(:meshx_store, :data_dir, db_path)

Application.stop(:meshx_store)

Enum.each([MeshxStore.DB, MeshxStore.Dedupe, MeshxStore.RelayCache], fn module ->
  if pid = Process.whereis(module), do: GenServer.stop(pid)
end)

# Start the core processes manually. In umbrella test runs these may already be
# running because meshx_runtime supervises them.
start_or_reuse = fn module ->
  case module.start_link([]) do
    {:ok, pid} ->
      Process.unlink(pid)
      pid

    {:error, {:already_started, pid}} ->
      pid
  end
end

start_or_reuse.(MeshxStore.DB)

defmodule MeshxStore.TestHelpers do
  @moduledoc false

  def ensure_db_started do
    case MeshxStore.DB.start_link([]) do
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
  Enum.each([MeshxStore.DB, MeshxStore.Dedupe, MeshxStore.RelayCache], fn module ->
    if pid = Process.whereis(module), do: GenServer.stop(pid)
  end)

  File.rm_rf(db_path)
end)
