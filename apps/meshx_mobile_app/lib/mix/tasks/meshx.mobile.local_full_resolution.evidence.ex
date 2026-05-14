defmodule Mix.Tasks.Meshx.Mobile.LocalFullResolution.Evidence do
  @moduledoc """
  Emits the local full-message resolution evidence manifest.

      mix meshx.mobile.local_full_resolution.evidence
      mix meshx.mobile.local_full_resolution.evidence --json
      mix meshx.mobile.local_full_resolution.evidence --json --out tmp/local-full-resolution-evidence.json

  The manifest packages current BeaconRef, resolver, fetch request,
  planning, dry-run, and fake/offline fetch evidence. It intentionally keeps
  real transport resolution, delivery, trust, routing, and background claims
  blocked.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalFullMessageResolutionEvidenceManifest

  @shortdoc "Emit local full-message resolution evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalFullMessageResolutionEvidenceManifest.snapshot()
    json = LocalFullMessageResolutionEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_FULL_RESOLUTION_EVIDENCE mode=#{manifest.current_mode} real_transport_validated=#{manifest.real_fetch_transport_validated?} resolution_allowed=#{manifest.full_message_resolution_claim_allowed?}"
    )

    Mix.shell().info(
      "FULL_RESOLUTION_GATES satisfied #{manifest.satisfied_transport_gate_count} blocked #{manifest.blocked_transport_gate_count}"
    )
  end
end
