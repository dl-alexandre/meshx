defmodule Mob.Routing.BLE do
  @moduledoc """
  BLE native bridge adapter for the MeshX stack.

  This is the MeshX-specific transport adapter layer. It wraps any bridge
  that speaks the small `{:ble_*}` event contract and normalizes those into
  `Mob.Routing` events for `mob_runtime`.

  ## Bridge contract & compatibility

  Bridge modules implement either:

    * `Mob.Routing.BLE.Bridge` (the MeshX-named behaviour, kept for
      desktop/custom MeshX consumers and BlueZ etc.), or
    * `Mob.Ble.Bridge` (the canonical, plugin-owned behaviour defined in
      the `mob_ble` Hex package; see `apps/mob_ble/lib/mob/ble/bridge.ex`).

  The three callbacks are identical; `Mob.Routing.BLE` uses dynamic dispatch
  (`module.fun`) so either works. `Mob.Ble.Bridge` is the authoritative
  contract for mobile production use via the `mob_ble` plugin.

  See `Mob.Routing.BLE.Bridge` moduledoc (and its CONTRACT SYNC marker),
  `docs/mob_ble_bridge_migration.md`, and the `mob_ble` package for details.

  Native bridge modules (or the production `Mob.Ble.MobileBridge`) are expected to
  send the following messages to this process:

      {:ble_peer_up, peer_id, metadata}
      {:ble_peer_down, peer_id}
      {:ble_frame, peer_id, frame}

  The adapter then emits:

      {:mob_routing, :ble, {:peer_up, peer}}
      {:mob_routing, :ble, {:peer_down, peer_id}}
      {:mob_routing, :ble, {:frame, peer_id, frame}}
  """

  @behaviour Mob.Routing

  use GenServer

  alias Mob.Routing.{Event, Peer}

  @transport :ble

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :event_target, self())
    GenServer.start_link(__MODULE__, opts)
  end

  @impl Mob.Routing
  def send_frame(transport, peer_id, frame, opts \\ []) do
    GenServer.call(transport, {:send_frame, peer_id, frame, opts})
  end

  @impl Mob.Routing
  def broadcast_frame(transport, frame, opts \\ []) do
    GenServer.call(transport, {:broadcast_frame, frame, opts})
  end

  @impl Mob.Routing
  def peers(transport) do
    GenServer.call(transport, :peers)
  end

  @impl true
  def init(opts) do
    bridge_module = Keyword.get(opts, :bridge, Mob.Routing.BLE.NoopBridge)
    event_target = Keyword.fetch!(opts, :event_target)
    bridge_opts = opts |> Keyword.get(:bridge_opts, []) |> Keyword.put(:event_target, self())

    with {:ok, bridge} <- bridge_module.start_link(bridge_opts) do
      {:ok,
       %{
         bridge: bridge,
         bridge_module: bridge_module,
         event_target: event_target,
         peers: %{}
       }}
    end
  end

  @impl true
  def handle_call({:send_frame, peer_id, frame, opts}, _from, state) do
    result = state.bridge_module.send_frame(state.bridge, peer_id, frame, opts)
    {:reply, result, state}
  end

  def handle_call({:broadcast_frame, frame, opts}, _from, state) do
    result = state.bridge_module.broadcast_frame(state.bridge, frame, opts)
    {:reply, result, state}
  end

  def handle_call(:peers, _from, state) do
    {:reply, Map.values(state.peers), state}
  end

  @impl true
  def handle_info({:ble_peer_up, peer_id, metadata}, state) do
    peer = Peer.new(peer_id, @transport, address: peer_id, metadata: metadata)
    send(state.event_target, Event.peer_up(@transport, peer))
    {:noreply, put_in(state.peers[peer_id], peer)}
  end

  def handle_info({:ble_peer_down, peer_id}, state) do
    send(state.event_target, Event.peer_down(@transport, peer_id))
    {:noreply, update_in(state.peers, &Map.delete(&1, peer_id))}
  end

  def handle_info({:ble_frame, peer_id, frame}, state) do
    send(state.event_target, Event.frame(@transport, peer_id, frame))
    {:noreply, state}
  end
end
