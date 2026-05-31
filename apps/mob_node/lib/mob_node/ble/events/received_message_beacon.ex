defmodule Mob.Node.BLE.Events.ReceivedMessageBeacon do
  @moduledoc """
  Canonical BLE event for compact legacy advertisement message references.

  This is intentionally not `ReceivedMessage`: the full M14 envelope is not
  present. Older radios can prove they observed a MeshX-shaped message beacon,
  but routing, delivery semantics, payload access, ACKs, and persistence remain
  out of scope.
  """

  @enforce_keys [
    :beacon_version,
    :envelope_version,
    :payload_kind,
    :message_id_hash,
    :sender_peer_id_hash,
    :received_device_id,
    :received_at,
    :rssi,
    :raw_transport_metadata
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          beacon_version: pos_integer(),
          envelope_version: pos_integer(),
          payload_kind: binary(),
          message_id_hash: binary(),
          sender_peer_id_hash: binary(),
          received_device_id: binary(),
          received_at: integer(),
          rssi: integer(),
          raw_transport_metadata: map()
        }
end
