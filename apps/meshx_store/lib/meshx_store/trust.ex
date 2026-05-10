defmodule MeshxStore.Trust do
  @moduledoc """
  Persistent peer trust policy backed by CubDB.

  Supported policies:

    * `:tofu` - trust on first use, then reject key changes.
    * `:pinned` - require a pre-pinned key for the peer.
    * `:allowlist` - alias for `:pinned`.
  """

  alias MeshxStore.DB

  @trusted :trusted
  @blocked :blocked

  @type policy :: :tofu | :pinned | :allowlist
  @type t :: %__MODULE__{
          peer_id: String.t(),
          public_key: binary(),
          status: :trusted | :blocked,
          first_seen_at: DateTime.t(),
          last_seen_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
  @type authorize_result :: :ok | {:error, :blocked | :key_mismatch | :untrusted_peer}

  defstruct [
    :peer_id,
    :public_key,
    :status,
    :first_seen_at,
    :last_seen_at,
    :inserted_at,
    :updated_at
  ]

  @doc "Authorizes a peer key according to the configured trust policy."
  @spec authorize(term(), binary(), keyword()) :: authorize_result()
  def authorize(peer_id, public_key, opts \\ []) when is_binary(public_key) do
    policy = Keyword.get(opts, :policy, configured_policy())
    peer_id = to_string(peer_id)

    case DB.get(trust_key(peer_id)) do
      nil -> authorize_unknown(peer_id, public_key, policy)
      peer -> authorize_known(peer, public_key)
    end
  end

  @doc "Pins or replaces a peer public key."
  @spec pin(term(), binary()) :: {:ok, t()}
  def pin(peer_id, public_key) when is_binary(public_key) do
    now = DateTime.utc_now()
    peer_id = to_string(peer_id)
    key = trust_key(peer_id)

    existing = DB.get(key)

    attrs = %{
      peer_id: peer_id,
      public_key: public_key,
      status: @trusted,
      first_seen_at: (existing && existing.first_seen_at) || now,
      last_seen_at: now,
      inserted_at: (existing && existing.inserted_at) || now,
      updated_at: now
    }

    record = struct(__MODULE__, Map.to_list(attrs))
    DB.put(key, record)
    {:ok, record}
  end

  @doc "Blocks a pinned or first-seen peer."
  @spec block(term()) :: {:ok, t()} | {:error, :not_found}
  def block(peer_id) do
    key = trust_key(to_string(peer_id))

    case DB.get(key) do
      nil ->
        {:error, :not_found}

      peer ->
        record = %{peer | status: @blocked, updated_at: DateTime.utc_now()}
        DB.put(key, record)
        {:ok, record}
    end
  end

  @doc "Returns true when the peer is trusted with this exact public key."
  @spec trusted?(term(), binary()) :: boolean()
  def trusted?(peer_id, public_key) do
    case DB.get(trust_key(to_string(peer_id))) do
      %{status: @trusted, public_key: ^public_key} -> true
      _other -> false
    end
  end

  @doc "Returns the trust record for a peer."
  @spec get(term()) :: t() | nil
  def get(peer_id), do: DB.get(trust_key(to_string(peer_id)))

  @doc false
  @spec clear() :: :ok
  def clear do
    for {key, _value} <- DB.select(min_key: {:trust, nil}, max_key: {{:trust, nil}, nil}) do
      DB.delete(key)
    end

    :ok
  end

  defp authorize_unknown(peer_id, public_key, :tofu) do
    {:ok, _peer} = pin(peer_id, public_key)
    :ok
  end

  defp authorize_unknown(_peer_id, _public_key, policy) when policy in [:pinned, :allowlist] do
    {:error, :untrusted_peer}
  end

  defp authorize_known(%{status: @blocked}, _public_key), do: {:error, :blocked}

  defp authorize_known(%{public_key: public_key} = peer, public_key) do
    updated = %{peer | last_seen_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
    DB.put(trust_key(peer.peer_id), updated)
    :ok
  end

  defp authorize_known(_peer, _public_key), do: {:error, :key_mismatch}

  defp configured_policy do
    Application.get_env(:meshx_store, :trust_policy, :tofu)
  end

  defp trust_key(peer_id), do: {:trust, peer_id}
end
