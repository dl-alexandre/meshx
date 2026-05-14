defmodule MeshxMobileApp.BLE.Events.PeerAuthenticated do
  @moduledoc """
  Emitted once the post-connect cryptographic handshake succeeds.

  This is the boundary at which a transport device becomes a mesh peer.
  Both identifiers are carried so the runtime can correlate the stable
  `peer_id` with the rotating transport `device_id` for the lifetime of
  the connection.

  Not emitted by the current iOS bridge — the handshake landed in the
  Swift Noise harness but the NIF doesn't surface it yet. The struct
  exists in the contract so Android implementers see the boundary up
  front.
  """

  @type t :: %__MODULE__{
          peer_id: binary(),
          device_id: binary(),
          transport: :ble,
          capabilities: MeshxMobileApp.BLE.Capabilities.t()
        }

  @enforce_keys [:peer_id, :device_id, :capabilities]
  defstruct peer_id: nil, device_id: nil, transport: :ble, capabilities: nil
end
