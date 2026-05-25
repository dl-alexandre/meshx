ExUnit.start()
Logger.configure(level: :warning)

db_path =
  Path.join(System.tmp_dir!(), "meshx_runtime_test_#{System.unique_integer([:positive])}")

Application.stop(:meshx_runtime)
Application.stop(:meshx_store)

stop_store_processes = fn ->
  Enum.each([MeshxStore.DB, MeshxStore.Dedupe, MeshxStore.RelayCache], fn module ->
    if pid = Process.whereis(module), do: GenServer.stop(pid)
  end)
end

stop_store_processes.()

Application.put_env(:meshx_store, :data_dir, db_path)

{:ok, _apps} = Application.ensure_all_started(:meshx_runtime)

ExUnit.after_suite(fn _ ->
  Application.stop(:meshx_runtime)
  Application.stop(:meshx_store)
  stop_store_processes.()
  File.rm_rf(db_path)
end)
