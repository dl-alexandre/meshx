defmodule Mob.Node.Guardrails do
  @moduledoc """
  Host-side mesh/chat wiring checks to run before device install or release.

  Same paths as the CI step `MobNode mesh and chat wiring guardrails` in
  `.github/workflows/ci.yml`. Catches adapter env drift, router transport
  gaps, and chat ingress regressions in ~1s.
  """

  @app_test_paths [
    "test/mob_node/production_wiring_test.exs",
    "test/mob_node/mesh_status_test.exs",
    "test/mob_node/chat/",
    "test/mob_node/mob_ble_transport_wiring_test.exs",
    "test/mob_node/ble/adapter_test.exs"
  ]

  @doc "Test paths under `apps/mob_node/` (same files CI names from repo root)."
  @spec test_paths() :: [String.t()]
  def test_paths, do: @app_test_paths

  @doc """
  Runs guardrail tests. Returns `:ok` or `{:error, message}`.
  """
  @spec run() :: :ok | {:error, String.t()}
  def run do
    mix = System.find_executable("mix") || "mix"
    root = umbrella_root()
    args = ["test" | Enum.map(@app_test_paths, &Path.join("apps/mob_node", &1))]

    env =
      System.get_env()
      |> Map.put("MIX_ENV", "test")
      |> Map.new(fn {k, v} -> {k, v} end)

    IO.puts("MobNode guardrails (from #{root}):")
    IO.puts(Enum.join(args, " "))

    case System.cmd(mix, args, cd: root, env: env, stderr_to_stdout: true) do
      {output, 0} ->
        IO.write(output)
        :ok

      {output, status} ->
        IO.write(output)

        {:error,
         "mob_node guardrails failed (exit #{status}). Fix wiring tests before installing on device."}
    end
  end

  @doc "Like `run/0`, but raises on failure."
  @spec run!() :: :ok
  def run! do
    case run() do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end

  defp umbrella_root do
    find_umbrella_root(File.cwd!())
  end

  defp find_umbrella_root(dir) do
    if umbrella?(dir) do
      dir
    else
      parent = Path.dirname(dir)

      if parent == dir do
        Mix.raise("could not find mob mesh umbrella root (no mix.exs with apps/mob_node)")
      else
        find_umbrella_root(parent)
      end
    end
  end

  defp umbrella?(dir) do
    File.exists?(Path.join(dir, "mix.exs")) and
      File.exists?(Path.join(dir, "apps/mob_node/mix.exs"))
  end
end
