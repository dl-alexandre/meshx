defmodule MeshxMobileApp.BLE.LocalInboxPersistenceOperatorTest do
  use ExUnit.Case, async: false

  alias MeshxMobileApp.BLE.{
    LocalInbox,
    LocalInboxPersistenceOperator,
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

  defp snapshot do
    env = envelope()

    full = %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 1_000,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{platform: :android, address: "AA:01"}
    }

    beacon = %ReceivedMessageBeacon{
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

    LocalInbox.new()
    |> LocalInbox.ingest(full)
    |> LocalInbox.ingest(beacon)
    |> LocalInbox.snapshot()
  end

  test "snapshot exposes explicit operator controls without enabling defaults" do
    controls = LocalInboxPersistenceOperator.snapshot()
    ids = Enum.map(controls.actions, & &1.id)

    assert controls.control_version == 1
    assert controls.boundary == :operator_opt_in_local_inbox_persistence
    refute controls.default_persistence_enabled?
    refute controls.background_writes_enabled?
    refute controls.scheduled_cleanup_enabled?

    assert :status in ids
    assert :save_snapshot in ids
    assert :restore_snapshot in ids
    assert :prune_expired in ids
    assert :clear_snapshot in ids
    assert :clear_all in ids

    assert :delivery_record in controls.blocked_claims
    assert :background_persistence in controls.blocked_claims
  end

  test "status requires an injected clock and reports snapshot expiry" do
    assert {:error, :missing_now} = LocalInboxPersistenceOperator.status()
    assert {:error, :invalid_now} = LocalInboxPersistenceOperator.status(now: :now)

    assert {:ok, policy} =
             LocalInboxPersistencePolicy.new(
               full_message_retention_ms: 100,
               beacon_ref_retention_ms: 100
             )

    assert {:ok, _durable} =
             LocalInboxPersistenceOperator.save_snapshot(snapshot(),
               snapshot_id: :operator_a,
               persisted_at: 1_000,
               policy: policy
             )

    assert %{
             snapshot_count: 1,
             expired_count: 1,
             snapshots: [%{snapshot_id: :operator_a, expired?: true}]
           } = LocalInboxPersistenceOperator.status(now: 1_101)
  end

  test "save and restore remain read-model operations" do
    assert {:ok, durable} =
             LocalInboxPersistenceOperator.save_snapshot(snapshot(),
               snapshot_id: "operator-a",
               persisted_at: 2_000
             )

    assert durable.excluded_fields == [:raw_transport_metadata, :source_device_ids]

    assert {:ok, read_model} =
             LocalInboxPersistenceOperator.restore_snapshot(snapshot_id: "operator-a")

    assert [%{state: :full_message}, %{state: :unresolved_ref}] = read_model.nearby_messages

    assert [%{trust_state: :unsigned_observation}, %{trust_state: :untrusted_reference}] =
             read_model.trust_evidence
  end

  test "prune and clear controls are explicit manual operations" do
    assert {:ok, policy} =
             LocalInboxPersistencePolicy.new(
               full_message_retention_ms: 100,
               beacon_ref_retention_ms: 100
             )

    assert {:ok, _old} =
             LocalInboxPersistenceOperator.save_snapshot(snapshot(),
               snapshot_id: :old,
               persisted_at: 1_000,
               policy: policy
             )

    assert {:ok, _fresh} =
             LocalInboxPersistenceOperator.save_snapshot(snapshot(),
               snapshot_id: :fresh,
               persisted_at: 1_100
             )

    assert {:ok, [:old]} = LocalInboxPersistenceOperator.prune_expired(now: 1_101)
    assert {:error, :not_found} = LocalInboxStore.load(:old)
    assert {:ok, _durable} = LocalInboxStore.load(:fresh)

    assert :ok = LocalInboxPersistenceOperator.clear_snapshot(snapshot_id: :fresh)
    assert {:error, :not_found} = LocalInboxStore.load(:fresh)

    assert {:ok, _durable} =
             LocalInboxPersistenceOperator.save_snapshot(snapshot(),
               snapshot_id: :last,
               persisted_at: 1_200
             )

    assert :ok = LocalInboxPersistenceOperator.clear_all()
    assert %{snapshot_count: 0} = LocalInboxPersistenceOperator.status(now: 1_201)
  end

  test "json snapshot is machine readable" do
    controls = LocalInboxPersistenceOperator.json_snapshot()

    assert controls["control_version"] == 1
    assert controls["default_persistence_enabled?"] == false
    assert controls["scheduled_cleanup_enabled?"] == false

    assert Enum.any?(
             controls["actions"],
             &(&1["id"] == "prune_expired" and &1["status"] == "manual_only")
           )
  end
end
