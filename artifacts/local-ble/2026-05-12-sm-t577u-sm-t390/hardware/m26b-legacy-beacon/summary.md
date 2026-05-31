# MeshX Android BLE Message Delivery Verification

| Field | Value |
| --- | --- |
| mode | `live` |
| scan_window_sec | `15` |
| wait_for_devices_sec | `30` |
| observer_ready_timeout_sec | `10` |
| sender_log | `/tmp/mob-android-m26b-legacy-current/sender.log` |
| observer_log | `/tmp/mob-android-m26b-legacy-current/observer.log` |
| adb_devices_log | `/tmp/mob-android-m26b-legacy-current/adb-devices.txt` |
| adb_inventory_device_count | `2` |
| adb_ready_device_count | `2` |
| adb_nonready_device_count | `0` |
| adb_mdns_log | `/tmp/mob-android-m26b-legacy-current/adb-mdns-services.txt` |
| adb_mdns_service_count | `0` |
| host_usb_log | `/tmp/mob-android-m26b-legacy-current/host-usb.txt` |
| host_usb_android_candidate_count | `2` |
| sender_logcat_capture_failed | `false` |
| observer_logcat_capture_failed | `false` |
| summary_json | `/tmp/mob-android-m26b-legacy-current/summary.json` |
| summary_markdown | `/tmp/mob-android-m26b-legacy-current/summary.md` |
| legacy_beacon | `true` |
| full_envelope_delivery_complete | `false` |
| legacy_beacon_delivery_complete | `true` |
| m26_android_to_android_complete | `false` |

## Commands

```bash
scripts/android_ble_message_delivery_two_device.sh --wait-for-devices 30 --skip-install --legacy-beacon --observer-settle 3 --window 15 --sender R52W90AW7EN --observer 5200f354f4fb277f --out-dir /tmp/mob-android-m26b-legacy-current
adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.BLUETOOTH_SCAN
adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.BLUETOOTH_ADVERTISE
adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.BLUETOOTH_CONNECT
adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.ACCESS_FINE_LOCATION
adb -s 5200f354f4fb277f shell pm grant dev.mob.mob android.permission.BLUETOOTH_SCAN
adb -s 5200f354f4fb277f shell pm grant dev.mob.mob android.permission.BLUETOOTH_ADVERTISE
adb -s 5200f354f4fb277f shell pm grant dev.mob.mob android.permission.BLUETOOTH_CONNECT
adb -s 5200f354f4fb277f shell pm grant dev.mob.mob android.permission.ACCESS_FINE_LOCATION
adb -s R52W90AW7EN shell input keyevent KEYCODE_WAKEUP
adb -s R52W90AW7EN shell wm dismiss-keyguard
adb -s 5200f354f4fb277f shell input keyevent KEYCODE_WAKEUP
adb -s 5200f354f4fb277f shell wm dismiss-keyguard
adb -s R52W90AW7EN shell getprop ro.product.model
adb -s R52W90AW7EN shell getprop ro.build.version.release
adb -s R52W90AW7EN shell getprop ro.build.version.sdk
adb -s R52W90AW7EN shell pm has-feature android.hardware.bluetooth_le
adb -s 5200f354f4fb277f shell getprop ro.product.model
adb -s 5200f354f4fb277f shell getprop ro.build.version.release
adb -s 5200f354f4fb277f shell getprop ro.build.version.sdk
adb -s 5200f354f4fb277f shell pm has-feature android.hardware.bluetooth_le
adb -s R52W90AW7EN logcat -c
adb -s 5200f354f4fb277f logcat -c
adb -s R52W90AW7EN shell am force-stop dev.mob.mob
adb -s 5200f354f4fb277f shell am force-stop dev.mob.mob
adb -s 5200f354f4fb277f shell am start -n dev.mob.mob/.MainActivity --ez mob_start_scan true
wait up to 10s for Device B scan_start_result accepted=true
sleep 3
adb -s R52W90AW7EN shell am start -n dev.mob.mob/.MainActivity --ez mob_dispatch_test true --ez mob_dispatch_legacy_beacon true
sleep 15
adb devices -l > /tmp/mob-android-m26b-legacy-current/adb-devices.txt
adb mdns services > /tmp/mob-android-m26b-legacy-current/adb-mdns-services.txt
ioreg -p IOUSB -l -w0 > /tmp/mob-android-m26b-legacy-current/host-usb.txt
adb -s R52W90AW7EN logcat -d -s MobBle:I MobBleControl:I MobBleDispatch:I MobBleGossip:I AndroidRuntime:E > /tmp/mob-android-m26b-legacy-current/sender.log 2>&1 || true
adb -s 5200f354f4fb277f logcat -d -s MobBle:I MobBleControl:I MobBleDispatch:I MobBleGossip:I AndroidRuntime:E > /tmp/mob-android-m26b-legacy-current/observer.log 2>&1 || true
```

## ADB Inventory

| Serial | State | Ready | Details |
| --- | --- | --- | --- |
| `5200f354f4fb277f` | `device` | `true` | `usb:0-1.3 product:gtactive2wifixx model:SM_T390 device:gtactive2wifi transport_id:5` |
| `R52W90AW7EN` | `device` | `true` | `usb:1-1 product:gtactive3ue model:SM_T577U device:gtactive3 transport_id:4` |

## Devices

| Role | Serial | Model | Android | API | BLE LE |
| --- | --- | --- | --- | --- | --- |
| Device A sender | `R52W90AW7EN` | `SM-T577U` | `13` | `33` | `true` |
| Device B observer | `5200f354f4fb277f` | `SM-T390` | `9` | `28` | `true` |

## ADB mDNS Services

| Raw Service |
| --- |
| _none_ |

## Host USB Android Candidates

| Serial | Product | Vendor | Registry Name |
| --- | --- | --- | --- |
| `R52W90AW7EN` | `SAMSUNG_Android` | `SAMSUNG` | `SAMSUNG_Android` |
| `5200f354f4fb277f` | `SAMSUNG_Android` | `SAMSUNG` | `SAMSUNG_Android` |

## Payload Sizes

| Payload | Bytes |
| --- | --- |
| sender advertising_set_started.payload | `n/a` |
| sender legacy_beacon_advertising_started.beacon | `22` |
| observer received_message.envelope | `n/a` |
| observer received_message_beacon.beacon_payload | `22` |
| observer raw_transport_metadata.message_payload | `n/a` |
| observer raw_transport_metadata.manufacturer_data | `n/a` |
| observer raw_transport_metadata.advertisement | `n/a` |

## Validation

| Check | Result |
| --- | --- |
| `sender_attempt_dispatched` | `true` |
| `advertising_set_started` | `false` |
| `sender_attempt_matches_advertising_set` | `false` |
| `sender_payload_size_matches` | `false` |
| `sender_logcat_captured` | `true` |
| `observer_logcat_captured` | `true` |
| `observer_scan_started` | `true` |
| `received_message_logged` | `false` |
| `observer_m14_consistent` | `false` |
| `observer_mob_routing_metadata` | `false` |
| `payload_match` | `` |
| `legacy_beacon_requested` | `true` |
| `legacy_beacon_advertising_started` | `true` |
| `sender_legacy_beacon_size_matches` | `true` |
| `received_message_beacon_logged` | `true` |
| `observer_beacon_transport_metadata` | `true` |
| `legacy_beacon_payload_match` | `true` |

## M26 Completion Gate

| Check | Result |
| --- | --- |
| `sender_attempt_dispatched` | `true` |
| `advertising_set_started` | `false` |
| `sender_attempt_matches_advertising_set` | `false` |
| `sender_payload_size_matches` | `false` |
| `sender_logcat_captured` | `true` |
| `observer_logcat_captured` | `true` |
| `observer_scan_started` | `true` |
| `received_message_logged` | `false` |
| `observer_m14_consistent` | `false` |
| `observer_mob_routing_metadata` | `false` |
| `payload_match` | `` |
| `sender_and_observer_distinct` | `true` |
| `sender_and_observer_logs_distinct` | `true` |
| `sender_device_metadata_complete` | `true` |
| `observer_device_metadata_complete` | `true` |
| `require_scan_start` | `true` |
| `not_repo_fixture_log_pair` | `true` |
| `android_logcat_provenance` | `false` |

## M26 Completion Provenance

| Provenance | Value |
| --- | --- |
| `mode` | `live` |
| `live_run` | `true` |
| `verify_only` | `false` |
| `repo_fixture_log_pair` | `false` |
| `real_two_android_logcat_required` | `true` |

Blockers:

- `advertising_set_started`
- `sender_attempt_matches_advertising_set`
- `sender_payload_size_matches`
- `received_message_logged`
- `observer_m14_consistent`
- `observer_mob_routing_metadata`
- `payload_match`
- `android_logcat_provenance`

## Device A Attempt Outcome

```json
{
  "v": 1,
  "event": "attempt_outcome",
  "attempt_id": "spike-att-0",
  "message_id": "AAECAwQFBgcICQoLDA0ODw==",
  "target_peer_id": "meshx-beta",
  "target_device_ids": [
    "AA:BB:CC:DD:EE:FF"
  ],
  "kind": "dispatched",
  "reason": "legacy_beacon_fallback",
  "adapter": "ble_android",
  "outcome_at_ms": 107892826
}
```

## Device A Advertising Event

```json
null
```

## Device B Scan Start Event

```json
{
  "v": 1,
  "event": "scan_start_result",
  "accepted": true
}
```

## Device B Received Event

```json
null
```
