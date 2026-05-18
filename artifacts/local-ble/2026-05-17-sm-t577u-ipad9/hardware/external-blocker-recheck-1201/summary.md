# External Blocker Recheck

Checked at: 2026-05-17T12:01:59-0700.

## Devices

Command: `adb devices -l`

- Android device `R52W90AW7EN` remains attached as `SM_T577U`.

Command: `xcrun devicectl list devices`

- `Coding iPad` remains connected as `39FD8D3A-9CA5-5DEF-AFC0-AA5205511117`
  (`iPad12,1`).
- `DairyPhoneDeaux` remains unavailable as
  `1780F216-CB5C-560B-A86F-85D31F79ADEF` (`iPhone14,5`).

Result: no alternate iOS receiver is available for a new direct full-MX AUX
scan-response probe in this workspace.

## Upstream PRs

Fresh upstream PR metadata is archived in
`artifacts/local-ble/2026-05-17-sm-t577u-ipad9/hardware/upstream-pr-recheck-1201/`.

Observed state:

- `GenericJam/mob_dev#6` remains open, non-draft, mergeable, merge-state
  `UNSTABLE`, with GitGuardian Security Checks passed. Viewer permission is
  `READ`.
- `GenericJam/mob_new#5` remains open, non-draft, mergeable, merge-state
  `UNSTABLE`, with GitGuardian Security Checks passed. Viewer permission is
  `READ`.

Result: upstreaming remains blocked on GenericJam maintainer merge/release, then
MeshX dependency migration and post-migration gates.
