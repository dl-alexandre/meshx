defmodule Mob.Node.Chat.Identity do
  @moduledoc """
  Chat-facing identity overlay.

  The cryptographic identity (Noise static key pair + derived `peer_id`) is
  owned by `Mob.Store.Identity` and reused here unchanged. Chat layers a
  user-editable **nickname** on top for display purposes; the underlying
  `peer_id` is what wire payloads carry and what acks/dedup key on.

  The default nickname (`anon-<8 hex>`) is derived from the local public key
  so a peer always has *some* identifier even before the user picks a name.

  Persistence is `Mob.Store.DB` (CubDB), shared with the rest of the
  store's keyspace.
  """

  alias Mob.Store.DB
  alias Mob.Store.Identity, as: NodeIdentity

  @nickname_key {:chat, :nickname}

  @type t :: %{peer_id: binary(), wire_peer_id: binary(), nickname: String.t()}

  @doc """
  Returns the local chat identity, ensuring the underlying node identity
  exists and a nickname is set (defaulting if absent).

  The returned map carries two peer-id forms:

    * `:peer_id` — the URL-safe Base64 of the public key (~43 chars).
      The display form, used in nicknames and UI labels.
    * `:wire_peer_id` — the raw 32-byte public key. Fits `MessageEnvelope`'s
      `@max_peer_id_size 32` exactly; this is what outbound chat envelopes
      carry as `sender_peer_id`, and what receivers compare against to
      decide whether a row was sent by the local user.
  """
  @spec get() :: {:ok, t()}
  def get do
    with {:ok, identity} <- NodeIdentity.ensure_local() do
      peer_id = Base.url_encode64(identity.public_key, padding: false)
      nickname = DB.get(@nickname_key) || default_nickname(peer_id)

      {:ok,
       %{
         peer_id: peer_id,
         wire_peer_id: identity.public_key,
         nickname: nickname
       }}
    end
  end

  @doc """
  Sets the user-chosen nickname. Trims surrounding whitespace; rejects
  empty strings. Returns the updated identity.
  """
  @spec set_nickname(String.t()) :: {:ok, t()} | {:error, :empty_nickname}
  def set_nickname(nickname) when is_binary(nickname) do
    case String.trim(nickname) do
      "" ->
        {:error, :empty_nickname}

      trimmed ->
        DB.put(@nickname_key, trimmed)
        get()
    end
  end

  @doc false
  @spec clear_nickname() :: :ok
  def clear_nickname do
    DB.delete(@nickname_key)
    :ok
  end

  @doc """
  Derives the default nickname from a peer_id: `"anon-" <> first 8 chars`.
  Stable per device while distinguishing peers in the channel UI before
  any user-chosen name is set.
  """
  @spec default_nickname(binary()) :: String.t()
  def default_nickname(peer_id) when is_binary(peer_id) do
    "anon-" <> binary_part(peer_id, 0, min(8, byte_size(peer_id)))
  end
end
