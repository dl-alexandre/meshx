# Android BLE Transport — On-Device Validation Ledger

This ledger records the first hardware validation pass of the Kotlin BLE
transport (`apps/meshx_mobile_app/android/src/main/java/dev/meshx/mob/ble/`)
against a real Android device, and the round-trip of its v1 wire-format
events through `MeshxMobileApp.BLE.BridgeProtocol.decode/1`.

## Environment

| Item | Value |
| --- | --- |
| Date (validation pass) | 2026-05-11 |
| Host | macOS (Darwin 25.4.0), Apple Silicon |
| JDK (build + test) | Temurin 21 (`/Library/Java/JavaVirtualMachines/temurin-21.jdk`) |
| Gradle | wrapper 8.7 (bootstrapped with Homebrew Gradle 9.5) |
| Android Gradle Plugin | 8.5.0 |
| Kotlin | 1.9.24 |
| Android SDK platform | 34 (compileSdk/targetSdk); minSdk 26 |
| Device model | **Samsung SM-T577U** (Galaxy Tab Active 3) |
| Manufacturer | samsung |
| Android version | **13** (`ro.build.version.release=13`) |
| API level | **33** (`ro.build.version.sdk=33`) |
| Device codename | gtactive3 |
| ADB serial | `R52W90AW7EN` |

## Commands executed

```bash
# Identity probe
adb -s R52W90AW7EN shell getprop ro.product.model       # SM-T577U
adb -s R52W90AW7EN shell getprop ro.build.version.sdk   # 33

# Toolchain
brew install gradle                                     # 9.5.0
cd apps/meshx_mobile_app/android
gradle wrapper --gradle-version 8.7

# JVM unit tests
./gradlew --no-daemon test                              # PASS (see below)

# Install + launch
ANDROID_SERIAL=R52W90AW7EN ./gradlew --no-daemon installDebug
adb -s R52W90AW7EN shell am start -n dev.meshx.mob/.MainActivity

# Permission state
adb -s R52W90AW7EN shell dumpsys package dev.meshx.mob \
    | grep -E "granted|permission"

# Bluetooth on (was off at first launch — produced a real bluetooth_off event)
adb -s R52W90AW7EN shell svc bluetooth enable

# Capture
adb -s R52W90AW7EN logcat -c
adb -s R52W90AW7EN logcat -s MeshxBle:I  > /tmp/meshxble.log &

# Drive the UI (button bounds resolved from `uiautomator dump`)
adb -s R52W90AW7EN shell input tap 600 416   # Start advertising
adb -s R52W90AW7EN shell input tap 600 224   # Start scan
# … 20s capture …
adb -s R52W90AW7EN shell input tap 600 320   # Stop scan
adb -s R52W90AW7EN shell input tap 600 512   # Stop advertising
```

## Minimal fixes required for on-device run

Two real bugs surfaced during the pass. Both isolated to the Kotlin side;
the canonical contract (`BLE.BridgeProtocol`, event structs) was not
touched.

1. **`BleAdvertiser.kt` null-safety compile error.** The
   `adapter.name = localName` call sat below a `?.bluetoothLeAdvertiser`
   null-check, but Kotlin flow analysis does not carry that through.
   Fix: `adapter!!.name = localName` with a comment pointing at the
   earlier null-check. No behavioral change.

2. **`BleEvent.kt` base64 source.** `android.util.Base64` is stubbed to
   `null` under the default JVM test runner (no Robolectric in scope),
   which made the `toJsonObject` test NPE. Switched the encoder to
   `java.util.Base64` (available since API 26 = our minSdk). Output is
   identical for our inputs (standard alphabet, no line wrapping),
   visible on-device in the captured logcat lines below.

Neither fix touched the Elixir side. `BridgeProtocol` decoded real-device
output unchanged.

## Results

### JVM unit tests (`./gradlew test`)

```
BleEventTest        — 5 tests, 0 failures
FakeBleBridgeTest   — 2 tests, 0 failures
Total               — 7 tests, 0 failures
```

JUnit XML at `apps/meshx_mobile_app/android/build/test-results/testDebugUnitTest/`.

### Runtime permission state

After first launch and accepting prompts:

```
android.permission.BLUETOOTH_SCAN: granted=true
android.permission.BLUETOOTH_ADVERTISE: granted=true
android.permission.BLUETOOTH_CONNECT: granted=false  (not requested by BlePermissions; manifest only)
```

`BLUETOOTH_CONNECT` is in the manifest but intentionally not in
`BlePermissions.required()` — scan + advertise do not need it. The
advertiser's adapter-rename codepath catches `SecurityException` and
proceeds without renaming when `CONNECT` is absent, which is exactly
what happened on-device.

### Event capture (full session, BT on)

```
Total MeshxBle lines captured:    6575
"event":"device_discovered":        65
"event":"advertisement_received": 6503
"event":"error":                     3
```

The 3 errors are the two `bluetooth_off` events emitted before BT was
enabled (intentionally reproduced) plus one transient. The
`device_discovered` count equals the number of distinct `device_id`
values seen in the `advertisement_received` stream, proving the
first-sight vs repeat partition in `BleScanner` is working.

### Cross-platform discovery confirmed

One of the discovered devices was the existing iOS MeshX peer
advertising nearby:

```json
{
  "v": 1,
  "event": "device_discovered",
  "device_id": "4F:9C:5A:DC:6E:6D",
  "rssi": -50,
  "advertisement": "AgEaAgoMCv9MABAFBBzMjFoLCW1lc2h4LWlwYWQAAA…",
  "observed_at_ms": 761035
}
```

Base64 of the advertisement contains the ASCII string `meshx-ipad` —
the local name the iOS bridge emits. The Android scanner ingested an
iOS MeshX advertisement on the wire format defined by the unified
`BLE.Adapter` contract. No iOS or Elixir code paths were involved on
the Android side.

### Round-trip through `BridgeProtocol.decode/1`

Three real captured lines piped through the Elixir decoder
(`/tmp/one_*.json` produced by `grep` + `head -1` against the live
logcat capture):

```elixir
# device_discovered
{:ok,
 %MeshxMobileApp.BLE.Events.DeviceDiscovered{
   device_id: "94:94:4A:05:9C:99",
   transport: :ble,
   rssi: -83,
   advertisement: <<62 bytes>>,
   observed_at_ms: 760882
 }}

# advertisement_received
{:ok,
 %MeshxMobileApp.BLE.Events.AdvertisementReceived{
   device_id: "84:E0:F4:E0:26:52",
   transport: :ble,
   rssi: -80,
   advertisement: <<62 bytes>>,
   observed_at_ms: 760934
 }}

# error (captured before BT was enabled)
{:ok,
 %MeshxMobileApp.BLE.Events.Error{
   kind: :bluetooth_off,
   detail: "bluetooth adapter disabled or absent",
   device_id: nil
 }}
```

All three on-device JSON lines decoded into the canonical structs
verbatim. Field names, types, and the closed `kind` taxonomy survive
the language boundary.

### Elixir suite after the Kotlin fixes

```
mix test
38 tests, 0 failures
```

No Elixir code was changed. The existing
`MeshxMobileApp.BLE.AndroidWireFormatTest` continues to pass against
the committed fixtures, and the live logcat output matches those
fixtures' shape exactly.

## Pass / fail checklist

| Goal | Status | Evidence |
| --- | --- | --- |
| Bootstrap or verify Gradle wrapper | ✅ | `apps/meshx_mobile_app/android/gradlew` at 8.7 |
| `./gradlew test` green | ✅ | 7/7 tests |
| Install/debug app on device | ✅ | `Installed on 1 device.` on SM-T577U |
| Runtime permissions verified | ✅ | `dumpsys package` output above |
| Start advertise | ✅ | Tapped via `input tap 600 416`; no `advertise_failed` errors |
| Scan from another MeshX instance | ✅ | iPad's `meshx-ipad` advertisement captured (`4F:9C:5A:DC:6E:6D`) |
| Capture logcat tag `MeshxBle` | ✅ | 6575 lines at `/tmp/meshxble.full.log` |
| Confirm v1 JSON shape matches fixtures | ✅ | Field set, types, error taxonomy all match |
| BridgeProtocol decode validation | ✅ | Three live lines → canonical structs |
| Validation ledger | ✅ | This document |

## What is explicitly NOT validated by this pass

Out of scope by design and not exercised here:

- Mesh routing
- Crypto / Noise handshake
- Peer authentication (`PeerAuthenticated` event)
- Connection state transitions (`ConnectionStateChanged`)
- Message ingress on an authenticated peer (`MessageReceived`)
- `DeviceLost` (stale-device pruning not implemented yet)
- Reconnect orchestration
- Background service / foreground service for sustained scanning
- BEAM-on-Android NIF sink (events were observed via logcat, not via a
  live BEAM)

## Notes for the next pass

- `BLUETOOTH_CONNECT` entered `BlePermissions.required()` in M36 for
  the constrained beacon fetch GATT spike.
- The `observed_at_ms` field comes from `SystemClock.elapsedRealtime()`
  (boot-relative monotonic milliseconds). Sufficient for ordering and
  staleness windows; not wall-clock. Document in any future timestamp
  semantics agreement with iOS.
- `BleEventSink` in `MainActivity` currently appends every event to a
  `TextView` on the UI thread — that's fine for a 20-second bring-up
  but will need throttling or removal before any sustained scan
  session. Out of scope for this pass.

## M36 constrained fetch smoke attempt

Date: May 12, 2026.

Devices attached:

```
5200f354f4fb277f  SM-T390
R52W90AW7EN       SM-T577U
```

SM-T577U successfully started both the fixed-fixture legacy beacon and
the constrained fetch GATT responder:

```json
{"event":"fetch_server_started","accepted":true,"advertising_accepted":true,"responder_peer_id":"meshx-alpha","message_id_hash":"vkXLJgW/Nr4="}
{"event":"fetch_advertising_started","responder_peer_id":"meshx-alpha","message_id_hash":"vkXLJgW/Nr4=","connectable":true}
{"event":"legacy_beacon_advertising_started","beacon_size":22,"message_id_hash":"vkXLJgW/Nr4="}
```

SM-T390 started a one-shot fetch client against the SM-T577U Bluetooth
address, but the Android BLE stack returned `gatt_status=133` before
service discovery:

```json
{"event":"fetch_client_started","device_id":"B4:0B:1D:AB:24:3C","request_id":"fetch-android-1","message_id_hash":"vkXLJgW/Nr4="}
{"event":"fetch_client_connection_failed","gatt_status":133,"state":0}
```

So M36 code and local protocol tests are in place, but this smoke run is
not a completed hardware fetch proof. The next validation pass should
connect by the observer-discovered advertising address, or add a
bounded scan-for-fetch-service step before `connectGatt`.

## M37-M39 constrained GATT fetch hardening rerun

Date: May 12, 2026.

Local log captures:

```
/tmp/meshx-m37-m39-sm-t577u.log
/tmp/meshx-m37-m39-sm-t390.log
```

Build and test gates before hardware rerun:

```
mix test
# all umbrella tests passed

cd apps/meshx_mobile_app/android
./gradlew --no-daemon testDebugUnitTest
./gradlew --no-daemon assembleDebug
# both passed
```

### SM-T577U responder to SM-T390 requester

SM-T577U responder started successfully:

```json
{"event":"fetch_server_started","accepted":true,"advertising_accepted":true,"device_model":"SM-T577U","android_api":33,"adapter_state":"on","message_id_hash":"vkXLJgW/Nr4="}
{"event":"fetch_advertising_started","responder_peer_id":"meshx-alpha","connectable":true,"service_uuid":"8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f2000"}
```

SM-T390 requester used LE transport, reached the connect callback, and
closed the GATT handle after normalized Android status 133:

```json
{"event":"fetch_connect_start","target_address":"B4:0B:1D:AB:24:3C","transport_mode":"transport_le","device_model":"SM-T390","android_api":28}
{"event":"fetch_connect_result","gatt_status":133,"gatt_reason":"android_gatt_error","state_name":"disconnected"}
{"event":"fetch_client_closed","phase":"connect","terminal_event":"connect_failed","reason":"android_gatt_error"}
```

No service discovery, characteristic write, characteristic read, or
full-envelope response occurred.

### SM-T390 responder to SM-T577U requester

SM-T390 responder also started successfully, including legacy beacon and
connectable fetch advertisement:

```json
{"event":"fetch_server_started","accepted":true,"advertising_accepted":true,"device_model":"SM-T390","android_api":28,"adapter_state":"on","message_id_hash":"vkXLJgW/Nr4="}
{"event":"fetch_advertising_started","responder_peer_id":"meshx-alpha","connectable":true,"service_uuid":"8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f2000"}
```

SM-T577U requester likewise failed before service discovery:

```json
{"event":"fetch_connect_start","target_address":"80:20:FD:C2:60:01","transport_mode":"transport_le","device_model":"SM-T577U","android_api":33}
{"event":"fetch_connect_result","gatt_status":133,"gatt_reason":"android_gatt_error","state_name":"disconnected"}
{"event":"fetch_client_closed","phase":"connect","terminal_event":"connect_failed","reason":"android_gatt_error"}
```

### M39 result

M39 is **not** a full fetch success. The hardened diagnostics prove both
devices can start the constrained responder, but both requester
directions fail at Android GATT connection establishment with
`gatt_status=133` before service discovery. No full `MessageEnvelope`
was retrieved or parsed, so the hardware fetch proof remains incomplete.

## M40 standalone GATT interop harness

Date: May 12, 2026.

Purpose: determine whether Android GATT status 133 is caused by MeshX
fetch logic or by the Android/device BLE stack.

Harness:

- Android-only `PlainGattInteropHarness`
- log tag `MeshxGattInterop`
- service UUID `8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f4000`
- characteristic UUID `8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f4001`
- server read payload: base64 `b2s=` (`ok`)
- client write payload: base64 `aGk=` (`hi`)
- no `MessageEnvelope`
- no fetch protocol
- no MeshX planner/ledger/replay involvement
- no legacy beacon logic

Local log captures:

```
/tmp/meshx-m40-sm-t577u.log
/tmp/meshx-m40-sm-t390.log
```

Current May 12, 2026 rerun after waking both devices and dismissing
keyguard:

```
/tmp/meshx-android-m40-current/sm-t577u-responder.log
/tmp/meshx-android-m40-current/sm-t390-requester.log
/tmp/meshx-android-m40-current/sm-t390-responder.log
/tmp/meshx-android-m40-current/sm-t577u-requester.log
```

The current rerun still fails before service discovery with
`gatt_status=133` in both directions.

Current May 13, 2026 rerun from the current tree is archived at:

```
artifacts/local-ble/2026-05-13-sm-t577u-sm-t390/hardware/m40-gatt-interop-rerun/
```

That rerun rebuilt and installed the debug APK on both devices, then repeated
both standalone interop directions. SM-T577U -> SM-T390 failed with
`gatt_status=133` before service discovery, and SM-T390 -> SM-T577U failed
with the same status before service discovery. No characteristic discovery,
write, read, or payload exchange occurred.

Build and test gates:

```
mix test
./gradlew --no-daemon testDebugUnitTest
./gradlew --no-daemon assembleDebug
# all passed
```

### SM-T577U responder to SM-T390 requester

SM-T577U / Android API 33 advertised the standalone service
successfully:

```json
{"event":"interop_advertise_start","service_accepted":true,"advertise_accepted":true,"device_model":"SM-T577U","android_api":33,"adapter_state":"on"}
{"event":"interop_advertising_started","connectable":true,"service_uuid":"8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f4000"}
```

SM-T390 / Android API 28 failed before service discovery:

```json
{"event":"interop_connect_start","target_address":"B4:0B:1D:AB:24:3C","transport_mode":"transport_le","device_model":"SM-T390","android_api":28}
{"event":"interop_connect_result","gatt_status":133,"gatt_reason":"android_gatt_error","state_name":"disconnected"}
{"event":"interop_closed","phase":"connect","terminal_event":"connect_failed","reason":"android_gatt_error"}
```

No characteristic discovery, write, read, or payload exchange occurred.

### SM-T390 responder to SM-T577U requester

SM-T390 / Android API 28 advertised the standalone service successfully:

```json
{"event":"interop_advertise_start","service_accepted":true,"advertise_accepted":true,"device_model":"SM-T390","android_api":28,"adapter_state":"on"}
{"event":"interop_advertising_started","connectable":true,"service_uuid":"8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f4000"}
```

SM-T577U / Android API 33 failed before service discovery:

```json
{"event":"interop_connect_start","target_address":"80:20:FD:C2:60:01","transport_mode":"transport_le","device_model":"SM-T577U","android_api":33}
{"event":"interop_connect_result","gatt_status":133,"gatt_reason":"android_gatt_error","state_name":"disconnected"}
{"event":"interop_closed","phase":"connect","terminal_event":"connect_failed","reason":"android_gatt_error"}
```

### M40 conclusion

M40 result is case **B**: the minimal standalone GATT harness still
fails with Android `gatt_status=133` in both directions before service
discovery. Since this path excludes MessageEnvelope, fetch protocol,
legacy beacon, planner, ledger, replay, and MeshX routing, the failure
is transport/platform-level behavior for the SM-T577U / Android API 33
and SM-T390 / Android API 28 hardware pair, not a MeshX protocol
failure.

## M41 transport decision

GATT fetch is blocked on the current SM-T577U / SM-T390 hardware pair
because both the MeshX constrained fetch path and the standalone M40
interop harness fail with Android `gatt_status=133` before service
discovery.

Current runtime posture:

- GATT fetch is experimental and disabled by default.
- Android emits `fetch_gatt_experimental_warning` when the GATT fetch
  requester path is explicitly invoked on unvalidated hardware.
- Legacy beacon advertisement remains intact.
- Full-envelope advertisement remains intact for capability-proven
  hardware.
- M33-M36 fake/offline fetch tests remain the canonical deterministic
  fetch-contract proof while live GATT transport is blocked.
- M40 standalone GATT interop harness remains available as a diagnostic
  tool.

See `docs/ble_transport_strategy.md` for the transport comparison and
fallback strategy.
