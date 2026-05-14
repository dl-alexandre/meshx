defmodule Mix.Tasks.Meshx.Mobile.LocalSecurity.Evidence do
  @moduledoc """
  Emits the local BLE security evidence manifest.

      mix meshx.mobile.local_security.evidence
      mix meshx.mobile.local_security.evidence --json
      mix meshx.mobile.local_security.evidence --json --out tmp/local-security-evidence.json

  The manifest is an evidence artifact for the current local security
  boundaries. It intentionally keeps authenticated/trusted/delivery claims
  blocked while security gates remain open.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalSecurityEvidenceManifest

  @shortdoc "Emit local BLE security evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalSecurityEvidenceManifest.snapshot()
    json = LocalSecurityEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_SECURITY_EVIDENCE complete=#{manifest.security_evidence_complete?} trusted_message_allowed=#{manifest.trusted_message_claim_allowed?} trusted_delivery_allowed=#{manifest.trusted_delivery_claim_allowed?}"
    )

    Mix.shell().info(
      "SECURITY_GATES open #{manifest.open_security_gate_count} partial_fixture_groups #{manifest.partial_fixture_group_count} blocked_fixture_groups #{manifest.blocked_fixture_group_count}"
    )
  end
end
