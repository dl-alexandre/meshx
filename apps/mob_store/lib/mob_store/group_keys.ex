defmodule Mob.Store.GroupKeys do
  @moduledoc """
  Durable per-channel group-messaging key state, backed by CubDB.

  Stores one opaque session term per channel id under
  `{:group_keys, channel_id}`. The term is a serialized
  `Mob.Noise.GroupSession` (this module is intentionally agnostic about
  its shape so `mob_store` need not depend on `mob_noise` — the owning
  manager in `mob_runtime` round-trips the struct).

  Persisting the session keeps a member's **own sending chain** and the
  **receiving chains** it has installed for other senders across
  restarts, so a relaunched node keeps reading a channel without
  re-running key distribution.

  Sender keys are long-lived secrets; this store is only as private as
  the underlying CubDB data directory. Treat the data dir as sensitive.
  """

  alias Mob.Store.DB

  @namespace :group_keys

  @doc "Returns the stored session term for `channel_id`, or `nil`."
  @spec get(binary()) :: term() | nil
  def get(channel_id) when is_binary(channel_id), do: DB.get(key(channel_id))

  @doc "Persists `session` as the group-key state for `channel_id`."
  @spec put(binary(), term()) :: :ok
  def put(channel_id, session) when is_binary(channel_id), do: DB.put(key(channel_id), session)

  @doc """
  Atomically reads the current session for `channel_id`, applies `fun`,
  and writes the result back. `fun` receives the stored term (or `nil`)
  and returns `{return_value, new_session}`. Returns `return_value`.

  Use this for the read-modify-write of a ratchet step so concurrent
  encrypt/decrypt on the same channel can't lose an advance.
  """
  @spec update(binary(), (term() | nil -> {ret, term()})) :: ret when ret: var
  def update(channel_id, fun) when is_binary(channel_id) and is_function(fun, 1) do
    DB.get_and_update(key(channel_id), fun)
  end

  @doc "Deletes all group-key state for `channel_id`."
  @spec delete(binary()) :: :ok
  def delete(channel_id) when is_binary(channel_id), do: DB.delete(key(channel_id))

  @doc "Returns the list of channel ids that have stored group-key state."
  @spec channels() :: [binary()]
  def channels do
    for {{@namespace, channel_id}, _value} <-
          DB.select(min_key: {@namespace, nil}, max_key: {{@namespace, nil}, nil}) do
      channel_id
    end
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    for {{@namespace, _} = k, _value} <-
          DB.select(min_key: {@namespace, nil}, max_key: {{@namespace, nil}, nil}) do
      DB.delete(k)
    end

    :ok
  end

  defp key(channel_id), do: {@namespace, channel_id}
end
