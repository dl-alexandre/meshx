defmodule Mix.Tasks.Mob.Node.LocalSecurity.ReleaseReview do
  @moduledoc """
  Reviews local security release evidence metadata.

      mix mob.node.local_security.release_review
      mix mob.node.local_security.release_review --template --out artifacts/local-ble/run/security/evidence.json
      mix mob.node.local_security.release_review --input artifacts/local-ble/run/security/evidence.json
      mix mob.node.local_security.release_review --input artifacts/local-ble/run/security/evidence.json --json --out tmp/local-security-release-review.json

  Without `--input`, the review runs against an empty evidence package and
  reports missing security release evidence. The task does not persist keys,
  trust, or replay state; it only validates supplied metadata shape and
  blocked-claim callouts.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalSecurityReleaseEvidenceReview

  @shortdoc "Review local security release evidence"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)

    if opts.template? do
      print_template(opts)
    else
      input = read_input(opts.input_path)
      review = LocalSecurityReleaseEvidenceReview.review(input)
      json = LocalSecurityReleaseEvidenceReview.json_review(input) |> JSON.encode!()

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
      LocalSecurityReleaseEvidenceReview.template_input()
      |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    Mix.shell().info(json)
  end

  defp print_review(_review, json, true), do: Mix.shell().info(json)

  defp print_review(review, _json, false) do
    Mix.shell().info(
      "LOCAL_SECURITY_RELEASE_REVIEW status=#{review.status} complete=#{review.security_release_evidence_complete?}"
    )

    Mix.shell().info(
      "SECURITY_RELEASE_REVIEW missing #{length(review.missing)} attachments #{length(review.security_attachments)}"
    )

    maybe_print_template_hint(review)
  end

  defp maybe_print_template_hint(%{security_release_evidence_complete?: true}), do: :ok

  defp maybe_print_template_hint(_review) do
    Mix.shell().info(
      "SECURITY_RELEASE_TEMPLATE command=mix mob.node.local_security.release_review --template --out artifacts/local-ble/<run-id>/security/evidence.json"
    )
  end
end
