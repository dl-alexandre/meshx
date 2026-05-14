defmodule MeshxMobileApp.BLE.LocalInboxResolution do
  @moduledoc """
  Product-facing resolution status for advertisement-only local inbox items.

  This module adapts nearby-message read models into explicit full-message
  resolution states. It reuses `BeaconResolver` for the pure decision and
  deliberately does not fetch, connect, route, persist, ACK, retry, encrypt,
  or start background work.
  """

  alias MeshxMobileApp.BLE.{BeaconRef, BeaconResolver, LocalInboxView, MessageEnvelope}

  defmodule Status do
    @moduledoc false

    @enforce_keys [
      :message_key,
      :item_state,
      :resolution_state,
      :fetch_transport_state,
      :notes
    ]
    defstruct @enforce_keys ++
                [
                  request: nil,
                  envelope: nil,
                  reason: nil
                ]

    @type resolution_state ::
            :full_envelope_present
            | :already_known
            | :needs_fetch
            | :stale_needs_fetch
            | :unresolvable

    @type fetch_transport_state :: :not_needed | :not_validated | :not_applicable

    @type t :: %__MODULE__{
            message_key: binary(),
            item_state: LocalInboxView.Item.state(),
            resolution_state: resolution_state(),
            fetch_transport_state: fetch_transport_state(),
            request: map() | nil,
            envelope: MessageEnvelope.t() | nil,
            reason: term() | nil,
            notes: [atom()]
          }
  end

  @spec statuses(map()) :: [Status.t()]
  def statuses(%{} = snapshot) do
    items = nearby_messages(snapshot)
    envelopes = full_envelopes(items)

    Enum.map(items, &status(&1, envelopes))
  end

  defp nearby_messages(%{nearby_messages: nearby_messages}) when is_list(nearby_messages) do
    nearby_messages
  end

  defp nearby_messages(%{} = snapshot), do: LocalInboxView.nearby_messages(snapshot)

  @spec status(LocalInboxView.Item.t(), [MessageEnvelope.t()]) :: Status.t()
  def status(
        %LocalInboxView.Item{state: :full_message, envelope: %MessageEnvelope{} = envelope} = item,
        _envelopes
      ) do
    %Status{
      message_key: item.message_key,
      item_state: item.state,
      resolution_state: :full_envelope_present,
      fetch_transport_state: :not_needed,
      envelope: envelope,
      notes: [:full_envelope_available, :no_fetch_needed]
    }
  end

  def status(%LocalInboxView.Item{} = item, envelopes) do
    case item_to_ref(item) do
      {:ok, ref} -> resolve_ref(item, ref, envelopes)
      {:error, reason} -> unresolvable(item, {:invalid_beacon_ref, reason})
    end
  end

  defp resolve_ref(%LocalInboxView.Item{} = item, %BeaconRef{} = ref, envelopes) do
    case BeaconResolver.resolve(ref, envelopes) do
      {:already_known, envelope} ->
        %Status{
          message_key: item.message_key,
          item_state: item.state,
          resolution_state: :already_known,
          fetch_transport_state: :not_needed,
          envelope: envelope,
          notes: [:matching_full_envelope_available, :no_fetch_needed]
        }

      {:needs_fetch, request} ->
        %Status{
          message_key: item.message_key,
          item_state: item.state,
          resolution_state: needs_fetch_state(item),
          fetch_transport_state: :not_validated,
          request: request,
          notes: [:legacy_beacon_ref, :full_envelope_absent, :fetch_transport_not_validated]
        }

      {:unresolvable, reason} ->
        unresolvable(item, reason)
    end
  end

  defp unresolvable(%LocalInboxView.Item{} = item, reason) do
    %Status{
      message_key: item.message_key,
      item_state: item.state,
      resolution_state: :unresolvable,
      fetch_transport_state: :not_applicable,
      reason: reason,
      notes: [:legacy_beacon_ref, :cannot_resolve_from_local_state]
    }
  end

  defp needs_fetch_state(%LocalInboxView.Item{state: :stale_ref}), do: :stale_needs_fetch
  defp needs_fetch_state(%LocalInboxView.Item{}), do: :needs_fetch

  defp item_to_ref(%LocalInboxView.Item{} = item) do
    BeaconRef.new(
      envelope_version: item.envelope_version,
      payload_kind: item.payload_kind,
      message_id_hash: item.message_id_hash,
      sender_peer_hash: item.sender_peer_hash,
      observed_at: item.last_seen_at,
      received_device_id: received_device_id(item.source_device_ids),
      rssi: item.last_rssi
    )
  end

  defp received_device_id([id | _rest]) when is_binary(id) and id != "", do: id
  defp received_device_id(_ids), do: "unknown"

  defp full_envelopes(items) do
    items
    |> Enum.map(& &1.envelope)
    |> Enum.filter(&match?(%MessageEnvelope{}, &1))
  end
end
