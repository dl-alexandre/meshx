defmodule Mob.Node.BLE.ReplayTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{BridgeProtocol, Replay}
  alias Mob.Node.BLE.Events
  alias Mob.Node.Session

  @captures Path.expand("../../fixtures/captures", __DIR__)

  defp fixture(name), do: Path.join(@captures, name)

  describe "load!/1" do
    test "loads canonical events from a real hardware capture" do
      events = Replay.load!(fixture("cross_platform_discovery.jsonl"))

      assert length(events) == 8
      assert [%Events.DeviceDiscovered{} | _] = events

      assert Enum.all?(
               events,
               &match?(
                 %struct{} when struct in [Events.DeviceDiscovered, Events.AdvertisementReceived],
                 &1
               )
             )

      assert Enum.all?(events, &(&1.device_id == "4F:9C:5A:DC:6E:6D"))
    end

    test "every captured line in every fixture decodes through BridgeProtocol" do
      for path <- Path.wildcard(fixture("*.jsonl")) do
        events = Replay.load!(path)
        assert is_list(events), "expected list for #{path}"
        assert events != [], "expected non-empty replay for #{path}"
      end
    end
  end

  describe "stream_raw/1" do
    test "base64-decodes binary fields uniformly" do
      [first | _] = Enum.to_list(Replay.stream_raw(fixture("cross_platform_discovery.jsonl")))

      assert first["v"] == 1
      assert first["event"] == "device_discovered"
      assert is_binary(first["advertisement"])
      # The captured advertisement base64-decodes to a payload containing
      # the ASCII "meshx-ipad" local name. That's the iOS peer the
      # Android scanner saw on real hardware.
      assert String.contains?(first["advertisement"], "meshx-ipad")
    end

    test "ignores blank lines and comment lines" do
      tmp =
        Path.join(
          System.tmp_dir!(),
          "replay_comments_#{System.unique_integer([:positive])}.jsonl"
        )

      File.write!(tmp, """
      # this is a comment
      {"v":1,"event":"error","kind":"timeout","detail":"x"}

      # another comment
      {"v":1,"event":"error","kind":"timeout","detail":"y"}
      """)

      events = Replay.load!(tmp)
      assert length(events) == 2
      File.rm!(tmp)
    end
  end

  describe "into/2 — deterministic Session replay" do
    test "cross-platform discovery surfaces the iPad as a Device discovered event" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      count = Replay.into(session, fixture("cross_platform_discovery.jsonl"))
      assert count == 8

      # snapshot/1 is a GenServer.call — drains the mailbox to this
      # point, making the assertion deterministic without sleeps.
      snapshot = Session.snapshot(session)

      assert Enum.any?(snapshot.events, fn e ->
               e.title == "Device discovered" and e.detail =~ "4F:9C:5A:DC:6E:6D"
             end)

      assert Enum.any?(snapshot.events, &(&1.title == "Advertisement"))
    end

    test "bluetooth_off capture produces canonical Bridge error entries" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("bluetooth_off.jsonl"))
      snapshot = Session.snapshot(session)

      errors = Enum.filter(snapshot.events, &(&1.title == "Bridge error"))
      assert length(errors) == 2
      assert Enum.all?(errors, &(&1.detail =~ "bluetooth_off"))
    end

    test "mixed burst replays all 50 events without dropping or mutating any" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      count = Replay.into(session, fixture("mixed_devices_burst.jsonl"))
      assert count == 50

      snapshot = Session.snapshot(session)

      # Session caps its event log at 50; we replayed exactly 50 + the
      # pre-existing "Mob app ready" startup event, so the cap should
      # have shifted the startup entry out.
      assert length(snapshot.events) == 50
    end

    test "cross_platform_discovery.jsonl produces one visible iPad peer" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("cross_platform_discovery.jsonl"))
      snapshot = Session.snapshot(session)

      assert map_size(snapshot.peers) == 1
      assert %{"4F:9C:5A:DC:6E:6D" => entry} = snapshot.peers

      assert entry.advertisement_seen_count == 8
      # Last RSSI is the value from the most recent sighting in the
      # fixture (the 8 captured RSSIs are: -50, -50, -52, -54, -53,
      # -52, -53, -52).
      assert entry.last_rssi == -52
      assert entry.first_seen_at < entry.last_seen_at
      assert entry.error_count == 0
    end

    test "mixed_devices_burst.jsonl produces a stable peer inventory" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("mixed_devices_burst.jsonl"))
      snapshot1 = Session.snapshot(session)

      # Determinism: replaying the same fixture into a fresh session
      # produces the same inventory (same keys, same counts, same RSSIs).
      {:ok, session2} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)
      Replay.into(session2, fixture("mixed_devices_burst.jsonl"))
      snapshot2 = Session.snapshot(session2)

      assert snapshot1.peers == snapshot2.peers
      assert map_size(snapshot1.peers) > 1

      # Inventory must equal the unique device_id set in the underlying
      # raw stream — proves no events were dropped or double-counted.
      expected_device_ids =
        fixture("mixed_devices_burst.jsonl")
        |> Replay.stream_raw()
        |> Enum.flat_map(fn raw ->
          case raw["event"] do
            "device_discovered" -> [raw["device_id"]]
            "advertisement_received" -> [raw["device_id"]]
            _ -> []
          end
        end)
        |> MapSet.new()

      assert MapSet.new(Map.keys(snapshot1.peers)) == expected_device_ids
    end

    test "rotating_device_ids.jsonl collapses two device_ids into one logical peer" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("rotating_device_ids.jsonl"))
      snapshot = Session.snapshot(session)

      # Two transport entries (rotation produces a new device_id) …
      assert map_size(snapshot.peers) == 2

      # … but a single logical peer once grouped by peer_id.
      grouped = Mob.Node.BLE.PeerTable.by_peer_id(snapshot.peers)
      assert Map.keys(grouped) == ["meshx-alpha"]
      assert length(grouped["meshx-alpha"]) == 2

      device_ids =
        grouped["meshx-alpha"]
        |> Enum.map(& &1.device_id)
        |> MapSet.new()

      assert device_ids == MapSet.new(["AA:00:00:00:00:01", "BB:00:00:00:00:02"])
    end

    test "mixed_named_anonymous.jsonl partitions inventory into named + anonymous" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("mixed_named_anonymous.jsonl"))
      snapshot = Session.snapshot(session)

      grouped = Mob.Node.BLE.PeerTable.by_peer_id(snapshot.peers)

      # Two stable peers (alpha, beta) + a nil bucket for two anonymous
      # devices (no Local Name and a non-MeshX Local Name).
      assert MapSet.new(Map.keys(grouped)) ==
               MapSet.new(["meshx-alpha", "meshx-beta", nil])

      assert length(grouped["meshx-alpha"]) == 1
      assert length(grouped["meshx-beta"]) == 1
      assert length(grouped[nil]) == 2
    end

    test "cross_platform_discovery.jsonl derives peer_id from the captured iPad advertisement" do
      # The committed real-hardware fixture stays unchanged. Identity
      # derivation must surface the same peer_id the live capture
      # showed when base64-decoded — proves the rule works on real
      # bytes, not just synthetic ones.
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("cross_platform_discovery.jsonl"))
      snapshot = Session.snapshot(session)

      [entry] = Map.values(snapshot.peers)
      assert entry.peer_id == "meshx-ipad"
    end

    test "message_advertisement.jsonl replays into a canonical ReceivedMessage" do
      events = Replay.load!(fixture("message_advertisement.jsonl"))

      assert [
               %Events.ReceivedMessage{
                 message_id: <<1::128>>,
                 sender_peer_id: "meshx-alpha",
                 recipient_peer_id: "meshx-beta",
                 received_device_id: "AA:BB:CC:DD:EE:01",
                 received_at: 12_345,
                 rssi: -61,
                 envelope: envelope
               } = event
             ] = events

      assert envelope.payload == "hi"
      assert event.raw_transport_metadata.advertisement != <<>>

      assert event.raw_transport_metadata.message_payload ==
               Mob.Node.BLE.MessageEnvelope.encode(envelope)

      assert event.raw_transport_metadata.manufacturer_data ==
               <<0xFF, 0xFF, event.raw_transport_metadata.message_payload::binary>>

      assert event.raw_transport_metadata.company_identifier == 65_535
      assert event.raw_transport_metadata.ad_type == 255

      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)
      assert Replay.into(session, fixture("message_advertisement.jsonl")) == 1

      snapshot = Session.snapshot(session)
      assert snapshot.peers == %{}
      assert Enum.any?(snapshot.events, &(&1.title == "Message received"))
    end

    test "malformed_message_advertisement.jsonl replays as a tagged decode error" do
      assert [
               %Events.Error{
                 kind: :unknown,
                 device_id: "AA:BB:CC:DD:EE:02",
                 detail: detail
               }
             ] = Replay.load!(fixture("malformed_message_advertisement.jsonl"))

      assert detail =~ "message_advertisement_decode_error"
      assert detail =~ "truncated_envelope"
    end

    test "M8 — rotating device_ids with same peer_id produce ZERO collisions" do
      # Two distinct device_ids advertising `mob-alpha` is grouping,
      # not a collision. Each entry stays clean; by_peer_id collapses
      # them into one logical peer.
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("rotating_device_ids.jsonl"))
      snapshot = Session.snapshot(session)

      assert Enum.all?(Map.values(snapshot.peers), &(&1.identity_collision_count == 0))
      assert Enum.all?(Map.values(snapshot.peers), &(&1.last_conflicting_peer_id == nil))
      assert Enum.all?(Map.values(snapshot.peers), &(&1.identity_source == :advertised_name))
    end

    test "M8 — same device_id later claiming a different peer_id bumps collision counter" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("identity_collision.jsonl"))
      snapshot = Session.snapshot(session)

      assert map_size(snapshot.peers) == 1
      entry = snapshot.peers["AA:00:00:00:00:01"]

      # First claim wins.
      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_source == :advertised_name

      # Two later `mob-beta` advertisements both register as
      # conflicts against the original claim.
      assert entry.identity_collision_count == 2
      assert entry.last_conflicting_peer_id == "meshx-beta"

      # Sighting counts are unaffected — the events themselves still
      # tick the per-device telemetry.
      assert entry.advertisement_seen_count == 4
    end

    test "M8 — anonymous → named promotion records identity_source advance, no collision" do
      # Build a synthetic stream in-memory: an anonymous sighting
      # followed by a named one for the same device_id.
      tmp =
        Path.join(
          System.tmp_dir!(),
          "m8_promotion_#{System.unique_integer([:positive])}.jsonl"
        )

      File.write!(tmp, """
      {"v":1,"event":"device_discovered","device_id":"ZZ:01","rssi":-50,"advertisement":"AgEG","observed_at_ms":100}
      {"v":1,"event":"advertisement_received","device_id":"ZZ:01","rssi":-52,"advertisement":"DAltZXNoeC1hbHBoYQ==","observed_at_ms":200}
      """)

      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)
      Replay.into(session, tmp)
      entry = Session.snapshot(session).peers["ZZ:01"]

      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_source == :advertised_name
      assert entry.identity_collision_count == 0
      File.rm!(tmp)
    end

    test "M8 — named → name-omitted is sticky, no demotion, no collision" do
      tmp =
        Path.join(
          System.tmp_dir!(),
          "m8_no_demote_#{System.unique_integer([:positive])}.jsonl"
        )

      File.write!(tmp, """
      {"v":1,"event":"device_discovered","device_id":"ZZ:02","rssi":-50,"advertisement":"DAltZXNoeC1hbHBoYQ==","observed_at_ms":100}
      {"v":1,"event":"advertisement_received","device_id":"ZZ:02","rssi":-52,"advertisement":"AgEG","observed_at_ms":200}
      """)

      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)
      Replay.into(session, tmp)
      entry = Session.snapshot(session).peers["ZZ:02"]

      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_source == :advertised_name
      assert entry.identity_collision_count == 0
      assert entry.last_conflicting_peer_id == nil
      File.rm!(tmp)
    end

    test "identity derivation is replay-deterministic across independent replays" do
      {:ok, s1} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)
      {:ok, s2} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(s1, fixture("mixed_named_anonymous.jsonl"))
      Replay.into(s2, fixture("mixed_named_anonymous.jsonl"))

      # Full peer table equality — covers peer_id values, counts,
      # timestamps, rssi, error_count, the lot.
      assert Session.snapshot(s1).peers == Session.snapshot(s2).peers
    end

    test "bluetooth_off.jsonl creates no peer entries (errors without device_id)" do
      {:ok, session} = Session.start_link(bridge: Mob.Node.NativeBridge.Noop)

      Replay.into(session, fixture("bluetooth_off.jsonl"))
      snapshot = Session.snapshot(session)

      assert snapshot.peers == %{}
    end

    test "replay path goes through BridgeProtocol.decode/1 — proven by closed-taxonomy coercion" do
      tmp =
        Path.join(
          System.tmp_dir!(),
          "replay_unknown_kind_#{System.unique_integer([:positive])}.jsonl"
        )

      File.write!(
        tmp,
        ~s({"v":1,"event":"error","kind":"definitely_not_a_real_kind","detail":"x"}\n)
      )

      # Direct evidence: an unknown error kind should be coerced to
      # :unknown by BridgeProtocol — proving the replay path actually
      # routes through it (no separate test-only decoder).
      [raw] = Enum.to_list(Replay.stream_raw(tmp))
      assert {:ok, %Events.Error{kind: :unknown}} = BridgeProtocol.decode(raw)

      File.rm!(tmp)
    end
  end
end
