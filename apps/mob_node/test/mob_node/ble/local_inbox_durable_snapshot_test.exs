defmodule Mob.Node.BLE.LocalInboxDurableSnapshotTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    LocalInbox,
    LocalInboxDurableSnapshot,
    LocalInboxPersistencePolicy,
    LocalInboxQuery,
    MessageEnvelope
  }

  alias Mob.Node.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  defp envelope(opts) do
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
    env = envelope(opts)

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: Keyword.get(opts, :received_at, 1_000),
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event(opts) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: Keyword.get(opts, :message_id_hash, <<1, 2, 3, 4, 5, 6, 7, 8>>),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_id_hash, <<8, 7, 6, 5, 4, 3, 2, 1>>),
      received_device_id: "AA:02",
      received_at: Keyword.get(opts, :received_at, 1_000),
      rssi: -70,
      raw_transport_metadata: Keyword.get(opts, :raw_transport_metadata, %{})
    }
  end

  defp durable_snapshot(opts \\ []) do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event())
      |> LocalInbox.ingest(beacon_event(opts))
      |> LocalInbox.snapshot()

    {:ok, durable} = LocalInboxPersistencePolicy.durable_snapshot(snapshot, persisted_at: 2_000)
    durable
  end

  test "restores durable full messages and beacon refs into queryable nearby messages" do
    assert {:ok, read_model} = LocalInboxDurableSnapshot.to_read_model(durable_snapshot())

    assert read_model.durable_schema_version == 1
    assert read_model.persisted_at == 2_000
    assert [%{state: :full_message}, %{state: :unresolved_ref}] = read_model.nearby_messages

    assert [%{trust_state: :unsigned_observation}, %{trust_state: :untrusted_reference}] =
             read_model.trust_evidence

    assert [%{state: :unresolved_ref}] =
             LocalInboxQuery.list(read_model, states: [:unresolved_ref])
  end

  test "restores gossiped and stale ref states from durable metadata" do
    durable =
      durable_snapshot(raw_transport_metadata: %{transport: :advert_gossip_simulation})

    assert {:ok, read_model} = LocalInboxDurableSnapshot.to_read_model(durable)
    assert [%{state: :full_message}, %{state: :gossiped_ref}] = read_model.nearby_messages

    assert {:ok, stale_model} =
             LocalInboxDurableSnapshot.to_read_model(durable, now: 10_000, stale_after_ms: 10)

    assert [%{state: :full_message}, %{state: :stale_ref}] = stale_model.nearby_messages
  end

  test "rejects malformed durable snapshots" do
    durable = durable_snapshot()
    [message] = durable.full_messages

    malformed = %{durable | full_messages: [%{message | envelope_wire: "not-base64"}]}

    assert {:error, :invalid_base64} = LocalInboxDurableSnapshot.to_read_model(malformed)

    assert {:error, :unsupported_schema_version} =
             LocalInboxDurableSnapshot.to_read_model(%{durable | schema_version: 99})

    assert {:error, :missing_schema_version} =
             LocalInboxDurableSnapshot.to_read_model(%{})
  end

  test "restores JSON-decoded durable snapshots without unsafe migration" do
    durable =
      durable_snapshot(raw_transport_metadata: %{transport: :advert_gossip_simulation})
      |> JSON.encode!()
      |> JSON.decode!()

    assert {:ok, read_model} = LocalInboxDurableSnapshot.to_read_model(durable)
    assert read_model.durable_schema_version == 1
    assert [%{state: :full_message}, %{state: :gossiped_ref}] = read_model.nearby_messages
  end
end
