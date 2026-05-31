defmodule Mob.Store.Outbox do
  @moduledoc """
  Store-and-forward outbox backed by CubDB.

  Messages are enqueued with a status of `:pending`, marked `:sent` when
  a delivery acknowledgement arrives, or `:failed` when retries are exhausted.
  Read receipts are tracked separately from delivery so callers can distinguish
  delivered-but-unread from read messages without changing retry semantics.

  ## Error contract

  Write operations return explicit domain-level error atoms rather than
  generic changeset errors. This keeps the outbox API independent of any
  persistence layer and makes failure modes enumerable:

    * `:missing_msg_id` — required `msg_id` field was omitted
    * `:missing_payload` — required `payload` field was omitted
    * `:invalid_attempts` — negative `attempts` value
    * `:invalid_max_attempts` — `max_attempts` less than 1
    * `:not_found` — referenced record does not exist

  Status queries (`pending/1`, `pending_for_destination/2`) return empty lists
  when no records match; they do not return error tuples.
  """

  alias Mob.Store.DB

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          msg_id: non_neg_integer(),
          payload: binary(),
          destinations: [String.t()],
          attempts: non_neg_integer(),
          max_attempts: non_neg_integer(),
          status: :pending | :sent | :failed,
          delivery_acked_at: DateTime.t() | nil,
          read_at: DateTime.t() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [
    :id,
    :msg_id,
    :payload,
    :destinations,
    :attempts,
    :max_attempts,
    :status,
    :delivery_acked_at,
    :read_at,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Enqueues a new message for store-and-forward.
  """
  @spec enqueue(map()) ::
          {:ok, t()}
          | {:error,
             :missing_msg_id | :missing_payload | :invalid_attempts | :invalid_max_attempts}
  def enqueue(attrs) do
    msg_id = Map.get(attrs, :msg_id)
    payload = Map.get(attrs, :payload)
    attempts = Map.get(attrs, :attempts, 0)
    max_attempts = Map.get(attrs, :max_attempts, 5)

    cond do
      is_nil(msg_id) ->
        {:error, :missing_msg_id}

      is_nil(payload) ->
        {:error, :missing_payload}

      attempts < 0 ->
        {:error, :invalid_attempts}

      max_attempts < 1 ->
        {:error, :invalid_max_attempts}

      true ->
        now = DateTime.utc_now()

        record = %__MODULE__{
          id: :erlang.unique_integer([:positive]),
          msg_id: msg_id,
          payload: payload,
          destinations: Map.get(attrs, :destinations, []),
          attempts: attempts,
          max_attempts: max_attempts,
          status: Map.get(attrs, :status, :pending),
          delivery_acked_at: Map.get(attrs, :delivery_acked_at),
          read_at: Map.get(attrs, :read_at),
          inserted_at: now,
          updated_at: now
        }

        DB.put({:outbox, record.id}, record)
        {:ok, record}
    end
  end

  @doc "Returns an outbox row by internal id."
  @spec get(non_neg_integer()) :: t() | nil
  def get(id), do: DB.get({:outbox, id})

  @doc """
  Returns up to `limit` pending messages ordered by insertion time.
  """
  @spec pending(non_neg_integer()) :: [t()]
  def pending(limit \\ 100) do
    DB.select(min_key: {:outbox, 0}, max_key: {{:outbox, nil}, nil})
    |> Stream.map(fn {_key, value} -> value end)
    |> Stream.filter(&(&1.status == :pending))
    |> Enum.sort_by(& &1.inserted_at, DateTime)
    |> Enum.take(limit)
  end

  @doc """
  Returns pending messages for a destination.

  Empty destination lists are treated as broadcast entries and match any peer.
  """
  @spec pending_for_destination(String.t() | term(), non_neg_integer()) :: [t()]
  def pending_for_destination(destination, limit \\ 100) do
    destination = to_string(destination)

    pending(limit * 5)
    |> Enum.filter(fn message ->
      message.destinations == [] or destination in message.destinations
    end)
    |> Enum.take(limit)
  end

  @doc """
  Marks a message as successfully sent by msg_id.
  """
  @spec mark_sent(non_neg_integer()) :: {:ok, t()} | {:error, :not_found}
  def mark_sent(msg_id) do
    case find_by_msg_id(msg_id) do
      nil -> {:error, :not_found}
      record -> update_by_id(record.id, %{status: :sent})
    end
  end

  @doc "Marks a specific outbox row as successfully sent."
  @spec mark_sent_by_id(non_neg_integer()) :: {:ok, t()} | {:error, :not_found}
  def mark_sent_by_id(id) do
    update_by_id(id, %{status: :sent})
  end

  @doc "Marks a row delivered when a delivery ACK arrives from a destination."
  @spec ack(non_neg_integer(), String.t() | term()) :: {:ok, t()} | {:error, :not_found}
  def ack(msg_id, destination), do: mark_delivered(msg_id, destination)

  @doc "Marks a row delivered when a delivery ACK arrives from a destination."
  @spec mark_delivered(non_neg_integer(), String.t() | term()) ::
          {:ok, t()} | {:error, :not_found}
  def mark_delivered(msg_id, destination) do
    destination = to_string(destination)

    find_by_msg_id_and_destination(msg_id, destination)
    |> case do
      nil ->
        {:error, :not_found}

      record ->
        update_by_id(record.id, %{
          status: :sent,
          delivery_acked_at: Map.get(record, :delivery_acked_at) || DateTime.utc_now()
        })
    end
  end

  @doc "Marks a row read when a read receipt arrives from a destination."
  @spec mark_read(non_neg_integer(), String.t() | term()) :: {:ok, t()} | {:error, :not_found}
  def mark_read(msg_id, destination) do
    destination = to_string(destination)

    find_by_msg_id_and_destination(msg_id, destination)
    |> case do
      nil ->
        {:error, :not_found}

      record ->
        now = DateTime.utc_now()

        update_by_id(record.id, %{
          status: :sent,
          delivery_acked_at: Map.get(record, :delivery_acked_at) || now,
          read_at: Map.get(record, :read_at) || now
        })
    end
  end

  @doc """
  Increments the attempt counter. If `max_attempts` is reached the status
  becomes `:failed`.
  """
  @spec mark_failed(non_neg_integer()) :: {:ok, t()} | {:error, :not_found}
  def mark_failed(msg_id) do
    case find_by_msg_id(msg_id) do
      nil -> {:error, :not_found}
      record -> mark_record_failed(record)
    end
  end

  @doc "Increments attempts for a specific outbox row."
  @spec mark_failed_by_id(non_neg_integer()) :: {:ok, t()} | {:error, :not_found}
  def mark_failed_by_id(id) do
    record_attempt_by_id(id)
  end

  @doc "Records one delivery attempt and fails the row after max attempts."
  @spec record_attempt_by_id(non_neg_integer()) :: {:ok, t()} | {:error, :not_found}
  def record_attempt_by_id(id) do
    case DB.get({:outbox, id}) do
      nil -> {:error, :not_found}
      record -> mark_record_failed(record)
    end
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    for {key, _value} <- DB.select(min_key: {:outbox, 0}, max_key: {{:outbox, nil}, nil}) do
      DB.delete(key)
    end

    :ok
  end

  # --- Helpers ---

  defp find_by_msg_id(msg_id) do
    DB.select(min_key: {:outbox, 0}, max_key: {{:outbox, nil}, nil})
    |> Stream.map(fn {_key, value} -> value end)
    |> Enum.find(&(&1.msg_id == msg_id))
  end

  defp find_by_msg_id_and_destination(msg_id, destination) do
    DB.select(min_key: {:outbox, 0}, max_key: {{:outbox, nil}, nil})
    |> Stream.map(fn {_key, value} -> value end)
    |> Enum.find(fn record ->
      record.msg_id == msg_id and
        (record.destinations == [] or destination in record.destinations)
    end)
  end

  defp update_by_id(id, attrs) do
    case DB.get({:outbox, id}) do
      nil ->
        {:error, :not_found}

      record ->
        updated = Map.merge(record, Map.new(attrs))
        updated = %{updated | updated_at: DateTime.utc_now()}
        DB.put({:outbox, id}, updated)
        {:ok, updated}
    end
  end

  defp mark_record_failed(record) do
    attempts = record.attempts + 1
    status = if attempts >= record.max_attempts, do: :failed, else: :pending

    update_by_id(record.id, %{attempts: attempts, status: status})
  end
end
