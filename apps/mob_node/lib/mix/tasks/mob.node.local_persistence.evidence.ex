defmodule Mix.Tasks.Mob.Node.LocalPersistence.Evidence do
  @moduledoc """
  Emits the local inbox persistence evidence manifest.

      mix mob.node.local_persistence.evidence
      mix mob.node.local_persistence.evidence --json
      mix mob.node.local_persistence.evidence --json --out tmp/local-persistence-evidence.json

  The manifest packages opt-in persistence evidence and open
  production-default lifecycle gates. It intentionally keeps default,
  background, delivery-record, and full-resolution claims blocked.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalPersistenceEvidenceManifest

  @shortdoc "Emit local inbox persistence evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalPersistenceEvidenceManifest.snapshot()
    json = LocalPersistenceEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_PERSISTENCE_EVIDENCE default=#{manifest.current_default_mode} opt_in_durable=#{manifest.opt_in_durable_snapshots_available?} production_default_allowed=#{manifest.production_default_persistence_allowed?}"
    )

    Mix.shell().info(
      "PERSISTENCE_GATES open #{manifest.open_production_gate_count} default_allowed=#{manifest.default_persistence_claim_allowed?} delivery_record_allowed=#{manifest.delivery_record_claim_allowed?}"
    )

    Mix.shell().info(
      "PERSISTENCE_CAPTURE_PLAN sections=#{length(manifest.operator_capture_plan.capture_sections)} artifact_root=#{inspect(manifest.operator_capture_plan.artifact_root)}"
    )
  end
end
