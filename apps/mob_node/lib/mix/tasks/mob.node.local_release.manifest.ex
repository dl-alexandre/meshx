defmodule Mix.Tasks.Mob.Node.LocalRelease.Manifest do
  @moduledoc """
  Emits the advert-only local mesh release manifest.

      mix mob.node.local_release.manifest
      mix mob.node.local_release.manifest --json
      mix mob.node.local_release.manifest --json --out tmp/local-release.json

  The manifest is for the constrained advertisement-only local mode. It
  intentionally reports whole_project_complete? as false while project
  readiness remains open.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalReleaseManifest

  @shortdoc "Emit advert-only local mesh release manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalReleaseManifest.snapshot()
    json = LocalReleaseManifest.json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_manifest(manifest, json, opts.json?)
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

  defp print_manifest(_manifest, json, true), do: Mix.shell().info(json)

  defp print_manifest(manifest, _json, false) do
    Mix.shell().info(
      "LOCAL_RELEASE #{manifest.mode} releasable_with_limitations=#{manifest.releasable_with_limitations?} whole_project_complete=#{manifest.whole_project_complete?}"
    )

    Mix.shell().info(
      "READINESS open #{manifest.project_readiness.open_item_count} blocked #{manifest.project_readiness.blocked_item_count} partial #{manifest.project_readiness.partial_item_count}"
    )

    Mix.shell().info(
      "COMPLETION_REVIEW prompt_checklist #{length(manifest.completion_audit.prompt_artifact_checklist)} hardware_blocked #{length(manifest.completion_audit.blocker_matrix.blocked_by_new_hardware)} no_new_hardware #{length(manifest.completion_audit.blocker_matrix.can_progress_without_new_hardware)}"
    )

    coverage = manifest.completion_audit.review_template_coverage

    Mix.shell().info(
      "REVIEW_TEMPLATES covered=#{coverage.covered_review_count}/#{coverage.review_count} all_listed=#{coverage.all_review_templates_listed?}"
    )

    Mix.shell().info(
      "POLICY routing_claims_allowed=#{manifest.policy_gates.routing.routing_claims_allowed?} background_claims_allowed=#{manifest.policy_gates.lifecycle.background_claims_allowed?} ios_claims_allowed=#{manifest.policy_gates.ios_parity.ios_participation_claims_allowed?}"
    )
  end
end
