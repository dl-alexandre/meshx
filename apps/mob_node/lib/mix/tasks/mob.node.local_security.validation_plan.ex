defmodule Mix.Tasks.Mob.Node.LocalSecurity.ValidationPlan do
  @moduledoc """
  Emits the authenticated local BLE security validation plan.

      mix mob.node.local_security.validation_plan
      mix mob.node.local_security.validation_plan --json
      mix mob.node.local_security.validation_plan --json --out tmp/local-security-validation-plan.json

  The plan is an operator checklist for authenticated peer identity,
  authorship, replay, trust lifecycle, beacon authentication, and negative
  claim evidence. It does not create keys, persist trust, persist replay
  state, fetch envelopes, route, ACK, retry, encrypt, or run background work.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalSecurityIdentityValidationPlan

  @shortdoc "Emit authenticated local BLE security validation plan"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    plan = LocalSecurityIdentityValidationPlan.snapshot()
    json = LocalSecurityIdentityValidationPlan.json_snapshot() |> JSON.encode!()

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
      "LOCAL_SECURITY_VALIDATION_PLAN #{plan.boundary} current_mode=#{plan.current_mode} trusted_message_allowed=#{plan.trusted_message_claim_allowed?} trusted_delivery_allowed=#{plan.trusted_delivery_claim_allowed?}"
    )

    Mix.shell().info(
      "SECURITY_VALIDATION_GATES blocked=#{plan.blocked_gate_count} total=#{plan.gate_count} authenticated_peer_allowed=#{plan.authenticated_peer_identity_claim_allowed?}"
    )

    Mix.shell().info("SECURITY_VALIDATION_REQUIRED gates=#{gate_ids(plan.gates)}")

    Mix.shell().info(
      "SECURITY_VALIDATION_NEXT evidence=#{inspect(next_missing_evidence(plan.gates))}"
    )
  end

  defp gate_ids(gates), do: Enum.map_join(gates, ",", &(&1.id |> Atom.to_string()))

  defp next_missing_evidence([gate | _rest]), do: Enum.join(gate.missing_evidence, " | ")
  defp next_missing_evidence([]), do: ""
end
