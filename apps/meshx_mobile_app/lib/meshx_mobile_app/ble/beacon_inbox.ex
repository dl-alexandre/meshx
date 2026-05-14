defmodule MeshxMobileApp.BLE.BeaconInbox do
  @moduledoc """
  In-memory inbox for canonical `received_message_beacon` events.

  A beacon inbox records nearby message references observed via legacy
  advertisements. It does not resolve, fetch, route, persist, retry, ACK,
  decrypt, or claim message delivery.
  """

  alias MeshxMobileApp.BLE.Events.ReceivedMessageBeacon

  defmodule Entry do
    @moduledoc false
    @enforce_keys [
      :message_id_hash,
      :sender_peer_hash,
      :first_seen_at,
      :last_seen_at,
      :seen_count,
      :source_device_ids,
      :last_rssi,
      :payload_kind,
      :envelope_version
    ]
    defstruct @enforce_keys ++
                [
                  observed_via: []
                ]

    @type t :: %__MODULE__{
            message_id_hash: binary(),
            sender_peer_hash: binary(),
            first_seen_at: integer(),
            last_seen_at: integer(),
            seen_count: pos_integer(),
            source_device_ids: [binary()],
            last_rssi: integer(),
            payload_kind: binary(),
            envelope_version: pos_integer(),
            observed_via: [atom()]
          }
  end

  defstruct entries: %{}

  @type key :: {binary(), binary()}
  @type t :: %__MODULE__{entries: %{key() => Entry.t()}}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec insert(t(), ReceivedMessageBeacon.t()) :: t()
  def insert(%__MODULE__{} = inbox, %ReceivedMessageBeacon{} = event) do
    key = {event.message_id_hash, event.sender_peer_id_hash}

    entry =
      case Map.get(inbox.entries, key) do
        nil -> new_entry(event)
        %Entry{} = existing -> update_entry(existing, event)
      end

    %{inbox | entries: Map.put(inbox.entries, key, entry)}
  end

  @spec ingest(t(), term()) :: t()
  def ingest(%__MODULE__{} = inbox, %ReceivedMessageBeacon{} = event), do: insert(inbox, event)
  def ingest(%__MODULE__{} = inbox, _event), do: inbox

  @spec snapshot(t()) :: [Entry.t()]
  def snapshot(%__MODULE__{} = inbox) do
    inbox.entries
    |> Map.values()
    |> Enum.sort_by(fn %Entry{} = entry ->
      {entry.first_seen_at, entry.message_id_hash, entry.sender_peer_hash}
    end)
  end

  defp new_entry(%ReceivedMessageBeacon{} = event) do
    %Entry{
      message_id_hash: event.message_id_hash,
      sender_peer_hash: event.sender_peer_id_hash,
      first_seen_at: event.received_at,
      last_seen_at: event.received_at,
      seen_count: 1,
      source_device_ids: [event.received_device_id],
      last_rssi: event.rssi,
      payload_kind: event.payload_kind,
      envelope_version: event.envelope_version,
      observed_via: [observed_via(event)]
    }
  end

  defp update_entry(%Entry{} = entry, %ReceivedMessageBeacon{} = event) do
    %{
      entry
      | last_seen_at: max(entry.last_seen_at, event.received_at),
        seen_count: entry.seen_count + 1,
        source_device_ids: merge_source(entry.source_device_ids, event.received_device_id),
        last_rssi: event.rssi,
        payload_kind: event.payload_kind,
        envelope_version: event.envelope_version,
        observed_via: merge_observed_via(entry.observed_via, observed_via(event))
    }
  end

  defp merge_source(ids, id), do: Enum.sort(Enum.uniq([id | ids]))

  defp merge_observed_via(via, value), do: Enum.sort(Enum.uniq([value | via]))

  defp observed_via(%ReceivedMessageBeacon{} = event) do
    transport = Map.get(event.raw_transport_metadata, :transport)

    cond do
      transport in [:advert_gossip_simulation, "advert_gossip_simulation"] ->
        :gossip_simulation

      transport in [:ble_advertisement, "ble_advertisement", :ble_android, "ble_android"] ->
        :ble_advertisement

      true ->
        :unknown
    end
  end
end
