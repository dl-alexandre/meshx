defmodule MeshxTransport.Memory do
  @moduledoc """
  In-memory transport simulator.

  Each endpoint registers with `MeshxTransport.Memory.Hub`. Frames sent through
  one endpoint are delivered as normalized transport events to the target
  endpoint's configured `:event_target` process.
  """

  @behaviour MeshxTransport

  use GenServer

  alias MeshxTransport.{Capabilities, Event, Memory.Hub}

  @transport :memory

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    opts = Keyword.put_new(opts, :event_target, self())
    GenServer.start_link(__MODULE__, opts)
  end

  @impl MeshxTransport
  def send_frame(transport, peer_id, frame, _opts \\ []) do
    GenServer.call(transport, {:send_frame, peer_id, frame})
  end

  @impl MeshxTransport
  def broadcast_frame(transport, frame, opts \\ []) do
    GenServer.call(transport, {:broadcast_frame, frame, opts})
  end

  @impl MeshxTransport
  def peers(transport) do
    GenServer.call(transport, :peers)
  end

  @impl true
  def init(opts) do
    id = Keyword.fetch!(opts, :id)
    event_target = Keyword.fetch!(opts, :event_target)
    metadata =
      opts
      |> Keyword.get(:metadata, %{})
      |> maybe_put_mtu(Keyword.get(opts, :mtu))
      |> maybe_put_capabilities(Keyword.get(opts, :capabilities))

    :ok = Hub.ensure_started()
    :ok = Hub.register(id, self(), metadata: metadata)

    {:ok, %{id: id, event_target: event_target}}
  end

  @impl true
  def handle_call({:send_frame, peer_id, frame}, _from, %{id: id} = state) do
    {:reply, Hub.deliver(id, peer_id, frame), state}
  end

  def handle_call({:broadcast_frame, frame, opts}, _from, %{id: id} = state) do
    {:reply, Hub.broadcast(id, frame, opts), state}
  end

  def handle_call(:peers, _from, %{id: id} = state) do
    {:reply, Hub.peers(id), state}
  end

  @impl true
  def handle_cast({:peer_up, peer}, %{event_target: target} = state) do
    send(target, Event.peer_up(@transport, peer))
    {:noreply, state}
  end

  def handle_cast({:peer_down, peer_id}, %{event_target: target} = state) do
    send(target, Event.peer_down(@transport, peer_id))
    {:noreply, state}
  end

  def handle_cast({:frame, from_id, frame}, %{event_target: target} = state) do
    send(target, Event.frame(@transport, from_id, frame))
    {:noreply, state}
  end

  defp maybe_put_mtu(metadata, nil), do: metadata
  defp maybe_put_mtu(metadata, mtu), do: Map.put(metadata, :mtu, mtu)

  defp maybe_put_capabilities(metadata, nil), do: metadata

  defp maybe_put_capabilities(metadata, %Capabilities{} = capabilities) do
    Map.merge(metadata, Capabilities.to_metadata(capabilities))
  end

  defp maybe_put_capabilities(metadata, capabilities) when is_map(capabilities) or is_list(capabilities) do
    Map.merge(metadata, Capabilities.to_metadata(Capabilities.new(capabilities)))
  end
end
