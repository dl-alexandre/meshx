defmodule Mob.Node.BLE.LocalInboxDurableSnapshot do
  @moduledoc """
  Restores a policy-approved durable local inbox snapshot into a read model.

  The restored shape is for product/query consumers. It does not rebuild
  the live in-memory inbox, replay raw BLE events, resolve beacons, fetch
  envelopes, route, persist, ACK, retry, encrypt, or start background work.
  """

  alias Mob.Node.BLE.{
    LocalInboxResolution,
    LocalInboxDurableSnapshotSchemaPolicy,
    LocalInboxTrust,
    LocalInboxView,
    MessageEnvelope
  }

  @type opts :: [now: integer(), stale_after_ms: pos_integer()]

  @spec to_read_model(map(), opts()) :: {:ok, map()} | {:error, term()}
  def to_read_model(durable, opts \\ [])

  def to_read_model(%{} = durable, opts) do
    with {:ok, durable} <- LocalInboxDurableSnapshotSchemaPolicy.normalize(durable) do
      restore_current(durable, opts)
    end
  end

  def to_read_model(_durable, _opts), do: {:error, :invalid_durable_snapshot}

  defp restore_current(durable, opts) do
    with {:ok, full_items} <- full_items(Map.get(durable, :full_messages, [])),
         {:ok, ref_items} <- ref_items(Map.get(durable, :unresolved_beacon_refs, []), opts) do
      read_model = %{
        durable_schema_version: durable.schema_version,
        persisted_at: durable.persisted_at,
        policy: Map.get(durable, :policy, %{}),
        transport_profile: Map.get(durable, :transport_profile),
        capability_notes: Map.get(durable, :capability_notes, []),
        nearby_messages: sort_items(full_items ++ ref_items)
      }

      read_model =
        Map.put(read_model, :trust_evidence, LocalInboxTrust.classify_snapshot(read_model))

      {:ok, Map.put(read_model, :resolution_statuses, LocalInboxResolution.statuses(read_model))}
    end
  end

  defp full_items(messages) when is_list(messages) do
    messages
    |> Enum.reduce_while({:ok, []}, fn message, {:ok, acc} ->
      case full_item(message) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok()
  end

  defp full_items(_messages), do: {:error, :invalid_full_messages}

  defp ref_items(refs, opts) when is_list(refs) do
    refs
    |> Enum.reduce_while({:ok, []}, fn ref, {:ok, acc} ->
      case ref_item(ref, opts) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> reverse_ok()
  end

  defp ref_items(_refs, _opts), do: {:error, :invalid_beacon_refs}

  defp full_item(%{kind: :full_message} = message) do
    with {:ok, message_id} <- decode64(Map.get(message, :message_id), :invalid_message_id),
         {:ok, envelope_wire} <-
           decode64(Map.get(message, :envelope_wire), :invalid_envelope_wire),
         {:ok, envelope} <- parse_envelope(envelope_wire),
         :ok <- require_equal(envelope.message_id, message_id, :message_id_mismatch),
         :ok <-
           require_equal(
             envelope.sender_peer_id,
             Map.get(message, :sender_peer_id),
             :sender_peer_id_mismatch
           ),
         :ok <-
           require_equal(
             envelope.recipient_peer_id,
             Map.get(message, :recipient_peer_id),
             :recipient_peer_id_mismatch
           ) do
      {:ok,
       %LocalInboxView.Item{
         state: :full_message,
         message_key: Base.encode16(message_id, case: :lower),
         message_id: message_id,
         sender_peer_id: envelope.sender_peer_id,
         recipient_peer_id: envelope.recipient_peer_id,
         payload_kind: envelope.payload_type,
         envelope_version: envelope.envelope_version,
         envelope: envelope,
         first_seen_at: Map.get(message, :first_seen_at),
         last_seen_at: Map.get(message, :last_seen_at),
         seen_count: Map.get(message, :seen_count),
         source_device_ids: Map.get(message, :source_device_ids, []),
         last_rssi: Map.get(message, :last_rssi)
       }}
    end
  end

  defp full_item(_message), do: {:error, :invalid_full_message}

  defp ref_item(%{kind: :unresolved_beacon_ref} = ref, opts) do
    with {:ok, message_id_hash} <-
           decode64(Map.get(ref, :message_id_hash), :invalid_message_id_hash),
         {:ok, sender_peer_hash} <-
           decode64(Map.get(ref, :sender_peer_hash), :invalid_sender_peer_hash) do
      {:ok,
       %LocalInboxView.Item{
         state: ref_state(ref, opts),
         message_key:
           Base.encode16(message_id_hash, case: :lower) <>
             ":" <> Base.encode16(sender_peer_hash, case: :lower),
         message_id_hash: message_id_hash,
         sender_peer_hash: sender_peer_hash,
         payload_kind: Map.get(ref, :payload_kind),
         envelope_version: Map.get(ref, :envelope_version),
         first_seen_at: Map.get(ref, :first_seen_at),
         last_seen_at: Map.get(ref, :last_seen_at),
         seen_count: Map.get(ref, :seen_count),
         source_device_ids: Map.get(ref, :source_device_ids, []),
         last_rssi: Map.get(ref, :last_rssi),
         observed_via: normalize_observed_via(Map.get(ref, :observed_via, []))
       }}
    end
  end

  defp ref_item(_ref, _opts), do: {:error, :invalid_beacon_ref}

  defp ref_state(ref, opts) do
    now = Keyword.get(opts, :now)
    stale_after_ms = Keyword.get(opts, :stale_after_ms, 60_000)

    cond do
      is_integer(now) and is_integer(stale_after_ms) and
          now - Map.get(ref, :last_seen_at, 0) > stale_after_ms ->
        :stale_ref

      :gossip_simulation in normalize_observed_via(Map.get(ref, :observed_via, [])) ->
        :gossiped_ref

      true ->
        :unresolved_ref
    end
  end

  defp parse_envelope(envelope_wire) do
    case MessageEnvelope.parse(envelope_wire) do
      {:ok, envelope} -> {:ok, envelope}
      {:error, reason} -> {:error, {:invalid_envelope, reason}}
    end
  end

  defp decode64(value, _reason) when is_binary(value) do
    case Base.decode64(value, padding: false) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, :invalid_base64}
    end
  end

  defp decode64(_value, reason), do: {:error, reason}

  defp normalize_observed_via(values) when is_list(values) do
    Enum.flat_map(values, fn
      value when is_atom(value) -> [value]
      "gossip_simulation" -> [:gossip_simulation]
      "ble_advertisement" -> [:ble_advertisement]
      "unknown" -> [:unknown]
      _value -> []
    end)
  end

  defp normalize_observed_via(_values), do: []

  defp sort_items(items) do
    Enum.sort_by(items, fn %LocalInboxView.Item{} = item ->
      {-item.last_seen_at, state_rank(item.state), item.message_key}
    end)
  end

  defp state_rank(:full_message), do: 0
  defp state_rank(:unresolved_ref), do: 1
  defp state_rank(:gossiped_ref), do: 2
  defp state_rank(:stale_ref), do: 3

  defp reverse_ok({:ok, list}), do: {:ok, Enum.reverse(list)}
  defp reverse_ok({:error, _reason} = error), do: error

  defp require_equal(left, right, _reason) when left == right, do: :ok
  defp require_equal(_left, _right, reason), do: {:error, reason}
end
