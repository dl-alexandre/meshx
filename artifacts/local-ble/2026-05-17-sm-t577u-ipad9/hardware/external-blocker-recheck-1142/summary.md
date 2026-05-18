# External Blocker Recheck

Checked at: 2026-05-17T11:42:04-0700.

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

Commands:

- `gh pr view 6 --repo GenericJam/mob_dev --json state,isDraft,mergeable,mergeStateStatus,headRefOid,statusCheckRollup,reviewDecision,reviews,comments,baseRefName,headRefName,headRepositoryOwner,url`
- `gh pr view 5 --repo GenericJam/mob_new --json state,isDraft,mergeable,mergeStateStatus,headRefOid,statusCheckRollup,reviewDecision,reviews,comments,baseRefName,headRefName,headRepositoryOwner,url`
- `gh repo view GenericJam/mob_dev --json viewerPermission,defaultBranchRef`
- `gh repo view GenericJam/mob_new --json viewerPermission,defaultBranchRef`

Observed state:

- `GenericJam/mob_dev#6`
  - URL: https://github.com/GenericJam/mob_dev/pull/6
  - State: open.
  - Draft: false.
  - Mergeability: mergeable.
  - Merge-state status: unstable.
  - Head SHA: `0cf9df03224b163356404b5484b338005754b244`.
  - Visible check: GitGuardian Security Checks passed.
  - Reviews: none returned.
  - Handoff comment: present at
    https://github.com/GenericJam/mob_dev/pull/6#issuecomment-4471758623.
  - Viewer permission: READ.
- `GenericJam/mob_new#5`
  - URL: https://github.com/GenericJam/mob_new/pull/5
  - State: open.
  - Draft: false.
  - Mergeability: mergeable.
  - Merge-state status: unstable.
  - Head SHA: `3dbe111e33ecb7e42ab2b8c3f55c8960c69f1c43`.
  - Visible check: GitGuardian Security Checks passed.
  - Reviews: none returned.
  - Handoff comment: present at
    https://github.com/GenericJam/mob_new/pull/5#issuecomment-4471758634.
  - Viewer permission: READ.

Result: upstreaming remains blocked on GenericJam maintainer merge/release, then
MeshX dependency migration and post-migration gates.
