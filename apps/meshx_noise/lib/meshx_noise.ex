defmodule MeshxNoise do
  @moduledoc """
  MeshX Noise — Noise Protocol Framework wrapper for secure mesh sessions.

  Provides `MeshxNoise.Session` (a GenServer-isolated Decibel session)
  and `MeshxNoise.Supervisor` (a `DynamicSupervisor` for session lifecycles).

  ## Usage

      # Initiator
      {:ok, pid} = MeshxNoise.Session.start_link(role: :initiator)
      {:ok, msg1} = MeshxNoise.Session.handshake_send(pid)
      # … transport msg1 …
      :ok = MeshxNoise.Session.handshake_recv(pid, msg2)
      {:ok, msg3} = MeshxNoise.Session.handshake_send(pid)
      # … transport msg3 …
      true = MeshxNoise.Session.established?(pid)
      {:ok, ciphertext} = MeshxNoise.Session.encrypt(pid, "hello")

  See `MeshxNoise.Session` for the full API.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MeshxNoise.Supervisor
    ]

    opts = [strategy: :one_for_one, name: MeshxNoise.TopSupervisor]
    Supervisor.start_link(children, opts)
  end
end
