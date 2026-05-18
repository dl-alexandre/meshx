# Upstream PR Recheck

Checked at: 2026-05-17T12:01:59-0700.

Commands:

- `gh pr view 6 --repo GenericJam/mob_dev --json number,state,isDraft,mergeable,mergeStateStatus,mergedAt,headRefName,baseRefName,statusCheckRollup,reviewDecision,url,title,updatedAt,maintainerCanModify`
- `gh pr view 5 --repo GenericJam/mob_new --json number,state,isDraft,mergeable,mergeStateStatus,mergedAt,headRefName,baseRefName,statusCheckRollup,reviewDecision,url,title,updatedAt,maintainerCanModify`
- `gh api repos/GenericJam/mob_dev --jq '{name,viewer_permission:.permissions,default_branch,updated_at}'`
- `gh api repos/GenericJam/mob_new --jq '{name,viewer_permission:.permissions,default_branch,updated_at}'`

Raw outputs are archived beside this file:

- `mob-dev-pr-6.json`
- `mob-new-pr-5.json`
- `mob-dev-repo.json`
- `mob-new-repo.json`

Observed state:

- `GenericJam/mob_dev#6` remains open, non-draft, mergeable, merge-state
  `UNSTABLE`, with GitGuardian Security Checks passed and no merge recorded.
  Viewer permission remains `READ`.
- `GenericJam/mob_new#5` remains open, non-draft, mergeable, merge-state
  `UNSTABLE`, with GitGuardian Security Checks passed and no merge recorded.
  Viewer permission remains `READ`.

Result: upstreaming remains blocked on GenericJam maintainer merge/release, then
MeshX dependency migration, downstream patch removal, and post-migration gates.
