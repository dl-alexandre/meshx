defmodule Mix.Tasks.Meshx.Mobile.RemainingItems.Audit do
  @moduledoc """
  Emits the focused four-row remaining-items audit.

      mix meshx.mobile.remaining_items.audit
      mix meshx.mobile.remaining_items.audit --json
      mix meshx.mobile.remaining_items.audit --json --out artifacts/local-ble/<run-id>/manifests/focused-remaining-items-audit.json
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalFocusedRemainingItemsAudit

  @shortdoc "Emit focused remaining-items audit"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    audit = LocalFocusedRemainingItemsAudit.snapshot()
    json = LocalFocusedRemainingItemsAudit.json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_audit(audit, json, opts.json?)
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

  defp print_audit(_audit, json, true), do: Mix.shell().info(json)

  defp print_audit(audit, _json, false) do
    Mix.shell().info(
      "REMAINING_ITEMS complete=#{audit.complete} completed=#{length(audit.completed_rows)} incomplete=#{length(audit.incomplete_rows)} update_goal_allowed=#{audit.completion_decision.update_goal_allowed}"
    )

    Mix.shell().info(
      "CHECKLIST count=#{length(audit.prompt_to_artifact_checklist)} objective_success_criteria=#{length(audit.objective_success_criteria)}"
    )

    Enum.each(audit.rows, fn row ->
      Mix.shell().info(
        "ROW id=#{row.id} priority=#{row.priority} status=#{row.status} claim_allowed=#{row.completion_claim_allowed}"
      )
    end)

    Enum.each(audit.prompt_to_artifact_checklist, fn item ->
      Mix.shell().info(
        "CHECKLIST_ITEM id=#{item.id} status=#{item.status} rows=#{Enum.join(item.row_ids, ",")}"
      )
    end)
  end
end
