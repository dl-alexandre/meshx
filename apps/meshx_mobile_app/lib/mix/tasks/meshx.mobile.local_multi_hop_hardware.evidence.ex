defmodule Mix.Tasks.Meshx.Mobile.LocalMultiHopHardware.Evidence do
  @moduledoc """
  Emits the local multi-hop hardware evidence manifest.

      mix meshx.mobile.local_multi_hop_hardware.evidence
      mix meshx.mobile.local_multi_hop_hardware.evidence --json
      mix meshx.mobile.local_multi_hop_hardware.evidence --json --out tmp/local-multi-hop-hardware-evidence.json

  The manifest packages replay evidence, the current one-hop hardware scope,
  and the open origin/relay/observer gates required before physical multi-hop
  advert gossip can be claimed.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalMultiHopHardwareEvidenceManifest

  @shortdoc "Emit local multi-hop hardware evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalMultiHopHardwareEvidenceManifest.snapshot()
    json = LocalMultiHopHardwareEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_MULTI_HOP_HARDWARE_EVIDENCE scope=#{manifest.current_hardware_scope} multi_hop_present=#{manifest.multi_hop_physical_proof_present?} multi_hop_allowed=#{manifest.multi_hop_hardware_gossip_claim_allowed?}"
    )

    Mix.shell().info(
      "MULTI_HOP_HARDWARE_GATES replay_policy=#{manifest.replay_policy_evidence_present?} one_hop_hardware=#{manifest.one_hop_hardware_evidence_present?} blocked #{manifest.blocked_gate_count}"
    )
  end
end
