# AUX Alternate iOS Target Availability Check

Date: 2026-05-17.
Last verified: 2026-05-17T11:32:22-0700.

This check records whether another iOS receiver was available for a fresh
direct full-MX AUX scan-response probe. It does not complete the AUX row.

## Result

- Android sender candidate: SM-T577U `R52W90AW7EN` is attached over ADB.
- iOS receiver candidate: Coding iPad `39FD8D3A-9CA5-5DEF-AFC0-AA5205511117`
  is connected.
- Alternate iOS receiver candidate: `DairyPhoneDeaux` iPhone 13
  `1780F216-CB5C-560B-A86F-85D31F79ADEF` is unavailable.

No second iOS receiver target was available in this workspace for an
additional direct full-MX AUX probe. The AUX status therefore remains bounded
by the attached iPad12,1 negative captures.

## Artifacts

- `adb-devices.txt`
- `devicectl-devices.txt`
