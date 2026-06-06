defmodule Mob.Node.TestSupport.RecordingBleBridge do
  @moduledoc false
  @behaviour Mob.Ble.Bridge

  use GenServer

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name))
  end

  @spec last_broadcast(pid() | atom()) :: binary() | nil
  def last_broadcast(server \\ __MODULE__) do
    GenServer.call(server, :last_broadcast)
  end

  @impl true
  def init(opts) do
    {:ok, %{event_target: Keyword.get(opts, :event_target), last_broadcast: nil}}
  end

  @impl true
  def handle_call(:last_broadcast, _from, state) do
    {:reply, state.last_broadcast, state}
  end

  @impl true
  def send_frame(_bridge, _peer_id, _frame, _opts), do: :ok

  @impl true
  def broadcast_frame(bridge, frame, _opts) do
    GenServer.call(bridge, {:broadcast, frame})
  end

  @impl true
  def handle_call({:broadcast, frame}, _from, state) do
    {:reply, :ok, %{state | last_broadcast: frame}}
  end
end