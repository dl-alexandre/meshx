defmodule Mob.Node.BLE.Events.DeviceLost do
  @moduledoc """
  Emitted when a previously discovered device has not been seen within
  the bridge's stale-device window. Counterpart to `DeviceDiscovered`.
  """

  @type t :: %__MODULE__{
          device_id: binary(),
          transport: :ble,
          observed_at_ms: integer()
        }

  @enforce_keys [:device_id, :observed_at_ms]
  defstruct device_id: nil, transport: :ble, observed_at_ms: 0
end
