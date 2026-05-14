defmodule Mix.Tasks.Meshx.Mobile.LocalCompletion.Audit do
  @moduledoc """
  Emits the whole-project completion audit.

      mix meshx.mobile.local_completion.audit
      mix meshx.mobile.local_completion.audit --allow-open
      mix meshx.mobile.local_completion.audit --allow-open --json
      mix meshx.mobile.local_completion.audit --allow-open --json --out tmp/local-completion-audit.json

  By default this task exits nonzero while whole-project completion is still
  blocked. Use `--allow-open` for development/status reporting and release
  artifact generation.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalProjectCompletionAudit

  @shortdoc "Emit whole-project completion audit"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    snapshot = LocalProjectCompletionAudit.snapshot()
    json = LocalProjectCompletionAudit.json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_snapshot(snapshot, json, opts.json?)

    if Map.fetch!(snapshot, :completion_claim_allowed?) == false and not opts.allow_open? do
      Mix.raise("whole-project completion remains blocked")
    end
  end

  defp parse_args(args), do: parse_args(args, %{allow_open?: false, json?: false, out_path: nil})
  defp parse_args([], opts), do: opts

  defp parse_args(["--allow-open" | rest], opts),
    do: parse_args(rest, %{opts | allow_open?: true})

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

  defp print_snapshot(_snapshot, json, true), do: Mix.shell().info(json)

  defp print_snapshot(snapshot, _json, false) do
    Mix.shell().info(
      "LOCAL_COMPLETION_AUDIT #{snapshot.objective} completion_allowed=#{snapshot.completion_claim_allowed?}"
    )

    Mix.shell().info(
      "OPEN #{snapshot.open_item_count} blocked #{snapshot.blocked_item_count} partial #{snapshot.partial_item_count} not_started #{snapshot.not_started_item_count}"
    )

    Mix.shell().info(
      "PROMPT_CHECKLIST #{length(snapshot.prompt_artifact_checklist)} objectives=#{objective_ids(snapshot.prompt_artifact_checklist)}"
    )

    Mix.shell().info("OPEN_ITEMS #{length(snapshot.items)}")
    Enum.each(snapshot.items, &print_open_item/1)

    matrix = snapshot.blocker_matrix

    Mix.shell().info(
      "HARDWARE_BLOCKED #{length(matrix.blocked_by_new_hardware)} objectives=#{objective_ids(matrix.blocked_by_new_hardware)}"
    )

    Mix.shell().info(
      "NO_NEW_HARDWARE #{length(matrix.can_progress_without_new_hardware)} objectives=#{objective_ids(matrix.can_progress_without_new_hardware)}"
    )

    Mix.shell().info(
      "RECOMMENDED_NEXT objective=#{matrix.next_action_summary.recommended_now.objective_id} action=#{matrix.next_action_summary.recommended_now.next_unblock_action}"
    )

    coverage = snapshot.review_template_coverage

    Mix.shell().info(
      "REVIEW_TEMPLATES covered=#{coverage.covered_review_count}/#{coverage.review_count} all_listed=#{coverage.all_review_templates_listed?}"
    )
  end

  defp objective_ids(checklist) do
    checklist
    |> Enum.map(&objective_id/1)
    |> Enum.map_join(",", &Atom.to_string/1)
  end

  defp objective_id(%{objective_id: objective_id}), do: objective_id
  defp objective_id(objective_id) when is_atom(objective_id), do: objective_id

  defp print_open_item(item) do
    Mix.shell().info(
      "OPEN_ITEM objective=#{item.objective_id} status=#{item.status} missing=#{length(item.missing_evidence)}"
    )
  end
end
