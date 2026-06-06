defmodule Mix.Tasks.Mob.Node.Guardrails do
  @shortdoc "Run mesh/chat wiring guardrails (same as CI pre-install check)"

  @moduledoc """
  Runs the fast mob_node integration tests that guard production BLE + chat wiring.

  Same suite as the `MobNode mesh and chat wiring guardrails` CI step. Use before
  `mix mob.node.deploy_device` so device installs do not ship broken adapter/router
  wiring.

      mix mob.node.guardrails
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mob.Node.Guardrails.run!()
  end
end