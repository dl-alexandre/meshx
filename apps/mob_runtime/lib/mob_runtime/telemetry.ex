defmodule Mob.Runtime.Telemetry do
  @moduledoc """
  Telemetry helpers for runtime operations.

  Events are emitted under the `[:mob_runtime, ...]` prefix.
  """

  @spec execute([atom()], map(), map()) :: :ok
  def execute(event, measurements \\ %{}, metadata \\ []) when is_list(event) do
    :telemetry.execute([:mob_runtime | event], measurements, Map.new(metadata))
  end
end
