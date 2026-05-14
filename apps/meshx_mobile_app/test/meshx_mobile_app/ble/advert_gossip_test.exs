defmodule MeshxMobileApp.BLE.AdvertGossipTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{
    AdvertGossipDispatcher,
    AdvertGossipLedger,
    AdvertGossipPlanner,
    AdvertGossipPolicy,
    BeaconInbox,
    BeaconRef,
    LocalInbox,
    Replay
  }

  @fixture_dir Path.expand("../../fixtures/captures", __DIR__)

  defp fixture(name), do: Path.join(@fixture_dir, name)

  defp snapshot_from_fixture(name) do
    LocalInbox.new()
    |> LocalInbox.ingest_many(Replay.load!(fixture(name)))
    |> LocalInbox.snapshot()
  end

  test "plans legacy beacon gossip for unresolved beacon refs" do
    snapshot = snapshot_from_fixture("legacy_beacon_advertisement.jsonl")

    assert [
             %AdvertGossipPlanner.Intent{
               gossip_intent_id: "gossip-0",
               source: :beacon_ref,
               advertise_as: :legacy_beacon_advert,
               payload_kind: "TX",
               envelope: nil
             } = intent
           ] =
             AdvertGossipPlanner.plan(snapshot,
               now: 100,
               id_fun: fn index -> "gossip-#{index}" end
             )

    assert byte_size(intent.message_id_hash) == 8
    assert byte_size(intent.sender_peer_hash) == 8
  end

  test "full-message gossip defaults to beacon refs unless full adverts are capability-proven" do
    snapshot = snapshot_from_fixture("message_advertisement.jsonl")

    assert [%{source: :full_message, advertise_as: :legacy_beacon_advert, envelope: nil}] =
             AdvertGossipPlanner.plan(snapshot, now: 100)

    assert [%{source: :full_message, advertise_as: :full_envelope_advert, envelope: envelope}] =
             AdvertGossipPlanner.plan(snapshot,
               now: 100,
               full_envelope_capability_proven: true
             )

    assert envelope.payload == "hi"
  end

  test "planner prefers full message over duplicate unresolved beacon ref" do
    full_snapshot = snapshot_from_fixture("message_advertisement.jsonl")
    full_entry = hd(full_snapshot.full_messages)
    envelope = full_entry.envelope

    duplicate_beacon_ref = %BeaconInbox.Entry{
      message_id_hash: BeaconRef.message_id_hash(envelope),
      sender_peer_hash: BeaconRef.sender_peer_hash(envelope),
      first_seen_at: full_entry.first_seen_at + 1,
      last_seen_at: full_entry.last_seen_at + 1,
      seen_count: 1,
      source_device_ids: ["AA:BB:CC:DD:EE:02"],
      last_rssi: -49,
      payload_kind: envelope.payload_type,
      envelope_version: envelope.envelope_version
    }

    snapshot = %{
      full_snapshot
      | unresolved_beacon_refs: [duplicate_beacon_ref]
    }

    assert [%{source: :full_message}] = AdvertGossipPlanner.plan(snapshot, now: 100)
  end

  test "suppression ledger prevents immediate re-gossip planning" do
    snapshot = snapshot_from_fixture("legacy_beacon_advertisement.jsonl")
    policy = %AdvertGossipPolicy{min_interval_ms: 1_000, max_intents: 16}

    first = AdvertGossipPlanner.plan(snapshot, now: 10, policy: policy)
    ledger = AdvertGossipLedger.record(AdvertGossipLedger.new(), first)

    assert [] = AdvertGossipPlanner.plan(snapshot, now: 999, policy: policy, ledger: ledger)
    assert [_] = AdvertGossipPlanner.plan(snapshot, now: 1_010, policy: policy, ledger: ledger)
  end

  test "policy validates ttl, hop, and neighbor cooldown bounds" do
    assert {:ok, %AdvertGossipPolicy{default_ttl: 3, max_hops: 5, neighbor_cooldown_ms: 250}} =
             AdvertGossipPolicy.new(default_ttl: 3, max_hops: 5, neighbor_cooldown_ms: 250)

    assert {:error, :default_ttl_exceeds_max_hops} =
             AdvertGossipPolicy.new(default_ttl: 5, max_hops: 4)

    assert {:error, :invalid_neighbor_cooldown_ms} =
             AdvertGossipPolicy.new(neighbor_cooldown_ms: -1)
  end

  test "dry-run dispatcher emits auditable outcomes without sending" do
    snapshot = snapshot_from_fixture("legacy_beacon_advertisement.jsonl")
    intents = AdvertGossipPlanner.plan(snapshot, now: 100)

    assert [
             %AdvertGossipDispatcher.DryRun.Outcome{
               kind: :would_gossip,
               adapter: :advert_gossip_dry_run,
               outcome_at: 110
             }
           ] = AdvertGossipDispatcher.DryRun.dispatch(intents, outcome_at: 110)

    assert [%{kind: :no_candidates, reason: :empty_intents}] =
             AdvertGossipDispatcher.DryRun.dispatch([], outcome_at: 110)
  end
end
