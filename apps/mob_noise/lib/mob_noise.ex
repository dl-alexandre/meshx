defmodule Mob.Noise do
  @moduledoc """
  MeshX Noise — Noise Protocol Framework wrapper for secure mesh sessions.

  Provides `Mob.Noise.Session` (a GenServer-isolated Decibel session)
  and `Mob.Noise.Supervisor` (a `DynamicSupervisor` for session lifecycles).

  ## Usage

      # Initiator
      {:ok, pid} = Mob.Noise.Session.start_link(role: :initiator)
      {:ok, msg1} = Mob.Noise.Session.handshake_send(pid)
      # … transport msg1 …
      :ok = Mob.Noise.Session.handshake_recv(pid, msg2)
      {:ok, msg3} = Mob.Noise.Session.handshake_send(pid)
      # … transport msg3 …
      true = Mob.Noise.Session.established?(pid)
      {:ok, ciphertext} = Mob.Noise.Session.encrypt(pid, "hello")

  See `Mob.Noise.Session` for the full API.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Mob.Noise.Supervisor
    ]

    opts = [strategy: :one_for_one, name: Mob.Noise.TopSupervisor]
    Supervisor.start_link(children, opts)
  end
end
