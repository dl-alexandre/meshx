defmodule Mix.Tasks.Mob.Node.LocalRouting.ValidationPlan do
  @moduledoc """
  Emits the production routing hardware validation plan.

      mix mob.node.local_routing.validation_plan
      mix mob.node.local_routing.validation_plan --json
      mix mob.node.local_routing.validation_plan --json --out tmp/local-routing-validation-plan.json

  The plan is an operator checklist for route table, selection, forwarding,
  delivery semantics, multi-hop hardware, TTL/loop, release evidence, and
  negative claim review. It does not route, forward, scan, advertise, persist,
  ACK, retry, fetch, encrypt, authenticate, or run background work.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalRoutingHardwareValidationPlan

  @shortdoc "Emit production routing validation plan"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    plan = LocalRoutingHardwareValidationPlan.snapshot()
    json = LocalRoutingHardwareValidationPlan.json_snapshot() |> JSON.encode!()

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
      "LOCAL_ROUTING_VALIDATION_PLAN #{plan.boundary} current_mode=#{plan.current_mode} route_selection_allowed=#{plan.route_selection_claim_allowed?} routed_delivery_allowed=#{plan.routed_delivery_claim_allowed?}"
    )

    Mix.shell().info(
      "ROUTING_VALIDATION_GATES blocked=#{plan.blocked_gate_count} total=#{plan.gate_count} forwarding_allowed=#{plan.forwarding_claim_allowed?}"
    )

    Mix.shell().info("ROUTING_VALIDATION_REQUIRED gates=#{gate_ids(plan.gates)}")

    Mix.shell().info(
      "ROUTING_VALIDATION_NEXT evidence=#{inspect(next_missing_evidence(plan.gates))}"
    )
  end

  defp gate_ids(gates), do: Enum.map_join(gates, ",", &(&1.id |> Atom.to_string()))

  defp next_missing_evidence([gate | _rest]), do: Enum.join(gate.missing_evidence, " | ")
  defp next_missing_evidence([]), do: ""
end
