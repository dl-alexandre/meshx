defmodule Mob.Noise.Supervisor do
  @moduledoc """
  DynamicSupervisor for `Mob.Noise.Session` processes.
  """

  use DynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @spec start_session(keyword()) :: DynamicSupervisor.on_start_child()
  def start_session(opts \\ []) do
    spec = {Mob.Noise.Session, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @spec terminate_session(pid()) :: :ok | {:error, :not_found}
  def terminate_session(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
