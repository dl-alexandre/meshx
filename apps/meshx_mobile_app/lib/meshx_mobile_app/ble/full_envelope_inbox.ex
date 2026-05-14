defmodule MeshxMobileApp.BLE.FullEnvelopeInbox do
  @moduledoc """
  In-memory inbox for full `ReceivedMessage` advertisement events.

  Inserts validate that the embedded canonical `MessageEnvelope` can
  round-trip through the envelope wire parser. The inbox deduplicates by
  `message_id` and records only local observation metadata.
  """

  alias MeshxMobileApp.BLE.Events.ReceivedMessage
  alias MeshxMobileApp.BLE.MessageEnvelope

  defmodule Entry do
    @moduledoc false
    @enforce_keys [
      :message_id,
      :sender_peer_id,
      :recipient_peer_id,
      :first_seen_at,
      :last_seen_at,
      :seen_count,
      :source_device_ids,
      :last_rssi,
      :envelope
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            message_id: binary(),
            sender_peer_id: binary(),
            recipient_peer_id: binary() | nil,
            first_seen_at: integer(),
            last_seen_at: integer(),
            seen_count: pos_integer(),
            source_device_ids: [binary()],
            last_rssi: integer(),
            envelope: MessageEnvelope.t()
          }
  end

  defstruct entries: %{}, rejected: []

  @type t :: %__MODULE__{entries: %{binary() => Entry.t()}, rejected: [term()]}

  @spec new() :: t()
  def new, do: %__MODULE__{}

  @spec insert(t(), ReceivedMessage.t()) :: {:ok, t()} | {:error, term(), t()}
  def insert(%__MODULE__{} = inbox, %ReceivedMessage{} = event) do
    with :ok <- validate_received_message(event) do
      entry =
        case Map.get(inbox.entries, event.message_id) do
          nil -> new_entry(event)
          %Entry{} = existing -> update_entry(existing, event)
        end

      {:ok, %{inbox | entries: Map.put(inbox.entries, event.message_id, entry)}}
    else
      {:error, reason} ->
        {:error, reason, %{inbox | rejected: [reason | inbox.rejected]}}
    end
  end

  @spec ingest(t(), term()) :: t()
  def ingest(%__MODULE__{} = inbox, %ReceivedMessage{} = event) do
    case insert(inbox, event) do
      {:ok, inbox} -> inbox
      {:error, _reason, inbox} -> inbox
    end
  end

  def ingest(%__MODULE__{} = inbox, _event), do: inbox

  @spec snapshot(t()) :: [Entry.t()]
  def snapshot(%__MODULE__{} = inbox) do
    inbox.entries
    |> Map.values()
    |> Enum.sort_by(fn %Entry{} = entry -> {entry.first_seen_at, entry.message_id} end)
  end

  defp validate_received_message(%ReceivedMessage{} = event) do
    encoded = MessageEnvelope.encode(event.envelope)

    with {:ok, parsed} <- MessageEnvelope.parse(encoded),
         :ok <- require_equal(parsed.message_id, event.message_id, :message_id_mismatch),
         :ok <-
           require_equal(parsed.sender_peer_id, event.sender_peer_id, :sender_peer_id_mismatch),
         :ok <-
           require_equal(
             parsed.recipient_peer_id,
             event.recipient_peer_id,
             :recipient_peer_id_mismatch
           ) do
      :ok
    else
      {:error, reason} -> {:error, {:invalid_envelope, reason}}
    end
  end

  defp require_equal(left, right, _reason) when left == right, do: :ok
  defp require_equal(_left, _right, reason), do: {:error, reason}

  defp new_entry(%ReceivedMessage{} = event) do
    %Entry{
      message_id: event.message_id,
      sender_peer_id: event.sender_peer_id,
      recipient_peer_id: event.recipient_peer_id,
      first_seen_at: event.received_at,
      last_seen_at: event.received_at,
      seen_count: 1,
      source_device_ids: [event.received_device_id],
      last_rssi: event.rssi,
      envelope: event.envelope
    }
  end

  defp update_entry(%Entry{} = entry, %ReceivedMessage{} = event) do
    %{
      entry
      | last_seen_at: max(entry.last_seen_at, event.received_at),
        seen_count: entry.seen_count + 1,
        source_device_ids: merge_source(entry.source_device_ids, event.received_device_id),
        last_rssi: event.rssi,
        envelope: event.envelope
    }
  end

  defp merge_source(ids, id), do: Enum.sort(Enum.uniq([id | ids]))
end
