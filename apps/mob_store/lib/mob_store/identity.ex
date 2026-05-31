defmodule Mob.Store.Identity do
  @moduledoc """
  Persistent local node identity storage backed by CubDB.

  MeshX Noise sessions use this key pair as their static `s` key. Keeping it in
  a local CubDB store gives the node a stable cryptographic identity across
  restarts instead of generating a throwaway key for every session.

  ## Error contract

  `ensure_local/1` and its dependents return `{:ok, t()}` under all normal
  operation. If `:crypto.generate_key/2` fails, the process crashes, as a
  node cannot operate without a valid Noise static key pair.
  """

  alias Mob.Store.DB

  @local_name "local"
  @key {:identity, @local_name}

  @type t :: %__MODULE__{
          name: String.t(),
          public_key: binary(),
          private_key: binary(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  defstruct [:name, :public_key, :private_key, :inserted_at, :updated_at]

  @doc "Returns the persisted local identity, creating one if needed."
  @spec ensure_local(keyword()) :: {:ok, t()}
  def ensure_local(opts \\ []) do
    name = Keyword.get(opts, :name, @local_name)
    key = {:identity, name}

    case DB.get(key) do
      nil -> create_local(name, key)
      identity -> {:ok, identity}
    end
  end

  @doc "Returns the local static key map expected by `Mob.Noise.Session`."
  @spec static_keys(keyword()) :: {:ok, %{s: {binary(), binary()}}}
  def static_keys(opts \\ []) do
    with {:ok, identity} <- ensure_local(opts) do
      {:ok, %{s: {identity.public_key, identity.private_key}}}
    end
  end

  @doc "Derives a stable, URL-safe peer id from the local public key."
  @spec local_peer_id(keyword()) :: {:ok, String.t()}
  def local_peer_id(opts \\ []) do
    with {:ok, identity} <- ensure_local(opts) do
      {:ok, Base.url_encode64(identity.public_key, padding: false)}
    end
  end

  @doc false
  @spec clear() :: :ok
  def clear do
    DB.delete(@key)
    :ok
  end

  defp create_local(name, key) do
    now = DateTime.utc_now()

    {public_key, private_key} = :crypto.generate_key(:ecdh, :x25519)

    identity = %__MODULE__{
      name: name,
      public_key: public_key,
      private_key: private_key,
      inserted_at: now,
      updated_at: now
    }

    DB.put(key, identity)
    {:ok, identity}
  end
end
