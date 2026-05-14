# BLE Transport Re-Evaluation Gate

M66 records the next transport decision gate after advertisement-only
local mesh, opportunistic beacon gossip, and the local inbox consumer
surface.

## Current Hardware State

The attached Android pair remains:

| Role | Device | API | adb serial |
| --- | --- | --- | --- |
| Current capable sender | Samsung SM-T577U | 33 | `R52W90AW7EN` |
| Current old-Android participant | Samsung SM-T390 | 28 | `5200f354f4fb277f` |

This pair is validated for:

- legacy beacon advertisement reception;
- legacy beacon gossip advertisement from SM-T577U to SM-T390;
- canonical `received_message_beacon` replay/log shape.

This pair is not validated for:

- GATT fetch;
- standalone GATT read/write interop;
- full-envelope extended advertisement reception by SM-T390.

## Decision

Do not re-enable GATT fetch on SM-T577U/SM-T390. The M37-M40 evidence
shows Android `gatt_status=133` before service discovery in both MeshX
fetch and the standalone GATT interop harness. A May 12, 2026 rerun after
waking both devices and dismissing keyguard still failed the standalone
M40 interop harness in both directions before service discovery:

```text
/tmp/meshx-android-m40-current/sm-t577u-responder.log
/tmp/meshx-android-m40-current/sm-t390-requester.log
/tmp/meshx-android-m40-current/sm-t390-responder.log
/tmp/meshx-android-m40-current/sm-t577u-requester.log
```

Re-running the same known-bad pair is not new positive evidence unless
Android OS, firmware, hardware pair, or app BLE lifecycle behavior
materially changes.

Advertisement-only local mesh remains the validated local mode:

1. Full-envelope advertisements are allowed only where sender and
   observer capability is proven.
2. Legacy beacon advertisements are the old-Android compatibility path.
3. Legacy beacon gossip is validated for SM-T577U -> SM-T390.
4. Beacon refs stay references until a separate resolution transport is
   proven.

## Known-Good GATT Entry Criteria

GATT fetch can only move out of experimental/disabled status after a
new hardware pair produces all of the following artifacts:

- responder model, Android API, adapter state, and adb serial;
- requester model, Android API, adapter state, and adb serial;
- M40 standalone GATT interop log with:
  - connect callback `status=0`;
  - service discovery success;
  - characteristic discovery success;
  - one successful tiny read or write;
  - clean disconnect/close;
- M33-M36 constrained fetch log with:
  - one requester;
  - one responder;
  - one request id;
  - one matching `message_id_hash`;
  - full `MessageEnvelope` response parsed successfully;
- explicit statement that no routing, retries, persistence, ACKs,
  crypto, fragmentation, or background service behavior was enabled.

Until that evidence exists, any GATT attempt must remain a diagnostic
run and must not be described as message delivery.

## Future Alternatives

Any alternative resolution transport must preserve the same contract
line:

- a `received_message_beacon` is a pointer/reference;
- a full `ReceivedMessage` requires a validated canonical
  `MessageEnvelope`;
- transport evidence and message evidence remain distinct;
- failure must be auditable without fake success.
