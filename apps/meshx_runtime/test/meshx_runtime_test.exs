defmodule MeshxRuntimeTest do
  use ExUnit.Case
  doctest MeshxRuntime

  test "application starts successfully" do
    # meshx_runtime is started as part of the umbrella in tests.
    assert Application.started_applications()
           |> Enum.any?(fn {app, _, _} -> app == :meshx_runtime end)
  end
end
