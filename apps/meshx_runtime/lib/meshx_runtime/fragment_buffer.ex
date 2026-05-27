defmodule MeshxRuntime.FragmentBuffer do
  @moduledoc """
  Buffers inbound fragment packets until the original frame can be reassembled.

  The protocol fragment payload contains the original message id, fragment index,
  total fragment count, and byte chunk. The router fragments whole encoded
  protocol frames, so successful reassembly returns the original frame binary.

  Incomplete reassemblies are bounded two ways so a lossy peer (fragments that
  never complete) cannot grow the buffer without limit:

    * a per-message reassembly TTL (`:reassembly_ttl_ms`, default 30s) swept
      periodically (`:sweep_interval_ms`, default 10s), and
    * a hard cap on concurrent in-flight reassemblies (`:max_entries`,
      default 256) that drops the oldest when exceeded.

  Dropped incomplete reassemblies emit `[:meshx_runtime, :fragment_buffer, :evict]`
  telemetry with the `:reason` (`:ttl` or `:capacity`).
  """

  use GenServer

  alias MeshxProtocol.{Fragment, Packet}
  alias MeshxRuntime.Telemetry

  @default_reassembly_ttl_ms :timer.seconds(30)
  @default_sweep_interval_ms :timer.seconds(10)
  @default_max_entries 256

  @type add_result ::
          {:complete, non_neg_integer(), binary()}
          | {:partial, non_neg_integer(), pos_integer()}
          | {:error, term()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec add(Packet.t()) :: add_result()
  def add(%Packet{type: :fragment} = packet) do
    GenServer.call(__MODULE__, {:add, packet})
  end

  @doc false
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(opts) do
    config = %{
      reassembly_ttl_ms: Keyword.get(opts, :reassembly_ttl_ms, @default_reassembly_ttl_ms),
      max_entries: Keyword.get(opts, :max_entries, @default_max_entries),
      sweep_interval_ms: Keyword.get(opts, :sweep_interval_ms, @default_sweep_interval_ms),
      auto_sweep?: Keyword.get(opts, :auto_sweep?, true)
    }

    _ = if config.auto_sweep?, do: schedule_sweep(config.sweep_interval_ms)
    {:ok, %{buffers: %{}, config: config}}
  end

  @impl true
  def handle_call({:add, packet}, _from, state) do
    case parse(packet) do
      {:ok, original_id, index, total} ->
        now = now_ms()
        buffers = put_fragment(state.buffers, original_id, index, packet, now)
        entry = Map.fetch!(buffers, original_id)

        if map_size(entry.fragments) == total do
          finalize(original_id, entry.fragments, buffers, state)
        else
          {buffers, evicted} = enforce_max(buffers, state.config.max_entries)
          emit_evictions(evicted, :capacity)
          {:reply, {:partial, map_size(entry.fragments), total}, %{state | buffers: buffers}}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | buffers: %{}}}
  end

  @impl true
  def handle_info(:sweep, state) do
    {buffers, evicted} = evict_expired(state.buffers, now_ms(), state.config.reassembly_ttl_ms)
    emit_evictions(evicted, :ttl)
    _ = if state.config.auto_sweep?, do: schedule_sweep(state.config.sweep_interval_ms)
    {:noreply, %{state | buffers: buffers}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp finalize(original_id, fragments, buffers, state) do
    case Fragment.reassemble(Map.values(fragments)) do
      {:ok, ^original_id, frame} ->
        {:reply, {:complete, original_id, frame},
         %{state | buffers: Map.delete(buffers, original_id)}}

      {:incomplete, received, expected} ->
        {:reply, {:partial, received, expected}, %{state | buffers: buffers}}
    end
  end

  # --- pure buffer operations (unit-tested without timers) ---

  @doc false
  @spec put_fragment(map(), non_neg_integer(), non_neg_integer(), Packet.t(), integer()) :: map()
  def put_fragment(buffers, original_id, index, packet, now_ms) do
    entry = Map.get(buffers, original_id, %{fragments: %{}, first_seen_ms: now_ms})
    Map.put(buffers, original_id, %{entry | fragments: Map.put(entry.fragments, index, packet)})
  end

  @doc false
  @spec evict_expired(map(), integer(), pos_integer()) :: {map(), [non_neg_integer()]}
  def evict_expired(buffers, now_ms, ttl_ms) do
    expired =
      for {id, %{first_seen_ms: first}} <- buffers, now_ms - first >= ttl_ms, do: id

    {Map.drop(buffers, expired), expired}
  end

  @doc false
  @spec enforce_max(map(), pos_integer()) :: {map(), [non_neg_integer()]}
  def enforce_max(buffers, max_entries) when map_size(buffers) <= max_entries, do: {buffers, []}

  def enforce_max(buffers, max_entries) do
    drop_count = map_size(buffers) - max_entries

    oldest =
      buffers
      |> Enum.sort_by(fn {_id, %{first_seen_ms: first}} -> first end)
      |> Enum.take(drop_count)
      |> Enum.map(&elem(&1, 0))

    {Map.drop(buffers, oldest), oldest}
  end

  defp emit_evictions([], _reason), do: :ok

  defp emit_evictions(ids, reason) do
    Telemetry.execute([:fragment_buffer, :evict], %{count: length(ids)}, %{
      reason: reason,
      original_ids: ids
    })
  end

  defp schedule_sweep(interval), do: Process.send_after(self(), :sweep, interval)

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp parse(%Packet{payload: <<original_id::32-little, index::8, total::8, _chunk::binary>>})
       when total > 0 and index < total do
    {:ok, original_id, index, total}
  end

  defp parse(_packet), do: {:error, :malformed_fragment}
end
