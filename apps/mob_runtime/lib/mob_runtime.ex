defmodule Mob.Runtime do
  @moduledoc """
  MeshX Runtime — top-level OTP application and coordinator.

  `mob_runtime` depends on all other MeshX umbrella applications
  (`mob_protocol`, `mob_noise`, `mob_store`, `mob_routing`,
  `mob_routing_ble`, `mob_node`) and is responsible for orchestrating
  them into a coherent mesh node.

  Starts runtime coordinators. Dependency applications normally own their
  own supervisors, including `mob_store` for local persistence/cache
  workers and `mob_noise` for dynamic Noise sessions. Lightweight
  script/test entrypoints that start `mob_runtime` without those
  application workers get guarded fallback children for the missing
  processes.

    * `Mob.Runtime.SessionManager` — per-peer Noise XX session tracking
    * `Mob.Runtime.FragmentBuffer` — inbound packet fragment reassembly
    * `Mob.Runtime.PeerRegistry` — active peer tracking
    * `Mob.Runtime.FlowControl` — per-peer send windows and bounded queues
    * `Mob.Runtime.Router` — frame decode, dedupe, TTL relay, delivery
    * `Mob.Runtime.Discovery` — opt-in LAN discovery beacon
    * `Mob.Runtime.Outbox` — offline store-and-forward replay worker
    * `Mob.Runtime.Topology` — periodic gossip announcements
    * `Mob.Runtime.Telemetry` — runtime observability event helpers
  """

  use Application

  # NOTE: :mob_node intentionally NOT in this list. Pre-rename this was
  # :meshx_mob — a tiny shim with platform abstractions safe to start from
  # the runtime. After absorption into mob_node, including :mob_node here
  # causes a startup deadlock: mob_node depends on mob_runtime, so
  # Application.ensure_all_started(:mob_node) blocks waiting for runtime
  # to come up — which is exactly the caller. The runtime doesn't need
  # the mobile-app started; consumers that do can start mob_node
  # themselves.
  @dependency_apps [
    :mob_protocol,
    :mob_noise,
    :mob_store,
    :mob_routing,
    :mob_routing_ble
  ]

  @impl true
  def start(_type, _args) do
    with :ok <- ensure_dependency_apps_started() do
      children =
        fallback_dependency_children() ++
          [
            Mob.Runtime.SessionManager,
            Mob.Runtime.FragmentBuffer,
            Mob.Runtime.PeerRegistry,
            Mob.Runtime.Router,
            {Mob.Runtime.Discovery, Application.get_env(:mob_runtime, :discovery, [])},
            Mob.Runtime.Outbox,
            Mob.Runtime.Topology
          ]

      opts = [strategy: :one_for_one, name: Mob.Runtime.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end

  @doc false
  @spec ensure_dependency_workers_started() :: :ok | {:error, term()}
  def ensure_dependency_workers_started do
    with :ok <- ensure_dependency_apps_started() do
      Enum.reduce_while(fallback_dependency_children(), :ok, fn child, :ok ->
        case Supervisor.start_child(Mob.Runtime.Supervisor, child) do
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
      fallback_child(Mob.Store.DB),
      fallback_child(Mob.Store.Dedupe),
      fallback_child(Mob.Store.RelayCache),
      fallback_child(Mob.Noise.Supervisor)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp fallback_child(module) do
    if Process.whereis(module), do: nil, else: module
  end

  defp restart_dependency_child(child) do
    case Supervisor.restart_child(Mob.Runtime.Supervisor, child) do
      {:ok, _pid} -> :ok
      {:ok, _pid, _info} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
