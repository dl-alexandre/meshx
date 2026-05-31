defmodule Mob.Node.BLE.Events.AdvertGossipOutcome do
  @moduledoc """
  Canonical outcome for one advertisement-gossip execution attempt.

  This is execution evidence only. `:gossiped` means the local Android
  BLE stack accepted a bounded advertisement action; it does not imply
  peer observation, delivery, ACK, routing, persistence, or retry.
  """

  @enforce_keys [
    :gossip_intent_id,
    :message_id_hash,
    :sender_peer_id_hash,
    :advertise_as,
    :kind,
    :outcome_at_ms,
    :adapter
  ]
  defstruct @enforce_keys ++ [reason: nil]

  @type kind :: :gossiped | :failed | :skipped | :invalid_intent | :would_gossip
  @type advertise_as :: :legacy_beacon_advert | :full_envelope_advert
  @type adapter :: :ble_android | :advert_gossip_dry_run

  @type t :: %__MODULE__{
          gossip_intent_id: binary(),
          message_id_hash: binary(),
          sender_peer_id_hash: binary(),
          advertise_as: advertise_as(),
          kind: kind(),
          outcome_at_ms: integer(),
          reason: atom() | binary() | nil,
          adapter: adapter()
        }
end
