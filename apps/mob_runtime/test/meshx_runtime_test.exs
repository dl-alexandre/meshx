defmodule Mob.RuntimeTest do
  use ExUnit.Case
  doctest Mob.Runtime

  test "application starts successfully" do
    # mob_runtime is started as part of the umbrella in tests.
    assert Application.started_applications()
           |> Enum.any?(fn {app, _, _} -> app == :mob_runtime end)
  end
end
