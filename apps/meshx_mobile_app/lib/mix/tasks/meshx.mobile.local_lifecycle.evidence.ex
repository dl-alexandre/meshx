defmodule Mix.Tasks.Meshx.Mobile.LocalLifecycle.Evidence do
  @moduledoc """
  Emits the local lifecycle evidence manifest.

      mix meshx.mobile.local_lifecycle.evidence
      mix meshx.mobile.local_lifecycle.evidence --json
      mix meshx.mobile.local_lifecycle.evidence --json --out tmp/local-lifecycle-evidence.json

  The manifest packages current foreground/manual lifecycle evidence and open
  background lifecycle gates. It intentionally keeps Android foreground-service,
  Android/iOS background BLE, automatic restart, scheduled retry, background
  gossip, and background delivery claims blocked.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalLifecycleEvidenceManifest

  @shortdoc "Emit local lifecycle evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalLifecycleEvidenceManifest.snapshot()
    json = LocalLifecycleEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_LIFECYCLE_EVIDENCE mode=#{manifest.current_mode} background_allowed=#{manifest.background_ble_claim_allowed?} restart_allowed=#{manifest.restart_claim_allowed?}"
    )

    Mix.shell().info(
      "LIFECYCLE_GATES open #{manifest.open_hardware_gate_count} scheduled_retry_allowed=#{manifest.scheduled_retry_claim_allowed?}"
    )

    Mix.shell().info(
      "LIFECYCLE_CAPTURE_PLAN sections=#{length(manifest.operator_capture_plan.capture_sections)} artifact_root=#{inspect(manifest.operator_capture_plan.artifact_root)}"
    )
  end
end
