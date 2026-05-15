# Local BLE Evidence Bundle: iPhone 13 ↔ SM-T577U (advert-only, on-air)

Run date: May 15, 2026.

This bundle archives the first hardware proof of the iOS advert-only path
for the MeshX local mesh release boundary. It mirrors the prior
Android-only bundles under `2026-05-12-sm-t577u-sm-t390/` and
`2026-05-13-sm-t577u-sm-t390/`, and adds the iPhone leg.

## Devices

| Role | Identifier | Model | OS |
| --- | --- | --- | --- |
| iPhone (sender + observer) | `00008110-0006619A2132801E` (ECID) | iPhone 13 (iPhone14,5, A15) | iOS 26.4.2 |
| Android sender (USB) | `R52W90AW7EN` | Samsung SM-T577U | Android 13 / API 33 |
| Android sender (ambient) | `sender_peer_id_hash=f70806eddc285bcc` | unknown Android | n/a |

The iPhone was running the `dev.meshx.mobile.harness` MeshxMobileHarness
build at commit `fb5afa8` (latest `origin/master` at capture time)
with the new `MessageAdvertisementObserver` MB branch and harness
auto-dispatch flag. The Android SM-T577U was running the shipping
`dev.meshx.mob` app with `BleSelfTest` periodic dispatch active.

## Hardware Evidence

| Directory | Purpose | Outcome |
| --- | --- | --- |
| `hardware/i26-iphone-dispatch/` | iPhone 13 puts MB legacy beacons on air via `MeshxBLEPeripheral.advertiseLegacyBeacon` (new harness `--meshx-auto-beacon` flag). | Passed: 57 contiguous dispatches captured in transcript, 59 total dispatched on-device, ~1.5 s cadence, no errors. |
| `hardware/i26b-android-to-iphone-receive/` | Android-emitted MB legacy beacons decoded byte-for-byte by iPhone 13 harness via the new `MessageAdvertisementObserver` MB branch (`meshxMessageObserverDidObserveLegacyBeacon`). | Passed: 73 beacons captured, 8 distinct `message_id_hash` values, two independent Android peers (`sender_peer_id_hash` `da6e7833…49` and `f70806ed…cc`) decoded with matching `envelope_version=1`, `beacon_version=1`, `payload_kind=TX`. |

The base64 sender hash `2m54M5Qylkk=` reported in Android logcat
(`MeshxBleDispatch.legacy_beacon_advertising_started.sender_peer_id_hash`)
decodes to hex `da6e783394329649` — exactly the
`sender_peer_id_hash` the iPhone harness logged. Cross-platform identity
round-trips.

## Source-of-truth code changes

Bundled landing commit: **`fb5afa8`** (`ble(ios): close cross-platform
receive on advert-only path`).

* `meshx_mobile/Sources/MeshxMobile/MessageAdvertisementObserver.swift`
  — adds the MB legacy beacon parse branch after MX decode declines, and
  the `meshxMessageObserverDidObserveLegacyBeacon` delegate method (with
  default no-op so existing observers compile unchanged).
* `meshx_mobile/Examples/MeshxMobileHarness/MeshxMobileHarness/BLEHarnessModel.swift`
  — adds `import Security`, `--meshx-auto-beacon` flag handling
  (`startAutoBeaconDispatch()` periodic `peripheral.advertiseLegacyBeacon`),
  the new client-side `meshxDidObserveLegacyBeacon` handler, and the new
  observer-side `meshxMessageObserverDidObserveLegacyBeacon` handler.
  Both handlers emit a `legacy_beacon_received` JSON-ish line via
  `print`, captured by `xcrun devicectl device process launch --console`.

## What this bundle does NOT establish

* **iPhone → Android receive.** The Android app's MeshX-level scanner
  was not active in this capture (only `BleSelfTest` dispatch was
  observed). Closing this requires either (a) the shipping Android app
  to reliably start its scanner in the home-screen / session-bring-up
  flow rather than only during selftest, or (b) a directed observer
  harness on Android equivalent to the new iOS harness flags.
* **Full MX envelope receive on iOS production bridge.** The shipping
  iOS app (`MeshxNativeBLEBridge` + `MeshxBLEClient`) already routes MB
  legacy beacons through `meshxDidObserveLegacyBeacon` →
  `meshx_ble_emit_received_message_beacon`, but it does not yet decode
  full `MX` extended-advertising envelopes on the central side. See the
  third iOS gap in `docs/BLE_BRIDGE.md`.

## Operator release note

Allowed wording (unchanged from prior bundle):

> MeshX can show messages seen nearby from passive BLE advertisement
> observations.

This bundle extends the validated claim to include **iOS hardware** as
both sender and observer of the 22-byte MB legacy beacon reference layer.
The reference layer carries `sha256(message_id)[0..8]` and
`sha256(sender_peer_id)[0..8]` only — beacons are unresolved pointers,
not full message delivery.

## Capture methodology

Both legs were exercised at the same time on the same iPhone (the
harness's `--meshx-auto-scan` runs the observer concurrently with
`--meshx-auto-beacon` dispatch). CoreBluetooth suppresses self-discovery,
so the iPhone never sees its own beacons; observer hits in
`i26b-android-to-iphone-receive/observer.log` are entirely from external
Android peers in radio range.

Verifier mechanics: built via `mcp__xcode__BuildProject`, installed via
`xcrun devicectl device install app`, launched via `xcrun devicectl
device process launch --terminate-existing --console …`. Console stdout
was filtered server-side by `grep -E --line-buffered`; representative
streams are archived in this bundle. The full radio-level cadence on the
iPhone was uninterrupted by transcript rate-limiting; some sequence
numbers (`seq=52`, `seq=56`) are missing from `sender.log` only because
the chat-side monitor dropped them, not because the radio missed them.
