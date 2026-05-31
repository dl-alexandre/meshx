# Android BLE Message Delivery Validation (M23-M27)

Status: **M26 Android-to-Android full-envelope proof incomplete;
supporting cross-device hardware proof exists** with Android Device A and
a macOS CoreBluetooth MeshX observer.
Device A emitted a complete 60-byte M14 `MessageEnvelope` in a BLE
extended-advertising scan response. The macOS observer ingested the
advertisement and emitted canonical `received_message` JSON. The emitted
envelope base64 in Android logcat matched the observer's `envelope`
field byte-for-byte. A current two-Android rerun with SM-T577U as sender
and SM-T390 as observer has two ready adb devices and `scan_start_result
accepted=true`, but SM-T390 still does not log canonical
`received_message` for the full-envelope extended advert.

M26B compatibility proof is complete and freshly rerun: Android Device A
emitted a compact 22-byte legacy message beacon, Android Device B
observed it as canonical `received_message_beacon`, and the summary
reports `legacy_beacon_delivery_complete=true` while keeping
`full_envelope_delivery_complete=false`.

## Environment

| Item | Value |
| --- | --- |
| Validation date | 2026-05-11 America/Los_Angeles |
| Latest ledger update | 2026-05-12 America/Los_Angeles; current full-envelope Android-to-Android rerun artifact is `/tmp/mob-android-m26-live-current/summary.json`; current legacy-beacon rerun artifact is `/tmp/mob-android-m26b-legacy-current/summary.json` |
| Host | macOS / Apple Silicon |
| Device A | Samsung SM-T577U / Galaxy Tab Active 3 |
| Device A serial | `R52W90AW7EN` |
| Device A Android | 13, API 33 |
| Supporting observer proof | `DairyBookPro` macOS CoreBluetooth observer app wrapper produced a live canonical `received_message` |
| Non-Android observer candidates also tried | `DairyPhoneDeaux` iOS 26.4.2 USB; `Coding iPad` iOS 26.3 local network |
| M26 Android Device B status | Samsung SM-T390 / Android 9 / API 28 is attached and scans, but does not observe the SM-T577U full-envelope extended advert as canonical `received_message` |
| M26B legacy Device B | Samsung SM-T390 / Android 9 / API 28 |
| M26B artifact | `/tmp/mob-android-m26b-legacy-current/summary.json`; summary reports `legacy_beacon_delivery_complete=true` with no legacy blockers |

Device inventory commands:

```bash
adb devices -l
adb mdns services
adb -s R52W90AW7EN shell getprop ro.product.model
adb -s R52W90AW7EN shell getprop ro.build.version.release
adb -s R52W90AW7EN shell getprop ro.build.version.sdk
xcrun devicectl list devices
system_profiler SPBluetoothDataType
```

Observed:

```text
R52W90AW7EN device usb:1-1 product:gtactive3ue model:SM_T577U device:gtactive3
List of discovered mdns services

SM-T577U
13
33
Coding iPad       Coding-iPad.coredevice.local       39FD8D3A-9CA5-5DEF-AFC0-AA5205511117   unavailable   iPad (9th generation) (iPad12,1)
DairyPhoneDeaux   DairyPhoneDeaux.coredevice.local   1780F216-CB5C-560B-A86F-85D31F79ADEF   connected     iPhone 13 (iPhone14,5)

Bluetooth controller state: On
Nearby/not-connected Bluetooth entries included Coding iPad, DairyPhoneDeaux, TestPad, creamerymini, and testserver.
```

## Payload Shape

The dispatch test envelope is the existing M14 `MessageEnvelope` v1
wire shape:

| Field | Value |
| --- | --- |
| message_id | `000102030405060708090a0b0c0d0e0f` |
| sender_peer_id | `mob-alpha` |
| recipient_peer_id | `mob-beta` |
| created_at | `1700000000000` |
| ttl | `1` |
| payload_type | `TX` |
| payload | `hi` |
| manufacturer CIC | `0xFFFF` development placeholder |
| extended advertisement service UUID | `8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f1000` |
| encoded envelope size | 60 bytes |
| emitted manufacturer data size | 62 bytes |
| full replay scan-record fixture size | 67 bytes |
| minimal possible M14 envelope | 37 bytes |
| legacy manufacturer payload budget | 24 bytes |

Because even the minimal M14 envelope exceeds the legacy manufacturer
payload budget, Android dispatch uses extended advertising when the
adapter reports support. Android's non-legacy scannable advertising
path keeps the primary advertising data empty and carries the complete
M14 manufacturer payload in the scan response. If the envelope exceeds
the reported manufacturer payload budget, the dispatcher returns a
failed/skipped outcome before advertising and never truncates the
envelope.

Encoded emitted envelope:

```text
TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp
```

Encoded replay fixture:

```text
TVgBAAAAAAAAAAAAAAAAAAAAAAEAAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp
```

## Commands Run

```bash
mix test

cd apps/mob_node/android
./gradlew --no-daemon test
./gradlew --no-daemon test installDebug

cd ../../../mob_node
xcrun swift test

cd Examples/Mob.NodeHarness
xcodegen generate
xcodebuild -project Mob.NodeHarness.xcodeproj -scheme Mob.NodeHarness -destination generic/platform=iOS -allowProvisioningUpdates DEVELOPMENT_TEAM=2MP8QWK7R6 CODE_SIGN_STYLE=Automatic build
xcrun devicectl device install app --device 39FD8D3A-9CA5-5DEF-AFC0-AA5205511117 "<DerivedData>/Build/Products/Debug-iphoneos/Mob Mobile Harness.app"
xcrun devicectl device process launch --device 39FD8D3A-9CA5-5DEF-AFC0-AA5205511117 --terminate-existing --console dev.mob.node.harness --mob-auto-scan

cd ../..
xcrun swift build --product MobMessageObserverCLI
open -n -W /tmp/MobMessageObserver.app --args --timeout 45 --exit-after-first --log-file /tmp/mob-mac-observer-proof.log --log-discoveries

adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.BLUETOOTH_SCAN
adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.BLUETOOTH_ADVERTISE
adb -s R52W90AW7EN shell pm grant dev.mob.mob android.permission.BLUETOOTH_CONNECT
adb -s R52W90AW7EN logcat -c
adb -s R52W90AW7EN shell am force-stop dev.mob.mob
adb -s R52W90AW7EN shell am start -n dev.mob.mob/.MainActivity --ez mob_dispatch_test true
adb -s R52W90AW7EN logcat -d -s MobBle:I MobBleDispatch:I AndroidRuntime:E
adb -s R52W90AW7EN logcat -d -s MobBle:I MobBleDispatch:I AndroidRuntime:E > /tmp/mob-android-proof.log
ruby -rjson -e 'android = File.readlines("/tmp/mob-android-proof.log").find { |line| line.include?("advertising_set_started") }; observer = File.readlines("/tmp/mob-mac-observer-proof.log").find { |line| line.include?("received_message") }; android_json = JSON.parse(android[/\{.*\}/]); observer_json = JSON.parse(observer[/\{.*\}/]); puts "payload_match=#{android_json.fetch("payload") == observer_json.fetch("envelope")}"; puts "payload=#{android_json.fetch("payload")}"; puts "received_event=#{observer_json.fetch("event")}"'

# Diagnostic only: keep the same M14 envelope but make the extended
# advertising set connectable/non-scannable to test Apple observer behavior.
adb -s R52W90AW7EN shell am start -n dev.mob.mob/.MainActivity --ez mob_dispatch_test true --ez mob_dispatch_connectable true
```

When a second Android device is available, start the observer without
tapping UI and keep the logs/summaries in one directory:

```bash
scripts/android_ble_message_delivery_two_device.sh \
  --preflight-only \
  --wait-for-devices 30 \
  --sender <DEVICE_A_SERIAL> \
  --observer <DEVICE_B_SERIAL> \
  --out-dir /tmp/mob-android-m26-ready

scripts/android_ble_message_delivery_two_device.sh \
  --wait-for-devices 30 \
  --sender <DEVICE_A_SERIAL> \
  --observer <DEVICE_B_SERIAL> \
  --out-dir /tmp/mob-android-m26-live
```

If exactly two adb devices are attached, the `--sender` / `--observer`
arguments may be omitted and the verifier will use adb order.

```bash
scripts/android_ble_message_delivery_two_device.sh \
  --wait-for-devices 30 \
  --out-dir /tmp/mob-android-m26-live
```

`--wait-for-devices <seconds>` lets the preflight/live command wait for
the required adb inventory before writing a one-device failure artifact;
it does not weaken the completion gate.
Live mode also waits up to `--observer-ready-timeout <seconds>`
(default 10, `0` to skip) after launching Android Device B's scan path for
`scan_start_result` with `accepted: true` before dispatching Device A's
test envelope, and waits `--observer-settle <seconds>` after scan
readiness before dispatch. The harness wakes both devices and attempts to
dismiss keyguard before radio work because SM-T390 reports accepted scans
that are paused by Android when the screen is off. The final completion
gate still comes from the captured
logcat pair, so this readiness wait only reduces timing races; it does
not weaken the required `received_message` proof.
`--preflight-only` runs the same adb inventory, host USB inventory, and
BLE LE checks, writes readiness `summary.json` / `summary.md`, then exits
before install, logcat, scan, or advertise work. It is a readiness check
only: `m26_android_to_android_complete` remains `false` because no radio
evidence was captured; its blockers are the missing sender
`attempt_outcome` / `advertising_set_started`, Android Device B
`scan_start_result` / `received_message`, logcat-capture proof,
derived payload/M14 validation checks, and the absent distinct role-log
proof. The live run writes `sender.log`, `observer.log`,
`summary.json`, `summary.md`, `adb-devices.txt`,
`adb-mdns-services.txt`, and `host-usb.txt` under `--out-dir`, so the
radio proof and attached-device inventory stay in the same artifact
directory. Live summaries parse the captured `adb-devices.txt` into the
same `adb_inventory*` fields used by preflight summaries, while
verify-only summaries set those fields to empty/zero because no fresh
adb inventory is captured. If either final `adb logcat -d` dump fails,
the verifier keeps the log file with the adb failure text, writes
`summary.json` / `summary.md`, and fails through the normal
`m26_completion_blockers` gate instead of losing the artifact. The
completion audit requires live summaries to include ready adb inventory
rows for both sender and observer, and requires the referenced
`adb-devices.txt` file to exist and independently show both serials as
ready `device` rows; verify-only summaries instead rely on explicit
device metadata and log revalidation. The summary records
`sender_logcat_capture_failed`, `observer_logcat_capture_failed`,
`sender_logcat_captured`, and `observer_logcat_captured` so log capture
failures are explicit audit facts rather than inferred only from
missing events.

If fewer than two adb devices are attached, or if explicit `--sender` /
`--observer` serials are not currently attached, the verifier exits
before touching the radio and writes a preflight `summary.json`,
`summary.md`, `adb-devices.txt`, `adb-mdns-services.txt`, and
`host-usb.txt` so the hardware blocker is captured as an audit artifact.
The summary also includes `host_usb_android_candidates` parsed from the
host USB registry when available, which distinguishes "adb sees one
device" from "a second Android-like USB device is connected but not in
adb." Live summaries include the same `adb_devices_log`,
`adb_mdns_log`, `adb_mdns_service_count`, `adb_mdns_services`,
`host_usb_log`, `host_usb_android_candidate_count`, and
`host_usb_android_candidates` fields as preflight summaries when those
inventory logs are captured. When `--out-dir` is omitted, the verifier
creates a timestamped `/tmp/mob-android-m26-*` directory and prints
the generated `preflight_summary` and `preflight_summary_markdown` paths
to stderr.
The preflight summary records both the requested sender/observer
serials, the original verifier command, and the currently attached adb
inventory, including model, Android release/API, and BLE feature
support when adb can query them. It also records the full raw adb
inventory as `adb_inventory`, `adb_inventory_device_count`,
`adb_ready_device_count`, and `adb_nonready_device_count`, so
`unauthorized` / `offline` Android rows are visible even though only
`device` rows count toward the two-ready-device gate. Auto-selection
failures report the ready count plus non-ready adb rows, and explicit
`--sender` / `--observer` failures distinguish missing serials from
serials that are visible but not ready, such as `unauthorized`, and keep
both reasons when a request mixes missing and non-ready devices.
Failure summaries also expose `sender_ble_le_supported` and
`observer_ble_le_supported` in `validation` whenever requested role
devices can be matched, so BLE-capability blockers are machine-readable.
`capture_context.wait_for_devices_sec` records whether the command
waited for the adb inventory before writing the artifact, and
`adb_mdns_service_count` / `adb_mdns_services` expose non-header raw
lines from `adb mdns services` for wireless-debugging discovery
evidence. The generated JSON and Markdown both record
`summary_json` and `summary_markdown` paths so either artifact can point
back to the other.
Preflight failures also print `preflight_adb_mdns_service_count` and
`preflight_host_usb_android_candidate_count` to stderr beside the
generated summary paths, so the immediate terminal output shows whether
wireless adb discovery or host-visible Android USB inventory found
anything beyond the ready adb rows.
If either requested Android device reports `bluetooth_le_feature` other
than `true`, the verifier exits before install/radio work and writes
the same preflight artifacts; in that case `two_android_devices_attached`
remains `true` when the attached inventory contains both devices.
The separate `exactly_two_android_devices_attached` flag records whether
the adb inventory also satisfies the auto-selection path's exact-count
requirement.

To re-check an already captured pair of logs without starting another
radio window. Add `--require-scan-start` when both logs came from
Android devices and Android Device B should contain `scan_start_result`:

```bash
scripts/android_ble_message_delivery_two_device.sh --verify-only \
  --sender <DEVICE_A_SERIAL> \
  --observer <DEVICE_B_SERIAL> \
  --sender-log <OUT_DIR>/sender.log \
  --observer-log <OUT_DIR>/observer.log \
  --summary-json <OUT_DIR>/summary.json \
  --sender-device-json '{"serial":"<DEVICE_A_SERIAL>","model":"<MODEL>","android_release":"<ANDROID>","android_sdk":"<API>","bluetooth_le_feature":"true"}' \
  --observer-device-json '{"serial":"<DEVICE_B_SERIAL>","model":"<MODEL>","android_release":"<ANDROID>","android_sdk":"<API>","bluetooth_le_feature":"true"}'

# The verifier also writes <OUT_DIR>/summary.md for direct ledger paste-in.
scripts/audit_android_ble_message_delivery_completion.sh <OUT_DIR>/summary.json
scripts/test_android_ble_message_delivery_two_device.sh
```

The generated `summary.json` includes `matched_payload`, decoded
`m14_envelope` fields, a `payload_sizes` object,
`m26_android_to_android_complete`, `m26_completion_validation`, and
`m26_completion_blockers`, plus `m26_completion_provenance` with the
verifier mode, live/verify-only booleans, repo-fixture status, and the
real two-Android logcat requirement. `summary.md` includes the same size
data as a payload-size table plus the M26 completion gate, provenance
table, and separate JSON sections for Device A's
dispatched `attempt_outcome`, Device A's `advertising_set_started`, and
Android Device B's `scan_start_result` plus canonical `received_message`.

The verifier accepts a captured Android-to-Android pair only when the
sender log contains a dispatched `attempt_outcome` whose `attempt_id`
matches the `advertising_set_started` callback, the sender
`advertising_set_started.payload_size` matches the decoded envelope byte
length, Android Device B logs `scan_start_result` with `accepted: true`,
Android Device B logs canonical `received_message`, the received event is
internally M14-consistent, the observer raw transport metadata still
identifies a MeshX manufacturer-data advertisement (`company_identifier`
65535, `ad_type` 255, raw `advertisement` containing the
`manufacturer_data`, and manufacturer data carrying the same envelope),
and the sender `payload` equals the observer `envelope`.

M26 remains open until a live Android-to-Android run, or a verify-only
check over real captured Android logcat files, writes a `summary.json`
whose `summary_json` path identifies that audited file, whose
`summary_markdown` path points to an existing ledger artifact, and whose
`m26_completion_validation` object has all of these flags set to `true`:
`sender_attempt_dispatched`, `advertising_set_started`,
`sender_attempt_matches_advertising_set`, `sender_payload_size_matches`,
`sender_logcat_captured`, `observer_logcat_captured`,
`observer_scan_started`, `received_message_logged`,
`observer_m14_consistent`, `observer_mob_routing_metadata`,
`payload_match`, `sender_and_observer_distinct`,
`sender_and_observer_logs_distinct`, `sender_device_metadata_complete`,
`observer_device_metadata_complete`, `require_scan_start`,
`android_logcat_provenance`, and
`not_repo_fixture_log_pair`. The generated
`m26_android_to_android_complete` field
must also be `true`, with an empty `m26_completion_blockers` list. The
sender and observer rows must be two distinct adb serials; the sender
and observer logcat files must be two distinct files, must exist, and
must not be checked-in repo fixtures. Device A/B proof events must come
from full Android `adb logcat -d`
lines with timestamp/pid/tid/tag provenance (`MobBleDispatch`,
`MobBleControl`, and `MobBle`), and `sender_device` /
`observer_device` must record the exact serial, model, Android release,
numeric API level, and BLE LE feature state for each Android role. The
completion audit also rejects known verifier fixture identities,
including the checked-in observer fixture's fake top-level and raw
transport metadata `received_device_id` values.
`m26_completion_provenance` must show either `mode: "live"` or
`mode: "verify_only"` with `repo_fixture_log_pair: false`. The
completion audit rejects copied or renamed completion summaries whose
embedded `summary_json` no longer matches the file being audited, and it
rejects summaries whose referenced `summary_markdown` ledger file is
missing. When the audit rejects a parsed summary object, it echoes the
audited `summary` path, the recorded `summary_markdown` path when
present, and any captured inventory log paths (`adb_devices_log`,
`adb_mdns_log`, `host_usb_log`), `adb_ready_device_count`,
`adb_nonready_device_count`, `adb_mdns_service_count`, and
`host_usb_android_candidate_count` values so blockers can be read
directly from the audit output. The
Android-to-macOS proof is supporting evidence only.

M26 gate coverage:

| M26 requirement | Required verifier evidence |
| --- | --- |
| Device A dispatches the test envelope | Android Device A logcat contains dispatched `attempt_outcome` plus `advertising_set_started`; attempt ID, message ID, target peer, target devices, payload size, and decoded M14 envelope must agree |
| Android Device B scans and logs the advert | Android Device B logcat contains `scan_start_result accepted=true` and canonical `received_message` |
| Capture logcat from both sides | `sender_logcat_captured`, `observer_logcat_captured`, `sender_and_observer_logs_distinct`, and `android_logcat_provenance` must all be true |
| Observed payload becomes unchanged `ReceivedMessage` | `observer_m14_consistent`, `observer_mob_routing_metadata`, and `payload_match` must all be true |
| Hardware proof is not a fixture or one-device shortcut | Distinct serials, complete sender/observer device metadata, `not_repo_fixture_log_pair=true`, existing role logs, and audit revalidation over the referenced logs |

Manual equivalent:

```bash
adb -s <DEVICE_B_SERIAL> shell pm grant dev.mob.mob android.permission.BLUETOOTH_SCAN
adb -s <DEVICE_B_SERIAL> shell input keyevent KEYCODE_WAKEUP
adb -s <DEVICE_B_SERIAL> shell wm dismiss-keyguard
adb -s <DEVICE_B_SERIAL> logcat -c
adb -s <DEVICE_B_SERIAL> shell am force-stop dev.mob.mob
adb -s <DEVICE_B_SERIAL> shell am start -n dev.mob.mob/.MainActivity --ez mob_start_scan true
adb -s <DEVICE_B_SERIAL> logcat -d -s MobBle:I MobBleControl:I AndroidRuntime:E
```

Test results:

```text
mix test
# 509 tests and 11 properties, 0 failures

mix test apps/mob_node/test/mob_node/ble/message_advertisement_test.exs apps/mob_node/test/mob_node/ble/replay_test.exs apps/mob_node/test/mob_node/ble/bridge_protocol_test.exs
# 54 tests, 0 failures

mix test apps/mob_node/test/mob_node/ble/android_wire_format_test.exs
# 4 tests, 0 failures

mix test apps/mob_node/test/mob_node/ble/peer_table_test.exs
# 26 tests, 0 failures

mix format --check-formatted
passed

./gradlew --no-daemon test
BUILD SUCCESSFUL (46 actionable tasks: 5 executed, 41 up-to-date)

./gradlew --no-daemon test installDebug
BUILD SUCCESSFUL
Installed on 1 device.

./gradlew --no-daemon testDebugUnitTest --tests dev.mob.mob.ble.MobMessageAdvertisementTest --tests dev.mob.mob.ble.MobMessageEnvelopeTest --tests dev.mob.mob.ble.BleDispatcherTest --tests dev.mob.mob.ble.BleScannerTest --tests dev.mob.mob.ble.BleEventTest
BUILD SUCCESSFUL

xcrun swift test
23 tests, 0 failures

xcrun swift test --filter MessageAdvertisementTests
5 tests, 0 failures

bash -n scripts/android_ble_message_delivery_two_device.sh scripts/test_android_ble_message_delivery_two_device.sh scripts/audit_android_ble_message_delivery_completion.sh
shellcheck scripts/android_ble_message_delivery_two_device.sh scripts/test_android_ble_message_delivery_two_device.sh scripts/audit_android_ble_message_delivery_completion.sh
scripts/test_android_ble_message_delivery_two_device.sh
android_ble_message_delivery_two_device verifier tests passed
```

## Device A Dispatch Log

The Android activity was launched with the debug dispatch extra because
the tablet was on the lock screen and UI automation could not tap the
button. This path calls the same `BleDispatcher.dispatch(...)` method
as the on-screen "Dispatch test attempt" button.

Original Android-to-macOS proof log after the bounded advertising window
was increased to 5 seconds and the extended advertising set was made
scannable over LE 1M PHY:

```text
05-11 18:26:21.531  7670  7670 I MobBleDispatch: {"v":1,"event":"attempt_outcome","attempt_id":"spike-att-0","target_peer_id":"meshx-beta","kind":"dispatched","reason":null,"adapter":"ble_android","outcome_at_ms":13934660}
05-11 18:26:21.619  7670  7670 I MobBleDispatch: {"v":1,"event":"advertising_set_started","attempt_id":"spike-att-0","payload_size":60,"payload":"TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp","tx_power":-7,"window_ms":5000,"connectable":false,"scannable":true,"data_carrier":"scan_response"}
```

Original proof outcome JSON:

```json
{
  "v": 1,
  "event": "attempt_outcome",
  "attempt_id": "spike-att-0",
  "target_peer_id": "meshx-beta",
  "kind": "dispatched",
  "reason": null,
  "adapter": "ble_android",
  "outcome_at_ms": 13934660
}
```

Current verifier-facing `attempt_outcome` JSON from the refreshed
single-device sender regression, including the M25 provenance fields
required by the two-Android verifier:

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
  "reason": null,
  "adapter": "ble_android",
  "outcome_at_ms": 46484156
}
```

The async callback line proves the Android BLE stack started the
extended advertising set with the complete 60-byte M14 payload:

```json
{
  "v": 1,
  "event": "advertising_set_started",
  "attempt_id": "spike-att-0",
  "payload_size": 60,
  "payload": "TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp",
  "tx_power": -7,
  "window_ms": 5000,
  "connectable": false,
  "scannable": true,
  "data_carrier": "scan_response"
}
```

Latest sender-only regression, saved to
`/tmp/mob-android-sender-regression.log`, revalidated the same
dispatch path while only one Android was attached:

```json
{
  "attempt_id": "spike-att-0",
  "started_attempt_id": "spike-att-0",
  "kind": "dispatched",
  "payload_size": 60,
  "decoded_payload_bytes": 60,
  "payload_size_matches": true,
  "payload": "TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp",
  "data_carrier": "scan_response",
  "scannable": true
}
```

## Non-Android Observer Attempts

### iPad Harness

`Coding iPad` was reachable over CoreDevice local-network transport and
the Swift harness launched with a command-line `--mob-auto-scan`
observer mode. Console output:

```text
MobMessageObserver: scan_requested
MobMessageObserver: state CBManagerState(rawValue: 5)
MobMessageObserver: scan_started
```

No `MobMessageObserver: {"v":1,"event":"received_message",...}` line
appeared during repeated Android dispatch attempts.

### iPhone Harness

`DairyPhoneDeaux` initially launched an older installed harness build,
but the console did not emit the auto-scan observer markers. The current
harness was then rebuilt and installed successfully on the phone:

```text
** BUILD SUCCEEDED **
App installed:
bundleID: dev.mob.node.harness
```

Foreground launch of the fresh build failed because the device was
locked:

```text
Unable to launch dev.mob.node.harness because the device was not, or could not be, unlocked.
```

After unlocking, the fresh harness launched with `--mob-auto-scan`
and reached the same powered-on scan state as the iPad:

```text
MobMessageObserver: scan_requested
MobMessageObserver: state CBManagerState(rawValue: 5)
MobMessageObserver: scan_started
```

An additional diagnostic `--mob-log-discoveries` mode was added to the
harness and installed on the iPhone. It confirmed the iPhone observer
was receiving CoreBluetooth discovery callbacks from many nearby BLE
advertisers, including manufacturer-data and service-UUID advertisements,
while the Android tablet dispatched the 60-byte MeshX envelope. No
`MobMessageObserver: {"v":1,"event":"received_message",...}` line was
observed during that dispatch window.

A quieter `--mob-log-candidate-discoveries` diagnostic was then added
to log only MeshX-looking discoveries. A later relaunch succeeded and
again reached powered-on scan state:

```text
MobMessageObserver: scan_requested
MobMessageObserver: state CBManagerState(rawValue: 5)
MobMessageObserver: scan_started
```

Three Android dispatch windows were triggered while that observer was
active. Android reported `advertising_set_started` for the complete
60-byte payload at `18:16:18`, `18:16:52`, and `18:17:09`. The candidate
observer printed no `candidate_discovery` and no canonical
`received_message` line during those windows.

### macOS Observer

A macOS `.app` wrapper around `MobMessageObserverCLI` was launched so
CoreBluetooth privacy attribution belonged to the app bundle instead of
the terminal. It reached the powered-on scanning state and then emitted
the live canonical message event:

```text
MobMessageObserverCLI: scanning
MobMessageObserverCLI: state CBManagerState(rawValue: 5)
MobMessageObserverCLI: scan_started
MobMessageObserverCLI: discovery device_id=7E8AA64A-59E9-88A4-56E9-52D9127495F3 rssi=-59 local_name= service_uuids=8F4F1201-6F3D-4F9C-9E3B-7F4A4F0F1000 manufacturer_data_len=62
MobMessageObserverCLI: {"v":1,"event":"received_message","message_id":"AAECAwQFBgcICQoLDA0ODw==","sender_peer_id":"meshx-alpha","recipient_peer_id":"meshx-beta","received_device_id":"7E8AA64A-59E9-88A4-56E9-52D9127495F3","received_at":1778549184556,"rssi":-59,"envelope":"TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp","raw_transport_metadata":{"transport":"ble_advertisement","source_event":"advertisement_received","received_device_id":"7E8AA64A-59E9-88A4-56E9-52D9127495F3","advertisement":"//9NWAEAAAECAwQFBgcICQoLDA0ODwAAAYvP5WgAAQttZXNoeC1hbHBoYQptZXNoeC1iZXRhAlRYAAACaGk=","message_payload":"TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp","manufacturer_data":"//9NWAEAAAECAwQFBgcICQoLDA0ODwAAAYvP5WgAAQttZXNoeC1hbHBoYQptZXNoeC1iZXRhAlRYAAACaGk=","company_identifier":65535,"ad_type":255}}
```

The key fix was moving the extended-advertising payload from primary
advertising data into scan response data for the default non-legacy
scannable path. Before that fix, diagnostic mode with
`--log-discoveries` confirmed CoreBluetooth was receiving nearby BLE
advertisements, including a `mob-ipad` advertiser, but it did not
report the Android extended advertisement as a discovery.

The Android dispatcher also has a diagnostic-only
`mob_dispatch_connectable` intent extra that keeps the same 60-byte
M14 envelope but starts the extended advertising set as
connectable/non-scannable. Android accepted and started that radio
window:

```text
05-11 18:21:24.681  7254  7254 I MobBleDispatch: {"v":1,"event":"advertising_set_started","attempt_id":"spike-att-0","payload_size":60,"tx_power":-7,"window_ms":5000,"connectable":true,"scannable":false}
```

The macOS app-bundled observer was active for that diagnostic and wrote
854 discovery lines before timeout. The saved observer log had no
`received_message`, no MeshX service UUID, and no manufacturer-data
length large enough to contain the 60-byte envelope.

### Envelope Equality Proof

The final proof run saved Android logcat to
`/tmp/mob-android-proof.log` and the macOS observer log to
`/tmp/mob-mac-observer-proof.log`. A JSON comparison of Android's
emitted `payload` field with the observer's canonical `envelope` field
returned:

```text
payload_match=true
payload=TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp
received_event=received_message
```

### Android Observer Readiness

The Android scanner now contains the same receive-side promotion as the
Elixir replay path. If a second Android BLE 5 device is attached and
started with the app's "Start scan" control or the `mob_start_scan`
intent extra, a MeshX message scan record is logged directly as
canonical `received_message` JSON on `MobBle`; malformed tagged
message advertisements log a canonical `error` with
`message_advertisement_decode_error` in `detail`.

Validated by JVM tests:

```text
MobMessageAdvertisementTest
BleEventTest
MobMessageEnvelopeTest
```

## Replay Received Event

The hardware capture above proves the live receive path. The replay
fixture below preserves a raw scan payload and proves the same receive
path without hardware:

```jsonl
{"v":1,"event":"advertisement_received","device_id":"AA:BB:CC:DD:EE:01","rssi":-61,"advertisement":"AgEGP////01YAQAAAAAAAAAAAAAAAAAAAAABAAABi8/laAABC21lc2h4LWFscGhhCm1lc2h4LWJldGECVFgAAAJoaQ==","observed_at_ms":12345}
```

Canonical received event produced by replay:

```json
{
  "v": 1,
  "event": "received_message",
  "message_id": "AAAAAAAAAAAAAAAAAAAAAQ==",
  "sender_peer_id": "meshx-alpha",
  "recipient_peer_id": "meshx-beta",
  "received_device_id": "AA:BB:CC:DD:EE:01",
  "received_at": 12345,
  "rssi": -61,
  "envelope": "TVgBAAAAAAAAAAAAAAAAAAAAAAEAAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp",
  "raw_transport_metadata": {
    "transport": "ble_advertisement",
    "source_event": "advertisement_received",
    "received_device_id": "AA:BB:CC:DD:EE:01",
    "advertisement": "AgEGP////01YAQAAAAAAAAAAAAAAAAAAAAABAAABi8/laAABC21lc2h4LWFscGhhCm1lc2h4LWJldGECVFgAAAJoaQ==",
    "message_payload": "TVgBAAAAAAAAAAAAAAAAAAAAAAEAAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp",
    "manufacturer_data": "//9NWAEAAAAAAAAAAAAAAAAAAAAAAQAAAYvP5WgAAQttZXNoeC1hbHBoYQptZXNoeC1iZXRhAlRYAAACaGk=",
    "company_identifier": 65535,
    "ad_type": 255
  }
}
```

Malformed message-advertisement fixture:

```jsonl
{"v":1,"event":"advertisement_received","device_id":"AA:BB:CC:DD:EE:02","rssi":-70,"advertisement":"AgEGCf///01YAQABAgM=","observed_at_ms":12346}
```

Replay output is a canonical bridge error whose detail contains the
tagged decode reason:

```text
{:message_advertisement_decode_error, :truncated_envelope}
```

## Checklist

| Requirement | Status | Evidence |
| --- | --- | --- |
| Recognize MeshX message advertisements | Done offline | Elixir `MessageAdvertisement.decode/1`; Android `MobMessageAdvertisement.decodeScanRecord(...)`; bridge/Kotlin tests |
| Parse only M14 `MessageEnvelope` | Done offline | Elixir parser delegates to `MessageEnvelope.parse/1`; Android scanner uses `MobMessageEnvelope.parse(...)`; Kotlin validates M14 before advertising |
| Malformed message adverts produce tagged errors | Done offline | `malformed_message_advertisement.jsonl` replay test; Elixir and Android parser tests cover truncated M14 envelopes, truncated AD structures already identifiable as MeshX message advertisements, and first-entry behavior when a later truncated structure follows a valid MeshX message; Swift observer error JSON is structured and escaping-tested |
| Preserve raw payload in capture/replay fixtures | Done offline | `message_advertisement.jsonl` keeps raw `advertisement`; `ReceivedMessage.raw_transport_metadata` keeps `advertisement`, `message_payload`, `manufacturer_data`, company ID, and AD type |
| Canonical `ReceivedMessage` event struct | Done offline | `Mob.Node.BLE.Events.ReceivedMessage` |
| Encode/decode fixtures and replay tests | Done offline | `received_message.json` preserves `advertisement`, `message_payload`, `manufacturer_data`, company ID, and AD type; `message_advertisement.jsonl`, replay tests, and bridge encode/decode round-trip with full BLE metadata; direct `received_message` wire maps reject missing M24 fields including `envelope`, invalid M24 field types including non-binary/non-struct `envelope`, or non-map `raw_transport_metadata` |
| Android advertises real encoded M14 envelope | Hardware-validated on Device A | Android dispatch test uses 60-byte M14 envelope; logcat outcome was `dispatched`; async callback logs structured `advertising_set_started` JSON with `payload_size: 60`; verifier checks `payload_size` against decoded payload bytes |
| Preserve `AttemptOutcome` contract | Done | Dispatch outcome emits `attempt_id`, base64 `message_id`, `target_peer_id`, `target_device_ids`, `kind`, `reason`, `adapter`, and `outcome_at_ms`; Android tests parse the emitted JSON detail with escaped attempt/peer IDs plus array/base64 provenance |
| No truncation of invalid envelope | Done in code/tests | Dispatcher parses M14 and rejects non-M14 payloads, caller `message_id` mismatches, and non-broadcast target-peer mismatches before radio work; it also uses `payloadBudgetFailure(...)` before advertising. Android tests cover those invalid-attempt paths, unsupported extended advertising, too-small extended budgets, and accepted full-envelope budgets, including an available fake radio that records zero advertiser start calls for invalid, unsupported, or oversized attempts; two-device verifier rejects sender logs whose `attempt_outcome.message_id` or target provenance no longer matches the advertised M14 payload |
| Supporting observer scans and logs received advertisement | Supporting hardware proof only | macOS `MobMessageObserverCLI` app wrapper logged the MeshX service UUID, manufacturer data length 62, and canonical `received_message`; M26 still requires the same observer proof from a second Android `adb logcat` stream |
| Emitted envelope parses into `ReceivedMessage` unchanged | Supporting hardware proof only | Android `advertising_set_started.payload` equals the macOS observer `received_message.envelope`; comparison returned `payload_match=true`; bridge decode rejects direct `received_message` events whose top-level message ID or peer IDs disagree with the embedded envelope; M26 completion still requires the Android-to-Android verifier gate |
| Capture logcat from both sides | Open | Device A logcat was saved to `/tmp/mob-android-proof.log`; supporting observer proof is `/tmp/mob-mac-observer-proof.log`, not Android logcat; only `R52W90AW7EN` was attached over adb; `scripts/android_ble_message_delivery_two_device.sh` is ready to run when a second Android is attached and records Android Device B `scan_start_result` in its summary |

## Completion Audit Snapshot

M23-M25 and the replay path are covered by code, tests, and fixtures.
The Android-to-macOS hardware run is supporting cross-device payload
evidence, but the objective is not fully complete until the explicit
M26 Android-to-Android logcat capture succeeds.

Prompt-to-artifact audit:

| Objective item | Artifact / command inspected | Audit result |
| --- | --- | --- |
| M23 receive parser | `apps/mob_node/lib/mob_node/ble/message_advertisement.ex`; `apps/mob_node/android/src/main/java/dev/mob/mob/ble/MobMessageAdvertisement.kt`; `mob_node/Sources/Mob.Node/MessageAdvertisement.swift` | Implemented for MeshX manufacturer-data adverts, M14-only parsing, non-message pass-through, and tagged malformed errors |
| M23 malformed-advert errors | `mix test apps/mob_node/test/mob_node/ble/message_advertisement_test.exs`; `xcrun swift test --filter MessageAdvertisementTests`; `MobMessageAdvertisementTest.kt` | Elixir targeted suite passed with 5 tests and Swift targeted suite passed with 5 tests; both cover truncated tagged message payloads as tagged decode errors, and Elixir/Android tests cover truncated AD structures plus first-valid-entry behavior |
| M24 `ReceivedMessage` contract | `apps/mob_node/lib/mob_node/ble/events/received_message.ex`; `apps/mob_node/lib/mob_node/ble/bridge_protocol.ex`; `BleEvent.ReceivedMessage`; Swift `ReceivedMessageEvent`; `received_message.json`; targeted bridge/wire-format tests | All required fields are present, including `envelope` and `raw_transport_metadata`; bridge decode validates top-level IDs against the embedded envelope and rejects direct `received_message` wire maps with missing M24 fields, invalid M24 field types, or non-map `raw_transport_metadata`; Android wire-format fixture verifies advertisement, message payload, manufacturer data, company ID, AD type, and envelope equality; Android `BleEventTest` and Swift `MessageAdvertisementTests` assert every canonical `received_message` JSON field plus every raw metadata field |
| M24 replay fixtures | `message_advertisement.jsonl`; `malformed_message_advertisement.jsonl`; targeted `mix test` receive/replay/bridge suite | Replay reproduces canonical `received_message` and tagged decode-error paths without hardware |
| M25 Android dispatch | `BleDispatcher.dispatch(...)`; `MobMessageEnvelope.buildV1(...)`; `BleDispatcherTest.kt`; `scripts/android_ble_message_delivery_two_device.sh`; `scripts/test_android_ble_message_delivery_two_device.sh` | Dispatch validates the existing M14 envelope shape before radio work, rejects attempts whose caller `messageId` disagrees with the envelope or whose non-broadcast envelope recipient disagrees with `targetPeerId`, preserves verifier-facing `attempt_outcome` provenance (`attempt_id`, base64 `message_id`, `target_peer_id`, `target_device_ids`, `kind`, `reason`, `adapter`, `outcome_at_ms`), logs `advertising_set_started`, and refuses unsupported or over-budget payloads without truncation; `BleDispatcherTest` covers non-M14 payloads, message-id mismatches, and target-peer mismatches returning `INVALID_ATTEMPT` before radio use, `advertising_set_started` JSON preserving `payload_size` / base64 `payload` / `data_carrier`, unsupported extended advertising returning `SKIPPED`, too-small extended budgets returning `FAILED`, accepted complete-envelope budgets, and zero advertiser start calls on invalid/unsupported/oversized attempts with an enabled fake radio; verifier fixture tests reject missing or mismatched sender `attempt_outcome.message_id`, mismatched `target_peer_id`, and missing/invalid `target_device_ids` |
| Strict non-goals: passive receive only | `apps/mob_node/lib/mob_node/ble/events/received_message.ex`; `apps/mob_node/lib/mob_node/session.ex`; `apps/mob_node/lib/mob_node/ble/replay.ex`; `apps/mob_node/android/src/main/java/dev/mob/mob/ble/BleScanner.kt` | `ReceivedMessage` is documented as passive BLE-advertisement ingress; the session handler only calls `track/2`, appends a bounded in-memory UI event via `record/3`, and broadcasts the snapshot to current subscribers; replay only feeds canonical adapter messages from fixture files; and the Android scanner only promotes scan records into sink events. No File/Repo/ETS writes, routing, gossip, retries, persistence, crypto, handshake, background service, guaranteed-delivery, fragmentation, or ACK behavior was added to the receive path |
| Strict non-goals: no Android background service | `apps/mob_node/android/AndroidManifest.xml`; merged and packaged debug/release manifest intermediates under `apps/mob_node/android/build/intermediates/`; `rg -n '<service|foregroundServiceType|FOREGROUND_SERVICE|WorkManager|JobScheduler|AlarmManager|startForeground|startService|bindService' apps/mob_node/android/build apps/mob_node/android/AndroidManifest.xml apps/mob_node/android/src/main/java apps/mob_node/android/src/test/java`; manifest-merger output for `androidx.profileinstaller.ProfileInstallReceiver` | Source manifest declares only `MainActivity` plus BLE permissions/features; merged and packaged manifest intermediates add AndroidX ProfileInstaller's initializer/provider and `ProfileInstallReceiver` from `androidx.profileinstaller:profileinstaller:1.3.0`, guarded by `android.permission.DUMP`. No Android service, foreground-service permission/type, WorkManager, JobScheduler, AlarmManager, `startForeground`, `startService`, or `bindService` usage exists in source, tests, merged manifest output, packaged manifest intermediates, or Android build outputs |
| Strict non-goal: no peer graph mutation | `apps/mob_node/lib/mob_node/ble/peer_table.ex`; `apps/mob_node/test/mob_node/ble/peer_table_test.exs`; `mix test apps/mob_node/test/mob_node/ble/peer_table_test.exs` | `ReceivedMessage` is treated as a non-advertisement event for peer-table purposes; targeted PeerTable suite passed with 26 tests, including `ReceivedMessage does not create or mutate peer graph entries` |
| M26 live hardware proof | `/tmp/mob-android-proof.log`; `/tmp/mob-mac-observer-proof.log`; `/tmp/mob-android-sender-regression-latest.log`; `scripts/android_ble_message_delivery_two_device.sh --verify-only ...` | The Android-to-macOS proof remains supporting payload evidence: the older Device A sender payload matched the macOS observer `received_message.envelope`, and the observer event preserved the same 60-byte envelope in `raw_transport_metadata.message_payload`. A newer single-device sender regression refreshed `/tmp/mob-android-sender-regression-latest.log` with current `attempt_outcome.message_id` / `target_device_ids` provenance and a 60-byte `advertising_set_started.payload`. This still is not the requested two-Android logcat pair because the observer side is macOS, not Android logcat, and no second adb Android is attached |
| M26 two-Android verifier gate | `scripts/android_ble_message_delivery_two_device.sh`; `scripts/audit_android_ble_message_delivery_completion.sh`; `scripts/test_android_ble_message_delivery_two_device.sh`; `bash -n ...`; `shellcheck ...`; `/tmp/mob-android-m26-positive-fixture-summary.json`; `/tmp/mob-android-m26-live-attempt-latest/summary.json`; `/tmp/mob-android-m26-same-device-preflight/summary.json` | Positive fixture summary uses synthetic `android-a` / `android-b` serials and records command evidence, payload sizes, decoded M14 fields, Device A/B event JSON, provenance, and all core validation flags true, but remains `m26_android_to_android_complete=false` with `not_repo_fixture_log_pair` as a blocker because checked-in fixtures are supporting evidence only; verifier separately proves a non-fixture captured log pair can satisfy the completion gate with verify-only provenance, Android logcat timestamp/pid/tid/tag provenance, distinct sender/observer log files, and explicit device model/numeric API/BLE metadata, proves `--preflight-only` records two-device/BLE/USB/mDNS readiness without radio evidence and keeps the expected radio-evidence blockers, proves `--wait-for-devices` handles both a delayed second-device readiness transition and a one-device timeout artifact without weakening the gate, proves one-device/default-output/missing-device/same-device/BLE-missing preflight failures print `preflight_adb_mdns_service_count` and `preflight_host_usb_android_candidate_count` beside the generated summary paths, proves a simulated live run waits for Device B scan readiness, captures `adb-devices.txt`, parsed `adb mdns services`, `host-usb.txt`, and parsed host USB Android candidates alongside the radio logs, proves final logcat dump failures still produce log files and a blocker summary, and proves a payload-matching supporting proof without Android `scan_start_result`, Android observer metadata, or Android logcat provenance remains incomplete with `observer_scan_started`, `observer_device_metadata_complete`, `require_scan_start`, and `android_logcat_provenance` blockers; the audit script exits 0 only for M26-complete summaries, requires distinct sender/observer log files, exact sender/observer device metadata, re-runs the two-device verifier over the referenced logs before passing, and fails for repo fixtures, exact fixture-content copies outside the fixture directory, known synthetic fixture identities including top-level and raw metadata `received_device_id`, missing device metadata, forged fixture-log summaries, forged bogus-log summaries, missing-log summaries, same-log and symlink-same-log summaries, contradictory `m26_completion_provenance.live_run` / `verify_only` values for the recorded mode, one-device preflight, non-Android-logcat proof lines, tag-only fake logcat lines, and supporting-only proofs; rejects one-device, missing-device, same-serial, BLE-missing, missing-log, same-log, symlink-same-log, mismatched-envelope, missing or mismatched attempt message IDs, mismatched sender target peer, missing sender target-device lists, bad-metadata, mismatched raw metadata identity, and inconsistent-event cases; preflight and live summaries include `adb-mdns-services.txt`, parsed `adb_mdns_services`, `host-usb.txt`, and parsed `host_usb_android_candidates`; verifier scripts pass shell syntax and ShellCheck; live run is blocked because only one adb Android is attached |
| M27 artifact integrity | `/tmp/mob-android-proof.log`; `/tmp/mob-mac-observer-proof.log`; `/tmp/mob-android-m26-live-attempt-latest/summary.json`; `/tmp/mob-android-m26-readiness-current/summary.json`; `/tmp/mob-android-m26-same-device-preflight/summary.json`; `/tmp/mob-android-sender-regression-latest.log`; `/tmp/mob-android-observer-readiness-latest.log` | All ledger-referenced proof/preflight artifacts exist and parse; current live attempt records one attached Android, the `--wait-for-devices 15` command evidence, `m26_completion_provenance.mode=preflight_failed`, `host_usb_android_candidate_count=1`, and `m26_android_to_android_complete=false`; latest readiness recheck records the same one-device blocker after `--wait-for-devices 30`, `adb_ready_device_count=1`, `adb_nonready_device_count=0`, `adb_mdns_service_count=0`, `host_usb_android_candidate_count=1`, and `R52W90AW7EN` as the only ready Android with model `SM-T577U`, Android `13`, API `33`, and BLE LE support `true`; same-device preflight records `--sender and --observer must be different adb devices`; latest sender regression payload decodes to the logged 60-byte `scan_response` payload and its `attempt_outcome.message_id` matches the M14 envelope; observer-readiness log records `scan_start_result` with `accepted=true` |
| M27 ledger | This document; generated `summary.json` / `summary.md` artifacts | Documents devices, API levels, commands, logs, payload sizes, outcome JSON, received-event JSON, limitations, and the open M26 hardware item |

| Milestone | Concrete artifact | Audit result |
| --- | --- | --- |
| M23 receive parser | Elixir `MessageAdvertisement.decode/1`; Android `MobMessageAdvertisement.decodeScanRecord(...)`; Swift `MessageAdvertisement.decode(...)` | Covers MeshX manufacturer-data recognition, M14-only parsing, ignored ordinary adverts, and tagged malformed errors |
| M24 event contract | Elixir `ReceivedMessage`; `BridgeProtocol.decode/1`; Kotlin `BleEvent.ReceivedMessage`; Swift `ReceivedMessageEvent`; fixtures `received_message.json`, `message_advertisement.jsonl`, `malformed_message_advertisement.jsonl` | Covers all required event fields and raw transport metadata; direct `received_message` decode rejects missing M24 fields, invalid M24 field types, mismatched top-level IDs, and invalid raw metadata |
| M25 Android dispatch | `BleDispatcher.dispatch(...)` validates M14, checks budget via `payloadBudgetFailure(...)`, emits structured `AttemptOutcome` and `advertising_set_started` JSON, logs `advertising_set_started.payload` | Covers valid M14 advertising and no-truncation behavior; `BleDispatcherTest` verifies non-M14 input, caller/envelope message-id mismatch, and target-peer mismatch fail as `INVALID_ATTEMPT`, `attempt_outcome` preserves base64 `message_id` and `target_device_ids`, `advertising_set_started` preserves `payload_size`, base64 `payload`, and `data_carrier`, unsupported extended advertising is `SKIPPED`, too-small extended budgets are `FAILED`, complete-envelope budgets pass, invalid/unsupported/oversized attempts make zero advertiser start calls with an enabled fake radio, and escaped string fields remain parseable in verifier-facing log lines |
| M26 Device A proof | `/tmp/mob-android-proof.log` | Covers Android Device A dispatch logcat and complete 60-byte envelope payload |
| Supporting observer proof | `/tmp/mob-mac-observer-proof.log` | Covers a MeshX-capable macOS observer ingesting the advert as canonical `received_message`, but not Android logcat |
| M26 Android-to-Android proof | `scripts/android_ble_message_delivery_two_device.sh`; `scripts/audit_android_ble_message_delivery_completion.sh`; `scripts/test_android_ble_message_delivery_two_device.sh` | Not run to completion because only one Android adb device is attached; live mode records both devices' model/release/API/BLE feature, command sequence, completion provenance, parsed adb inventory, and a structured validation checklist in `summary.json` and ledger-ready `summary.md`, requires Device A `attempt_outcome` dispatched with the same `attempt_id` as `advertising_set_started`, `attempt_outcome.message_id` matching the advertised M14 envelope, `attempt_outcome.target_peer_id` matching the envelope recipient, valid `attempt_outcome.target_device_ids`, Device A `payload_size` matching decoded envelope bytes, Device B `scan_start_result`, Device B MeshX manufacturer-data metadata, Android logcat timestamp/pid/tid/tag provenance, successful final logcat capture from both roles, distinct role log files, ready adb inventory rows for both roles, and both devices reporting BLE LE support; preflight failure mode records the original verifier command, attached ready-device inventory, full adb inventory including non-ready rows, mDNS output, host USB Android-candidate inventory, and `m26_completion_provenance.mode=preflight_failed` when fewer than two devices are available, requested serials are absent, the same serial is supplied for sender and observer, or a requested device lacks BLE LE support, including a default timestamped `/tmp/mob-android-m26-*` artifact directory when `--out-dir` is omitted and stderr diagnostics for mDNS service count plus host USB Android-candidate count; `--preflight-only` records a two-device readiness summary after distinct-device and BLE checks but exits before install or radio work; `--wait-for-devices` can wait for a just-attached second adb device, and fixture tests cover both the successful wait transition and timeout artifact; fixture test proves accepted distinct log pairs pass, same underlying role-log file fails, including symlink aliases, verify-only keeps `--require-scan-start` in command evidence and uses empty adb inventory fields, live summaries missing ready adb inventory for either role fail audit, one-device preflight writes failure artifacts with both explicit and default output directories, non-ready adb rows such as `unauthorized` are preserved in `adb_inventory` but do not satisfy the two-ready-device gate, auto-selection reports ready/total/non-ready adb counts, explicit requested-device failures distinguish absent serials from visible-but-not-ready serials and preserve mixed missing/non-ready reasons, missing explicit observer preflight writes failure artifacts, same sender/observer serials fail before radio work, BLE-missing preflight writes failure artifacts with `sender_ble_le_supported` / `observer_ble_le_supported` validation flags, readiness-only preflight writes no sender/observer logs, sets `sender_and_observer_logs_distinct=false`, and remains M26-incomplete, final logcat dump failures still produce log files plus explicit `sender_logcat_captured` / `observer_logcat_captured` blockers, stale or shortened completion-validation schemas fail audit, contradictory `*_logcat_capture_failed=true` summaries fail audit, missing dispatch outcomes fail, mismatched sender attempt IDs fail, missing or mismatched sender attempt message IDs fail, mismatched sender target peers fail, missing sender target-device lists fail, bad sender payload sizes fail, missing scan-start pairs fail, mismatched envelopes fail, wrong company identifiers fail, detached manufacturer-data metadata fails, non-Android-logcat proof lines fail the completion gate, tag-only fake logcat lines fail the completion gate, and internally inconsistent `received_message` events fail |
| M27 ledger | This document | Covers devices, API level, commands, logs, payload sizes, JSON examples, limitations, and the open hardware item |

Latest single-device Android observer readiness check:

```text
05-12 03:33:59.439 21049 21049 I MobBleControl: {"v":1,"event":"scan_start_result","accepted":true}
```

Latest single-device sender regression:

```text
05-12 03:28:51.033 20628 20628 I MobBleDispatch: {"v":1,"event":"attempt_outcome","attempt_id":"spike-att-0","message_id":"AAECAwQFBgcICQoLDA0ODw==","target_peer_id":"meshx-beta","target_device_ids":["AA:BB:CC:DD:EE:FF"],"kind":"dispatched","reason":null,"adapter":"ble_android","outcome_at_ms":46484156}
05-12 03:28:51.123 20628 20628 I MobBleDispatch: {"v":1,"event":"advertising_set_started","attempt_id":"spike-att-0","payload_size":60,"payload":"TVgBAAABAgMEBQYHCAkKCwwNDg8AAAGLz+VoAAELbWVzaHgtYWxwaGEKbWVzaHgtYmV0YQJUWAAAAmhp","tx_power":-7,"window_ms":5000,"connectable":false,"scannable":true,"data_carrier":"scan_response"}
```

The refreshed sender log is saved at
`/tmp/mob-android-sender-regression-latest.log`; the refreshed
observer-readiness log is saved at
`/tmp/mob-android-observer-readiness-latest.log`. A refreshed
verify-only cross-check against the saved macOS observer proof wrote
`/tmp/mob-verify-latest-sender-mac-observer-summary.json` and
`/tmp/mob-verify-latest-sender-mac-observer-summary.md` with
`payload_match=true`, `sender_payload_size_matches=true`,
`validation.received_message_logged=true`,
`observer_m14_consistent=true`, and
`observer_mob_routing_metadata=true`. The same summary keeps
`m26_android_to_android_complete=false` with blockers
`observer_scan_started`, `sender_device_metadata_complete`,
`observer_device_metadata_complete`, `require_scan_start`, and
`android_logcat_provenance`; the M26 completion gate still requires a
fresh two-Android logcat pair.

Latest two-Android verifier blocker:

```text
scripts/android_ble_message_delivery_two_device.sh --preflight-only --wait-for-devices 30 --out-dir /tmp/mob-android-m26-readiness-current
expected exactly two attached adb devices, found 1
List of devices attached
R52W90AW7EN            device usb:1-1 product:gtactive3ue model:SM_T577U device:gtactive3 transport_id:1

preflight_summary=/tmp/mob-android-m26-readiness-current/summary.json
preflight_summary_markdown=/tmp/mob-android-m26-readiness-current/summary.md
preflight_adb_mdns_service_count=0
preflight_host_usb_android_candidate_count=1

scripts/audit_android_ble_message_delivery_completion.sh /tmp/mob-android-m26-readiness-current/summary.json
m26_complete=false
reason=m26_android_to_android_complete is not true
blockers=expected exactly two attached adb devices, found 1
summary=/tmp/mob-android-m26-readiness-current/summary.json
summary_markdown=/tmp/mob-android-m26-readiness-current/summary.md
adb_devices_log=/tmp/mob-android-m26-readiness-current/adb-devices.txt
adb_mdns_log=/tmp/mob-android-m26-readiness-current/adb-mdns-services.txt
host_usb_log=/tmp/mob-android-m26-readiness-current/host-usb.txt
adb_ready_device_count=1
adb_nonready_device_count=0
adb_mdns_service_count=0
host_usb_android_candidate_count=1
```

The generated readiness ledger at
`/tmp/mob-android-m26-readiness-current/summary.md` also records the
only attached Android as serial `R52W90AW7EN`, model `SM-T577U`,
Android `13` / API `33`, BLE LE support `true`, and host USB product
`SAMSUNG_Android`.

Latest implementation-surface regression checks, run 2026-05-12:

```bash
mix test
# 509 tests and 11 properties, 0 failures

mix test apps/mob_node/test/mob_node/ble/message_advertisement_test.exs apps/mob_node/test/mob_node/ble/android_wire_format_test.exs apps/mob_node/test/mob_node/ble/bridge_protocol_test.exs apps/mob_node/test/mob_node/ble/replay_test.exs apps/mob_node/test/mob_node/ble/peer_table_test.exs
# 84 tests, 0 failures

cd apps/mob_node/android && ./gradlew --no-daemon test
# BUILD SUCCESSFUL

cd apps/mob_node/android && ./gradlew --no-daemon testDebugUnitTest \
  --tests 'dev.mob.mob.ble.MobMessageAdvertisementTest' \
  --tests 'dev.mob.mob.ble.MobMessageEnvelopeTest' \
  --tests 'dev.mob.mob.ble.BleDispatcherTest' \
  --tests 'dev.mob.mob.ble.BleScannerTest' \
  --tests 'dev.mob.mob.ble.BleEventTest'
# BUILD SUCCESSFUL; use testDebugUnitTest for class filters in this Gradle setup

cd mob_node && xcrun swift test --filter MessageAdvertisementTests
# 5 tests, 0 failures

bash -n scripts/android_ble_message_delivery_two_device.sh scripts/test_android_ble_message_delivery_two_device.sh scripts/audit_android_ble_message_delivery_completion.sh

shellcheck scripts/android_ble_message_delivery_two_device.sh scripts/test_android_ble_message_delivery_two_device.sh scripts/audit_android_ble_message_delivery_completion.sh

scripts/test_android_ble_message_delivery_two_device.sh
# android_ble_message_delivery_two_device verifier tests passed
```

Same-serial smoke preflight also writes structured artifacts at
`/tmp/mob-android-m26-same-device-preflight/summary.json` and
`/tmp/mob-android-m26-same-device-preflight/summary.md`. The current
summary records `requested_sender_serial=R52W90AW7EN`,
`requested_observer_serial=R52W90AW7EN`, and
`error=--sender and --observer must be different adb devices`,
confirming one adb device cannot stand in for both sender and observer.

Latest post-restart discovery check, after `adb kill-server` /
`adb start-server`, still found only the Samsung tablet over USB and no
wireless debugging services:

```text
adb devices -l
R52W90AW7EN device usb:1-1 product:gtactive3ue model:SM_T577U device:gtactive3

adb mdns services
List of discovered mdns services

latest adb inventory watch
adb track-devices
R52W90AW7EN device
# no device-change events appeared during the 10s watch window

host USB registry
SAMSUNG_Android serial R52W90AW7EN
# no second Android-like USB device; other USB entries were hub, LAN, and camera devices

latest lower-level USB recheck
ioreg -p IOUSB -l -w0
# Android-like USB match: SAMSUNG_Android serial R52W90AW7EN; UsbExclusiveOwner=adb
# no second Android-like USB candidate was visible to the host

latest Device A sender readiness check
adb -s R52W90AW7EN shell pm list packages dev.mob.mob
adb -s R52W90AW7EN shell pm list features
adb -s R52W90AW7EN shell dumpsys package dev.mob.mob
# package dev.mob.mob is installed; android.hardware.bluetooth_le is present
# BLUETOOTH_SCAN, BLUETOOTH_ADVERTISE, and BLUETOOTH_CONNECT are granted

dns-sd -B _adb-tls-connect._tcp local
dns-sd -B _adb-tls-pairing._tcp local
# no services appeared during the watch window
```

## Limitations

- The successful supporting observer proof used the macOS CoreBluetooth
  observer rather than a second Android device, so there is still no
  Android-to-Android logcat pair.
- Earlier Apple observer attempts did not surface the Android extended
  advertisement while payload data was placed in primary advertising
  data. Moving the payload to the scan response fixed the macOS
  observer path.
- The connected iPhone is visible to Xcode and the harness installed,
  but several foreground relaunch attempts were denied while the device
  was locked. It was not revalidated after the Android scan-response
  fix.
- The Android tablet was locked during this pass; dispatch was triggered
  through an explicit debug intent extra rather than by tapping the UI.
- No routing, gossip, retries, persistence, crypto, handshake, background
  service, guaranteed delivery, large payload fragmentation, ACKs, or
  peer graph mutation was added to the M23-M27 BLE advertisement delivery
  path. Pre-existing Swift core modules such as `Frame`, `Fragment`,
  `Noise`, and `SecureSession` remain outside this proof and are not used
  by the message advertisement observer/dispatcher path validated here.
