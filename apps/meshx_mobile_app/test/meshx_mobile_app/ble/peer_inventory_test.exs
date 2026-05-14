defmodule MeshxMobileApp.BLE.PeerInventoryTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{Events, PeerInventory, PeerTable, PresencePolicy, Replay}
  alias MeshxMobileApp.BLE.PeerInventory.PeerSummary
  alias MeshxMobileApp.Session

  @captures Path.expand("../../fixtures/captures", __DIR__)
  defp fixture(name), do: Path.join(@captures, name)

  defp build(events) do
    Enum.reduce(events, PeerTable.new(), &PeerTable.update(&2, &1))
  end

  defp sighting(device_id, advertisement, observed_at_ms, rssi \\ -50) do
    %Events.DeviceDiscovered{
      device_id: device_id,
      transport: :ble,
      rssi: rssi,
      advertisement: advertisement,
      observed_at_ms: observed_at_ms
    }
  end

  describe "list/1 — named groups" do
    test "collapses rotated device_ids into one summary keyed by peer_id" do
      ad = <<12, 0x09, "meshx-alpha">>

      table =
        build([
          sighting("AA:01", ad, 100, -50),
          sighting("BB:02", ad, 200, -55)
        ])

      assert [%PeerSummary{} = s] = PeerInventory.list(table)
      assert s.peer_id == "meshx-alpha"
      assert s.device_ids == ["AA:01", "BB:02"]
      assert s.display_name == "meshx-alpha"
      assert s.identity_confidence == :advertised
      assert s.identity_source == :advertised_name
      assert s.first_seen_at == 100
      assert s.last_seen_at == 200
      assert s.last_rssi == -55
      assert s.advertisement_seen_count == 2
      assert s.collision_count == 0
      assert s.anonymous? == false
      assert s.suspicious? == false
    end

    test "device_ids are sorted for deterministic output" do
      ad = <<12, 0x09, "meshx-alpha">>

      table_a =
        build([sighting("BB:02", ad, 100), sighting("AA:01", ad, 200)])

      table_b =
        build([sighting("AA:01", ad, 200), sighting("BB:02", ad, 100)])

      [s_a] = PeerInventory.list(table_a)
      [s_b] = PeerInventory.list(table_b)
      assert s_a.device_ids == ["AA:01", "BB:02"]
      assert s_b.device_ids == ["AA:01", "BB:02"]
    end
  end

  describe "list/1 — anonymous entries" do
    test "each anonymous device_id is its own summary" do
      table =
        build([
          sighting("X:01", <<2, 0x01, 0x06>>, 100),
          sighting("X:02", <<2, 0x01, 0x06>>, 200)
        ])

      summaries = PeerInventory.list(table)
      assert length(summaries) == 2
      assert Enum.all?(summaries, & &1.anonymous?)
      assert Enum.all?(summaries, &(&1.identity_confidence == :unknown))
      assert Enum.all?(summaries, &(&1.identity_source == :none))
      # display_name falls back to the device_id when anonymous.
      assert MapSet.new(Enum.map(summaries, & &1.display_name)) ==
               MapSet.new(["X:01", "X:02"])
    end
  end

  describe "list/1 — collision visibility" do
    test "collision_count > 0 → :contested confidence and suspicious? true" do
      table =
        build([
          sighting("Z:01", <<12, 0x09, "meshx-alpha">>, 100),
          sighting("Z:01", <<11, 0x09, "meshx-beta">>, 200)
        ])

      [s] = PeerInventory.list(table)
      assert s.peer_id == "meshx-alpha"
      assert s.identity_confidence == :contested
      assert s.suspicious? == true
      assert s.collision_count == 1
      assert s.last_conflicting_peer_id == "meshx-beta"
    end
  end

  describe "list/1 — ordering" do
    test "sorted by last_seen_at desc, display_name asc as tiebreaker" do
      table =
        build([
          sighting("A:01", <<12, 0x09, "meshx-alpha">>, 300),
          sighting("B:02", <<11, 0x09, "meshx-beta">>, 500),
          sighting("C:03", <<2, 0x01, 0x06>>, 400)
        ])

      [s1, s2, s3] = PeerInventory.list(table)
      # beta last_seen=500 → first
      assert s1.peer_id == "meshx-beta"
      # anonymous C:03 last_seen=400
      assert s2.display_name == "C:03"
      # alpha last_seen=300
      assert s3.peer_id == "meshx-alpha"
    end

    test "ties on last_seen_at break by display_name ascending" do
      ad_a = <<12, 0x09, "meshx-alpha">>
      ad_b = <<11, 0x09, "meshx-beta">>

      table = build([sighting("A:1", ad_a, 100), sighting("B:1", ad_b, 100)])

      assert ["meshx-alpha", "meshx-beta"] =
               PeerInventory.list(table) |> Enum.map(& &1.display_name)
    end
  end

  describe "by_logical_peer/1" do
    test "keys named peers by peer_id, anonymous by device_id" do
      table =
        build([
          sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 100),
          sighting("AA:2", <<12, 0x09, "meshx-alpha">>, 200),
          sighting("X:1", <<>>, 300)
        ])

      map = PeerInventory.by_logical_peer(table)

      assert Map.has_key?(map, "meshx-alpha")
      assert Map.has_key?(map, "X:1")
      assert map_size(map) == 2
      assert map["meshx-alpha"].device_ids == ["AA:1", "AA:2"]
    end
  end

  describe "by_device/1" do
    test "rotated device_ids all point to the SAME summary instance" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 100), sighting("BB:2", ad, 200)])

      map = PeerInventory.by_device(table)

      assert map["AA:1"] == map["BB:2"]
      assert map["AA:1"].peer_id == "meshx-alpha"
      assert map["AA:1"].device_ids == ["AA:1", "BB:2"]
    end
  end

  describe "replay-driven inventory snapshots" do
    test "rotating_device_ids.jsonl produces one named summary with both device_ids" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("rotating_device_ids.jsonl"))
      inv = PeerInventory.list(Session.snapshot(session).peers)

      assert [%PeerSummary{peer_id: "meshx-alpha"} = s] = inv
      assert s.device_ids == ["AA:00:00:00:00:01", "BB:00:00:00:00:02"]
      assert s.identity_confidence == :advertised
      assert s.suspicious? == false
    end

    test "mixed_named_anonymous.jsonl partitions into 2 named + 2 anonymous summaries" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("mixed_named_anonymous.jsonl"))
      inv = PeerInventory.list(Session.snapshot(session).peers)

      assert length(inv) == 4
      assert Enum.count(inv, &(&1.anonymous? == false)) == 2
      assert Enum.count(inv, &(&1.anonymous? == true)) == 2

      named_names = inv |> Enum.reject(& &1.anonymous?) |> Enum.map(& &1.display_name)
      assert MapSet.new(named_names) == MapSet.new(["meshx-alpha", "meshx-beta"])
    end

    test "identity_collision.jsonl surfaces :contested confidence with conflicting claim" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("identity_collision.jsonl"))
      [s] = PeerInventory.list(Session.snapshot(session).peers)

      assert s.peer_id == "meshx-alpha"
      assert s.identity_confidence == :contested
      assert s.suspicious? == true
      assert s.collision_count == 2
      assert s.last_conflicting_peer_id == "meshx-beta"
    end

    test "cross_platform_discovery.jsonl shows the iPad as one logical peer with :advertised confidence" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("cross_platform_discovery.jsonl"))
      [s] = PeerInventory.list(Session.snapshot(session).peers)

      assert s.peer_id == "meshx-ipad"
      assert s.device_ids == ["4F:9C:5A:DC:6E:6D"]
      assert s.identity_confidence == :advertised
      assert s.suspicious? == false
      assert s.advertisement_seen_count == 8
    end

    test "inventory is byte-identical across two independent replays — deterministic" do
      {:ok, s1} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      {:ok, s2} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

      Replay.into(s1, fixture("mixed_devices_burst.jsonl"))
      Replay.into(s2, fixture("mixed_devices_burst.jsonl"))

      inv1 = PeerInventory.list(Session.snapshot(s1).peers)
      inv2 = PeerInventory.list(Session.snapshot(s2).peers)

      assert inv1 == inv2
    end

    test "M10 — active → stale → expired progression for a single peer" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 1_000)])

      [active] = PeerInventory.list(table, now: 5_000)
      [stale] = PeerInventory.list(table, now: 25_000)
      [expired] = PeerInventory.list(table, now: 100_000)

      assert active.presence == :active
      assert stale.presence == :stale
      assert expired.presence == :expired
    end

    test "M10 — reappearance after expiration returns presence to :active" do
      ad = <<12, 0x09, "meshx-alpha">>

      # First sighting at t=1000, then a long gap, then a fresh
      # sighting at t=100_000 from the same device_id.
      table_seen_long_ago = build([sighting("AA:1", ad, 1_000)])
      [s_expired] = PeerInventory.list(table_seen_long_ago, now: 100_000)
      assert s_expired.presence == :expired

      table_reappeared =
        table_seen_long_ago
        |> PeerTable.update(sighting("AA:1", ad, 100_500))

      [s_back] = PeerInventory.list(table_reappeared, now: 101_000)
      assert s_back.presence == :active
      assert s_back.last_seen_at == 100_500
      assert s_back.advertisement_seen_count == 2
    end

    test "M10 — rotating device_ids inherit presence from the latest sighting" do
      # AA:1 seen long ago, BB:2 (rotated identity) seen recently. The
      # collapsed logical peer should be :active because the latest
      # sighting across the group is recent.
      ad = <<12, 0x09, "meshx-alpha">>

      table = build([sighting("AA:1", ad, 1_000), sighting("BB:2", ad, 99_000)])

      [s] = PeerInventory.list(table, now: 100_000)
      assert s.device_ids == ["AA:1", "BB:2"]
      assert s.last_seen_at == 99_000
      assert s.presence == :active
    end

    test "M10 — mixed anonymous/named peers each get presence derived independently" do
      # Pick timestamps that land each peer in a distinct presence
      # state against the default policy (active=10s, stale=30s,
      # expires after 40s combined).
      table =
        build([
          sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000),
          sighting("AA:2", <<11, 0x09, "meshx-beta">>, 80_000),
          sighting("X:1", <<2, 0x01, 0x06>>, 98_000)
        ])

      summaries = PeerInventory.list(table, now: 100_000)
      by_name = Map.new(summaries, &{&1.display_name, &1})

      # alpha: delta 99_000 → :expired
      # beta:  delta 20_000 → :stale
      # X:1:   delta 2_000  → :active
      assert by_name["meshx-alpha"].presence == :expired
      assert by_name["meshx-beta"].presence == :stale
      assert by_name["X:1"].presence == :active
    end

    test "M10 — custom policy is honored" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 1_000)])
      tight = %PresencePolicy{active_window_ms: 100, stale_window_ms: 200}

      [s] = PeerInventory.list(table, now: 1_150, policy: tight)
      # delta = 150ms, beyond active(100) but within active+stale(300) → :stale
      assert s.presence == :stale
    end

    test "M10 — omitting :now leaves presence at its struct default (:active)" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 1_000)])

      [s] = PeerInventory.list(table)
      assert s.presence == :active
    end

    test "M10 — by_logical_peer/2 and by_device/2 honor the same :now" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 1_000), sighting("BB:2", ad, 1_000)])

      logical = PeerInventory.by_logical_peer(table, now: 100_000)
      by_dev = PeerInventory.by_device(table, now: 100_000)

      assert logical["meshx-alpha"].presence == :expired
      assert by_dev["AA:1"].presence == :expired
      assert by_dev["BB:2"].presence == :expired
    end

    test "M10 — with_presence/2 re-stamps an already-built summary list" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 1_000)])

      [s_at_5k] = PeerInventory.list(table, now: 5_000)
      assert s_at_5k.presence == :active

      [s_at_100k] = PeerInventory.with_presence([s_at_5k], now: 100_000)
      assert s_at_100k.presence == :expired
      # No other field should change — with_presence only touches presence.
      assert %{s_at_5k | presence: :expired} == s_at_100k
    end

    test "M10 — replay determinism with injected clock: identical inventories" do
      {:ok, s1} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      {:ok, s2} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

      Replay.into(s1, fixture("mixed_devices_burst.jsonl"))
      Replay.into(s2, fixture("mixed_devices_burst.jsonl"))

      # All observed_at_ms in the burst are around 760_000 — pick a now
      # that lands every peer in :stale to prove the same clock applied
      # to identical inputs yields identical presence stamps.
      inv1 = PeerInventory.list(Session.snapshot(s1).peers, now: 785_000)
      inv2 = PeerInventory.list(Session.snapshot(s2).peers, now: 785_000)

      assert inv1 == inv2
      # And the now we picked actually exercises the policy.
      assert Enum.any?(inv1, &(&1.presence == :stale))
    end

    test "M13 — capabilities_v1.jsonl surfaces v1 capabilities on the PeerSummary" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("capabilities_v1.jsonl"))
      [s] = PeerInventory.list(Session.snapshot(session).peers)

      assert s.peer_id == "meshx-alpha"
      assert s.capabilities.protocol_version == 1
      assert s.capabilities.supports_replay_contract == true
      assert s.capabilities.supports_passive_presence == true
      assert s.capabilities.supports_churn == true
      assert s.capabilities.supports_message_exchange == false
      assert s.capabilities.supports_crypto_identity == false
    end

    test "M13 — unknown future capability version preserves unknown_payload" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("capabilities_unknown_version.jsonl"))
      [s] = PeerInventory.list(Session.snapshot(session).peers)

      assert s.peer_id == "meshx-beta"
      assert s.capabilities.protocol_version == 2
      # v1-compatible flag bits still surface even on an unknown version.
      assert s.capabilities.supports_replay_contract == true
      # Future bytes are preserved verbatim for a later parser.
      assert s.capabilities.unknown_payload == <<0xAA, 0xBB>>
    end

    test "M13 — malformed capability advertisements do not crash inventory derivation" do
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("capabilities_malformed.jsonl"))

      # Two anonymous summaries: malformed → defaults, no exception.
      summaries = PeerInventory.list(Session.snapshot(session).peers)
      assert length(summaries) == 2
      assert Enum.all?(summaries, &(&1.capabilities.protocol_version == nil))
      assert Enum.all?(summaries, &(&1.capabilities.supports_replay_contract == false))
    end

    test "M13 — existing fixtures without capabilities surface protocol_version: nil" do
      # The committed real-hardware capture predates the capability
      # AD record, so the iPad's PeerSummary must show no MeshX caps
      # rather than crash or fabricate defaults.
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("cross_platform_discovery.jsonl"))
      [s] = PeerInventory.list(Session.snapshot(session).peers)

      assert s.peer_id == "meshx-ipad"
      assert s.capabilities.protocol_version == nil
      assert MeshxMobileApp.BLE.PeerCapabilities.mesh_x_capable?(s.capabilities) == false
    end

    test "M13 — capability sighting is replay-deterministic across two sessions" do
      {:ok, s1} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      {:ok, s2} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

      Replay.into(s1, fixture("capabilities_v1.jsonl"))
      Replay.into(s2, fixture("capabilities_v1.jsonl"))

      assert PeerInventory.list(Session.snapshot(s1).peers) ==
               PeerInventory.list(Session.snapshot(s2).peers)
    end

    test "ordering of a real-hardware burst is stable across replays" do
      {:ok, s1} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      {:ok, s2} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

      Replay.into(s1, fixture("mixed_devices_burst.jsonl"))
      Replay.into(s2, fixture("mixed_devices_burst.jsonl"))

      names1 = PeerInventory.list(Session.snapshot(s1).peers) |> Enum.map(& &1.display_name)
      names2 = PeerInventory.list(Session.snapshot(s2).peers) |> Enum.map(& &1.display_name)

      assert names1 == names2
      # Sanity check that the order isn't accidentally trivial.
      assert length(names1) > 1
    end
  end
end
