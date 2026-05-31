ExUnit.start()
Logger.configure(level: :warning)

db_path =
  Path.join(System.tmp_dir!(), "mob_runtime_test_#{System.unique_integer([:positive])}")

Application.stop(:mob_runtime)
Application.stop(:mob_store)

stop_store_processes = fn ->
  Enum.each([Mob.Store.DB, Mob.Store.Dedupe, Mob.Store.RelayCache], fn module ->
    if pid = Process.whereis(module), do: GenServer.stop(pid)
  end)
end

stop_store_processes.()

Application.put_env(:mob_store, :data_dir, db_path)

{:ok, _apps} = Application.ensure_all_started(:mob_runtime)

ExUnit.after_suite(fn _ ->
  Application.stop(:mob_runtime)
  Application.stop(:mob_store)
  stop_store_processes.()
  File.rm_rf(db_path)
end)
