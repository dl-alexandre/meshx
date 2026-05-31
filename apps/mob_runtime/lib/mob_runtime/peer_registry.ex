defmodule Mob.Runtime.PeerRegistry do
  @moduledoc """
  Tracks currently visible peers across transports.
  """

  use GenServer

  alias Mob.Routing.Peer
  alias Mob.Routing.Capabilities

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @spec up(Peer.t()) :: :ok
  def up(%Peer{} = peer) do
    GenServer.call(__MODULE__, {:up, peer})
  end

  @spec down(term()) :: :ok
  def down(peer_id) do
    GenServer.call(__MODULE__, {:down, peer_id})
  end

  @spec get(term()) :: Peer.t() | nil
  def get(peer_id) do
    GenServer.call(__MODULE__, {:get, peer_id})
  end

  @spec list() :: [Peer.t()]
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @spec capabilities(term()) :: Capabilities.t() | nil
  def capabilities(peer_id) do
    case get(peer_id) do
      nil -> nil
      %Peer{metadata: metadata} -> Capabilities.from_metadata(metadata)
    end
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:up, %Peer{id: id} = peer}, _from, state) do
    {:reply, :ok, Map.put(state, id, peer)}
  end

  def handle_call({:down, peer_id}, _from, state) do
    {:reply, :ok, Map.delete(state, peer_id)}
  end

  def handle_call({:get, peer_id}, _from, state) do
    {:reply, Map.get(state, peer_id), state}
  end

  def handle_call(:list, _from, state) do
    {:reply, Map.values(state), state}
  end

  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{}}
  end
end
