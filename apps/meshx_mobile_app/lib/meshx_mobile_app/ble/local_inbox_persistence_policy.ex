defmodule MeshxMobileApp.BLE.LocalInboxPersistencePolicy do
  @moduledoc """
  Pure persistence policy for advertisement-only local inbox snapshots.

  This module defines what a future durable store may write for nearby
  messages. It does not write files, open a database, start a process,
  subscribe to BLE events, resolve beacons, fetch envelopes, route, ACK,
  retry, encrypt, or run in the background.
  """

  alias MeshxMobileApp.BLE.{BeaconInbox, FullEnvelopeInbox, MessageEnvelope}

  @schema_version 1
  @default_full_message_retention_ms 7 * 24 * 60 * 60 * 1_000
  @default_beacon_ref_retention_ms 24 * 60 * 60 * 1_000

  defstruct schema_version: @schema_version,
            full_message_retention_ms: @default_full_message_retention_ms,
            beacon_ref_retention_ms: @default_beacon_ref_retention_ms,
            persist_raw_transport_metadata?: false,
            persist_source_device_ids?: false

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          full_message_retention_ms: pos_integer() | :forever,
          beacon_ref_retention_ms: pos_integer() | :forever,
          persist_raw_transport_metadata?: boolean(),
          persist_source_device_ids?: boolean()
        }

  @type durable_snapshot :: %{
          required(:schema_version) => pos_integer(),
          required(:persisted_at) => integer(),
          required(:policy) => map(),
          required(:transport_profile) => map() | nil,
          required(:full_messages) => [map()],
          required(:unresolved_beacon_refs) => [map()],
          required(:excluded_fields) => [atom()],
          required(:capability_notes) => [binary()]
        }

  @spec default() :: t()
  def default, do: %__MODULE__{}

  @spec new(keyword()) :: {:ok, t()} | {:error, term()}
  def new(opts) do
    policy = %__MODULE__{
      full_message_retention_ms:
        Keyword.get(opts, :full_message_retention_ms, @default_full_message_retention_ms),
      beacon_ref_retention_ms:
        Keyword.get(opts, :beacon_ref_retention_ms, @default_beacon_ref_retention_ms),
      persist_source_device_ids?: Keyword.get(opts, :persist_source_device_ids?, false)
    }

    with :ok <- validate_retention(policy.full_message_retention_ms),
         :ok <- validate_retention(policy.beacon_ref_retention_ms) do
      {:ok, policy}
    end
  end

  @spec durable_snapshot(map(), keyword()) :: {:ok, durable_snapshot()} | {:error, term()}
  def durable_snapshot(snapshot, opts \\ [])

  def durable_snapshot(%{} = local_snapshot, opts) do
    policy = Keyword.get(opts, :policy, default())

    with {:ok, persisted_at} <- fetch_persisted_at(opts),
         :ok <- validate_policy(policy),
         {:ok, full_messages} <- full_messages(local_snapshot, policy, persisted_at),
         {:ok, beacon_refs} <- beacon_refs(local_snapshot, policy, persisted_at) do
      {:ok,
       %{
         schema_version: policy.schema_version,
         persisted_at: persisted_at,
         policy: policy_snapshot(policy),
         transport_profile: Map.get(local_snapshot, :transport_profile),
         full_messages: full_messages,
         unresolved_beacon_refs: beacon_refs,
         excluded_fields: excluded_fields(policy),
         capability_notes: Map.get(local_snapshot, :capability_notes, [])
       }}
    end
  end

  def durable_snapshot(_snapshot, _opts), do: {:error, :invalid_local_inbox_snapshot}

  defp fetch_persisted_at(opts) do
    case Keyword.fetch(opts, :persisted_at) do
      {:ok, value} when is_integer(value) -> {:ok, value}
      {:ok, _value} -> {:error, :invalid_persisted_at}
      :error -> {:error, :missing_persisted_at}
    end
  end

  @spec persistable?(FullEnvelopeInbox.Entry.t() | BeaconInbox.Entry.t(), t(), integer()) ::
          boolean()
  def persistable?(%FullEnvelopeInbox.Entry{} = entry, %__MODULE__{} = policy, now) do
    within_retention?(entry.last_seen_at, now, policy.full_message_retention_ms)
  end

  def persistable?(%BeaconInbox.Entry{} = entry, %__MODULE__{} = policy, now) do
    within_retention?(entry.last_seen_at, now, policy.beacon_ref_retention_ms)
  end

  def persistable?(_entry, _policy, _now), do: false

  defp full_messages(snapshot, policy, persisted_at) do
    snapshot
    |> Map.get(:full_messages, [])
    |> Enum.filter(&persistable?(&1, policy, persisted_at))
    |> Enum.reduce_while({:ok, []}, fn
      %FullEnvelopeInbox.Entry{} = entry, {:ok, acc} ->
        case durable_full_message(entry, policy) do
          {:ok, durable} -> {:cont, {:ok, [durable | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      _entry, {:ok, _acc} ->
        {:halt, {:error, :invalid_full_message_entry}}
    end)
    |> reverse_ok()
  end

  defp beacon_refs(snapshot, policy, persisted_at) do
    refs =
      snapshot
      |> Map.get(:unresolved_beacon_refs, [])
      |> Enum.filter(&persistable?(&1, policy, persisted_at))
      |> Enum.map(&durable_beacon_ref(&1, policy))

    if Enum.all?(refs, &match?({:ok, _}, &1)) do
      {:ok, Enum.map(refs, fn {:ok, ref} -> ref end)}
    else
      {:error, :invalid_beacon_ref_entry}
    end
  end

  defp durable_full_message(%FullEnvelopeInbox.Entry{} = entry, policy) do
    encoded = MessageEnvelope.encode(entry.envelope)

    with {:ok, parsed} <- MessageEnvelope.parse(encoded),
         :ok <- require_equal(parsed.message_id, entry.message_id, :message_id_mismatch),
         :ok <-
           require_equal(parsed.sender_peer_id, entry.sender_peer_id, :sender_peer_id_mismatch),
         :ok <-
           require_equal(
             parsed.recipient_peer_id,
             entry.recipient_peer_id,
             :recipient_peer_id_mismatch
           ) do
      {:ok,
       maybe_put_source_device_ids(
         %{
           kind: :full_message,
           message_id: encode64(entry.message_id),
           sender_peer_id: entry.sender_peer_id,
           recipient_peer_id: entry.recipient_peer_id,
           envelope_version: entry.envelope.envelope_version,
           payload_kind: entry.envelope.payload_type,
           envelope_wire: encode64(encoded),
           first_seen_at: entry.first_seen_at,
           last_seen_at: entry.last_seen_at,
           seen_count: entry.seen_count,
           source_device_count: length(entry.source_device_ids),
           last_rssi: entry.last_rssi
         },
         entry.source_device_ids,
         policy
       )}
    else
      {:error, reason} -> {:error, {:invalid_full_message_entry, reason}}
    end
  end

  defp durable_beacon_ref(%BeaconInbox.Entry{} = entry, policy) do
    {:ok,
     maybe_put_source_device_ids(
       %{
         kind: :unresolved_beacon_ref,
         delivery_state: :unresolved,
         message_id_hash: encode64(entry.message_id_hash),
         sender_peer_hash: encode64(entry.sender_peer_hash),
         envelope_version: entry.envelope_version,
         payload_kind: entry.payload_kind,
         first_seen_at: entry.first_seen_at,
         last_seen_at: entry.last_seen_at,
         seen_count: entry.seen_count,
         source_device_count: length(entry.source_device_ids),
         last_rssi: entry.last_rssi,
         observed_via: entry.observed_via
       },
       entry.source_device_ids,
       policy
     )}
  end

  defp durable_beacon_ref(_entry, _policy), do: {:error, :invalid_beacon_ref_entry}

  defp maybe_put_source_device_ids(map, source_device_ids, %__MODULE__{
         persist_source_device_ids?: true
       }) do
    Map.put(map, :source_device_ids, source_device_ids)
  end

  defp maybe_put_source_device_ids(map, _source_device_ids, %__MODULE__{}), do: map

  defp validate_policy(%__MODULE__{schema_version: @schema_version} = policy) do
    with :ok <- validate_retention(policy.full_message_retention_ms),
         :ok <- validate_retention(policy.beacon_ref_retention_ms),
         false <- policy.persist_raw_transport_metadata? do
      :ok
    else
      true -> {:error, :raw_transport_metadata_not_persistable}
      {:error, _reason} = error -> error
    end
  end

  defp validate_policy(%__MODULE__{}), do: {:error, :unsupported_schema_version}
  defp validate_policy(_policy), do: {:error, :invalid_policy}

  defp validate_retention(:forever), do: :ok
  defp validate_retention(value) when is_integer(value) and value > 0, do: :ok
  defp validate_retention(_value), do: {:error, :invalid_retention}

  defp within_retention?(_last_seen_at, _now, :forever), do: true

  defp within_retention?(last_seen_at, now, retention_ms)
       when is_integer(last_seen_at) and is_integer(now) and is_integer(retention_ms) do
    now - last_seen_at <= retention_ms
  end

  defp within_retention?(_last_seen_at, _now, _retention_ms), do: false

  defp policy_snapshot(%__MODULE__{} = policy) do
    %{
      full_message_retention_ms: policy.full_message_retention_ms,
      beacon_ref_retention_ms: policy.beacon_ref_retention_ms,
      persist_raw_transport_metadata?: policy.persist_raw_transport_metadata?,
      persist_source_device_ids?: policy.persist_source_device_ids?
    }
  end

  defp excluded_fields(%__MODULE__{} = policy) do
    [:raw_transport_metadata]
    |> maybe_exclude_source_device_ids(policy)
    |> Enum.sort()
  end

  defp maybe_exclude_source_device_ids(fields, %__MODULE__{persist_source_device_ids?: true}),
    do: fields

  defp maybe_exclude_source_device_ids(fields, %__MODULE__{}), do: [:source_device_ids | fields]

  defp reverse_ok({:ok, list}), do: {:ok, Enum.reverse(list)}
  defp reverse_ok({:error, _reason} = error), do: error

  defp require_equal(left, right, _reason) when left == right, do: :ok
  defp require_equal(_left, _right, reason), do: {:error, reason}

  defp encode64(value), do: Base.encode64(value, padding: false)
end
