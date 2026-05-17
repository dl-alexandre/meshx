defmodule MeshxRuntime do
  @moduledoc """
  MeshX Runtime — top-level OTP application and coordinator.

  `meshx_runtime` depends on all other MeshX umbrella applications
  (`meshx_protocol`, `meshx_noise`, `meshx_store`, `meshx_transport`,
  `meshx_transport_ble`, `meshx_mob`) and is responsible for orchestrating
  them into a coherent mesh node.

  Starts runtime coordinators. Dependency applications normally own their
  own supervisors, including `meshx_store` for local persistence/cache
  workers and `meshx_noise` for dynamic Noise sessions. Lightweight
  script/test entrypoints that start `meshx_runtime` without those
  application workers get guarded fallback children for the missing
  processes.

    * `MeshxRuntime.SessionManager` — per-peer Noise XX session tracking
    * `MeshxRuntime.FragmentBuffer` — inbound packet fragment reassembly
    * `MeshxRuntime.PeerRegistry` — active peer tracking
    * `MeshxRuntime.FlowControl` — per-peer send windows and bounded queues
    * `MeshxRuntime.Router` — frame decode, dedupe, TTL relay, delivery
    * `MeshxRuntime.Discovery` — opt-in LAN discovery beacon
    * `MeshxRuntime.Outbox` — offline store-and-forward replay worker
    * `MeshxRuntime.Topology` — periodic gossip announcements
    * `MeshxRuntime.Telemetry` — runtime observability event helpers
  """

  use Application

  @dependency_apps [
    :meshx_protocol,
    :meshx_noise,
    :meshx_store,
    :meshx_transport,
    :meshx_transport_ble,
    :meshx_mob
  ]

  @impl true
  def start(_type, _args) do
    with :ok <- ensure_dependency_apps_started() do
      children =
        fallback_dependency_children() ++
          [
            MeshxRuntime.SessionManager,
            MeshxRuntime.FragmentBuffer,
            MeshxRuntime.PeerRegistry,
            MeshxRuntime.Router,
            {MeshxRuntime.Discovery, Application.get_env(:meshx_runtime, :discovery, [])},
            MeshxRuntime.Outbox,
            MeshxRuntime.Topology
          ]

      opts = [strategy: :one_for_one, name: MeshxRuntime.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end

  @doc false
  @spec ensure_dependency_workers_started() :: :ok | {:error, term()}
  def ensure_dependency_workers_started do
    with :ok <- ensure_dependency_apps_started() do
      Enum.reduce_while(fallback_dependency_children(), :ok, fn child, :ok ->
        case Supervisor.start_child(MeshxRuntime.Supervisor, child) do
          {:ok, _pid} -> {:cont, :ok}
          {:error, {:already_started, _pid}} -> {:cont, :ok}
          {:error, :already_present} -> {:cont, restart_dependency_child(child)}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp ensure_dependency_apps_started do
    Enum.reduce_while(@dependency_apps, :ok, fn app, :ok ->
      case Application.ensure_all_started(app) do
        {:ok, _apps} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {app, reason}}}
      end
    end)
  end

  defp fallback_dependency_children do
    [
      fallback_child(MeshxStore.DB),
      fallback_child(MeshxStore.Dedupe),
      fallback_child(MeshxStore.RelayCache),
      fallback_child(MeshxNoise.Supervisor)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp fallback_child(module) do
    if Process.whereis(module), do: nil, else: module
  end

  defp restart_dependency_child(child) do
    case Supervisor.restart_child(MeshxRuntime.Supervisor, child) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
