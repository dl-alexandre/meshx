# External Blocker Recheck 2026-05-17T13:58:54-0700

## Device Availability

| Device | State | Evidence |
| --- | --- | --- |
| SM-T577U Android tablet `R52W90AW7EN` | Connected | `adb-devices.txt` |
| Coding iPad iPad12,1 | Connected | `devicectl-devices.txt` |
| DairyPhoneDeaux iPhone 13 iPhone14,5 | Unavailable | `devicectl-devices.txt` |

## Result

No fresh direct full-MX AUX rerun was attempted because the only connected iOS
receiver remains the already-tested Coding iPad. The alternate iOS receiver
needed for a new receiver-path check is still unavailable.

| Blocker | Latest evidence | Status |
| --- | --- | --- |
| Direct full-MX AUX alternate iOS receiver | `devicectl-devices.txt` | Still blocked: no second iOS receiver is available. |
| Upstream patch migration | `../upstream-pr-recheck-1358/` | Latest upstream-only PR recheck is archived separately; both upstream PRs are still open and unmerged. |

This recheck does not change the completion decision: direct full-MX AUX
completion remains blocked until a future hardware/API run shows MX
manufacturer data delivered to the platform scanner callback and parsed
canonically.
