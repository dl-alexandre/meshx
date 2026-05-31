defmodule Mob.Node.BLE.AdvertGossipPlanner do
  @moduledoc """
  Pure planner for opportunistic advertisement gossip.

  It turns a `LocalInbox.snapshot/1` into planned advertisement intents.
  Full messages may be gossiped as full-envelope advertisements only when
  the caller marks that path capability-proven; otherwise they degrade to
  legacy beacon references. Unresolved beacon refs always remain refs.

  No BLE radio call, routing, ACK, retry, persistence, crypto, or
  background service is introduced here.
  """

  alias Mob.Node.BLE.{
    AdvertGossipLedger,
    AdvertGossipPolicy,
    BeaconInbox,
    BeaconRef,
    FullEnvelopeInbox,
    MessageEnvelope
  }

  defmodule Intent do
    @moduledoc false

    @enforce_keys [
      :gossip_intent_id,
      :source,
      :advertise_as,
      :message_id_hash,
      :sender_peer_hash,
      :payload_kind,
      :envelope_version,
      :source_device_ids,
      :first_seen_at,
      :last_seen_at,
      :seen_count,
      :planned_at
    ]
    defstruct @enforce_keys ++ [envelope: nil, status: :planned]

    @type source :: :full_message | :beacon_ref
    @type advertise_as :: :full_envelope_advert | :legacy_beacon_advert

    @type t :: %__MODULE__{
            gossip_intent_id: binary(),
            source: source(),
            advertise_as: advertise_as(),
            message_id_hash: binary(),
            sender_peer_hash: binary(),
            payload_kind: binary(),
            envelope_version: pos_integer(),
            source_device_ids: [binary()],
            first_seen_at: integer(),
            last_seen_at: integer(),
            seen_count: pos_integer(),
            planned_at: integer(),
            envelope: MessageEnvelope.t() | nil,
            status: :planned
          }
  end

  @type opts :: [
          now: integer(),
          policy: AdvertGossipPolicy.t(),
          ledger: AdvertGossipLedger.t(),
          full_envelope_capability_proven: boolean(),
          id_fun: (non_neg_integer() -> binary())
        ]

  @spec plan(map(), opts()) :: [Intent.t()]
  def plan(%{} = local_snapshot, opts) do
    now = Keyword.fetch!(opts, :now)
    policy = Keyword.get(opts, :policy, AdvertGossipPolicy.default())
    ledger = Keyword.get(opts, :ledger, AdvertGossipLedger.new())
    full_envelope_capability_proven = Keyword.get(opts, :full_envelope_capability_proven, false)
    id_fun = Keyword.get(opts, :id_fun, &default_id/1)

    with :ok <- AdvertGossipPolicy.validate(policy) do
      local_snapshot
      |> candidates(full_envelope_capability_proven, now)
      |> suppress(ledger, policy, now)
      |> Enum.take(policy.max_intents)
      |> Enum.with_index()
      |> Enum.map(fn {attrs, index} ->
        struct!(Intent, Map.put(attrs, :gossip_intent_id, id_fun.(index)))
      end)
    else
      {:error, _reason} -> []
    end
  end

  defp candidates(snapshot, full_envelope_capability_proven, now) do
    full =
      snapshot
      |> Map.get(:full_messages, [])
      |> Enum.map(&full_message_candidate(&1, full_envelope_capability_proven, now))

    full_keys = MapSet.new(full, &{&1.message_id_hash, &1.sender_peer_hash})

    beacon =
      snapshot
      |> Map.get(:unresolved_beacon_refs, [])
      |> Enum.reject(&MapSet.member?(full_keys, {&1.message_id_hash, &1.sender_peer_hash}))
      |> Enum.map(&beacon_candidate(&1, now))

    (full ++ beacon)
    |> Enum.sort_by(fn attrs ->
      {-attrs.last_seen_at, attrs.source, attrs.message_id_hash, attrs.sender_peer_hash}
    end)
  end

  defp full_message_candidate(
         %FullEnvelopeInbox.Entry{} = entry,
         full_envelope_capability_proven,
         now
       ) do
    %{
      source: :full_message,
      advertise_as:
        if(full_envelope_capability_proven,
          do: :full_envelope_advert,
          else: :legacy_beacon_advert
        ),
      message_id_hash: BeaconRef.message_id_hash(entry.envelope),
      sender_peer_hash: BeaconRef.sender_peer_hash(entry.envelope),
      payload_kind: entry.envelope.payload_type,
      envelope_version: entry.envelope.envelope_version,
      source_device_ids: entry.source_device_ids,
      first_seen_at: entry.first_seen_at,
      last_seen_at: entry.last_seen_at,
      seen_count: entry.seen_count,
      planned_at: now,
      envelope: if(full_envelope_capability_proven, do: entry.envelope, else: nil)
    }
  end

  defp beacon_candidate(%BeaconInbox.Entry{} = entry, now) do
    %{
      source: :beacon_ref,
      advertise_as: :legacy_beacon_advert,
      message_id_hash: entry.message_id_hash,
      sender_peer_hash: entry.sender_peer_hash,
      payload_kind: entry.payload_kind,
      envelope_version: entry.envelope_version,
      source_device_ids: entry.source_device_ids,
      first_seen_at: entry.first_seen_at,
      last_seen_at: entry.last_seen_at,
      seen_count: entry.seen_count,
      planned_at: now,
      envelope: nil
    }
  end

  defp suppress(candidates, %AdvertGossipLedger{} = ledger, %AdvertGossipPolicy{} = policy, now) do
    Enum.reject(candidates, fn attrs ->
      key = {attrs.message_id_hash, attrs.sender_peer_hash}
      AdvertGossipLedger.suppressed?(ledger, key, now, policy.min_interval_ms)
    end)
  end

  defp default_id(index), do: "advert-gossip-#{index}"
end
