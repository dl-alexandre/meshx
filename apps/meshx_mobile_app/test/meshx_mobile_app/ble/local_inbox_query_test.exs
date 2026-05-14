defmodule MeshxMobileApp.BLE.LocalInboxQueryTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{LocalInbox, LocalInboxQuery, MessageEnvelope}
  alias MeshxMobileApp.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

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

  defp full_event(opts) do
    env = Keyword.get(opts, :envelope, envelope(opts))

    %ReceivedMessage{
      message_id: env.message_id,
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: Keyword.get(opts, :received_device_id, "AA:01"),
      received_at: Keyword.get(opts, :received_at, 10),
      rssi: Keyword.get(opts, :rssi, -60),
      envelope: env,
      raw_transport_metadata: %{}
    }
  end

  defp beacon_event(opts) do
    %ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: Keyword.get(opts, :payload_kind, "TX"),
      message_id_hash: Keyword.get(opts, :message_id_hash, <<2, 2, 2, 2, 2, 2, 2, 2>>),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_id_hash, <<3, 3, 3, 3, 3, 3, 3, 3>>),
      received_device_id: Keyword.get(opts, :received_device_id, "AA:02"),
      received_at: Keyword.get(opts, :received_at, 20),
      rssi: Keyword.get(opts, :rssi, -80),
      raw_transport_metadata: Keyword.get(opts, :raw_transport_metadata, %{})
    }
  end

  defp snapshot do
    stale =
      beacon_event(
        message_id_hash: <<4, 4, 4, 4, 4, 4, 4, 4>>,
        sender_peer_id_hash: <<5, 5, 5, 5, 5, 5, 5, 5>>,
        received_device_id: "AA:03",
        received_at: 1,
        rssi: -90,
        payload_kind: "AL"
      )

    gossip =
      beacon_event(
        message_id_hash: <<6, 6, 6, 6, 6, 6, 6, 6>>,
        sender_peer_id_hash: <<7, 7, 7, 7, 7, 7, 7, 7>>,
        received_device_id: "AA:04",
        received_at: 95,
        rssi: -50,
        raw_transport_metadata: %{transport: :advert_gossip_simulation}
      )

    inbox =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(received_at: 100, rssi: -65))
      |> LocalInbox.ingest(beacon_event(received_at: 90, rssi: -70))
      |> LocalInbox.ingest(gossip)
      |> LocalInbox.ingest(stale)

    base = LocalInbox.snapshot(inbox)

    Map.put(
      base,
      :nearby_messages,
      MeshxMobileApp.BLE.LocalInboxView.nearby_messages(base, now: 100, stale_after_ms: 10)
    )
  end

  test "filters nearby messages by state, payload kind, source device, and observation source" do
    snapshot = snapshot()

    assert [%{state: :full_message}] = LocalInboxQuery.list(snapshot, states: [:full_message])
    assert [%{payload_kind: "AL"}] = LocalInboxQuery.list(snapshot, payload_kinds: ["AL"])

    assert [%{source_device_ids: ["AA:02"]}] =
             LocalInboxQuery.list(snapshot, source_device_id: "AA:02")

    assert [%{state: :gossiped_ref}] =
             LocalInboxQuery.list(snapshot, observed_via: :gossip_simulation)
  end

  test "sorts deterministically for common product views" do
    snapshot = snapshot()

    assert [:full_message, :gossiped_ref, :unresolved_ref, :stale_ref] =
             snapshot
             |> LocalInboxQuery.list(sort: :recent_first)
             |> Enum.map(& &1.state)

    assert [:stale_ref, :unresolved_ref, :gossiped_ref, :full_message] =
             snapshot
             |> LocalInboxQuery.list(sort: :oldest_first)
             |> Enum.map(& &1.state)

    assert [:gossiped_ref, :full_message, :unresolved_ref, :stale_ref] =
             snapshot
             |> LocalInboxQuery.list(sort: :strongest_rssi)
             |> Enum.map(& &1.state)
  end

  test "unknown sort falls back to recent-first ordering" do
    assert [:full_message, :gossiped_ref, :unresolved_ref, :stale_ref] =
             snapshot()
             |> LocalInboxQuery.list(sort: :unknown_sort)
             |> Enum.map(& &1.state)
  end

  test "returns stable counts and detail lookup by message key" do
    snapshot = snapshot()

    assert %{
             full_message: 1,
             unresolved_ref: 1,
             gossiped_ref: 1,
             stale_ref: 1
           } = LocalInboxQuery.counts_by_state(snapshot)

    [first | _] = LocalInboxQuery.list(snapshot)
    assert {:ok, ^first} = LocalInboxQuery.detail(snapshot, first.message_key)
    assert {:error, :not_found} = LocalInboxQuery.detail(snapshot, "missing")
  end

  test "freshness options classify stale refs from raw inbox snapshots" do
    raw_snapshot = Map.delete(snapshot(), :nearby_messages)

    assert %{unresolved_ref: 1, stale_ref: 1} =
             LocalInboxQuery.counts_by_state(raw_snapshot, now: 100, stale_after_ms: 10)

    assert [%{state: :stale_ref} = stale] =
             LocalInboxQuery.list(raw_snapshot,
               states: [:stale_ref],
               now: 100,
               stale_after_ms: 10
             )

    assert {:ok, ^stale} =
             LocalInboxQuery.detail(raw_snapshot, stale.message_key,
               now: 100,
               stale_after_ms: 10
             )
  end

  test "limit keeps explicit empty results valid" do
    assert [%{state: :full_message}] =
             snapshot()
             |> LocalInboxQuery.list(states: [:full_message], limit: 1)

    assert [] =
             LocalInboxQuery.list(snapshot(),
               states: [:unresolved_ref],
               payload_kinds: ["missing"]
             )
  end
end
