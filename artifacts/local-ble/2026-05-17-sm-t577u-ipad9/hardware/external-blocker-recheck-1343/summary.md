# External Blocker Recheck 2026-05-17T13:43:40-0700

Fresh device-availability check for the direct full-MX AUX row.

| Blocker | Evidence | Result |
| --- | --- | --- |
| Android AUX sender | `adb-devices.txt` | SM-T577U `R52W90AW7EN` remains attached and available. |
| Primary iOS receiver | `devicectl-devices.txt` | Coding iPad `iPad12,1` remains connected. This is the same receiver used for the prior negative AUX captures. |
| Alternate iOS receiver | `devicectl-devices.txt` | `DairyPhoneDeaux` iPhone 13 `iPhone14,5` remains `unavailable`, so no alternate iOS receiver is available for a fresh direct full-MX AUX probe. |
| Upstream patch migration | `../upstream-pr-recheck-1336/` | The latest upstream-only PR recheck remains archived separately; both upstream PRs are still open and unmerged. |

Result: no new direct full-MX AUX validation run was attempted from this
recheck because the only available iOS receiver is the already-tested iPad12,1
path that did not surface `FF FF 4D 58` manufacturer data to the scanner
callback. The AUX row remains blocked pending a new hardware/API receiver path.
