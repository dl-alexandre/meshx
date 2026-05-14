defmodule MeshxMobileApp.BLE.Events.ConnectionStateChanged do
  @moduledoc """
  Transport-level connection state, keyed by `device_id`.

  Distinct from `PeerAuthenticated` — a connected device is not yet a
  trusted peer. Mesh identity is established only after the post-connect
  cryptographic handshake.

  `reason` is only meaningful on `:disconnected` and must be drawn from
  `MeshxMobileApp.BLE.Error.kinds/0`.
  """

  @type state :: :connecting | :connected | :disconnecting | :disconnected

  @type t :: %__MODULE__{
          device_id: binary(),
          transport: :ble,
          state: state(),
          reason: MeshxMobileApp.BLE.Error.kind() | nil
        }

  @enforce_keys [:device_id, :state]
  defstruct device_id: nil, transport: :ble, state: :disconnected, reason: nil
end
