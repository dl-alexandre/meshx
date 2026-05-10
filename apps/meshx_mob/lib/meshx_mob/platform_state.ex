defmodule MeshxMob.PlatformState do
  @moduledoc """
  In-memory mobile platform state with transition notifications.

  Wraps `MeshxMob.Platform` in a small GenServer so other components (the
  runtime router, transports, native bridges) can subscribe to background
  ↔ foreground transitions and react — for example by lowering BLE scan
  duty cycles, suspending discovery, or queuing outbound packets.

  Transitions are validated against the allowed mode set so callers get a
  clear error rather than silently flipping into a bogus state.
  """

  use GenServer

  alias MeshxMob.Platform

  @valid_modes [:foreground, :background, :suspended]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec get(GenServer.server()) :: Platform.t()
  def get(server \\ __MODULE__), do: GenServer.call(server, :get)

  @spec subscribe(GenServer.server(), pid()) :: :ok
  def subscribe(server \\ __MODULE__, pid \\ self()) do
    GenServer.call(server, {:subscribe, pid})
  end

  @spec unsubscribe(GenServer.server(), pid()) :: :ok
  def unsubscribe(server \\ __MODULE__, pid \\ self()) do
    GenServer.call(server, {:unsubscribe, pid})
  end

  @doc """
  Transitions the platform's background mode. Returns `{:ok, new_mode}` or
  `{:error, reason}` for unknown modes. Subscribers receive
  `{:meshx_mob, :background_mode, %{from: old, to: new}}`.
  """
  @spec transition(GenServer.server(), Platform.background_mode()) ::
          {:ok, Platform.background_mode()} | {:error, term()}
  def transition(server \\ __MODULE__, mode) do
    GenServer.call(server, {:transition, mode})
  end

  @impl true
  def init(opts) do
    platform =
      opts
      |> Keyword.get(:platform, %{os: :unknown})
      |> Platform.new()

    {:ok, %{platform: platform, subscribers: MapSet.new()}}
  end

  @impl true
  def handle_call(:get, _from, state), do: {:reply, state.platform, state}

  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {:reply, :ok, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_call({:transition, mode}, _from, state) when mode in @valid_modes do
    %{platform: platform, subscribers: subs} = state
    old = platform.background_mode
    platform = %{platform | background_mode: mode}

    if old != mode do
      notify(subs, {:meshx_mob, :background_mode, %{from: old, to: mode}})
    end

    {:reply, {:ok, mode}, %{state | platform: platform}}
  end

  def handle_call({:transition, mode}, _from, state) do
    {:reply, {:error, {:invalid_background_mode, mode}}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp notify(subs, msg), do: Enum.each(subs, &send(&1, msg))
end
