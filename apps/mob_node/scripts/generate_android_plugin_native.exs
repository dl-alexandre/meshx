#!/usr/bin/env elixir

root = Path.expand(Path.join(__DIR__, "../../.."))
project_root = Path.join(root, "apps/mob_node")
mob_dev_root = Path.join(project_root, "deps/mob_dev")

Code.require_file(Path.join(mob_dev_root, "lib/mob_dev/android_plugin_native.ex"))

manifests =
  case System.argv() do
    [] -> nil
    paths -> Enum.map(paths, &Path.expand(&1, File.cwd!()))
  end

opts =
  [project_root: project_root]
  |> then(fn opts ->
    if manifests, do: Keyword.put(opts, :manifests, manifests), else: opts
  end)

case MobDev.AndroidPluginNative.generate(opts) do
  {:ok, count} ->
    IO.puts("Generated Android plugin native inputs for #{count} plugin(s).")

  {:error, reason} ->
    IO.puts(:stderr, "Failed to generate Android plugin native inputs: #{reason}")
    System.halt(1)
end
