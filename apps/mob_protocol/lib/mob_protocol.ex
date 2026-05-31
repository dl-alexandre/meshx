defmodule Mob.Protocol do
  @moduledoc """
  MeshX Protocol — packet framing, codecs, TTL, gossip, and fragmentation.

  This is the foundational, transport-agnostic wire protocol for the MeshX mesh
  networking stack. It provides compact binary framing suitable for BLE and
  other constrained transports.

  ## Modules

    * `Mob.Protocol.Packet` — packet struct and type constants
    * `Mob.Protocol.Framing` — frame encoding/decoding with checksums
    * `Mob.Protocol.Fragment` — payload fragmentation and reassembly
    * `Mob.Protocol.Gossip` — epidemic gossip primitives
    * `Mob.Protocol.Codec` — high-level encode/decode API
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Protocol layer is currently stateless; supervisor exists for OTP compliance.
    children = []
    opts = [strategy: :one_for_one, name: Mob.Protocol.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc "Returns the current protocol version byte."
  def version, do: Mob.Protocol.Packet.version()
end
