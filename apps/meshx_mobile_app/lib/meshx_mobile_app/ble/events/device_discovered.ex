defmodule MeshxMobileApp.BLE.Events.DeviceDiscovered do
  @moduledoc """
  Emitted when a BLE scan turns up a previously unseen device.

  `device_id` is a transport-local opaque identifier — on iOS this is the
  rotating peripheral UUID, on Android the (possibly randomized) MAC.
  The mesh runtime never trusts it as identity; mesh-stable identity
  only arrives later via `PeerAuthenticated`.
  """

  @type t :: %__MODULE__{
          device_id: binary(),
          transport: :ble,
          rssi: integer(),
          advertisement: binary(),
          observed_at_ms: integer()
        }

  @enforce_keys [:device_id, :rssi, :advertisement, :observed_at_ms]
  defstruct device_id: nil, transport: :ble, rssi: 0, advertisement: <<>>, observed_at_ms: 0
end
