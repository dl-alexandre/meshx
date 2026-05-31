defmodule Mob.Routing.Memory.Hub do
  @moduledoc """
  Local simulator hub for `Mob.Routing.Memory` endpoints.

  The hub lets tests and desktop tooling exercise peer discovery, send, and
  broadcast behavior without BLE hardware.
  """

  use GenServer

  alias Mob.Routing.Peer

  @type node_id :: term()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec ensure_started() :: :ok
  def ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        case start_link([]) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

      _pid ->
        :ok
    end
  end

  @spec register(node_id(), pid(), keyword()) :: :ok | {:error, term()}
  def register(node_id, endpoint, opts \\ []) do
    GenServer.call(__MODULE__, {:register, node_id, endpoint, opts})
  end

  @spec unregister(node_id()) :: :ok
  def unregister(node_id) do
    GenServer.call(__MODULE__, {:unregister, node_id})
  end

  @spec deliver(node_id(), node_id(), binary()) :: :ok | {:error, :peer_not_found}
  def deliver(from_id, peer_id, frame) do
    GenServer.call(__MODULE__, {:deliver, from_id, peer_id, frame})
  end

  @spec broadcast(node_id(), binary(), keyword()) :: :ok
  def broadcast(from_id, frame, opts \\ []) do
    GenServer.call(__MODULE__, {:broadcast, from_id, frame, opts})
  end

  @spec peers(node_id()) :: [Peer.t()]
  def peers(node_id) do
    GenServer.call(__MODULE__, {:peers, node_id})
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(_opts) do
    {:ok, %{nodes: %{}, monitors: %{}}}
  end

  @impl true
  def handle_call({:register, node_id, endpoint, opts}, _from, state) do
    state = unregister_node(node_id, state)
    monitor = Process.monitor(endpoint)
    node = %{pid: endpoint, monitor: monitor, metadata: Keyword.get(opts, :metadata, %{})}

    Enum.each(state.nodes, fn {existing_id, existing} ->
      GenServer.cast(existing.pid, {:peer_up, peer_for(node_id, node)})
      GenServer.cast(endpoint, {:peer_up, peer_for(existing_id, existing)})
    end)

    nodes = Map.put(state.nodes, node_id, node)
    monitors = Map.put(state.monitors, monitor, node_id)

    {:reply, :ok, %{state | nodes: nodes, monitors: monitors}}
  end

  def handle_call({:unregister, node_id}, _from, state) do
    {:reply, :ok, unregister_node(node_id, state)}
  end

  def handle_call({:deliver, from_id, peer_id, frame}, _from, state) do
    case Map.fetch(state.nodes, peer_id) do
      {:ok, node} ->
        GenServer.cast(node.pid, {:frame, from_id, frame})
        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :peer_not_found}, state}
    end
  end

  def handle_call({:broadcast, from_id, frame, opts}, _from, state) do
    except = opts |> Keyword.get(:except, []) |> List.wrap() |> MapSet.new()

    state.nodes
    |> Enum.reject(fn {node_id, _node} -> node_id == from_id or MapSet.member?(except, node_id) end)
    |> Enum.each(fn {_node_id, node} -> GenServer.cast(node.pid, {:frame, from_id, frame}) end)

    {:reply, :ok, state}
  end

  def handle_call({:peers, node_id}, _from, state) do
    peers =
      state.nodes
      |> Enum.reject(fn {id, _node} -> id == node_id end)
      |> Enum.map(fn {id, node} -> peer_for(id, node) end)

    {:reply, peers, state}
  end

  def handle_call(:reset, _from, state) do
    Enum.each(state.monitors, fn {monitor, _node_id} -> Process.demonitor(monitor, [:flush]) end)
    {:reply, :ok, %{state | nodes: %{}, monitors: %{}}}
  end

  @impl true
  def handle_info({:DOWN, monitor, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, monitor) do
      {nil, _monitors} ->
        {:noreply, state}

      {node_id, monitors} ->
        {:noreply, unregister_node(node_id, %{state | monitors: monitors})}
    end
  end

  defp unregister_node(node_id, state) do
    case Map.pop(state.nodes, node_id) do
      {nil, nodes} ->
        %{state | nodes: nodes}

      {node, nodes} ->
        Process.demonitor(node.monitor, [:flush])
        monitors = Map.delete(state.monitors, node.monitor)

        Enum.each(nodes, fn {_existing_id, existing} ->
          GenServer.cast(existing.pid, {:peer_down, node_id})
        end)

        %{state | nodes: nodes, monitors: monitors}
    end
  end

  defp peer_for(node_id, node) do
    Peer.new(node_id, :memory, address: node_id, metadata: node.metadata)
  end
end
