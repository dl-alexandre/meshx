# MeshxMobileApp

Mob-based MeshX mobile app shell.

This app is the mobile product surface. It runs the MeshX runtime inside the
on-device BEAM, renders the control screen with Mob, and delegates platform BLE
work to `MeshxMobileApp.NativeBridge`.

## Status

| Layer | Status | Notes |
| --- | --- | --- |
| Mob app shell | Done | Generated from Mob and compiled inside the umbrella. |
| MeshX runtime startup | Done | `MeshxMobileApp.App` starts `meshx_runtime` and sets a mobile store directory when Mob provides one. |
| Session/UI contract | Done | `MeshxMobileApp.Session` owns scan/advertise/ping state and is covered by ExUnit. |
| Native BLE bridge | Partial | The iOS simulator build links the Swift CoreBluetooth harness through `NativeBridge.IOS`; hardware validation still needs a bridge-linked physical build and valid development profile. |
| Android shell | Debug harness | Gradle project + BLE-permissioned `MainActivity` with explicit debug intents for scan start and M14 test-envelope dispatch. No BEAM boot yet. |
| Android BLE transport | Message scan + advertise | Kotlin scanner/advertiser emit v1 wire-format events, dispatch a real M14 `MessageEnvelope`, and promote MeshX manufacturer-data adverts into canonical `received_message` JSON. Logcat + on-screen sink today; NIF/BEAM sink lands with BEAM-on-Android. No routing, crypto, retries, reconnect, or guaranteed delivery. |

## Local Setup

`mob.exs` is machine-local and ignored by git. Start from the example:

```bash
cp mob.example.exs mob.exs
mix deps.get
mix compile
```

For a native iOS deploy:

```bash
mix deps.get
mix mob.deploy --native
```

> The `mix deps.get` step also applies project-local patches to the
> vendored `mob_dev` / `mob` deps (extra Swift sources for the
> MeshxMobile package, `meshx_ble_nif` registration in the static NIF
> table). The patches live in `patches/` at the repo root and are
> applied by `mix meshx.patch_deps`, wired into the `deps.*` aliases.
> See [CONTRIBUTING.md](CONTRIBUTING.md) for when you'll run into them
> and how to handle upstream drift.
> The upstream replacement path is tracked in
> [docs/upstream_mob_patches.md](../../docs/upstream_mob_patches.md);
> keep the patches until `GenericJam/mob_dev#6` and
> `GenericJam/mob_new#5` are merged, released, and this app has
> migrated to the released extension points.
>
> For Android dev opt-in (route `sendToPeer` through the full MX
> envelope + GATT fetch responder and enable Android scanner-side
> MB-cue -> GATT-fetch resolution instead of the default MB-only path),
> see [CONTRIBUTING.md](CONTRIBUTING.md) § "Android dev opt-in: full MX
> envelopes". Release builds are hard-gated against the flag so it
> cannot accidentally ship.
> To enable only receive-side fetch resolution at runtime, launch Android
> with `--ez meshx_ble_fetch_on_beacon true`; combine it with
> `--ez meshx_ble_selftest_send false` for receive-only selftest captures.

For a physical iPhone or iPad, provision once first:

```bash
mix mob.provision
mix mob.devices
mix meshx.mobile.deploy_device --device <device-udid>
```

The MeshX device task reuses Mob's physical iOS build script and patches in the
MeshX BLE bridge sources before compiling. The M23-M27 delivery ledger includes
an Android-to-macOS CoreBluetooth proof; exact Android-to-Android logcat proof
is still blocked on attaching a second Android BLE device. When two Android
devices are available, first confirm adb readiness.

Before the final run, make sure `adb devices -l` lists both Android
devices as `device`, not `unauthorized` or `offline`. For wireless
debugging, pair/connect the observer first, then re-run `adb devices -l`
and `adb mdns services` so the readiness summary captures the actual
adb and mDNS state.

Then run:

```bash
scripts/android_ble_message_delivery_two_device.sh \
  --preflight-only \
  --wait-for-devices 30 \
  --sender <DEVICE_A_SERIAL> \
  --observer <DEVICE_B_SERIAL> \
  --out-dir /tmp/meshx-android-m26-ready

scripts/android_ble_message_delivery_two_device.sh \
  --wait-for-devices 30 \
  --sender <DEVICE_A_SERIAL> \
  --observer <DEVICE_B_SERIAL> \
  --out-dir /tmp/meshx-android-m26-live
```

If exactly two adb Android devices are ready, the `--sender` and
`--observer` arguments may be omitted and the verifier will use adb
order. Keep explicit serials when more than two devices are visible or
when preserving a specific sender/observer role matters.

The script writes `sender.log`, `observer.log`, `summary.json`,
`summary.md`, `adb-devices.txt`, `adb-mdns-services.txt`, and
`host-usb.txt` for the live run. `--preflight-only` writes readiness
artifacts and exits before install/radio work; it cannot complete M26.
`--wait-for-devices` only waits for adb inventory; the verifier still
requires two distinct Android logcat files before completion.
Live and preflight summaries record all adb inventory rows, including
`unauthorized` or `offline` devices, while only ready `device` rows count
toward the two-device gate. Verify-only summaries use empty adb inventory
fields because no fresh adb query is run. Explicit sender/observer
failures distinguish missing serials from visible-but-not-ready adb rows,
including mixed requests where one serial is absent and another is
unauthorized.
On preflight failures, stderr prints the generated summary paths plus
`preflight_adb_mdns_service_count` and
`preflight_host_usb_android_candidate_count` so missing wireless adb
services or host-visible Android USB candidates are visible immediately.
If a final logcat dump fails, the script keeps the failure text in that
log file and still writes explicit logcat-capture blockers in the
summary.
Live mode also waits for Android Device B's `scan_start_result accepted=true`
before dispatch by default; use `--observer-ready-timeout 0` only when
that readiness wait needs to be skipped for diagnostics. The harness
wakes both devices before radio work and waits `--observer-settle`
seconds after scan readiness so Android does not pause the scan while
the screen is off.
For `--verify-only`, pass `--sender-device-json` and
`--observer-device-json` with each Android's serial, model, Android
release, numeric API level, and `bluetooth_le_feature` value so the
ledger remains complete.
Treat `summary.json`'s `m26_android_to_android_complete` field as the
verifier gate for a captured two-Android log pair: it must be `true`,
`m26_completion_blockers` must be empty, and
`m26_completion_provenance.repo_fixture_log_pair` must be `false` before
the run can count for M26. The helper
`scripts/audit_android_ble_message_delivery_completion.sh <summary.json>`
checks that gate directly, including the `summary_json` path matching
the audited file, an existing `summary_markdown` ledger file, distinct
sender/observer log files, log existence, non-fixture provenance,
required device metadata, live `adb-devices.txt` file proof for both
ready role serials, and re-runs the verifier over the referenced logs
before passing. Device A/B proof events must come from full Android
`adb logcat -d`
timestamp/pid/tid/tag lines, not generic JSON or tag-only lines.
When the audit rejects a parsed summary object, it also echoes captured
summary paths, adb/mDNS/USB inventory log paths (`adb_devices_log`,
`adb_mdns_log`, `host_usb_log`), adb ready/non-ready counts, adb mDNS
service count, and host USB Android-candidate count so blockers are
visible without opening `summary.json`.
Checked-in verifier fixtures, including exact
fixture-content copies outside the repo fixture directory and known
synthetic fixture identities such as the checked-in observer fixture's
fake top-level or raw transport metadata `received_device_id`, are
supporting evidence only and keep the completion gate blocked. See
`docs/android_ble_message_delivery_validation.md` for the current ledger
and blocker artifacts; the latest live-attempt blocker artifact is
`/tmp/meshx-android-m26-live-attempt-latest/summary.json`, which records
one ready adb Android device. The latest readiness recheck artifact is
`/tmp/meshx-android-m26-readiness-current/summary.json`; it records the
same one-device blocker after a 30-second adb wait, zero adb mDNS
services, one host USB Android candidate, and keeps
`m26_android_to_android_complete` false until a second Android observer
is attached.
The latest single-device readiness proofs are
`/tmp/meshx-android-sender-regression-latest.log` for Device A dispatch
and `/tmp/meshx-android-observer-readiness-latest.log` for Android
scan-start; they are supporting evidence only and do not replace the
two-Android logcat pair required for M26.

## Android

The `android/` directory holds a Gradle project that builds the Android debug
harness with the BLE permissions and Kotlin BLE bridge pieces used by the
message-delivery validation. The BEAM runtime is not wired up yet — see the
status table above.

Requirements:

- Android Studio or the standalone Android SDK with platform 34 installed
- `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) exported
- JDK 17

One-time bootstrap (generates the Gradle wrapper checked into `android/`):

```bash
cd apps/meshx_mobile_app/android
gradle wrapper --gradle-version 8.7
```

Build and install on the attached device:

```bash
cd apps/meshx_mobile_app/android
./build_device.sh                  # default device
./build_device.sh <device-serial>  # specific device (sets ANDROID_SERIAL)
```

`adb devices` lists available serials. The script is intentionally thin —
it just calls `./gradlew installDebug`. As the Mob-on-Android runtime
lands, this script will grow to mirror `ios/build_device.sh` (BEAM
cross-compile, OTP bundling, NIF linking).

### Kotlin BLE transport

`android/src/main/java/dev/meshx/mob/ble/` holds the transport layer:

- `BleEvent` — sealed class mirroring `MeshxMobileApp.BLE.BridgeProtocol`'s
  v1 wire format, including canonical `received_message`.
- `BleScanner` — wraps `BluetoothLeScanner`; first sight of a `device_id`
  emits `DeviceDiscovered`, ordinary repeats emit `AdvertisementReceived`,
  and MeshX message advertisements emit `ReceivedMessage` or tagged decode
  `Error`.
- `BleDispatcher` — wraps `BluetoothLeAdvertiser` for the dispatch path,
  validates a complete M14 envelope before radio work, and refuses to
  advertise truncated or non-M14 payloads.
- `BleAdvertiser` — wraps the passive advertiser; failures surface as `Error`
  with closed-taxonomy `kind`.
- `BleBridge` / `RealBleBridge` — facade. `FakeBleBridge` for tests.
- `BleEventSink` — `LogcatEventSink` for `adb logcat -s MeshxBle`,
  `InMemoryEventSink` for unit tests. The production NIF sink lands
  with BEAM-on-Android.
- `BlePermissions` — runtime permission set, API-aware.

The Kotlin layer is transport-only: no routing, gossip, retries,
persistence, crypto, handshake, background service, guaranteed delivery,
large payload fragmentation, ACKs, peer graph mutation, or reconnect
orchestration. Android promotes only tagged MeshX manufacturer-data
advertisements into the same canonical event shape that Elixir's
`BridgeProtocol` decodes for replay and future BEAM delivery.

JVM unit tests:

```bash
cd apps/meshx_mobile_app/android
./gradlew test
```

The Elixir test `test/meshx_mobile_app/ble/android_wire_format_test.exs`
loads JSON fixtures matching Kotlin's emitter output and decodes them
through `MeshxMobileApp.BLE.BridgeProtocol`, proving the wire contract
round-trips across the language boundary.
