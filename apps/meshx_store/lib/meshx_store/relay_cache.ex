defmodule MeshxStore.RelayCache do
  @moduledoc """
  In-memory cache for messages currently eligible for relay.

  Stores `{msg_id, payload, hops, inserted_at}` tuples. The runtime can query
  this cache to find messages to forward when new peers appear.
  """

  use GenServer

  @table :meshx_relay_cache
  @default_ttl_ms :timer.minutes(10)
  @cleanup_interval_ms :timer.minutes(2)

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Adds a message to the relay cache.
  """
  @spec add(non_neg_integer(), binary(), non_neg_integer()) :: :ok
  def add(msg_id, payload, hops \\ 0) do
    inserted = System.monotonic_time(:millisecond)
    :ets.insert(@table, {msg_id, payload, hops, inserted})
    :ok
  end

  @doc """
  Retrieves a single entry by message ID.
  """
  @spec get(non_neg_integer()) :: {non_neg_integer(), binary(), non_neg_integer()} | nil
  def get(msg_id) do
    case :ets.lookup(@table, msg_id) do
      [{^msg_id, payload, hops, _inserted}] -> {msg_id, payload, hops}
      [] -> nil
    end
  end

  @doc """
  Removes an entry from the relay cache.
  """
  @spec remove(non_neg_integer()) :: :ok
  def remove(msg_id) do
    :ets.delete(@table, msg_id)
    :ok
  end

  @doc """
  Returns all entries in the relay cache.
  """
  @spec all() :: [{non_neg_integer(), binary(), non_neg_integer()}]
  def all() do
    :ets.tab2list(@table)
    |> Enum.map(fn {msg_id, payload, hops, _inserted} -> {msg_id, payload, hops} end)
  end

  @doc """
  Returns the number of cached entries.
  """
  @spec count() :: non_neg_integer()
  def count() do
    :ets.info(@table, :size)
  end

  @doc "Returns all message IDs currently in the relay cache."
  @spec message_ids() :: [non_neg_integer()]
  def message_ids do
    :ets.tab2list(@table)
    |> Enum.map(fn {msg_id, _payload, _hops, _inserted} -> msg_id end)
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  # --- Server callbacks ---

  @impl true
  def init(opts) do
    ttl = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    interval = Keyword.get(opts, :cleanup_interval_ms, @cleanup_interval_ms)

    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_cleanup(interval)
    {:ok, %{ttl_ms: ttl, cleanup_interval_ms: interval}}
  end

  @impl true
  def handle_info(:cleanup, %{cleanup_interval_ms: interval, ttl_ms: ttl} = state) do
    now = System.monotonic_time(:millisecond)
    cutoff = now - ttl

    :ets.select_delete(@table, [
      {{:_, :_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}
    ])

    schedule_cleanup(interval)
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end
