defmodule MeshxMobileApp.BLE.ObservabilityTest do
  use ExUnit.Case, async: true

  alias MeshxMobileApp.BLE.Events
  alias MeshxMobileApp.BLE.Observability

  setup do
    {:ok, pid} =
      start_supervised({Observability, name: :"obs_#{System.unique_integer([:positive])}"})

    {:ok, pid: pid}
  end

  describe "snapshot/1" do
    test "starts empty with monotonic started_at_ms", %{pid: pid} do
      snap = Observability.snapshot(pid)
      assert snap.peers == %{}
      assert snap.dispatch_outcomes == %{}
      assert snap.error_kinds == %{}
      assert snap.distinct_message_keys == 0
      assert snap.total_events == 0
      assert is_integer(snap.started_at_ms)
    end
  end

  describe "DeviceDiscovered / AdvertisementReceived" do
    test "creates a peer row on first sight, refreshes last_seen on later sights", %{pid: pid} do
      Observability.record(pid, %Events.DeviceDiscovered{
        device_id: "AA:BB:CC:DD:EE:FF",
        rssi: -42,
        advertisement: <<>>,
        observed_at_ms: 1000
      })

      Observability.record(pid, %Events.AdvertisementReceived{
        device_id: "AA:BB:CC:DD:EE:FF",
        rssi: -38,
        advertisement: <<>>,
        observed_at_ms: 1100
      })

      snap = Observability.snapshot(pid)
      peer = snap.peers["AA:BB:CC:DD:EE:FF"]

      assert peer.device_id == "AA:BB:CC:DD:EE:FF"
      assert peer.rssi == -38
      assert peer.first_seen_at_ms <= peer.last_seen_at_ms
      assert peer.beacon_callbacks == 0
      assert peer.distinct_messages == 0
      assert snap.total_events == 2
    end
  end

  describe "ReceivedMessageBeacon" do
    test "increments beacon_callbacks per event and distinct_messages once per key", %{pid: pid} do
      # Same {sender_hash, msg_id_hash} delivered five times (CALLBACK_TYPE_ALL_MATCHES inflation)
      for _ <- 1..5 do
        Observability.record(pid, beacon("DEVICE_A", <<1::64>>, <<2::64>>, -50))
      end

      # A different distinct message from the same peer
      Observability.record(pid, beacon("DEVICE_A", <<3::64>>, <<2::64>>, -55))

      snap = Observability.snapshot(pid)
      peer = snap.peers["DEVICE_A"]

      assert peer.beacon_callbacks == 6
      assert peer.distinct_messages == 2
      assert snap.distinct_message_keys == 2
    end

    test "dedup is per {sender, msg_id} — two senders can share a msg_id without collision", %{
      pid: pid
    } do
      Observability.record(pid, beacon("DEV_A", <<10::64>>, <<99::64>>, -60))
      Observability.record(pid, beacon("DEV_B", <<10::64>>, <<88::64>>, -60))

      snap = Observability.snapshot(pid)
      assert snap.distinct_message_keys == 2
    end
  end

  describe "Error / dispatch outcomes" do
    test "BleDispatcher attempt_outcome JSON is folded into dispatch_outcomes, not error_kinds",
         %{pid: pid} do
      Observability.record(pid, %Events.Error{
        kind: :unknown,
        detail:
          ~s({"v":1,"event":"attempt_outcome","attempt_id":"x","message_id":"abc","target_peer_id":"broadcast","kind":"dispatched","reason":"legacy_beacon_fallback","adapter":"ble_android","outcome_at_ms":1234})
      })

      Observability.record(pid, %Events.Error{
        kind: :unknown,
        detail: ~s({"v":1,"event":"attempt_outcome","kind":"failed","reason":"bluetooth_off"})
      })

      snap = Observability.snapshot(pid)
      assert snap.dispatch_outcomes == %{"dispatched" => 1, "failed" => 1}
      assert snap.error_kinds == %{}
    end

    test "real bridge errors increment error_kinds keyed by kind atom", %{pid: pid} do
      Observability.record(pid, %Events.Error{
        kind: :unauthorized,
        detail: "Need android.permission.BLUETOOTH_SCAN"
      })

      Observability.record(pid, %Events.Error{
        kind: :scan_failed,
        detail: "scan failed (code=2)"
      })

      Observability.record(pid, %Events.Error{
        kind: :unauthorized,
        detail: "Need android.permission.BLUETOOTH_ADVERTISE"
      })

      snap = Observability.snapshot(pid)
      assert snap.error_kinds == %{unauthorized: 2, scan_failed: 1}
      assert snap.dispatch_outcomes == %{}
    end
  end

  describe "reset/1" do
    test "wipes all state and resets started_at_ms forward", %{pid: pid} do
      Observability.record(pid, beacon("DEV", <<1::64>>, <<2::64>>, -40))
      before = Observability.snapshot(pid)
      assert before.total_events == 1

      :ok = Observability.reset(pid)
      after_reset = Observability.snapshot(pid)

      assert after_reset.peers == %{}
      assert after_reset.total_events == 0
      assert after_reset.distinct_message_keys == 0
      assert after_reset.started_at_ms >= before.started_at_ms
    end
  end

  describe "record/2 fault tolerance" do
    test "returns :ok and is a no-op when the named server isn't running" do
      # No need to start anything — addressing a non-existent name must
      # be a silent no-op (observability is never a hard dependency).
      assert :ok =
               Observability.record(:no_such_observer, %Events.Error{kind: :unknown, detail: ""})
    end
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  defp beacon(device_id, msg_id_hash, sender_hash, rssi) do
    %Events.ReceivedMessageBeacon{
      beacon_version: 1,
      envelope_version: 1,
      payload_kind: "TX",
      message_id_hash: msg_id_hash,
      sender_peer_id_hash: sender_hash,
      received_device_id: device_id,
      received_at: 0,
      rssi: rssi,
      raw_transport_metadata: %{}
    }
  end
end
