# Upstream PR Recheck

Checked at: 2026-05-17T11:46:04-0700.

Commands:

- `gh pr view 6 --repo GenericJam/mob_dev --json state,isDraft,mergeable,mergeStateStatus,headRefOid,statusCheckRollup,reviewDecision,reviews,comments,baseRefName,headRefName,headRepositoryOwner,url`
- `gh pr view 5 --repo GenericJam/mob_new --json state,isDraft,mergeable,mergeStateStatus,headRefOid,statusCheckRollup,reviewDecision,reviews,comments,baseRefName,headRefName,headRepositoryOwner,url`
- `gh repo view GenericJam/mob_dev --json viewerPermission,defaultBranchRef`
- `gh repo view GenericJam/mob_new --json viewerPermission,defaultBranchRef`

Raw outputs are archived beside this file:

- `mob-dev-pr-6.json`
- `mob-new-pr-5.json`
- `mob-dev-repo.json`
- `mob-new-repo.json`

Observed state:

- `GenericJam/mob_dev#6` remains open, non-draft, mergeable, merge-state
  `UNSTABLE`, with GitGuardian Security Checks passed and no reviews returned.
  The handoff comment remains present. Viewer permission is `READ`.
- `GenericJam/mob_new#5` remains open, non-draft, mergeable, merge-state
  `UNSTABLE`, with GitGuardian Security Checks passed and no reviews returned.
  The handoff comment remains present. Viewer permission is `READ`.

Result: upstreaming remains blocked on GenericJam maintainer merge/release, then
MeshX dependency migration, downstream patch removal, and post-migration gates.
