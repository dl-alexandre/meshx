defmodule MeshxStore.Message do
  @moduledoc """
  Persisted mesh message backed by CubDB.

  ## Error contract

  `insert/1` validates required fields and returns explicit error atoms:

    * `:missing_msg_id` — required `msg_id` field was omitted
    * `:missing_payload` — required `payload` field was omitted

  Read operations (`get/1`) return `nil` when no record exists.
  """

  alias MeshxStore.DB

  @type t :: %__MODULE__{
          msg_id: non_neg_integer(),
          sender: binary(),
          payload: binary(),
          hops: non_neg_integer(),
          ttl: non_neg_integer(),
          received_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [:msg_id, :sender, :payload, :hops, :ttl, :received_at, :inserted_at, :updated_at]

  @doc "Validates and inserts a message into the store."
  @spec insert(map()) :: {:ok, t()} | {:error, :missing_msg_id | :missing_payload}
  def insert(attrs) do
    msg_id = Map.get(attrs, :msg_id)
    payload = Map.get(attrs, :payload)

    cond do
      is_nil(msg_id) -> {:error, :missing_msg_id}
      is_nil(payload) -> {:error, :missing_payload}
      true ->
        now = DateTime.utc_now()

        message = %__MODULE__{
          msg_id: msg_id,
          sender: Map.get(attrs, :sender),
          payload: payload,
          hops: Map.get(attrs, :hops, 0),
          ttl: Map.get(attrs, :ttl, 64),
          received_at: Map.get(attrs, :received_at, now),
          inserted_at: now,
          updated_at: now
        }

        DB.put({:message, msg_id}, message)
        {:ok, message}
    end
  end

  @doc "Retrieves a message by its msg_id."
  @spec get(non_neg_integer()) :: t() | nil
  def get(msg_id) do
    DB.get({:message, msg_id})
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    for {key, _value} <- DB.select(min_key: {:message, nil}, max_key: {{:message, nil}, nil}) do
      DB.delete(key)
    end

    :ok
  end
end
