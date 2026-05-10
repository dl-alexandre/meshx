defmodule MeshxStore do
  @moduledoc """
  MeshX Store — durable local persistence and in-memory caches.

  Provides:

    * `MeshxStore.DB` — CubDB-backed key-value store for local-first storage.
    * `MeshxStore.Identity` — persistent local Noise static key storage.
    * `MeshxStore.Trust` — peer trust-on-first-use, pinned, and allowlist policy.
    * `MeshxStore.Message` — persisted mesh messages.
    * `MeshxStore.Outbox` — store-and-forward outbox with retry logic.
    * `MeshxStore.Dedupe` — TTL-based deduplication cache.
    * `MeshxStore.RelayCache` — in-memory relay buffer.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MeshxStore.DB,
      MeshxStore.Dedupe,
      MeshxStore.RelayCache
    ]

    opts = [strategy: :one_for_one, name: MeshxStore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
