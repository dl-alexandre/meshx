defmodule Mix.Tasks.Meshx.Mobile.LocalCompletion.BlockerMatrix do
  @moduledoc """
  Emits the whole-project completion blocker matrix.

      mix meshx.mobile.local_completion.blocker_matrix
      mix meshx.mobile.local_completion.blocker_matrix --json
      mix meshx.mobile.local_completion.blocker_matrix --json --out tmp/local-completion-blocker-matrix.json

  The matrix classifies remaining whole-project work by blocker type. It is a
  planning and release evidence artifact only; it does not close hardware,
  transport, delivery, routing, trust, persistence, lifecycle, or iOS parity
  gates.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalProjectCompletionBlockerMatrix

  @shortdoc "Emit whole-project completion blocker matrix"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    snapshot = LocalProjectCompletionBlockerMatrix.snapshot()
    json = LocalProjectCompletionBlockerMatrix.json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_snapshot(snapshot, json, opts.json?)
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

  defp print_snapshot(_snapshot, json, true), do: Mix.shell().info(json)

  defp print_snapshot(snapshot, _json, false) do
    Mix.shell().info(
      "LOCAL_COMPLETION_BLOCKER_MATRIX #{snapshot.boundary} completion_allowed=#{snapshot.completion_claim_allowed?}"
    )

    Mix.shell().info(
      "BLOCKERS hardware #{length(snapshot.blocked_by_new_hardware)} non_hardware #{length(snapshot.can_progress_without_new_hardware)}"
    )

    Mix.shell().info(
      "HARDWARE_BLOCKED objectives=#{objective_ids(snapshot.blocked_by_new_hardware)}"
    )

    Mix.shell().info(
      "NO_NEW_HARDWARE objectives=#{objective_ids(snapshot.can_progress_without_new_hardware)}"
    )

    Mix.shell().info(
      "RECOMMENDED_NEXT objective=#{snapshot.next_action_summary.recommended_now.objective_id} action=#{snapshot.next_action_summary.recommended_now.next_unblock_action}"
    )
  end

  defp objective_ids(ids), do: Enum.map_join(ids, ",", &Atom.to_string/1)
end
