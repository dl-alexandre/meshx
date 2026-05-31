defmodule Mob.Routing do
  @moduledoc """
  Abstract transport layer for MeshX.

  Transports expose a small common API for sending framed protocol bytes and
  emitting normalized events to a runtime process:

      {:mob_routing, transport_name, {:peer_up, peer}}
      {:mob_routing, transport_name, {:peer_down, peer_id}}
      {:mob_routing, transport_name, {:frame, peer_id, frame}}

  Concrete transports include the in-memory simulator
  `Mob.Routing.Memory`, the TCP node transport `Mob.Routing.TCP`, BLE
  adapters, LAN multicast, WebRTC, LoRa, and future transport-specific bridges.
  """

  use Application

  @type adapter :: module()
  @type transport :: pid()
  @type peer_id :: term()

  @callback send_frame(transport(), peer_id(), binary(), keyword()) :: :ok | {:error, term()}
  @callback broadcast_frame(transport(), binary(), keyword()) :: :ok | {:error, term()}
  @callback peers(transport()) :: [Mob.Routing.Peer.t()]

  @impl true
  def start(_type, _args) do
    children = [
      Mob.Routing.Memory.Hub
    ]

    opts = [strategy: :one_for_one, name: Mob.Routing.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc "Sends a frame through an adapter-backed transport process."
  @spec send_frame(adapter(), transport(), peer_id(), binary(), keyword()) ::
          :ok | {:error, term()}
  def send_frame(adapter, transport, peer_id, frame, opts \\ []) do
    adapter.send_frame(transport, peer_id, frame, opts)
  end

  @doc "Broadcasts a frame through an adapter-backed transport process."
  @spec broadcast_frame(adapter(), transport(), binary(), keyword()) :: :ok | {:error, term()}
  def broadcast_frame(adapter, transport, frame, opts \\ []) do
    adapter.broadcast_frame(transport, frame, opts)
  end

  @doc "Lists currently visible peers for a transport."
  @spec peers(adapter(), transport()) :: [Mob.Routing.Peer.t()]
  def peers(adapter, transport) do
    adapter.peers(transport)
  end
end
