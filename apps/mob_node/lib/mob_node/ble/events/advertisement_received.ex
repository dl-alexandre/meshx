defmodule Mob.Node.BLE.Events.AdvertisementReceived do
  @moduledoc """
  Emitted for each advertisement packet observed for a device already
  surfaced via `DeviceDiscovered`. Lets the runtime track RSSI changes
  and rotating advertisement payloads without conflating them with
  new discoveries.
  """

  @type t :: %__MODULE__{
          device_id: binary(),
          rssi: integer(),
          advertisement: binary(),
          observed_at_ms: integer()
        }

  @enforce_keys [:device_id, :rssi, :advertisement, :observed_at_ms]
  defstruct device_id: nil, rssi: 0, advertisement: <<>>, observed_at_ms: 0
end
