defmodule Mob.Node.BLE.LocalInboxPersistencePolicyTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalInbox,
    LocalInboxPersistencePolicy,
    MessageEnvelope
  }

  alias Mob.Node.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  defp envelope(opts \\ []) do
    {:ok, envelope} =
      MessageEnvelope.build(
        Keyword.merge(
          [
            message_id: <<1::128>>,
            sender_peer_id: "meshx-alpha",
            recipient_peer_id: "meshx-beta",
            created_at: 1_700_000_000_000,
            ttl: 1,
            payload_type: "TX",
            payload: "hello",
            capability_requirements: 0
          ],
          opts
        )
      )

    envelope
  end

  defp full_event(opts \\ []) do
    env = Keyword.get(opts, :envelope, envelope())

    %ReceivedMessage{
      message_id: Keyword.get(opts, :message_id, env.message_id),
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: Keyword.get(opts, :received_device_id, "AA:BB"),
      received_at: Keyword.get(opts, :received_at, 1_000),
      rssi: Keyword.get(opts, :rssi, -60),
      envelope: env,
      raw_transport_metadata: %{platform: :android, address: "AA:BB"}
    }
  end

  defp beacon_event(opts \\ []) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: Keyword.get(opts, :message_id_hash, <<1, 2, 3, 4, 5, 6, 7, 8>>),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_id_hash, <<8, 7, 6, 5, 4, 3, 2, 1>>),
      received_device_id: Keyword.get(opts, :received_device_id, "AA:BB"),
      received_at: Keyword.get(opts, :received_at, 1_000),
      rssi: Keyword.get(opts, :rssi, -70),
      raw_transport_metadata: %{platform: :android, address: "AA:BB"}
    }
  end

  test "durable snapshot keeps canonical full envelope bytes and unresolved beacon refs" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.ingest(beacon_event())
      |> LocalInbox.snapshot()

    assert {:ok, durable} =
             LocalInboxPersistencePolicy.durable_snapshot(snapshot, persisted_at: 2_000)

    assert durable.schema_version == 1
    assert durable.excluded_fields == [:raw_transport_metadata, :source_device_ids]
    assert [%{kind: :full_message} = message] = durable.full_messages
    assert message.message_id == Base.encode64(<<1::128>>, padding: false)
    assert message.sender_peer_id == "meshx-alpha"
    assert message.payload_kind == "TX"
    assert message.source_device_count == 1
    refute Map.has_key?(message, :source_device_ids)

    assert {:ok, parsed} =
             message.envelope_wire
             |> Base.decode64!(padding: false)
             |> MessageEnvelope.parse()

    assert parsed == envelope()

    assert [%{kind: :unresolved_beacon_ref, delivery_state: :unresolved} = ref] =
             durable.unresolved_beacon_refs

    assert ref.message_id_hash == Base.encode64(<<1, 2, 3, 4, 5, 6, 7, 8>>, padding: false)
    assert ref.sender_peer_hash == Base.encode64(<<8, 7, 6, 5, 4, 3, 2, 1>>, padding: false)
    assert ref.source_device_count == 1
    refute Map.has_key?(ref, :source_device_ids)
  end

  test "retention policy drops stale entries without treating absence as an error" do
    {:ok, policy} =
      LocalInboxPersistencePolicy.new(
        full_message_retention_ms: 10,
        beacon_ref_retention_ms: 10
      )

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(received_at: 100))
      |> LocalInbox.ingest(beacon_event(received_at: 100))
      |> LocalInbox.snapshot()

    assert {:ok, durable} =
             LocalInboxPersistencePolicy.durable_snapshot(snapshot,
               policy: policy,
               persisted_at: 200
             )

    assert durable.full_messages == []
    assert durable.unresolved_beacon_refs == []
  end

  test "source device ids are opt-in diagnostic data" do
    {:ok, policy} = LocalInboxPersistencePolicy.new(persist_source_device_ids?: true)

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(received_device_id: "AA:01"))
      |> LocalInbox.ingest(beacon_event(received_device_id: "AA:02"))
      |> LocalInbox.snapshot()

    assert {:ok, durable} =
             LocalInboxPersistencePolicy.durable_snapshot(snapshot,
               policy: policy,
               persisted_at: 2_000
             )

    assert durable.excluded_fields == [:raw_transport_metadata]
    assert [%{source_device_ids: ["AA:01"]}] = durable.full_messages
    assert [%{source_device_ids: ["AA:02"]}] = durable.unresolved_beacon_refs
  end

  test "raw transport metadata remains non-persistable" do
    policy = %{LocalInboxPersistencePolicy.default() | persist_raw_transport_metadata?: true}

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.snapshot()

    assert {:error, :raw_transport_metadata_not_persistable} =
             LocalInboxPersistencePolicy.durable_snapshot(snapshot,
               policy: policy,
               persisted_at: 2_000
             )
  end

  test "invalid policy and malformed snapshots are rejected" do
    assert {:error, :invalid_retention} =
             LocalInboxPersistencePolicy.new(full_message_retention_ms: 0)

    assert {:error, :invalid_local_inbox_snapshot} =
             LocalInboxPersistencePolicy.durable_snapshot(:not_a_snapshot, persisted_at: 1)

    assert {:error, :missing_persisted_at} = LocalInboxPersistencePolicy.durable_snapshot(%{}, [])
  end
end
