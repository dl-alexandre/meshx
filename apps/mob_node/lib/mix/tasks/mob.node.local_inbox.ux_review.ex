defmodule Mix.Tasks.Mob.Node.LocalInbox.UxReview do
  @moduledoc """
  Reviews Nearby Messages on-device UX evidence metadata.

      mix mob.node.local_inbox.ux_review
      mix mob.node.local_inbox.ux_review --template --out artifacts/local-ble/run/ux/evidence.json
      mix mob.node.local_inbox.ux_review --input artifacts/local-ble/run/ux/evidence.json
      mix mob.node.local_inbox.ux_review --input artifacts/local-ble/run/ux/evidence.json --json --out tmp/local-inbox-ux-review.json

  Without `--input`, the review runs against an empty evidence package and
  reports the required missing target devices, state coverage, interactions,
  copy review, and visual density review. The task never reads screenshots or
  approves delivery/trust/routing claims by itself; it only validates supplied
  metadata shape and wording gates.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalInboxUxEvidenceReview

  @shortdoc "Review Nearby Messages on-device UX evidence"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)

    if opts.template? do
      print_template(opts)
    else
      input = read_input(opts.input_path)
      review = LocalInboxUxEvidenceReview.review(input)
      json = LocalInboxUxEvidenceReview.json_review(input) |> JSON.encode!()

      maybe_write_json(json, opts.out_path)
      print_review(review, json, opts.json?)
    end
  end

  defp parse_args(args),
    do: parse_args(args, %{json?: false, template?: false, out_path: nil, input_path: nil})

  defp parse_args([], opts), do: opts
  defp parse_args(["--json" | rest], opts), do: parse_args(rest, %{opts | json?: true})
  defp parse_args(["--template" | rest], opts), do: parse_args(rest, %{opts | template?: true})

  defp parse_args(["--input", path | rest], opts) when is_binary(path) and path != "",
    do: parse_args(rest, %{opts | input_path: path})

  defp parse_args(["--out", path | rest], opts) when is_binary(path) and path != "",
    do: parse_args(rest, %{opts | out_path: path})

  defp parse_args(["--input"], _opts), do: Mix.raise("missing path for --input")
  defp parse_args(["--out"], _opts), do: Mix.raise("missing path for --out")
  defp parse_args([unknown | _rest], _opts), do: Mix.raise("unknown option(s): #{unknown}")

  defp read_input(nil), do: %{}

  defp read_input(path) do
    path
    |> File.read!()
    |> JSON.decode!()
  end

  defp maybe_write_json(_json, nil), do: :ok

  defp maybe_write_json(json, path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, json <> "\n")
  end

  defp print_template(%{input_path: path}) when is_binary(path),
    do: Mix.raise("--template cannot be combined with --input")

  defp print_template(opts) do
    json =
      LocalInboxUxEvidenceReview.template_input()
      |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    Mix.shell().info(json)
  end

  defp print_review(_review, json, true), do: Mix.shell().info(json)

  defp print_review(review, _json, false) do
    Mix.shell().info(
      "LOCAL_INBOX_UX_REVIEW status=#{review.status} complete=#{review.on_device_ux_evidence_complete?}"
    )

    Mix.shell().info(
      "LOCAL_INBOX_UX_REVIEW missing #{length(review.missing)} states #{length(review.required_states)} interactions #{length(review.required_interactions)}"
    )

    Mix.shell().info("LOCAL_INBOX_UX_COVERAGE #{coverage_summary(review.coverage_summary)}")

    Mix.shell().info("LOCAL_INBOX_UX_COPY_REVIEW #{copy_review_summary(review.copy_review)}")

    maybe_print_template_hint(review)
  end

  defp copy_review_summary(copy_review) do
    [
      "warnings_captured=#{copy_review.warning_text_captured}",
      "control_summaries_captured=#{copy_review.control_summaries_captured}",
      "state_blocked_claim_copy_captured=#{copy_review.state_blocked_claim_copy_captured}",
      "detail_panel_copy_captured=#{copy_review.detail_panel_copy_captured}",
      "blocked_claims=#{length(copy_review.blocked_claims_called_out)}"
    ]
    |> Enum.join(" ")
  end

  defp coverage_summary(summary) do
    [
      "targets=#{summary.target_device_count}",
      "state_items=#{summary.state_evidence_count}",
      "interaction_items=#{summary.interaction_evidence_count}",
      "selected_detail_items=#{summary.selected_detail_evidence_count}",
      "all_states=#{summary.all_target_devices_have_state_coverage?}",
      "all_interactions=#{summary.all_target_devices_have_interaction_coverage?}",
      "all_selected_details=#{summary.all_target_devices_have_selected_detail_coverage?}",
      "copy_reviewed=#{summary.all_target_devices_copy_reviewed?}",
      "density_reviewed=#{summary.all_target_devices_density_reviewed?}"
    ]
    |> Enum.join(" ")
  end

  defp maybe_print_template_hint(%{on_device_ux_evidence_complete?: true}), do: :ok

  defp maybe_print_template_hint(_review) do
    Mix.shell().info(
      "LOCAL_INBOX_UX_TEMPLATE command=mix mob.node.local_inbox.ux_review --template --out artifacts/local-ble/<run-id>/ux/evidence.json"
    )
  end
end
