defmodule Mob.Node.BLE.AdvertGossipDispatcher.AndroidTest do
  use ExUnit.Case, async: true

  alias Mob.Node.BLE.AdvertGossipDispatcher.Android
  alias Mob.Node.BLE.AdvertGossipPlanner.Intent
  alias Mob.Node.BLE.Events.AdvertGossipOutcome

  defp intent(opts \\ []) do
    base = %Intent{
      gossip_intent_id: "gossip-0",
      source: :beacon_ref,
      advertise_as: :legacy_beacon_advert,
      message_id_hash: <<1, 2, 3, 4, 5, 6, 7, 8>>,
      sender_peer_hash: <<8, 7, 6, 5, 4, 3, 2, 1>>,
      payload_kind: "TX",
      envelope_version: 1,
      source_device_ids: ["AA:01"],
      first_seen_at: 10,
      last_seen_at: 20,
      seen_count: 1,
      planned_at: 30
    }

    Enum.reduce(opts, base, fn {key, value}, acc -> Map.put(acc, key, value) end)
  end

  test "legacy beacon intents call the injected Android bridge" do
    send_ok = fn %Intent{advertise_as: :legacy_beacon_advert} -> {:ok, :accepted} end

    assert [
             %AdvertGossipOutcome{
               kind: :gossiped,
               adapter: :ble_android,
               reason: nil,
               advertise_as: :legacy_beacon_advert,
               outcome_at_ms: 100
             }
           ] = Android.dispatch([intent()], outcome_at: 100, native_send: send_ok)
  end

  test "default bridge reports native bridge unavailable" do
    assert [%{kind: :failed, reason: :native_bridge_unavailable}] =
             Android.dispatch([intent()], outcome_at: 100)
  end

  test "full envelope gossip remains disabled unless a later milestone wires it" do
    full_intent = intent(source: :full_message, advertise_as: :full_envelope_advert)

    assert [%{kind: :skipped, reason: :full_envelope_gossip_unproven}] =
             Android.dispatch([full_intent], outcome_at: 100)

    assert [%{kind: :skipped, reason: :full_envelope_gossip_disabled}] =
             Android.dispatch([full_intent],
               outcome_at: 100,
               full_envelope_capability_proven: true
             )
  end

  test "dry_run does not invoke the bridge" do
    invoked = :counters.new(1, [])

    send_ok = fn _ ->
      :counters.add(invoked, 1, 1)
      {:ok, :accepted}
    end

    assert [%{kind: :would_gossip}] =
             Android.dispatch([intent()],
               outcome_at: 100,
               native_send: send_ok,
               dry_run: true
             )

    assert :counters.get(invoked, 1) == 0
  end

  test "invalid intent is rejected before bridge invocation" do
    invoked = :counters.new(1, [])

    send_ok = fn _ ->
      :counters.add(invoked, 1, 1)
      {:ok, :accepted}
    end

    bad = intent(message_id_hash: <<1, 2>>)

    assert [%{kind: :invalid_intent, reason: :validation}] =
             Android.dispatch([bad], outcome_at: 100, native_send: send_ok)

    assert :counters.get(invoked, 1) == 0
  end
end
