defmodule Mix.Tasks.Mob.Node.LocalInbox.UxEvidence do
  @moduledoc """
  Emits the Nearby Messages UX evidence manifest.

      mix mob.node.local_inbox.ux_evidence
      mix mob.node.local_inbox.ux_evidence --json
      mix mob.node.local_inbox.ux_evidence --json --out tmp/local-inbox-ux-evidence.json

  The manifest packages pure Nearby Messages surface coverage and open
  on-device validation gates. It intentionally keeps production UX,
  delivery, trust, routing, and background claims blocked.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalInboxUxEvidenceManifest

  @shortdoc "Emit Nearby Messages UX evidence manifest"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    manifest = LocalInboxUxEvidenceManifest.snapshot()
    json = LocalInboxUxEvidenceManifest.json_snapshot() |> JSON.encode!()

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
      "LOCAL_INBOX_UX_EVIDENCE production_ux_allowed=#{manifest.production_ux_claim_allowed?} rows=#{manifest.surface.row_count} states=#{length(manifest.surface.states)}"
    )

    Mix.shell().info(
      "UX_VALIDATION open #{manifest.validation_plan.open_gate_count} delivery_allowed=#{manifest.delivery_claim_allowed?} trusted_delivery_allowed=#{manifest.trusted_delivery_claim_allowed?}"
    )

    Mix.shell().info(
      "UX_SURFACE filter_summary=#{inspect(manifest.surface.filter_summary)} sort_summary=#{inspect(manifest.surface.sort_summary)}"
    )

    Mix.shell().info(
      "UX_BLOCKED_CLAIMS row_states=#{length(manifest.surface.row_blocked_claims)} routing_allowed=#{manifest.routing_claim_allowed?}"
    )

    Mix.shell().info(
      "UX_DETAIL_EVIDENCE states=#{detail_state_count(manifest)} all_delivery_blocked=#{all_detail_delivery_blocked?(manifest)}"
    )

    Mix.shell().info(
      "UX_DECISION selected=#{manifest.ux_decision_scenario_plan.selected_decision_outcome} scenarios=#{length(manifest.ux_decision_scenario_plan.decision_scenarios)} production_ux_allowed=#{manifest.ux_decision_scenario_plan.production_ux_claim_allowed?}"
    )

    Mix.shell().info("UX_COPY_REVIEW #{copy_review_anchor_summary(manifest)}")

    Mix.shell().info(
      "UX_CAPTURE_PLAN sections=#{length(manifest.operator_capture_plan.capture_sections)} artifact_root=#{inspect(manifest.operator_capture_plan.artifact_root)}"
    )
  end

  defp detail_state_count(manifest) do
    manifest.detail_evidence
    |> Enum.map(& &1.state)
    |> Enum.uniq()
    |> length()
  end

  defp all_detail_delivery_blocked?(manifest) do
    Enum.all?(manifest.detail_evidence, &(&1.delivery_claim_allowed? == false))
  end

  defp copy_review_anchor_summary(manifest) do
    gate =
      Enum.find(
        manifest.missing_on_device_evidence,
        &(&1.gate_id == :blocked_claim_copy_review)
      )

    artifact =
      Enum.find(
        manifest.required_artifacts,
        &(&1.id == :blocked_claim_copy_review)
      )

    required_evidence =
      gate
      |> Map.get(:required_evidence, [])
      |> Enum.join(" | ")

    purpose =
      artifact
      |> Map.get(:purpose, "")

    "required=#{inspect(required_evidence)} artifact=#{inspect(purpose)}"
  end
end
