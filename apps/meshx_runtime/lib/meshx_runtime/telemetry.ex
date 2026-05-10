defmodule MeshxRuntime.Telemetry do
  @moduledoc """
  Telemetry helpers for runtime operations.

  Events are emitted under the `[:meshx_runtime, ...]` prefix.
  """

  @spec execute([atom()], map(), map()) :: :ok
  def execute(event, measurements \\ %{}, metadata \\ []) when is_list(event) do
    :telemetry.execute([:meshx_runtime | event], measurements, Map.new(metadata))
  end
end
