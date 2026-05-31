# Android Fetch / iOS Responder Rerun

Run date: 2026-05-17.

Devices:

- Android requester: Samsung SM-T577U, Android 13 / API 33, adb serial `R52W90AW7EN`.
- iOS responder: Coding iPad, iPad 9th generation (`iPad12,1`), iOS 26.5, CoreDevice id `39FD8D3A-9CA5-5DEF-AFC0-AA5205511117`.

Harness:

- iOS: `dev.mob.node.harness --mob-auto-beacon`.
- Android: `dev.mob.mob.ble.IOSResponderFetchSmokeTest`.

First rerun:

- Files: `ipad-responder.log`, `android-instrumentation.log`.
- Outcome: failed because the responder returned `not_found`.
- Root cause: the Android smoke test could fall back from the current scan-record local name to Android's cached `BluetoothDevice.name`, which may retain a stale `mx<message_hash>` from an earlier iOS advertising session.

Second rerun after updating the Android smoke test to use only `ScanRecord.deviceName`:

- Files: `ipad-responder-2.log`, `android-instrumentation-2.log`, `android-logcat-2.log`.
- Outcome: passed.
- JUnit result: `OK (1 test)`.
- iOS responder evidence: `fetch_responder_served request_id=c167826e-52d4-4d6f-99cf-a7163ae54b79 status=0`.
- Android GATT evidence:
  - `fetch_connect_result` `gatt_status=0`.
  - `fetch_service_discovery_result` `gatt_status=0`, `service_found=true`.
  - `fetch_characteristic_write_result` `gatt_status=0`.
  - `fetch_characteristic_read_result` `gatt_status=0`.
  - `fetch_response_received` `status="ok"`, `envelope_parse="ok"`.
  - terminal `fetch_client_disconnect` / `fetch_client_closed` with `terminal_event="complete"` and `reason="complete"`.

This proves the Android beacon/service cue to iOS responder to Android MFQ/MFR fetch path on the attached hardware. It does not prove background BLE, routing, ACKs, retries, trusted delivery, or direct full-MX extended-advert delivery.
