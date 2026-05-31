defmodule Mix.Tasks.Mob.Node.LocalPersistence.LifecyclePlan do
  @moduledoc """
  Emits the production-default local inbox persistence lifecycle plan.

      mix mob.node.local_persistence.lifecycle_plan
      mix mob.node.local_persistence.lifecycle_plan --json
      mix mob.node.local_persistence.lifecycle_plan --json --out tmp/local-persistence-lifecycle-plan.json

  The plan is an operator checklist for deciding whether opt-in durable
  snapshots may become default app lifecycle behavior. It does not save,
  restore, migrate, prune, schedule cleanup, write in the background, resolve
  beacon refs, route, ACK, retry, encrypt, authenticate, or run mobile
  lifecycle hooks.
  """

  use Mix.Task

  alias Mob.Node.BLE.LocalPersistenceProductionLifecyclePlan

  @shortdoc "Emit production-default persistence lifecycle plan"

  @impl Mix.Task
  def run(args) do
    opts = parse_args(args)
    plan = LocalPersistenceProductionLifecyclePlan.snapshot()
    json = LocalPersistenceProductionLifecyclePlan.json_snapshot() |> JSON.encode!()

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
      "LOCAL_PERSISTENCE_LIFECYCLE_PLAN #{plan.boundary} current_default=#{plan.current_default_mode} production_default_allowed=#{plan.production_default_persistence_allowed?}"
    )

    Mix.shell().info(
      "PERSISTENCE_LIFECYCLE_GATES blocked=#{plan.blocked_gate_count} total=#{plan.gate_count} default_lifecycle_allowed=#{plan.default_lifecycle_claim_allowed?}"
    )

    Mix.shell().info("PERSISTENCE_LIFECYCLE_REQUIRED gates=#{gate_ids(plan.gates)}")

    Mix.shell().info(
      "PERSISTENCE_LIFECYCLE_NEXT evidence=#{inspect(next_missing_evidence(plan.gates))}"
    )
  end

  defp gate_ids(gates), do: Enum.map_join(gates, ",", &(&1.id |> Atom.to_string()))

  defp next_missing_evidence([gate | _rest]), do: Enum.join(gate.missing_evidence, " | ")
  defp next_missing_evidence([]), do: ""
end
