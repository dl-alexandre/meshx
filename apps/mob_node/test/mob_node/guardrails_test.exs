defmodule Mob.Node.GuardrailsTest do
  use ExUnit.Case, async: true

  alias Mob.Node.Guardrails

  test "test_paths/0 matches CI workflow guardrail list" do
    workflow =
      Path.expand("../../../../.github/workflows/ci.yml", __DIR__)
      |> File.read!()

    for path <- Guardrails.test_paths() do
      assert workflow =~ path
    end
  end
end