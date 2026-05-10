defmodule MeshxStore.DB do
  @moduledoc """
  CubDB-backed key-value store for MeshX durable local persistence.

  Wraps a single CubDB instance and exposes convenience helpers for
  the store modules (Identity, Trust, Message, Outbox).

  ## Internal key conventions

  Store modules use namespaced tuple keys to avoid collisions. These
  key shapes are an **internal implementation detail**, not a public
  API contract. Do not rely on them from outside `meshx_store`.

  | Namespace   | Key shape                | Owner module        |
  |------------|--------------------------|---------------------|
  | `:identity`| `{:identity, name}`      | `MeshxStore.Identity`|
  | `:trust`   | `{:trust, peer_id}`      | `MeshxStore.Trust`   |
  | `:message` | `{:message, msg_id}`     | `MeshxStore.Message` |
  | `:outbox`  | `{:outbox, id}`          | `MeshxStore.Outbox`  |

  """
  use GenServer

  @default_data_dir "meshx_store"

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    data_dir = Keyword.get(opts, :data_dir, default_data_dir())
    GenServer.start_link(__MODULE__, data_dir, name: __MODULE__)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @spec get(CubDB.key()) :: CubDB.value() | nil
  def get(key) do
    CubDB.get(db(), key)
  end

  @spec get(CubDB.key(), CubDB.value()) :: CubDB.value()
  def get(key, default) do
    CubDB.get(db(), key, default)
  end

  @spec put(CubDB.key(), CubDB.value()) :: :ok
  def put(key, value) do
    CubDB.put(db(), key, value)
  end

  @spec delete(CubDB.key()) :: :ok
  def delete(key) do
    CubDB.delete(db(), key)
  end

  @spec get_and_update(CubDB.key(), (CubDB.value() -> {return :: any(), CubDB.value()})) ::
          return :: any()
  def get_and_update(key, fun) do
    CubDB.get_and_update(db(), key, fun)
  end

  @spec select([CubDB.select_option()]) :: [CubDB.entry()]
  def select(opts \\ []) do
    CubDB.select(db(), opts)
    |> Enum.to_list()
  end

  @spec clear() :: :ok
  def clear do
    CubDB.clear(db())
  end

  @spec db() :: pid()
  def db do
    GenServer.call(__MODULE__, :db)
  end

  # --- Server callbacks ---

  @impl true
  def init(data_dir) do
    File.mkdir_p!(data_dir)
    {:ok, cub} = CubDB.start_link(data_dir: data_dir)
    {:ok, %{cub: cub, data_dir: data_dir}}
  end

  @impl true
  def handle_call(:db, _from, %{cub: cub} = state) do
    {:reply, cub, state}
  end

  defp default_data_dir do
    Application.get_env(:meshx_store, :data_dir, Path.join(System.tmp_dir!(), @default_data_dir))
  end
end
