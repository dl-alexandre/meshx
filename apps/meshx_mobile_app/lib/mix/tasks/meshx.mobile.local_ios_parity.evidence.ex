defmodule Mix.Tasks.Meshx.Mobile.LocalIosParity.Evidence do
  @moduledoc """
  Emits the local iOS parity evidence manifest.

      mix meshx.mobile.local_ios_parity.evidence
      mix meshx.mobile.local_ios_parity.evidence --json
      mix meshx.mobile.local_ios_parity.evidence --json --out tmp/local-ios-parity-evidence.json

  The manifest packages current iOS contract-only evidence and open iOS
  advert-only parity gates. It intentionally keeps iOS hardware participation,
  legacy beacon observe/gossip, full-envelope advert, hardware replay, and
  background BLE claims blocked.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalIOSParityEvidenceManifest

  @shortdoc "Emit local iOS parity evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalIOSParityEvidenceManifest.snapshot()
    json = LocalIOSParityEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_IOS_PARITY_EVIDENCE mode=#{manifest.current_ios_mode} participation_allowed=#{manifest.ios_participation_claim_allowed?} hardware_allowed=#{manifest.ios_hardware_claim_allowed?}"
    )

    Mix.shell().info(
      "IOS_PARITY_GATES open #{manifest.open_hardware_gate_count} background_allowed=#{manifest.ios_background_ble_claim_allowed?}"
    )
  end
end
