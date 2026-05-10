defmodule MeshxStore.Dedupe do
  @moduledoc """
  TTL-based deduplication cache for mesh message IDs.

  Prevents the same message from being processed or relayed multiple times
  by tracking recently seen `msg_id`s in an ETS table. Entries expire after
  a configurable TTL (default 5 minutes).
  """

  use GenServer

  @default_ttl_ms :timer.minutes(5)
  @cleanup_interval_ms :timer.minutes(1)
  @table :meshx_dedupe
  @ttl_key {__MODULE__, :ttl_ms}

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns `true` if the message ID has been seen recently.
  """
  @spec seen?(non_neg_integer()) :: boolean()
  def seen?(msg_id) do
    case :ets.lookup(@table, msg_id) do
      [{^msg_id, _expires_at}] -> true
      [] -> false
    end
  end

  @doc """
  Records a message ID in the dedupe cache.
  """
  @spec record(non_neg_integer()) :: :ok
  def record(msg_id) do
    expires = System.monotonic_time(:millisecond) + ttl_ms()
    :ets.insert(@table, {msg_id, expires})
    :ok
  end

  @doc """
  Conditionally records a message ID, returning `true` if it was already seen.
  """
  @spec record?(non_neg_integer()) :: boolean()
  def record?(msg_id) do
    if seen?(msg_id) do
      true
    else
      record(msg_id)
      false
    end
  end

  @doc "Returns all currently tracked message IDs."
  @spec ids() :: [non_neg_integer()]
  def ids do
    :ets.tab2list(@table)
    |> Enum.map(fn {msg_id, _expires_at} -> msg_id end)
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
    :persistent_term.put(@ttl_key, ttl)

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
  def handle_info(:cleanup, %{cleanup_interval_ms: interval} = state) do
    now = System.monotonic_time(:millisecond)

    :ets.select_delete(@table, [
      {{:_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    schedule_cleanup(interval)
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end

  defp ttl_ms do
    :persistent_term.get(@ttl_key, @default_ttl_ms)
  end
end
