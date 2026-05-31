defmodule Mix.Tasks.Mob.Node.LocalRelease.ArtifactBundle do
  @moduledoc """
  Emits the advert-only local mesh release artifact bundle checklist.

      mix mob.node.local_release.artifact_bundle
      mix mob.node.local_release.artifact_bundle --json
      mix mob.node.local_release.artifact_bundle --json --out tmp/local-release-artifact-bundle.json

  The bundle is an operator-facing checklist. It records generated, embedded,
  and still-open release-candidate artifacts without accepting hardware claims
  or release wording by itself.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalReleaseArtifactBundle

  @shortdoc "Emit advert-only local mesh release artifact bundle checklist"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    bundle = LocalReleaseArtifactBundle.snapshot()
    json = LocalReleaseArtifactBundle.json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_bundle(bundle, json, opts.json?)
  end

  defp parse_args(args), do: parse_args(args, %{json?: false, out_path: nil})
  defp parse_args([], opts), do: opts
  defp parse_args(["--json" | rest], opts), do: parse_args(rest, %{opts | json?: true})

  defp parse_args(["--out", path | rest], opts) when is_binary(path) and path != "",
    do: parse_args(rest, %{opts | out_path: path})

  defp parse_args(["--out"], _opts), do: Mix.raise("missing path for --out")
  defp parse_args([unknown | _rest], _opts), do: Mix.raise("unknown option(s): #{unknown}")

  defp maybe_write_json(_json, nil), do: :ok

  defp maybe_write_json(json, path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, json <> "\n")
  end

  defp print_bundle(_bundle, json, true), do: Mix.shell().info(json)

  defp print_bundle(bundle, _json, false) do
    Mix.shell().info(
      "LOCAL_RELEASE_ARTIFACT_BUNDLE #{bundle.boundary} complete=#{bundle.release_candidate_complete?}"
    )

    Mix.shell().info(
      "ARTIFACTS total #{bundle.artifact_count} open #{bundle.open_artifact_count}"
    )
  end
end
