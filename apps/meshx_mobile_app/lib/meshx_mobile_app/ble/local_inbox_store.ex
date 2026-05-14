defmodule MeshxMobileApp.BLE.LocalInboxStore do
  @moduledoc """
  Durable store boundary for advertisement-only local inbox snapshots.

  This module writes only the policy-approved durable snapshot shape
  produced by `LocalInboxPersistencePolicy`. It does not persist raw BLE
  events, raw transport metadata, in-memory inbox structs, routing state,
  fetch sessions, ACKs, retries, crypto material, or background work.
  """

  alias MeshxMobileApp.BLE.{LocalInboxDurableSnapshot, LocalInboxPersistencePolicy}
  alias MeshxStore.DB

  @default_snapshot_id :default

  @type snapshot_id :: atom() | binary()

  @type summary :: %{
          required(:snapshot_id) => snapshot_id(),
          required(:persisted_at) => integer() | nil,
          required(:full_message_count) => non_neg_integer(),
          required(:beacon_ref_count) => non_neg_integer(),
          required(:expires_at) => integer() | :forever | nil,
          required(:expired?) => boolean()
        }

  @spec save(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def save(local_snapshot, opts \\ [])

  def save(%{} = local_snapshot, opts) do
    snapshot_id = Keyword.get(opts, :snapshot_id, @default_snapshot_id)

    with :ok <- validate_snapshot_id(snapshot_id),
         {:ok, durable} <- LocalInboxPersistencePolicy.durable_snapshot(local_snapshot, opts),
         :ok <- DB.put(key(snapshot_id), durable) do
      {:ok, durable}
    end
  end

  def save(_local_snapshot, _opts), do: {:error, :invalid_local_inbox_snapshot}

  @spec load(snapshot_id()) :: {:ok, map()} | {:error, :not_found | :invalid_snapshot_id}
  def load(snapshot_id \\ @default_snapshot_id) do
    with :ok <- validate_snapshot_id(snapshot_id) do
      case DB.get(key(snapshot_id)) do
        nil -> {:error, :not_found}
        %{} = durable -> {:ok, durable}
      end
    end
  end

  @spec load_read_model(snapshot_id(), keyword()) ::
          {:ok, map()} | {:error, :not_found | :invalid_snapshot_id | term()}
  def load_read_model(snapshot_id \\ @default_snapshot_id, opts \\ []) do
    with {:ok, durable} <- load(snapshot_id) do
      LocalInboxDurableSnapshot.to_read_model(durable, opts)
    end
  end

  @spec list(keyword()) :: [summary()]
  def list(opts \\ []) do
    now = Keyword.get(opts, :now)

    DB.select(min_key: {:mobile_local_inbox, nil}, max_key: {{:mobile_local_inbox, nil}, nil})
    |> Enum.map(fn {{:mobile_local_inbox, snapshot_id}, durable} ->
      summarize(snapshot_id, durable, now)
    end)
    |> Enum.sort_by(&{sort_persisted_at(&1.persisted_at), to_string(&1.snapshot_id)})
  end

  @spec prune_expired(keyword()) :: {:ok, [snapshot_id()]} | {:error, :missing_now | :invalid_now}
  def prune_expired(opts \\ []) do
    case Keyword.fetch(opts, :now) do
      {:ok, now} when is_integer(now) ->
        deleted =
          opts
          |> list()
          |> Enum.filter(& &1.expired?)
          |> Enum.map(fn %{snapshot_id: snapshot_id} ->
            :ok = delete(snapshot_id)
            snapshot_id
          end)

        {:ok, deleted}

      {:ok, _now} ->
        {:error, :invalid_now}

      :error ->
        {:error, :missing_now}
    end
  end

  @spec delete(snapshot_id()) :: :ok | {:error, :invalid_snapshot_id}
  def delete(snapshot_id \\ @default_snapshot_id) do
    with :ok <- validate_snapshot_id(snapshot_id) do
      DB.delete(key(snapshot_id))
    end
  end

  @spec clear() :: :ok
  def clear do
    for {key, _value} <-
          DB.select(
            min_key: {:mobile_local_inbox, nil},
            max_key: {{:mobile_local_inbox, nil}, nil}
          ) do
      DB.delete(key)
    end

    :ok
  end

  defp validate_snapshot_id(snapshot_id) when is_atom(snapshot_id) or is_binary(snapshot_id),
    do: :ok

  defp validate_snapshot_id(_snapshot_id), do: {:error, :invalid_snapshot_id}

  defp key(snapshot_id), do: {:mobile_local_inbox, snapshot_id}

  defp summarize(snapshot_id, durable, now) do
    expires_at = expires_at(durable)

    %{
      snapshot_id: snapshot_id,
      persisted_at: persisted_at(durable),
      full_message_count: durable |> Map.get(:full_messages, []) |> count_list(),
      beacon_ref_count: durable |> Map.get(:unresolved_beacon_refs, []) |> count_list(),
      expires_at: expires_at,
      expired?: expired?(expires_at, now)
    }
  end

  defp persisted_at(%{persisted_at: persisted_at}) when is_integer(persisted_at), do: persisted_at
  defp persisted_at(_durable), do: nil

  defp count_list(values) when is_list(values), do: length(values)
  defp count_list(_values), do: 0

  defp expires_at(%{persisted_at: persisted_at, policy: policy}) when is_integer(persisted_at) do
    case max_retention(policy) do
      :forever -> :forever
      retention when is_integer(retention) -> persisted_at + retention
      nil -> nil
    end
  end

  defp expires_at(_durable), do: nil

  defp max_retention(%{} = policy) do
    [
      Map.get(policy, :full_message_retention_ms),
      Map.get(policy, :beacon_ref_retention_ms)
    ]
    |> Enum.reduce(nil, fn
      :forever, _acc -> :forever
      _value, :forever -> :forever
      value, acc when is_integer(value) and value > 0 -> max(value, acc || 0)
      _value, acc -> acc
    end)
  end

  defp max_retention(_policy), do: nil

  defp expired?(:forever, _now), do: false

  defp expired?(expires_at, now) when is_integer(expires_at) and is_integer(now),
    do: now > expires_at

  defp expired?(_expires_at, _now), do: false

  defp sort_persisted_at(nil), do: -1
  defp sort_persisted_at(persisted_at), do: persisted_at
end
