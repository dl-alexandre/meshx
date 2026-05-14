defmodule MeshxMobileApp.BLE.LocalInboxStoreTest do
  use ExUnit.Case, async: false

  alias MeshxMobileApp.BLE.{
    LocalInbox,
    LocalInboxPersistencePolicy,
    LocalInboxStore,
    MessageEnvelope
  }

  alias MeshxMobileApp.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  setup do
    Application.ensure_all_started(:meshx_store)
    ensure_db_started()
    LocalInboxStore.clear()

    on_exit(fn -> LocalInboxStore.clear() end)

    :ok
  end

  defp ensure_db_started do
    case MeshxStore.DB.start_link([]) do
      {:ok, pid} ->
        Process.unlink(pid)
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end
  end

  defp envelope do
    {:ok, envelope} =
      MessageEnvelope.build(
        message_id: <<1::128>>,
        sender_peer_id: "meshx-alpha",
        recipient_peer_id: "meshx-beta",
        created_at: 1_700_000_000_000,
        ttl: 1,
        payload_type: "TX",
        payload: "hello",
        capability_requirements: 0
      )

    envelope
  end

  defp full_event do
    env = envelope()

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 1_000,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{platform: :android, address: "AA:01"}
    }
  end

  defp beacon_event do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
      sender_peer_id_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
      received_device_id: "AA:02",
      received_at: 1_000,
      rssi: -70,
      raw_transport_metadata: %{platform: :android, address: "AA:02"}
    }
  end

  defp snapshot do
    LocalInbox.new()
    |> LocalInbox.ingest(full_event())
    |> LocalInbox.ingest(beacon_event())
    |> LocalInbox.snapshot()
  end

  test "save and load round-trip a policy-approved durable snapshot" do
    assert {:error, :not_found} = LocalInboxStore.load(:session_a)

    assert {:ok, durable} =
             LocalInboxStore.save(snapshot(),
               snapshot_id: :session_a,
               persisted_at: 2_000
             )

    assert {:ok, ^durable} = LocalInboxStore.load(:session_a)
    assert durable.schema_version == 1
    assert durable.excluded_fields == [:raw_transport_metadata, :source_device_ids]
    assert [%{kind: :full_message}] = durable.full_messages

    assert [%{kind: :unresolved_beacon_ref, delivery_state: :unresolved}] =
             durable.unresolved_beacon_refs
  end

  test "load_read_model restores a saved durable snapshot for query consumers" do
    assert {:ok, _durable} =
             LocalInboxStore.save(snapshot(),
               snapshot_id: :session_a,
               persisted_at: 2_000
             )

    assert {:ok, read_model} = LocalInboxStore.load_read_model(:session_a)
    assert [%{state: :full_message}, %{state: :unresolved_ref}] = read_model.nearby_messages

    assert [%{trust_state: :unsigned_observation}, %{trust_state: :untrusted_reference}] =
             read_model.trust_evidence
  end

  test "snapshot ids isolate records and delete removes only the selected snapshot" do
    assert {:ok, one} = LocalInboxStore.save(snapshot(), snapshot_id: "one", persisted_at: 2_000)
    assert {:ok, two} = LocalInboxStore.save(snapshot(), snapshot_id: "two", persisted_at: 3_000)

    assert {:ok, ^one} = LocalInboxStore.load("one")
    assert {:ok, ^two} = LocalInboxStore.load("two")

    assert :ok = LocalInboxStore.delete("one")
    assert {:error, :not_found} = LocalInboxStore.load("one")
    assert {:ok, ^two} = LocalInboxStore.load("two")
  end

  test "list summarizes durable snapshots with deterministic expiry state" do
    assert {:ok, expiring_policy} =
             LocalInboxPersistencePolicy.new(
               full_message_retention_ms: 1_000,
               beacon_ref_retention_ms: 1_000
             )

    assert {:ok, _one} =
             LocalInboxStore.save(snapshot(),
               snapshot_id: :one,
               persisted_at: 2_000,
               policy: expiring_policy
             )

    assert {:ok, policy} =
             LocalInboxPersistencePolicy.new(
               full_message_retention_ms: :forever,
               beacon_ref_retention_ms: :forever
             )

    assert {:ok, _two} =
             LocalInboxStore.save(snapshot(),
               snapshot_id: :two,
               persisted_at: 3_000,
               policy: policy
             )

    assert [
             %{
               snapshot_id: :one,
               persisted_at: 2_000,
               full_message_count: 1,
               beacon_ref_count: 1,
               expires_at: 3_000,
               expired?: true
             },
             %{
               snapshot_id: :two,
               persisted_at: 3_000,
               full_message_count: 1,
               beacon_ref_count: 1,
               expires_at: :forever,
               expired?: false
             }
           ] = LocalInboxStore.list(now: 3_001)
  end

  test "prune_expired deletes only snapshots beyond persisted retention" do
    assert {:ok, expiring_policy} =
             LocalInboxPersistencePolicy.new(
               full_message_retention_ms: 1_000,
               beacon_ref_retention_ms: 1_000
             )

    assert {:ok, _old} =
             LocalInboxStore.save(snapshot(),
               snapshot_id: :old,
               persisted_at: 1_000,
               policy: expiring_policy
             )

    assert {:ok, _fresh} =
             LocalInboxStore.save(snapshot(),
               snapshot_id: :fresh,
               persisted_at: 86_401_000
             )

    assert {:ok, [:old]} = LocalInboxStore.prune_expired(now: 2_001)

    assert {:error, :not_found} = LocalInboxStore.load(:old)
    assert {:ok, _durable} = LocalInboxStore.load(:fresh)
  end

  test "prune_expired requires an explicit deterministic clock" do
    assert {:error, :missing_now} = LocalInboxStore.prune_expired()
    assert {:error, :invalid_now} = LocalInboxStore.prune_expired(now: :now)
  end

  test "save forwards policy validation and rejects invalid snapshot ids" do
    assert {:error, :missing_persisted_at} = LocalInboxStore.save(snapshot())

    assert {:error, :invalid_snapshot_id} =
             LocalInboxStore.save(snapshot(), snapshot_id: 123, persisted_at: 1)

    assert {:error, :invalid_snapshot_id} = LocalInboxStore.load(123)
    assert {:error, :invalid_snapshot_id} = LocalInboxStore.delete(123)
  end

  test "clear removes all local inbox snapshots" do
    assert {:ok, _} = LocalInboxStore.save(snapshot(), snapshot_id: :one, persisted_at: 1)
    assert {:ok, _} = LocalInboxStore.save(snapshot(), snapshot_id: :two, persisted_at: 1)

    assert :ok = LocalInboxStore.clear()
    assert {:error, :not_found} = LocalInboxStore.load(:one)
    assert {:error, :not_found} = LocalInboxStore.load(:two)
  end
end
