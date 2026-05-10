defmodule MeshxRuntime do
  @moduledoc """
  MeshX Runtime — top-level OTP application and coordinator.

  `meshx_runtime` depends on all other MeshX umbrella applications
  (`meshx_protocol`, `meshx_noise`, `meshx_store`, `meshx_transport`,
  `meshx_transport_ble`, `meshx_mob`) and is responsible for orchestrating
  them into a coherent mesh node.

  Starts the local store/cache workers and runtime coordinators:

    * `MeshxStore.DB` — durable local CubDB persistence
    * `MeshxStore.Dedupe` — duplicate suppression cache
    * `MeshxStore.RelayCache` — store-and-forward relay buffer
    * `MeshxNoise.Supervisor` — dynamic Noise session supervisor
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

  @impl true
  def start(_type, _args) do
    children = [
      MeshxStore.DB,
      MeshxStore.Dedupe,
      MeshxStore.RelayCache,
      MeshxNoise.Supervisor,
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
