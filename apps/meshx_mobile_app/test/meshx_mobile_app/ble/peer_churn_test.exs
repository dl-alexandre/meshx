defmodule MeshxMobileApp.BLE.PeerChurnTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.{Events, PeerChurn, PeerInventory, PeerTable, Replay}
  alias MeshxMobileApp.BLE.PeerChurn.ChurnEvent
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

  describe "diff/3 — appeared" do
    test "peers only in current produce :appeared events" do
      prev = []

      curr =
        PeerInventory.list(
          build([sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000)]),
          now: 1_000
        )

      assert [%ChurnEvent{kind: :appeared} = e] = PeerChurn.diff(prev, curr)
      assert e.peer_id == "meshx-alpha"
      assert e.previous_presence == nil
      assert e.current_presence == :active
      assert e.previous_summary == nil
      assert e.current_summary == hd(curr)
    end

    test "anonymous appeared event carries nil peer_id" do
      prev = []
      curr = PeerInventory.list(build([sighting("X:1", <<>>, 100)]), now: 100)

      assert [%ChurnEvent{kind: :appeared, peer_id: nil}] = PeerChurn.diff(prev, curr)
    end
  end

  describe "diff/3 — presence transitions" do
    test "active → stale emits :became_stale" do
      table = build([sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000)])
      prev = PeerInventory.list(table, now: 5_000)
      curr = PeerInventory.list(table, now: 25_000)

      assert [%ChurnEvent{kind: :became_stale} = e] = PeerChurn.diff(prev, curr)
      assert e.previous_presence == :active
      assert e.current_presence == :stale
      assert e.peer_id == "meshx-alpha"
    end

    test "active → expired emits :expired" do
      table = build([sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000)])
      prev = PeerInventory.list(table, now: 5_000)
      curr = PeerInventory.list(table, now: 100_000)

      assert [%ChurnEvent{kind: :expired, previous_presence: :active, current_presence: :expired}] =
               PeerChurn.diff(prev, curr)
    end

    test "stale → expired emits :expired" do
      table = build([sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000)])
      prev = PeerInventory.list(table, now: 25_000)
      curr = PeerInventory.list(table, now: 100_000)

      assert [%ChurnEvent{kind: :expired, previous_presence: :stale}] = PeerChurn.diff(prev, curr)
    end

    test "expired → active emits :reappeared" do
      ad = <<12, 0x09, "meshx-alpha">>
      table_before = build([sighting("AA:1", ad, 1_000)])
      table_after = PeerTable.update(table_before, sighting("AA:1", ad, 100_500))

      prev = PeerInventory.list(table_before, now: 100_000)
      curr = PeerInventory.list(table_after, now: 101_000)

      assert [%ChurnEvent{kind: :reappeared} = e] = PeerChurn.diff(prev, curr)
      assert e.previous_presence == :expired
      assert e.current_presence == :active
    end

    test "no presence change → no event" do
      table = build([sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000)])
      prev = PeerInventory.list(table, now: 5_000)
      curr = PeerInventory.list(table, now: 6_000)

      assert [] = PeerChurn.diff(prev, curr)
    end

    test "stale → active without prior expiration produces NO event (intentional)" do
      # Documented non-event: reactivation without crossing expiration
      # is not interesting enough to surface. :reappeared is reserved
      # for the came-back-from-the-dead case.
      ad = <<12, 0x09, "meshx-alpha">>
      t_before = build([sighting("AA:1", ad, 1_000)])
      t_after = PeerTable.update(t_before, sighting("AA:1", ad, 24_500))

      prev = PeerInventory.list(t_before, now: 25_000)
      curr = PeerInventory.list(t_after, now: 25_000)
      # prev presence at now=25_000 with last_seen=1_000: delta=24_000 → :stale
      # curr presence at now=25_000 with last_seen=24_500: delta=500 → :active
      assert hd(prev).presence == :stale
      assert hd(curr).presence == :active
      assert [] = PeerChurn.diff(prev, curr)
    end
  end

  describe "diff/3 — identity events" do
    test "anonymous → named promotion emits :identity_promoted" do
      ad = <<12, 0x09, "meshx-alpha">>
      t_before = build([sighting("AA:1", <<2, 0x01, 0x06>>, 1_000)])
      t_after = PeerTable.update(t_before, sighting("AA:1", ad, 2_000))

      prev = PeerInventory.list(t_before, now: 2_000)
      curr = PeerInventory.list(t_after, now: 2_000)

      events = PeerChurn.diff(prev, curr)
      promotion = Enum.find(events, &(&1.kind == :identity_promoted))
      assert promotion != nil
      assert promotion.previous_summary.peer_id == nil
      assert promotion.current_summary.peer_id == "meshx-alpha"
      assert promotion.peer_id == "meshx-alpha"

      # No :identity_conflict — this is a positive transition.
      refute Enum.any?(events, &(&1.kind == :identity_conflict))
    end

    test "same name across rotation produces neither :identity_promoted nor :identity_conflict" do
      # Two device_ids advertising the same `meshx-alpha` — that's
      # grouping under one logical peer, not an identity change.
      ad = <<12, 0x09, "meshx-alpha">>
      t_before = build([sighting("AA:1", ad, 1_000)])
      t_after = PeerTable.update(t_before, sighting("BB:2", ad, 2_000))

      prev = PeerInventory.list(t_before, now: 2_000)
      curr = PeerInventory.list(t_after, now: 2_000)

      events = PeerChurn.diff(prev, curr)
      refute Enum.any?(events, &(&1.kind in [:identity_promoted, :identity_conflict]))
    end

    test "competing claim on the same device_id triggers :collision_detected, sticky peer_id means NO :identity_conflict" do
      # M8 sticky rules keep `peer_id` at "meshx-alpha" even after a
      # conflicting `meshx-beta` claim. The conflict surfaces as
      # collision_count++ rather than a snapshot identity change.
      ad_alpha = <<12, 0x09, "meshx-alpha">>
      ad_beta = <<11, 0x09, "meshx-beta">>

      t_before = build([sighting("AA:1", ad_alpha, 1_000)])
      t_after = PeerTable.update(t_before, sighting("AA:1", ad_beta, 2_000))

      prev = PeerInventory.list(t_before, now: 2_000)
      curr = PeerInventory.list(t_after, now: 2_000)

      events = PeerChurn.diff(prev, curr)
      assert Enum.any?(events, &(&1.kind == :collision_detected))
      refute Enum.any?(events, &(&1.kind == :identity_conflict))
    end
  end

  describe "diff/3 — collisions" do
    test "collision_count increasing emits :collision_detected" do
      ad_alpha = <<12, 0x09, "meshx-alpha">>
      ad_beta = <<11, 0x09, "meshx-beta">>

      t_before = build([sighting("AA:1", ad_alpha, 1_000)])
      t_after = PeerTable.update(t_before, sighting("AA:1", ad_beta, 2_000))

      prev = PeerInventory.list(t_before, now: 2_000)
      curr = PeerInventory.list(t_after, now: 2_000)

      assert events = PeerChurn.diff(prev, curr)
      collision = Enum.find(events, &(&1.kind == :collision_detected))
      assert collision != nil
      assert collision.current_summary.collision_count == 1
      assert collision.current_summary.last_conflicting_peer_id == "meshx-beta"
    end

    test "same collision_count produces no :collision_detected" do
      ad = <<12, 0x09, "meshx-alpha">>
      table = build([sighting("AA:1", ad, 1_000)])
      prev = PeerInventory.list(table, now: 5_000)
      curr = PeerInventory.list(table, now: 6_000)

      assert [] = PeerChurn.diff(prev, curr)
    end
  end

  describe "diff/3 — detected_at + sort order" do
    test "stamps every event with the supplied detected_at" do
      table = build([sighting("AA:1", <<12, 0x09, "meshx-alpha">>, 1_000)])
      prev = PeerInventory.list(table, now: 5_000)
      curr = PeerInventory.list(table, now: 100_000)

      [e] = PeerChurn.diff(prev, curr, detected_at: 12_345)
      assert e.detected_at == 12_345
    end

    test "events are sorted deterministically across input orderings" do
      ad_alpha = <<12, 0x09, "meshx-alpha">>
      ad_beta = <<11, 0x09, "meshx-beta">>

      curr_list_1 =
        PeerInventory.list(
          build([
            sighting("A:1", ad_alpha, 1_000),
            sighting("B:1", ad_beta, 1_000)
          ]),
          now: 100_000
        )

      curr_list_2 =
        PeerInventory.list(
          build([
            sighting("B:1", ad_beta, 1_000),
            sighting("A:1", ad_alpha, 1_000)
          ]),
          now: 100_000
        )

      d1 = PeerChurn.diff([], curr_list_1)
      d2 = PeerChurn.diff([], curr_list_2)

      assert Enum.map(d1, &{&1.kind, &1.peer_id}) ==
               Enum.map(d2, &{&1.kind, &1.peer_id})
    end
  end

  describe "diff/3 — replay-driven" do
    test "replaying the same fixture into two sessions yields identical churn" do
      {:ok, s1} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      {:ok, s2} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)

      Replay.into(s1, fixture("mixed_devices_burst.jsonl"))
      Replay.into(s2, fixture("mixed_devices_burst.jsonl"))

      # Diff each session against itself between an early and late
      # `now`. Same fixture + same `now`s → identical churn lists.
      prev1 = PeerInventory.list(Session.snapshot(s1).peers, now: 761_000)
      curr1 = PeerInventory.list(Session.snapshot(s1).peers, now: 785_000)
      prev2 = PeerInventory.list(Session.snapshot(s2).peers, now: 761_000)
      curr2 = PeerInventory.list(Session.snapshot(s2).peers, now: 785_000)

      assert PeerChurn.diff(prev1, curr1, detected_at: 785_000) ==
               PeerChurn.diff(prev2, curr2, detected_at: 785_000)
    end

    test "real-hardware burst transitions every peer through stale and expired" do
      # Burst spans roughly 760_882–761_298 ms. At early_now the latest
      # sighting was just observed → :active. At mid_now most peers have
      # crossed the active boundary → :stale. At late_now everyone is
      # past 40s since last sight → :expired.
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("mixed_devices_burst.jsonl"))
      table = Session.snapshot(session).peers

      early = PeerInventory.list(table, now: 761_300)
      mid = PeerInventory.list(table, now: 785_000)
      late = PeerInventory.list(table, now: 900_000)

      becamestale = PeerChurn.diff(early, mid, detected_at: 785_000)
      expired = PeerChurn.diff(mid, late, detected_at: 900_000)

      assert length(becamestale) > 0
      assert Enum.all?(becamestale, &(&1.kind == :became_stale))
      assert length(expired) > 0
      assert Enum.all?(expired, &(&1.kind == :expired))
    end

    test "reappearance after expiration produces a single :reappeared event per peer" do
      # Replay the cross-platform fixture, expire it, then build a
      # synthetic refresh sighting against the same table and diff.
      {:ok, session} = Session.start_link(bridge: MeshxMobileApp.NativeBridge.Noop)
      Replay.into(session, fixture("cross_platform_discovery.jsonl"))

      table_old = Session.snapshot(session).peers

      # Use the same ad bytes the captured iPad sends so the replay
      # path stays honest.
      ad = Base.decode64!("DAltZXNoeC1pcGFk")
      refresh = sighting("4F:9C:5A:DC:6E:6D", ad, 900_000)
      table_new = PeerTable.update(table_old, refresh)

      prev = PeerInventory.list(table_old, now: 850_000)
      curr = PeerInventory.list(table_new, now: 900_500)

      assert [%ChurnEvent{kind: :reappeared, peer_id: "meshx-ipad"}] = PeerChurn.diff(prev, curr)
    end
  end
end
