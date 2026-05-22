defmodule MeshxMobileApp.BleSelfTestTest do
  use ExUnit.Case, async: false

  alias MeshxMobileApp.BleSelfTest

  setup do
    previous_send = System.get_env("MESHX_BLE_SELFTEST_SEND")
    System.put_env("MESHX_BLE_SELFTEST_SEND", "0")

    {:ok, pid} = BleSelfTest.start_link(native?: false)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
      restore_env("MESHX_BLE_SELFTEST_SEND", previous_send)
    end)

    {:ok, pid: pid}
  end

  test "counts Mob.Ble.MobileBridge received_message_beacon events", %{pid: pid} do
    send(pid, {Mob.Ble.MobileBridge, :bridge_event, received_message_beacon_json()})

    state = :sys.get_state(pid)

    assert state.event_count == 1
    assert state.beacon_callbacks == 1
    assert MapSet.size(state.seen_messages) == 1
    assert state.full_envelopes_received == 0
  end

  test "still counts legacy NativeBridge received_message_beacon events", %{pid: pid} do
    send(pid, {MeshxMobileApp.NativeBridge, :bridge_event, received_message_beacon_json()})

    state = :sys.get_state(pid)

    assert state.event_count == 1
    assert state.beacon_callbacks == 1
    assert MapSet.size(state.seen_messages) == 1
  end

  defp received_message_beacon_json do
    ~s({
      "v": 1,
      "event": "received_message_beacon",
      "beacon_version": 1,
      "envelope_version": 1,
      "payload_kind": "TX",
      "message_id_hash": "+vNJsVUqo5M=",
      "sender_peer_id_hash": "pTyQj8lXnuI=",
      "received_device_id": "7B:93:F3:29:A5:7B",
      "received_at": 456142240,
      "rssi": -54,
      "raw_transport_metadata": {
        "transport": "ble_advertisement",
        "source_event": "device_discovered",
        "received_device_id": "7B:93:F3:29:A5:7B",
        "advertisement": "Gf///01CAQEBAPrzSbFVKqOTpTyQj8lXnuIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "beacon_payload": "TUIBAQEA+vNJsVUqo5OlPJCPyVee4g==",
        "manufacturer_data": "///NQgEBAQD680mxVSqjk6U8kI/JV57i",
        "company_identifier": 65535,
        "ad_type": 255
      }
    })
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
