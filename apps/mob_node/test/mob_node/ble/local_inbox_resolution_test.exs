defmodule Mob.Node.BLE.LocalInboxResolutionTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{
    BeaconRef,
    LocalInbox,
    LocalInboxDurableSnapshot,
    LocalInboxPersistencePolicy,
    LocalInboxResolution,
    LocalInboxView,
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

  defp full_event(env) do
    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: "AA:01",
      received_at: 100,
      rssi: -60,
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event(env, opts \\ []) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: env.envelope_version,
      payload_kind: env.payload_type,
      message_id_hash: BeaconRef.message_id_hash(env),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_hash, BeaconRef.sender_peer_hash(env)),
      received_device_id: Keyword.get(opts, :received_device_id, "AA:02"),
      received_at: Keyword.get(opts, :received_at, 90),
      rssi: Keyword.get(opts, :rssi, -70),
      raw_transport_metadata: %{}
    }
  end

  test "full messages are already present and do not need fetch" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(env))
      |> LocalInbox.snapshot()

    assert [%LocalInboxResolution.Status{} = status] = snapshot.resolution_statuses
    assert status.resolution_state == :full_envelope_present
    assert status.fetch_transport_state == :not_needed
    assert status.envelope == env
    assert :no_fetch_needed in status.notes
  end

  test "beacon refs resolve as already known when a matching full envelope is local" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(env))
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert [
             %{resolution_state: :full_envelope_present},
             %{
               resolution_state: :already_known,
               fetch_transport_state: :not_needed,
               envelope: ^env
             }
           ] = snapshot.resolution_statuses
  end

  test "unknown beacon refs become explicit fetch needs with unvalidated transport" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert [%{resolution_state: :needs_fetch} = status] = snapshot.resolution_statuses
    assert status.fetch_transport_state == :not_validated
    assert status.request.message_id_hash == BeaconRef.message_id_hash(env)
    assert :fetch_transport_not_validated in status.notes
  end

  test "stale beacon refs remain fetch needs but carry stale state" do
    env = envelope()

    base =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env, received_at: 1))
      |> LocalInbox.snapshot()

    nearby = LocalInboxView.nearby_messages(base, now: 1_000, stale_after_ms: 10)
    snapshot = %{base | nearby_messages: nearby}

    assert [%{resolution_state: :stale_needs_fetch, item_state: :stale_ref}] =
             LocalInboxResolution.statuses(snapshot)
  end

  test "hash mismatches are unresolvable instead of becoming fake fetch success" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(env))
      |> LocalInbox.ingest(beacon_event(env, sender_peer_hash: <<255::64>>))
      |> LocalInbox.snapshot()

    assert [
             %{resolution_state: :full_envelope_present},
             %{resolution_state: :unresolvable, reason: :hash_mismatch}
           ] = snapshot.resolution_statuses
  end

  test "durable restored read models include resolution statuses" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    {:ok, durable} = LocalInboxPersistencePolicy.durable_snapshot(snapshot, persisted_at: 2_000)
    assert {:ok, read_model} = LocalInboxDurableSnapshot.to_read_model(durable)

    assert [%{resolution_state: :needs_fetch, fetch_transport_state: :not_validated}] =
             read_model.resolution_statuses
  end
end
