defmodule Mob.Node.BLE.LocalInboxView do
  @moduledoc """
  Read-only presentation view for the advertisement-only local inbox.

  This module classifies nearby observations for product/UI consumers.
  It does not resolve beacon refs, fetch envelopes, route, persist, ACK,
  retry, encrypt, or mutate inbox state.
  """

  alias Mob.Node.BLE.{BeaconInbox, FullEnvelopeInbox}

  defmodule Item do
    @moduledoc false
    @enforce_keys [
      :state,
      :message_key,
      :payload_kind,
      :first_seen_at,
      :last_seen_at,
      :seen_count,
      :source_device_ids,
      :last_rssi
    ]
    defstruct @enforce_keys ++
                [
                  message_id: nil,
                  message_id_hash: nil,
                  sender_peer_id: nil,
                  sender_peer_hash: nil,
                  recipient_peer_id: nil,
                  envelope: nil,
                  envelope_version: nil,
                  observed_via: []
                ]

    @type state :: :full_message | :unresolved_ref | :gossiped_ref | :stale_ref

    @type t :: %__MODULE__{
            state: state(),
            message_key: binary(),
            message_id: binary() | nil,
            message_id_hash: binary() | nil,
            sender_peer_id: binary() | nil,
            sender_peer_hash: binary() | nil,
            recipient_peer_id: binary() | nil,
            payload_kind: binary(),
            envelope_version: pos_integer() | nil,
            envelope: term() | nil,
            first_seen_at: integer(),
            last_seen_at: integer(),
            seen_count: pos_integer(),
            source_device_ids: [binary()],
            last_rssi: integer(),
            observed_via: [atom()]
          }
  end

  @type opts :: [now: integer(), stale_after_ms: pos_integer()]

  @spec nearby_messages(map(), opts()) :: [Item.t()]
  def nearby_messages(%{} = snapshot, opts \\ []) do
    now = Keyword.get(opts, :now)
    stale_after_ms = Keyword.get(opts, :stale_after_ms, 60_000)

    full =
      snapshot
      |> Map.get(:full_messages, [])
      |> Enum.map(&full_item/1)

    refs =
      snapshot
      |> Map.get(:unresolved_beacon_refs, [])
      |> Enum.map(&ref_item(&1, now, stale_after_ms))

    (full ++ refs)
    |> Enum.sort_by(fn %Item{} = item ->
      {-item.last_seen_at, state_rank(item.state), item.message_key}
    end)
  end

  defp full_item(%FullEnvelopeInbox.Entry{} = entry) do
    %Item{
      state: :full_message,
      message_key: Base.encode16(entry.message_id, case: :lower),
      message_id: entry.message_id,
      sender_peer_id: entry.sender_peer_id,
      recipient_peer_id: entry.recipient_peer_id,
      payload_kind: entry.envelope.payload_type,
      envelope_version: entry.envelope.envelope_version,
      envelope: entry.envelope,
      first_seen_at: entry.first_seen_at,
      last_seen_at: entry.last_seen_at,
      seen_count: entry.seen_count,
      source_device_ids: entry.source_device_ids,
      last_rssi: entry.last_rssi
    }
  end

  defp ref_item(%BeaconInbox.Entry{} = entry, now, stale_after_ms) do
    %Item{
      state: ref_state(entry, now, stale_after_ms),
      message_key:
        Base.encode16(entry.message_id_hash, case: :lower) <>
          ":" <> Base.encode16(entry.sender_peer_hash, case: :lower),
      message_id_hash: entry.message_id_hash,
      sender_peer_hash: entry.sender_peer_hash,
      payload_kind: entry.payload_kind,
      envelope_version: entry.envelope_version,
      first_seen_at: entry.first_seen_at,
      last_seen_at: entry.last_seen_at,
      seen_count: entry.seen_count,
      source_device_ids: entry.source_device_ids,
      last_rssi: entry.last_rssi,
      observed_via: entry.observed_via
    }
  end

  defp ref_state(%BeaconInbox.Entry{} = entry, now, stale_after_ms)
       when is_integer(now) and is_integer(stale_after_ms) do
    if now - entry.last_seen_at > stale_after_ms do
      :stale_ref
    else
      ref_state(entry, nil, stale_after_ms)
    end
  end

  defp ref_state(%BeaconInbox.Entry{observed_via: observed_via}, _now, _stale_after_ms) do
    if :gossip_simulation in observed_via, do: :gossiped_ref, else: :unresolved_ref
  end

  defp state_rank(:full_message), do: 0
  defp state_rank(:unresolved_ref), do: 1
  defp state_rank(:gossiped_ref), do: 2
  defp state_rank(:stale_ref), do: 3
end
