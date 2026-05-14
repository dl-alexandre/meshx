defmodule Mix.Tasks.Meshx.Mobile.LocalInbox.UxValidationPlan do
  @moduledoc """
  Emits the Nearby Messages on-device UX validation plan.

      mix meshx.mobile.local_inbox.ux_validation_plan
      mix meshx.mobile.local_inbox.ux_validation_plan --json
      mix meshx.mobile.local_inbox.ux_validation_plan --json --out tmp/local-inbox-ux-validation-plan.json

  The plan is an operator checklist for product UX validation. It does not
  render UI, drive devices, scan, advertise, fetch, route, persist, ACK,
  retry, encrypt, or run background work.
  """

  use Mix.Task

  alias MeshxMobileApp.BLE.LocalInboxUxValidationPlan

  @shortdoc "Emit Nearby Messages on-device UX validation plan"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    plan = LocalInboxUxValidationPlan.snapshot()
    json = LocalInboxUxValidationPlan.json_snapshot() |> JSON.encode!()

    maybe_write_json(json, opts.out_path)
    print_plan(plan, json, opts.json?)
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

  defp print_plan(_plan, json, true), do: Mix.shell().info(json)

  defp print_plan(plan, _json, false) do
    Mix.shell().info(
      "LOCAL_INBOX_UX_VALIDATION_PLAN #{plan.boundary} production_ux_allowed=#{plan.production_ux_claim_allowed?}"
    )

    Mix.shell().info(
      "UX_VALIDATION_GATES open=#{plan.open_gate_count} satisfied=#{plan.satisfied_gate_count} blocked_claims=#{blocked_claims(plan.blocked_claims)}"
    )

    Mix.shell().info("UX_VALIDATION_REQUIRED gates=#{gate_ids(plan.gates)}")

    Mix.shell().info("UX_VALIDATION_NEXT evidence=#{inspect(next_required_evidence(plan.gates))}")
  end

  defp blocked_claims(claims), do: Enum.map_join(claims, ",", &Atom.to_string/1)
  defp gate_ids(gates), do: Enum.map_join(gates, ",", &(&1.id |> Atom.to_string()))

  defp next_required_evidence([gate | _rest]), do: Enum.join(gate.required_evidence, " | ")
  defp next_required_evidence([]), do: ""
end
