defmodule MeshxProtocol do
  @moduledoc """
  MeshX Protocol — packet framing, codecs, TTL, gossip, and fragmentation.

  This is the foundational, transport-agnostic wire protocol for the MeshX mesh
  networking stack. It provides compact binary framing suitable for BLE and
  other constrained transports.

  ## Modules

    * `MeshxProtocol.Packet` — packet struct and type constants
    * `MeshxProtocol.Framing` — frame encoding/decoding with checksums
    * `MeshxProtocol.Fragment` — payload fragmentation and reassembly
    * `MeshxProtocol.Gossip` — epidemic gossip primitives
    * `MeshxProtocol.Codec` — high-level encode/decode API
  """

  use Application

  @impl true
  def start(_type, _args) do
    # Protocol layer is currently stateless; supervisor exists for OTP compliance.
    children = []
    opts = [strategy: :one_for_one, name: MeshxProtocol.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc "Returns the current protocol version byte."
  def version, do: MeshxProtocol.Packet.version()
end
