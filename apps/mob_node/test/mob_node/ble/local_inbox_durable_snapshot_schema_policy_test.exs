defmodule Mob.Node.BLE.LocalInboxDurableSnapshotSchemaPolicyTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.LocalInboxDurableSnapshotSchemaPolicy

  test "normalizes current-version JSON-decoded durable snapshots" do
    snapshot =
      %{
        "schema_version" => 1,
        "persisted_at" => 2_000,
        "policy" => %{
          "full_message_retention_ms" => 86_400_000,
          "beacon_ref_retention_ms" => 86_400_000,
          "persist_raw_transport_metadata?" => false,
          "persist_source_device_ids?" => true
        },
        "full_messages" => [
          %{
            "kind" => "full_message",
            "message_id" => "AQID",
            "envelope_wire" => "BAUG",
            "source_device_ids" => ["AA:01"]
          }
        ],
        "unresolved_beacon_refs" => [
          %{
            "kind" => "unresolved_beacon_ref",
            "delivery_state" => "unresolved",
            "message_id_hash" => "AQIDBA",
            "sender_peer_hash" => "BQQDAg",
            "observed_via" => ["ble_advertisement"]
          }
        ],
        "excluded_fields" => ["raw_transport_metadata"],
        "capability_notes" => []
      }

    assert {:ok, normalized} = LocalInboxDurableSnapshotSchemaPolicy.normalize(snapshot)
    assert normalized.schema_version == 1
    assert normalized.policy.persist_source_device_ids?
    assert [%{kind: :full_message}] = normalized.full_messages

    assert [%{kind: :unresolved_beacon_ref, delivery_state: :unresolved}] =
             normalized.unresolved_beacon_refs

    assert normalized.excluded_fields == [:raw_transport_metadata]
  end

  test "fails closed for missing malformed or unsupported schema versions" do
    assert {:error, :missing_schema_version} =
             LocalInboxDurableSnapshotSchemaPolicy.normalize(%{})

    assert {:error, :invalid_schema_version} =
             LocalInboxDurableSnapshotSchemaPolicy.normalize(%{schema_version: "1"})

    assert {:error, :unsupported_schema_version} =
             LocalInboxDurableSnapshotSchemaPolicy.normalize(%{schema_version: 2})

    assert {:error, :invalid_durable_snapshot} =
             LocalInboxDurableSnapshotSchemaPolicy.normalize([])
  end

  test "snapshot documents current-only compatibility boundary" do
    snapshot = LocalInboxDurableSnapshotSchemaPolicy.snapshot()

    assert snapshot.boundary == :local_inbox_durable_snapshot_schema_policy
    assert snapshot.current_schema_version == 1
    assert snapshot.supported_schema_versions == [1]
    assert snapshot.json_decoded_current_version_restore_supported?
    refute snapshot.future_schema_versions_supported?
    refute snapshot.production_default_persistence_allowed?
    assert :unsafe_snapshot_upgrade in snapshot.blocked_claims
  end
end
