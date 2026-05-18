# Direct Full-MX AUX Validation Checklist 2026-05-17T13:58:54-0700

This checklist scopes the remaining evidence needed to close the
`extended_advertising_interop_aux_scan_response` row. It is based on the
SM-T577U -> iPad12,1 direct full-MX AUX scan-response probes archived in this
run.

The structured closure-progress artifact is archived beside this checklist at
`aux-closure-progress.json`. It records which closure criteria are already
satisfied by the negative runs and which criteria still block completion.

## Current Tested State

| Probe | Sender | Observer | Result |
| --- | --- | --- | --- |
| `android-aux-full-mx-ios-observe` | SM-T577U Android extended advertising, 80-byte scan-response carrier | Coding iPad iPad12,1 foreground scanner | Android emitted the direct full-MX scan response, but iOS surfaced no MX callback, candidate, decode, or `received_message` line. |
| `android-aux-full-mx-ios-observe-rerun` | SM-T577U Android extended advertising, 80-byte scan-response carrier | Coding iPad iPad12,1 foreground scanner with candidate discovery logging | iOS observed legacy MB beacons during the scan window, but still surfaced zero direct `FF FF 4D 58` MX callback, candidate, decode, or `received_message` lines. |
| `external-blocker-recheck-1358` | SM-T577U still attached | Coding iPad connected; DairyPhoneDeaux iPhone 13 unavailable | No alternate iOS receiver was available for a fresh direct full-MX AUX probe. |

## Evidence Required To Close The Row

The row can be marked complete only after a future hardware/API path provides
all of the following evidence in one coherent run:

1. Sender metadata: device model, OS/API version, app/build identifier,
   advertising mode, carrier, payload length, connectable/scannable flags, and
   the raw manufacturer-data bytes.
2. Observer metadata: device model, OS/API version, app/build identifier,
   scanner filters, scan mode, foreground/background state, and capture time.
3. Platform callback proof that the observer received manufacturer data
   containing `FF FF 4D 58` direct full-MX bytes from the sender.
4. Canonical parse proof that those bytes entered the normal MeshX
   `received_message` / MX envelope handling path without a test-only parser.
5. Control proof that the MB beacon fallback still works in the same hardware
   session or a paired immediately-adjacent session.
6. Negative-boundary notes for any platform that still hides AUX scan-response
   manufacturer data, so release docs do not overclaim cross-platform support.

## Current Completion Decision

The row remains incomplete because the tested iOS hardware did not surface the
direct full-MX AUX scan-response bytes to the scanner callback. MB beacon cue
plus GATT fetch remains the validated full-envelope path for the attached
SM-T577U -> iPad12,1 hardware pair.

Current closure-progress summary:

- Satisfied for the negative runs: sender metadata, observer metadata, MB
  fallback control, and negative-boundary notes.
- Missing: platform callback proof for `FF FF 4D 58`, canonical parse proof,
  and an alternate iOS receiver path.
