defmodule MeshxMobileApp.BLE.Events.ReceivedMessage do
  @moduledoc """
  Canonical message event derived from a MeshX message advertisement.

  This is separate from `MessageReceived`, which represents payload
  bytes received over an established/authenticated transport. A
  `ReceivedMessage` is passive BLE-advertisement ingress only: no
  routing, no acknowledgements, no peer graph mutation, and no
  delivery guarantee.
  """

  alias MeshxMobileApp.BLE.MessageEnvelope

  @type t :: %__MODULE__{
          message_id: MessageEnvelope.message_id(),
          sender_peer_id: binary(),
          recipient_peer_id: binary() | nil,
          received_device_id: binary(),
          received_at: integer(),
          rssi: integer(),
          envelope: MessageEnvelope.t(),
          raw_transport_metadata: map()
        }

  @enforce_keys [
    :message_id,
    :sender_peer_id,
    :recipient_peer_id,
    :received_device_id,
    :received_at,
    :rssi,
    :envelope,
    :raw_transport_metadata
  ]
  defstruct message_id: nil,
            sender_peer_id: nil,
            recipient_peer_id: nil,
            received_device_id: nil,
            received_at: 0,
            rssi: 0,
            envelope: nil,
            raw_transport_metadata: %{}
end
