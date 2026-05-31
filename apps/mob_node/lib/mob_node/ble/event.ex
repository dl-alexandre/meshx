defmodule Mob.Node.BLE.Event do
  @moduledoc """
  Sum type over canonical BLE events emitted by every platform bridge.

  Both `Mob.Node.BLE.Adapter` implementations (iOS today, Android
  next) emit only these structs through `Mob.Node.BLE.Adapter.event_message/1`.
  Anything else is a contract violation.
  """

  alias Mob.Node.BLE.Events.{
    DeviceDiscovered,
    DeviceLost,
    AdvertisementReceived,
    ConnectionStateChanged,
    PeerAuthenticated,
    MessageReceived,
    ReceivedMessage,
    ReceivedMessageBeacon,
    AdvertGossipOutcome,
    Error
  }

  @type t ::
          DeviceDiscovered.t()
          | DeviceLost.t()
          | AdvertisementReceived.t()
          | ConnectionStateChanged.t()
          | PeerAuthenticated.t()
          | MessageReceived.t()
          | ReceivedMessage.t()
          | ReceivedMessageBeacon.t()
          | AdvertGossipOutcome.t()
          | Error.t()

  @struct_modules [
    DeviceDiscovered,
    DeviceLost,
    AdvertisementReceived,
    ConnectionStateChanged,
    PeerAuthenticated,
    MessageReceived,
    ReceivedMessage,
    ReceivedMessageBeacon,
    AdvertGossipOutcome,
    Error
  ]

  @spec event?(term()) :: boolean()
  def event?(%mod{}) when mod in @struct_modules, do: true
  def event?(_), do: false
end
