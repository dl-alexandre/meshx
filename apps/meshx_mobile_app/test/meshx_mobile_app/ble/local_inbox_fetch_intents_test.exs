defmodule MeshxMobileApp.BLE.LocalInboxFetchIntentsTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    BeaconRef,
    LocalInbox,
    LocalInboxFetchIntents,
    LocalInboxView,
    MessageEnvelope
  }

  alias MeshxMobileApp.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

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
      sender_peer_id_hash: BeaconRef.sender_peer_hash(env),
      received_device_id: "AA:02",
      received_at: Keyword.get(opts, :received_at, 90),
      rssi: -70,
      raw_transport_metadata: %{}
    }
  end

  test "unknown beacon refs become blocked fetch intents without dispatch" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert {:ok, [%LocalInboxFetchIntents.Intent{} = intent]} =
             LocalInboxFetchIntents.from_snapshot(snapshot,
               now: 1_000,
               ttl_ms: 5_000,
               requesting_peer_id: "meshx-local",
               candidate_source_peer_ids: ["meshx-alpha"],
               id_fun: fn _ -> "fetch-1" end
             )

    assert intent.transport_state == :blocked_unvalidated
    assert intent.resolution_state == :needs_fetch
    assert intent.fetch_request.request_id == "fetch-1"
    assert intent.fetch_request.requesting_peer_id == "meshx-local"
    assert intent.fetch_request.candidate_source_peer_ids == ["meshx-alpha"]
    assert intent.fetch_request.expires_at == 6_000
    assert :no_dispatch in intent.notes
  end

  test "known full messages and already-known refs do not produce fetch intents" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(env))
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert {:ok, []} =
             LocalInboxFetchIntents.from_snapshot(snapshot,
               now: 1_000,
               ttl_ms: 5_000
             )
  end

  test "stale refs keep their stale resolution state in fetch intents" do
    env = envelope()

    base =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env, received_at: 1))
      |> LocalInbox.snapshot()

    nearby = LocalInboxView.nearby_messages(base, now: 1_000, stale_after_ms: 10)

    snapshot =
      base
      |> Map.put(:nearby_messages, nearby)
      |> Map.put(
        :resolution_statuses,
        MeshxMobileApp.BLE.LocalInboxResolution.statuses(%{base | nearby_messages: nearby})
      )

    assert {:ok, [%{resolution_state: :stale_needs_fetch}]} =
             LocalInboxFetchIntents.from_snapshot(snapshot,
               now: 1_000,
               ttl_ms: 5_000,
               id_fun: fn _ -> "fetch-stale" end
             )
  end

  test "invalid fetch request options fail instead of emitting malformed intents" do
    env = envelope()

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(beacon_event(env))
      |> LocalInbox.snapshot()

    assert {:error, :ttl_too_large} =
             LocalInboxFetchIntents.from_snapshot(snapshot,
               now: 1_000,
               ttl_ms: MeshxMobileApp.BLE.BeaconFetchRequest.max_ttl_ms() + 1
             )
  end
end
