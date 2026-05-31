defmodule Mob.Node.BLE.LocalInboxDurableSnapshotSchemaPolicy do
  @moduledoc """
  Fail-closed schema policy for durable local inbox snapshots.

  This policy keeps the production-default persistence boundary explicit:
  schema version 1 can be restored from in-memory or JSON-decoded snapshot
  maps, while unknown versions are rejected. It does not migrate data, write
  storage, schedule cleanup, enable default persistence, resolve beacon refs,
  route, ACK, retry, encrypt, or authenticate messages.
  """

  @current_schema_version 1

  @top_level_keys %{
    "schema_version" => :schema_version,
    "persisted_at" => :persisted_at,
    "policy" => :policy,
    "transport_profile" => :transport_profile,
    "full_messages" => :full_messages,
    "unresolved_beacon_refs" => :unresolved_beacon_refs,
    "excluded_fields" => :excluded_fields,
    "capability_notes" => :capability_notes
  }

  @policy_keys %{
    "full_message_retention_ms" => :full_message_retention_ms,
    "beacon_ref_retention_ms" => :beacon_ref_retention_ms,
    "persist_raw_transport_metadata?" => :persist_raw_transport_metadata?,
    "persist_source_device_ids?" => :persist_source_device_ids?
  }

  @full_message_keys %{
    "kind" => :kind,
    "message_id" => :message_id,
    "sender_peer_id" => :sender_peer_id,
    "recipient_peer_id" => :recipient_peer_id,
    "envelope_version" => :envelope_version,
    "payload_kind" => :payload_kind,
    "envelope_wire" => :envelope_wire,
    "first_seen_at" => :first_seen_at,
    "last_seen_at" => :last_seen_at,
    "seen_count" => :seen_count,
    "source_device_count" => :source_device_count,
    "source_device_ids" => :source_device_ids,
    "last_rssi" => :last_rssi
  }

  @beacon_ref_keys %{
    "kind" => :kind,
    "delivery_state" => :delivery_state,
    "message_id_hash" => :message_id_hash,
    "sender_peer_hash" => :sender_peer_hash,
    "envelope_version" => :envelope_version,
    "payload_kind" => :payload_kind,
    "first_seen_at" => :first_seen_at,
    "last_seen_at" => :last_seen_at,
    "seen_count" => :seen_count,
    "source_device_count" => :source_device_count,
    "source_device_ids" => :source_device_ids,
    "last_rssi" => :last_rssi,
    "observed_via" => :observed_via
  }

  @spec current_schema_version() :: pos_integer()
  def current_schema_version, do: @current_schema_version

  @spec normalize(map()) :: {:ok, map()} | {:error, term()}
  def normalize(%{} = durable) do
    durable = normalize_snapshot(durable)

    case Map.get(durable, :schema_version) do
      @current_schema_version ->
        {:ok, durable}

      version when is_integer(version) and version > @current_schema_version ->
        {:error, :unsupported_schema_version}

      version when is_integer(version) and version < @current_schema_version ->
        {:error, :unsupported_schema_version}

      nil ->
        {:error, :missing_schema_version}

      _version ->
        {:error, :invalid_schema_version}
    end
  end

  def normalize(_durable), do: {:error, :invalid_durable_snapshot}

  @spec snapshot() :: map()
  def snapshot do
    %{
      policy_version: 1,
      boundary: :local_inbox_durable_snapshot_schema_policy,
      current_schema_version: @current_schema_version,
      supported_schema_versions: [@current_schema_version],
      json_decoded_current_version_restore_supported?: true,
      future_schema_versions_supported?: false,
      production_default_persistence_allowed?: false,
      blocked_claims: [
        :automatic_schema_migration,
        :unsafe_snapshot_upgrade,
        :default_app_persistence,
        :delivery_record
      ],
      rules: [
        %{
          id: :current_schema,
          outcome: :restore_allowed,
          requirement:
            "Schema version 1 durable snapshots may be restored after known-key normalization."
        },
        %{
          id: :unknown_schema,
          outcome: :reject,
          requirement: "Unknown durable snapshot schema versions fail closed."
        },
        %{
          id: :missing_schema,
          outcome: :reject,
          requirement: "Durable snapshots without schema_version are not restored."
        }
      ],
      notes: [
        "This is a compatibility policy, not a migration implementation.",
        "Forward migrations still need explicit fixtures before persistence can become a default lifecycle behavior."
      ]
    }
  end

  @spec json_snapshot() :: map()
  def json_snapshot do
    snapshot()
    |> JSON.encode!()
    |> JSON.decode!()
  end

  defp normalize_snapshot(durable) do
    durable
    |> normalize_map(@top_level_keys)
    |> update_map(:policy, @policy_keys)
    |> update_list(:full_messages, @full_message_keys)
    |> update_list(:unresolved_beacon_refs, @beacon_ref_keys)
    |> normalize_excluded_fields()
  end

  defp update_map(map, key, key_map) do
    case Map.get(map, key) do
      %{} = value -> Map.put(map, key, normalize_map(value, key_map))
      _value -> map
    end
  end

  defp update_list(map, key, key_map) do
    case Map.get(map, key) do
      values when is_list(values) ->
        Map.put(
          map,
          key,
          Enum.map(values, fn
            %{} = value -> value |> normalize_map(key_map) |> normalize_known_values()
            value -> value
          end)
        )

      _value ->
        map
    end
  end

  defp normalize_map(map, key_map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {Map.get(key_map, key, key), value}
      pair -> pair
    end)
  end

  defp normalize_known_values(map) do
    map
    |> normalize_atom_value(:kind, %{
      "full_message" => :full_message,
      "unresolved_beacon_ref" => :unresolved_beacon_ref
    })
    |> normalize_atom_value(:delivery_state, %{"unresolved" => :unresolved})
  end

  defp normalize_atom_value(map, key, values) do
    case Map.get(map, key) do
      value when is_binary(value) -> Map.put(map, key, Map.get(values, value, value))
      _value -> map
    end
  end

  defp normalize_excluded_fields(%{excluded_fields: fields} = map) when is_list(fields) do
    fields =
      Enum.map(fields, fn
        "raw_transport_metadata" -> :raw_transport_metadata
        "source_device_ids" -> :source_device_ids
        value -> value
      end)

    Map.put(map, :excluded_fields, fields)
  end

  defp normalize_excluded_fields(map), do: map
end
