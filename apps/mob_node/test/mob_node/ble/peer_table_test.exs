defmodule Mob.Node.BLE.PeerTableTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.{Events, MessageEnvelope, PeerTable}
  alias Mob.Node.BLE.PeerTable.Entry

  describe "update/2 — advertisement-class events" do
    test "DeviceDiscovered creates an entry with sighting metadata" do
      e = %Events.DeviceDiscovered{
        device_id: "AA:BB:01",
        transport: :ble,
        rssi: -50,
        advertisement: <<>>,
        observed_at_ms: 100
      }

      table = PeerTable.update(PeerTable.new(), e)

      assert %Entry{
               device_id: "AA:BB:01",
               first_seen_at: 100,
               last_seen_at: 100,
               last_rssi: -50,
               advertisement_seen_count: 1,
               error_count: 0
             } = PeerTable.get(table, "AA:BB:01")
    end

    test "AdvertisementReceived for an unseen device still creates an entry" do
      # An adv-received before any device-discovered shouldn't be
      # silently dropped — the contract treats them as interchangeable
      # for sighting purposes.
      e = %Events.AdvertisementReceived{
        device_id: "AA:BB:02",
        rssi: -65,
        advertisement: <<>>,
        observed_at_ms: 200
      }

      table = PeerTable.update(PeerTable.new(), e)

      assert %Entry{first_seen_at: 200, advertisement_seen_count: 1} =
               PeerTable.get(table, "AA:BB:02")
    end

    test "repeat sightings bump count, advance last_seen_at, refresh rssi, preserve first_seen_at" do
      d = %Events.DeviceDiscovered{
        device_id: "AA:BB:03",
        transport: :ble,
        rssi: -55,
        advertisement: <<>>,
        observed_at_ms: 100
      }

      a1 = %Events.AdvertisementReceived{
        device_id: "AA:BB:03",
        rssi: -60,
        advertisement: <<>>,
        observed_at_ms: 150
      }

      a2 = %Events.AdvertisementReceived{
        device_id: "AA:BB:03",
        rssi: -45,
        advertisement: <<>>,
        observed_at_ms: 300
      }

      table =
        PeerTable.new()
        |> PeerTable.update(d)
        |> PeerTable.update(a1)
        |> PeerTable.update(a2)

      assert %Entry{
               first_seen_at: 100,
               last_seen_at: 300,
               last_rssi: -45,
               advertisement_seen_count: 3
             } = PeerTable.get(table, "AA:BB:03")
    end

    test "out-of-order observed_at_ms doesn't rewind last_seen_at" do
      a1 = %Events.AdvertisementReceived{
        device_id: "AA:BB:04",
        rssi: -50,
        advertisement: <<>>,
        observed_at_ms: 500
      }

      a2 = %Events.AdvertisementReceived{
        device_id: "AA:BB:04",
        rssi: -55,
        advertisement: <<>>,
        observed_at_ms: 200
      }

      table =
        PeerTable.new() |> PeerTable.update(a1) |> PeerTable.update(a2)

      assert PeerTable.get(table, "AA:BB:04").last_seen_at == 500
    end
  end

  describe "update/2 — error events" do
    test "errors without device_id leave the table unchanged" do
      table =
        PeerTable.new()
        |> PeerTable.update(%Events.Error{kind: :bluetooth_off, detail: "x"})

      assert PeerTable.size(table) == 0
    end

    test "errors with device_id for a known peer bump error_count" do
      d = %Events.DeviceDiscovered{
        device_id: "AA:BB:05",
        transport: :ble,
        rssi: -50,
        advertisement: <<>>,
        observed_at_ms: 1
      }

      err = %Events.Error{kind: :gatt_error, detail: "boom", device_id: "AA:BB:05"}

      table =
        PeerTable.new()
        |> PeerTable.update(d)
        |> PeerTable.update(err)
        |> PeerTable.update(err)

      assert PeerTable.get(table, "AA:BB:05").error_count == 2
    end

    test "errors for an unknown device_id do NOT create a phantom entry" do
      # A peer only exists once we've actually sighted it. Otherwise a
      # noisy error stream could create stub peers indistinguishable
      # from real sightings.
      err = %Events.Error{kind: :gatt_error, detail: "x", device_id: "AA:BB:06"}

      table = PeerTable.update(PeerTable.new(), err)

      assert PeerTable.size(table) == 0
    end
  end

  describe "update/2 — non-tracked event types" do
    test "non-advertisement events leave the table unchanged" do
      table = PeerTable.new()

      same =
        table
        |> PeerTable.update(%Events.DeviceLost{
          device_id: "AA",
          transport: :ble,
          observed_at_ms: 1
        })
        |> PeerTable.update(%Events.MessageReceived{
          peer_id: "p",
          transport: :ble,
          payload: <<>>,
          received_at_ms: 0
        })

      # DeviceLost arrives before any sighting → no entry. MessageReceived
      # is keyed by peer_id only and intentionally doesn't populate this
      # device-keyed table until peer-id correlation lands.
      assert same == table
    end

    test "ReceivedMessage does not create or mutate peer graph entries" do
      table = PeerTable.new()

      {:ok, envelope} =
        MessageEnvelope.build(
          message_id: <<1::128>>,
          sender_peer_id: "meshx-alpha",
          recipient_peer_id: "meshx-beta",
          created_at: 1_700_000_000_000,
          ttl: 1,
          payload_type: "TX",
          payload: "hi"
        )

      same =
        PeerTable.update(table, %Events.ReceivedMessage{
          message_id: envelope.message_id,
          sender_peer_id: envelope.sender_peer_id,
          recipient_peer_id: envelope.recipient_peer_id,
          received_device_id: "AA:BB:CC:DD:EE:01",
          received_at: 12_345,
          rssi: -61,
          envelope: envelope,
          raw_transport_metadata: %{
            transport: :ble_advertisement,
            message_payload: MessageEnvelope.encode(envelope)
          }
        })

      assert same == table
      assert PeerTable.size(same) == 0
    end
  end

  describe "peer_id derivation from advertisement" do
    test "named advertisement (mob- prefix) sets peer_id on the entry" do
      e = %Events.DeviceDiscovered{
        device_id: "AA:11",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      assert %Entry{peer_id: "meshx-alpha"} =
               PeerTable.update(PeerTable.new(), e) |> PeerTable.get("AA:11")
    end

    test "anonymous advertisement leaves peer_id as nil" do
      e = %Events.DeviceDiscovered{
        device_id: "BB:22",
        transport: :ble,
        rssi: -50,
        advertisement: <<2, 0x01, 0x06>>,
        observed_at_ms: 100
      }

      assert %Entry{peer_id: nil} =
               PeerTable.update(PeerTable.new(), e) |> PeerTable.get("BB:22")
    end

    test "a once-named device never demotes to anonymous on a name-less follow-up" do
      named = %Events.DeviceDiscovered{
        device_id: "CC:33",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      anon_followup = %Events.AdvertisementReceived{
        device_id: "CC:33",
        rssi: -52,
        advertisement: <<2, 0x01, 0x06>>,
        observed_at_ms: 200
      }

      table =
        PeerTable.new() |> PeerTable.update(named) |> PeerTable.update(anon_followup)

      assert PeerTable.get(table, "CC:33").peer_id == "meshx-alpha"
    end

    test "anonymous device promotes to named when a later advertisement carries the name" do
      anon = %Events.DeviceDiscovered{
        device_id: "DD:44",
        transport: :ble,
        rssi: -50,
        advertisement: <<2, 0x01, 0x06>>,
        observed_at_ms: 100
      }

      named = %Events.AdvertisementReceived{
        device_id: "DD:44",
        rssi: -52,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 200
      }

      table =
        PeerTable.new() |> PeerTable.update(anon) |> PeerTable.update(named)

      assert PeerTable.get(table, "DD:44").peer_id == "meshx-alpha"
    end
  end

  describe "identity_source + collision handling" do
    test "named sighting sets identity_source to :advertised_name" do
      e = %Events.DeviceDiscovered{
        device_id: "AA:01",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      entry = PeerTable.update(PeerTable.new(), e) |> PeerTable.get("AA:01")
      assert entry.identity_source == :advertised_name
      assert entry.identity_collision_count == 0
      assert entry.last_conflicting_peer_id == nil
    end

    test "anonymous sighting keeps identity_source at :none" do
      e = %Events.AdvertisementReceived{
        device_id: "BB:02",
        rssi: -50,
        advertisement: <<2, 0x01, 0x06>>,
        observed_at_ms: 100
      }

      entry = PeerTable.update(PeerTable.new(), e) |> PeerTable.get("BB:02")
      assert entry.identity_source == :none
      assert entry.peer_id == nil
    end

    test "promotion from anonymous to named advances identity_source" do
      anon = %Events.DeviceDiscovered{
        device_id: "CC:03",
        transport: :ble,
        rssi: -50,
        advertisement: <<2, 0x01, 0x06>>,
        observed_at_ms: 100
      }

      named = %Events.AdvertisementReceived{
        device_id: "CC:03",
        rssi: -52,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 200
      }

      entry =
        PeerTable.new()
        |> PeerTable.update(anon)
        |> PeerTable.update(named)
        |> PeerTable.get("CC:03")

      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_source == :advertised_name
      assert entry.identity_collision_count == 0
    end

    test "same device claiming a DIFFERENT peer_id triggers a collision" do
      first = %Events.DeviceDiscovered{
        device_id: "DD:04",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      conflicting = %Events.AdvertisementReceived{
        device_id: "DD:04",
        rssi: -55,
        advertisement: <<11, 0x09, "meshx-beta">>,
        observed_at_ms: 200
      }

      entry =
        PeerTable.new()
        |> PeerTable.update(first)
        |> PeerTable.update(conflicting)
        |> PeerTable.get("DD:04")

      # First claim wins — stability over recency.
      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_source == :advertised_name
      assert entry.identity_collision_count == 1
      assert entry.last_conflicting_peer_id == "meshx-beta"
      # Sighting counts still tick — the event itself isn't dropped.
      assert entry.advertisement_seen_count == 2
    end

    test "repeated conflicting claims accumulate the collision counter" do
      base = %Events.DeviceDiscovered{
        device_id: "EE:05",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      conflict_beta = %Events.AdvertisementReceived{
        device_id: "EE:05",
        rssi: -55,
        advertisement: <<11, 0x09, "meshx-beta">>,
        observed_at_ms: 200
      }

      conflict_gamma = %Events.AdvertisementReceived{
        device_id: "EE:05",
        rssi: -57,
        advertisement: <<12, 0x09, "meshx-gamma">>,
        observed_at_ms: 300
      }

      entry =
        PeerTable.new()
        |> PeerTable.update(base)
        |> PeerTable.update(conflict_beta)
        |> PeerTable.update(conflict_gamma)
        |> PeerTable.get("EE:05")

      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_collision_count == 2
      # Latest conflicting claim wins the slot — observability of the
      # most recent attempt.
      assert entry.last_conflicting_peer_id == "meshx-gamma"
    end

    test "reinforcing the same peer_id is NOT a collision" do
      e1 = %Events.DeviceDiscovered{
        device_id: "FF:06",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      e2 = %Events.AdvertisementReceived{
        device_id: "FF:06",
        rssi: -52,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 200
      }

      entry =
        PeerTable.new() |> PeerTable.update(e1) |> PeerTable.update(e2) |> PeerTable.get("FF:06")

      assert entry.identity_collision_count == 0
    end

    test "name-omission after a named claim is NOT a collision" do
      named = %Events.DeviceDiscovered{
        device_id: "11:07",
        transport: :ble,
        rssi: -50,
        advertisement: <<12, 0x09, "meshx-alpha">>,
        observed_at_ms: 100
      }

      anon_followup = %Events.AdvertisementReceived{
        device_id: "11:07",
        rssi: -52,
        advertisement: <<2, 0x01, 0x06>>,
        observed_at_ms: 200
      }

      entry =
        PeerTable.new()
        |> PeerTable.update(named)
        |> PeerTable.update(anon_followup)
        |> PeerTable.get("11:07")

      assert entry.peer_id == "meshx-alpha"
      assert entry.identity_source == :advertised_name
      assert entry.identity_collision_count == 0
    end
  end

  describe "by_peer_id/1" do
    test "groups rotating device_ids under their shared peer_id" do
      ad_alpha = <<12, 0x09, "meshx-alpha">>

      events = [
        %Events.DeviceDiscovered{
          device_id: "AA:1",
          transport: :ble,
          rssi: -50,
          advertisement: ad_alpha,
          observed_at_ms: 100
        },
        %Events.DeviceDiscovered{
          device_id: "BB:2",
          transport: :ble,
          rssi: -55,
          advertisement: ad_alpha,
          observed_at_ms: 200
        }
      ]

      table = Enum.reduce(events, PeerTable.new(), &PeerTable.update(&2, &1))
      grouped = PeerTable.by_peer_id(table)

      assert Map.keys(grouped) == ["meshx-alpha"]
      assert length(grouped["meshx-alpha"]) == 2

      assert MapSet.new(Enum.map(grouped["meshx-alpha"], & &1.device_id)) ==
               MapSet.new(["AA:1", "BB:2"])
    end

    test "anonymous peers collect under the nil key, one per device_id" do
      e1 = %Events.DeviceDiscovered{
        device_id: "A",
        transport: :ble,
        rssi: -50,
        advertisement: <<>>,
        observed_at_ms: 1
      }

      e2 = %Events.DeviceDiscovered{
        device_id: "B",
        transport: :ble,
        rssi: -50,
        advertisement: <<>>,
        observed_at_ms: 2
      }

      table =
        PeerTable.new() |> PeerTable.update(e1) |> PeerTable.update(e2)

      grouped = PeerTable.by_peer_id(table)
      assert length(grouped[nil]) == 2
    end
  end

  describe "capability tracking" do
    test "first sighting with a v1 capability record populates capabilities" do
      ad = <<5, 0xFF, "MX", 1, 0x07, 12, 0x09, "meshx-alpha">>

      e = %Events.DeviceDiscovered{
        device_id: "AA:CAP",
        transport: :ble,
        rssi: -50,
        advertisement: ad,
        observed_at_ms: 100
      }

      entry = PeerTable.update(PeerTable.new(), e) |> PeerTable.get("AA:CAP")
      assert entry.capabilities.protocol_version == 1
      assert entry.capabilities.supports_churn == true
    end

    test "capabilities are sticky: a follow-up advertisement without caps does NOT clear them" do
      ad_with_caps = <<5, 0xFF, "MX", 1, 0x07, 12, 0x09, "meshx-alpha">>
      ad_name_only = <<12, 0x09, "meshx-alpha">>

      first = %Events.DeviceDiscovered{
        device_id: "BB:CAP",
        transport: :ble,
        rssi: -50,
        advertisement: ad_with_caps,
        observed_at_ms: 100
      }

      followup = %Events.AdvertisementReceived{
        device_id: "BB:CAP",
        rssi: -52,
        advertisement: ad_name_only,
        observed_at_ms: 200
      }

      entry =
        PeerTable.new()
        |> PeerTable.update(first)
        |> PeerTable.update(followup)
        |> PeerTable.get("BB:CAP")

      # Sticky: protocol_version stays at 1 even though the latest
      # advertisement carried no MeshX capability record.
      assert entry.capabilities.protocol_version == 1
      assert entry.capabilities.supports_churn == true
    end

    test "a new capability claim replaces the previous one (capabilities legitimately update)" do
      ad_old = <<5, 0xFF, "MX", 1, 0x01>>
      ad_new = <<5, 0xFF, "MX", 1, 0x07>>

      first = %Events.DeviceDiscovered{
        device_id: "CC:CAP",
        transport: :ble,
        rssi: -50,
        advertisement: ad_old,
        observed_at_ms: 100
      }

      replace = %Events.AdvertisementReceived{
        device_id: "CC:CAP",
        rssi: -52,
        advertisement: ad_new,
        observed_at_ms: 200
      }

      entry =
        PeerTable.new()
        |> PeerTable.update(first)
        |> PeerTable.update(replace)
        |> PeerTable.get("CC:CAP")

      assert entry.capabilities.supports_replay_contract == true
      assert entry.capabilities.supports_passive_presence == true
      assert entry.capabilities.supports_churn == true
    end
  end

  describe "sorted/1" do
    test "returns entries sorted by last_seen_at descending" do
      e1 = %Events.AdvertisementReceived{
        device_id: "A",
        rssi: -1,
        advertisement: <<>>,
        observed_at_ms: 100
      }

      e2 = %Events.AdvertisementReceived{
        device_id: "B",
        rssi: -1,
        advertisement: <<>>,
        observed_at_ms: 300
      }

      e3 = %Events.AdvertisementReceived{
        device_id: "C",
        rssi: -1,
        advertisement: <<>>,
        observed_at_ms: 200
      }

      table =
        PeerTable.new()
        |> PeerTable.update(e1)
        |> PeerTable.update(e2)
        |> PeerTable.update(e3)

      assert ["B", "C", "A"] = table |> PeerTable.sorted() |> Enum.map(& &1.device_id)
    end
  end
end
