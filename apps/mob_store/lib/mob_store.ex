defmodule Mob.Store do
  @moduledoc """
  MeshX Store — durable local persistence and in-memory caches.

  Provides:

    * `Mob.Store.DB` — CubDB-backed key-value store for local-first storage.
    * `Mob.Store.Identity` — persistent local Noise static key storage.
    * `Mob.Store.Trust` — peer trust-on-first-use, pinned, and allowlist policy.
    * `Mob.Store.Message` — persisted mesh messages.
    * `Mob.Store.Outbox` — store-and-forward outbox with retry logic.
    * `Mob.Store.Dedupe` — TTL-based deduplication cache.
    * `Mob.Store.RelayCache` — in-memory relay buffer.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mob.Store.DB,
      Mob.Store.Dedupe,
      Mob.Store.RelayCache
    ]

    opts = [strategy: :one_for_one, name: Mob.Store.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
