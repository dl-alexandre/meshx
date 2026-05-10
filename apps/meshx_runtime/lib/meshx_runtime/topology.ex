defmodule MeshxRuntime.Topology do
  @moduledoc """
  Gossip worker for lightweight topology/message availability announcements.
  """

  use GenServer

  alias MeshxProtocol.Gossip
  alias MeshxRuntime.Router
  alias MeshxStore.RelayCache

  @default_interval_ms :timer.seconds(30)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Broadcasts one gossip summary immediately."
  @spec announce(pid() | atom()) :: :ok
  def announce(pid \\ __MODULE__) do
    GenServer.call(pid, :announce)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    auto_start? = Keyword.get(opts, :auto_start?, true)

    if auto_start?, do: schedule(interval)
    {:ok, %{interval_ms: interval, auto_start?: auto_start?}}
  end

  @impl true
  def handle_call(:announce, _from, state) do
    {:reply, do_announce(), state}
  end

  @impl true
  def handle_info(:announce, %{interval_ms: interval, auto_start?: auto_start?} = state) do
    do_announce()
    if auto_start?, do: schedule(interval)
    {:noreply, state}
  end

  defp do_announce do
    packet = RelayCache.message_ids() |> Gossip.gossip_packet(ttl: 3)
    Router.broadcast_packet(packet)
  end

  defp schedule(interval) do
    Process.send_after(self(), :announce, interval)
  end
end
