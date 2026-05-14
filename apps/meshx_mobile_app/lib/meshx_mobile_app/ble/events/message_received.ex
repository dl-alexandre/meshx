defmodule MeshxMobileApp.BLE.Events.MessageReceived do
  @moduledoc """
  Payload received from an authenticated peer over an established
  transport. Keyed by `peer_id` because by this point the device-level
  identifier is no longer the trust anchor.
  """

  @type t :: %__MODULE__{
          peer_id: binary(),
          transport: :ble,
          payload: binary(),
          received_at_ms: integer()
        }

  @enforce_keys [:peer_id, :payload, :received_at_ms]
  defstruct peer_id: nil, transport: :ble, payload: <<>>, received_at_ms: 0
end
