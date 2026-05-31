defmodule Mix.Tasks.Mob.Node.LocalRouting.Evidence do
  @moduledoc """
  Emits the local routing evidence manifest.

      mix mob.node.local_routing.evidence
      mix mob.node.local_routing.evidence --json
      mix mob.node.local_routing.evidence --json --out tmp/local-routing-evidence.json

  The manifest packages current route-candidate evidence and open production
  routing gates. It intentionally keeps route selection, forwarding, routed
  delivery, ACK/retry, and multi-hop hardware routing claims blocked.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalRoutingEvidenceManifest

  @shortdoc "Emit local routing evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalRoutingEvidenceManifest.snapshot()
    json = LocalRoutingEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_ROUTING_EVIDENCE mode=#{manifest.current_mode} route_selection_allowed=#{manifest.route_selection_claim_allowed?} forwarding_allowed=#{manifest.forwarding_claim_allowed?}"
    )

    Mix.shell().info(
      "ROUTING_GATES candidates #{manifest.candidate_count} hardware_open #{manifest.hardware_blocked_gate_count} routed_delivery_allowed=#{manifest.routed_delivery_claim_allowed?}"
    )

    Mix.shell().info(
      "ROUTING_CAPTURE_PLAN sections=#{length(manifest.operator_capture_plan.capture_sections)} artifact_root=#{inspect(manifest.operator_capture_plan.artifact_root)}"
    )
  end
end
