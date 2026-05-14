defmodule MeshxMobileApp.BLE.LocalInboxTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    AdvertOnlyTransportProfile,
    BeaconInbox,
    FullEnvelopeInbox,
    LocalInbox,
    MessageEnvelope,
    Replay
  }

  alias MeshxMobileApp.BLE.Events.{ReceivedMessage, ReceivedMessageBeacon}

  @fixture_dir Path.expand("../../fixtures/captures", __DIR__)

  defp fixture(name), do: Path.join(@fixture_dir, name)

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
            payload: "hi",
            capability_requirements: 0
          ],
          opts
        )
      )

    envelope
  end

  defp full_event(opts) do
    env = Keyword.get(opts, :envelope, envelope())

    %ReceivedMessage{
      message_id: Keyword.get(opts, :message_id, env.message_id),
      sender_peer_id: env.sender_peer_id,
      recipient_peer_id: env.recipient_peer_id,
      received_device_id: Keyword.get(opts, :received_device_id, "AA:BB"),
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
      payload_kind: "TX",
      message_id_hash: Keyword.get(opts, :message_id_hash, <<1, 2, 3, 4, 5, 6, 7, 8>>),
      sender_peer_id_hash: Keyword.get(opts, :sender_peer_id_hash, <<8, 7, 6, 5, 4, 3, 2, 1>>),
      received_device_id: Keyword.get(opts, :received_device_id, "AA:BB"),
      received_at: Keyword.get(opts, :received_at, 10),
      rssi: Keyword.get(opts, :rssi, -64),
      raw_transport_metadata: Keyword.get(opts, :raw_transport_metadata, %{})
    }
  end

  test "advert-only transport profile names supported and unsupported behavior" do
    profile = AdvertOnlyTransportProfile.advert_only()

    assert AdvertOnlyTransportProfile.supports?(profile, :legacy_beacon_adverts)

    assert AdvertOnlyTransportProfile.supports?(
             profile,
             :full_envelope_adverts_when_capability_proven
           )

    assert AdvertOnlyTransportProfile.unsupported?(profile, :gatt_fetch)
    assert AdvertOnlyTransportProfile.unsupported?(profile, :acks)
    assert AdvertOnlyTransportProfile.unsupported?(profile, :large_payloads)
    assert AdvertOnlyTransportProfile.unsupported?(profile, :retries)
    assert AdvertOnlyTransportProfile.unsupported?(profile, :guaranteed_delivery)
  end

  test "beacon inbox deduplicates by message and sender hash" do
    first = beacon_event(received_device_id: "AA:01", received_at: 10, rssi: -70)
    second = beacon_event(received_device_id: "AA:02", received_at: 20, rssi: -55)

    [entry] =
      BeaconInbox.new()
      |> BeaconInbox.insert(first)
      |> BeaconInbox.insert(second)
      |> BeaconInbox.snapshot()

    assert entry.first_seen_at == 10
    assert entry.last_seen_at == 20
    assert entry.seen_count == 2
    assert entry.source_device_ids == ["AA:01", "AA:02"]
    assert entry.last_rssi == -55
    assert entry.payload_kind == "TX"
    assert entry.envelope_version == 1
  end

  test "full-envelope inbox validates envelopes and deduplicates by message id" do
    first = full_event(received_device_id: "AA:01", received_at: 10, rssi: -70)
    second = full_event(received_device_id: "AA:02", received_at: 30, rssi: -50)

    {:ok, inbox} = FullEnvelopeInbox.insert(FullEnvelopeInbox.new(), first)
    {:ok, inbox} = FullEnvelopeInbox.insert(inbox, second)

    [entry] = FullEnvelopeInbox.snapshot(inbox)
    assert entry.first_seen_at == 10
    assert entry.last_seen_at == 30
    assert entry.seen_count == 2
    assert entry.source_device_ids == ["AA:01", "AA:02"]
    assert entry.last_rssi == -50

    assert {:error, {:invalid_envelope, :message_id_mismatch}, _inbox} =
             FullEnvelopeInbox.insert(inbox, full_event(message_id: <<2::128>>))
  end

  test "unified snapshot ingests M26 full-envelope replay fixture" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest_many(Replay.load!(fixture("message_advertisement.jsonl")))
      |> LocalInbox.snapshot()

    assert snapshot.transport_profile.name == :advertisement_only_local_mesh
    assert :gatt_fetch in snapshot.transport_profile.does_not_support
    assert [%FullEnvelopeInbox.Entry{} = message] = snapshot.full_messages
    assert message.message_id == <<1::128>>
    assert message.sender_peer_id == "meshx-alpha"
    assert message.seen_count == 1
    assert snapshot.unresolved_beacon_refs == []
  end

  test "unified snapshot ingests M26B legacy beacon replay fixture as unresolved ref" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest_many(Replay.load!(fixture("legacy_beacon_advertisement.jsonl")))
      |> LocalInbox.snapshot()

    assert snapshot.full_messages == []
    assert [%BeaconInbox.Entry{} = ref] = snapshot.unresolved_beacon_refs
    assert ref.payload_kind == "TX"
    assert ref.envelope_version == 1
    assert ref.seen_count == 1
    assert ref.source_device_ids == ["B4:0B:1D:AB:24:3C"]
    assert [%{state: :unresolved_ref, payload_kind: "TX"}] = snapshot.nearby_messages
  end

  test "nearby message view keeps full messages and refs in explicit states" do
    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(full_event(received_at: 20))
      |> LocalInbox.ingest(beacon_event(received_at: 10))
      |> LocalInbox.snapshot()

    assert [
             %{state: :full_message, sender_peer_id: "meshx-alpha"},
             %{state: :unresolved_ref, payload_kind: "TX"}
           ] = snapshot.nearby_messages
  end

  test "nearby message view can classify stale and simulated gossiped refs" do
    gossiped =
      beacon_event(
        received_at: 50,
        raw_transport_metadata: %{transport: :advert_gossip_simulation}
      )

    stale =
      beacon_event(
        message_id_hash: <<2, 2, 2, 2, 2, 2, 2, 2>>,
        sender_peer_id_hash: <<3, 3, 3, 3, 3, 3, 3, 3>>,
        received_at: 1
      )

    snapshot =
      LocalInbox.new()
      |> LocalInbox.ingest(gossiped)
      |> LocalInbox.ingest(stale)
      |> LocalInbox.snapshot()

    states =
      MeshxMobileApp.BLE.LocalInboxView.nearby_messages(snapshot,
        now: 100,
        stale_after_ms: 10
      )
      |> Enum.map(& &1.state)

    assert states == [:stale_ref, :stale_ref]

    states_without_stale =
      MeshxMobileApp.BLE.LocalInboxView.nearby_messages(snapshot,
        now: 55,
        stale_after_ms: 100
      )
      |> Enum.map(& &1.state)

    assert states_without_stale == [:gossiped_ref, :unresolved_ref]
  end
end
