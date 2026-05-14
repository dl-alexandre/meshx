# M40 GATT Interop Rerun - 2026-05-13

Devices:

- SM-T577U / Android API 33 / serial `R52W90AW7EN`
- SM-T390 / Android API 28 / serial `5200f354f4fb277f`

Debug APK was rebuilt/installed on both devices from the current tree before
the rerun.

## SM-T577U responder -> SM-T390 requester

SM-T577U started the standalone connectable GATT interop advertiser:

```json
{"event":"interop_advertise_start","service_accepted":true,"advertise_accepted":true,"device_model":"SM-T577U","android_api":33,"adapter_state":"on"}
{"event":"interop_advertising_started","connectable":true,"service_uuid":"8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f4000"}
```

SM-T390 attempted `TRANSPORT_LE` GATT connect to `B4:0B:1D:AB:24:3C` and
failed before service discovery:

```json
{"event":"interop_connect_result","target_address":"B4:0B:1D:AB:24:3C","gatt_status":133,"gatt_reason":"android_gatt_error","state_name":"disconnected","device_model":"SM-T390","android_api":28}
{"event":"interop_closed","target_address":"B4:0B:1D:AB:24:3C","phase":"connect","terminal_event":"connect_failed","reason":"android_gatt_error"}
```

No characteristic discovery, write, read, or payload exchange occurred.

## SM-T390 responder -> SM-T577U requester

SM-T390 started the standalone connectable GATT interop advertiser:

```json
{"event":"interop_advertise_start","service_accepted":true,"advertise_accepted":true,"device_model":"SM-T390","android_api":28,"adapter_state":"on"}
{"event":"interop_advertising_started","connectable":true,"service_uuid":"8f4f1201-6f3d-4f9c-9e3b-7f4a4f0f4000"}
```

SM-T577U attempted `TRANSPORT_LE` GATT connect to `80:20:FD:C2:60:01` and
failed before service discovery:

```json
{"event":"interop_connect_result","target_address":"80:20:FD:C2:60:01","gatt_status":133,"gatt_reason":"android_gatt_error","state_name":"disconnected","device_model":"SM-T577U","android_api":33}
{"event":"interop_closed","target_address":"80:20:FD:C2:60:01","phase":"connect","terminal_event":"connect_failed","reason":"android_gatt_error"}
```

No characteristic discovery, write, read, or payload exchange occurred.

## Conclusion

The current SM-T577U / SM-T390 pair still fails the minimal standalone GATT
interop harness in both directions with Android `gatt_status=133` before
service discovery. This remains transport/platform-level evidence, not a
MeshX protocol failure, because the harness excludes MessageEnvelope, fetch
contracts, planner/ledger, replay, routing, and legacy beacon logic.
