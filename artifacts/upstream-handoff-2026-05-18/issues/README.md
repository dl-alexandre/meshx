# Upstream Issue Handoff — 2026-05-18

Four follow-on issues for the GenericJam mob ecosystem.

These are the remaining upstreamable items after the carrier decision was locked (MB legacy + GATT as the only validated full-envelope path for iOS↔Android) and the two enabling PRs for Swift sources were opened.

## The two prerequisite PRs (already posted)

- https://github.com/GenericJam/mob_dev/pull/6
- https://github.com/GenericJam/mob_new/pull/5

Both are open, mergeable, have only the author's handoff comment, zero review threads, and pass GitGuardian.

## The four new issues (ready to post)

All four files in this directory contain the full title + body + suggested labels in the frontmatter.

### Order and targets

1. `01-ios-foreground-custom-data-limitation.md` → `GenericJam/mob_dev`
2. `02-extended-advertising-aux-ios-limitation.md` → `GenericJam/mob_dev`
3. `03-mb-gatt-as-canonical-full-envelope-path.md` → `GenericJam/mob` (main bridge repo — adjust if the canonical name differs)
4. `04-hybrid-test-scaffolding-for-future-platform-changes.md` → `GenericJam/mob_dev`

## How to post (when you have write access)

Option A — Using GitHub CLI (recommended):

```bash
# 1
gh issue create \
  --repo GenericJam/mob_dev \
  --title "$(head -1 01-ios-foreground-custom-data-limitation.md | sed 's/title: "//; s/"$//')" \
  --body-file 01-ios-foreground-custom-data-limitation.md \
  --label ble,ios,documentation,carrier

# 2
gh issue create \
  --repo GenericJam/mob_dev \
  --title "$(head -1 02-extended-advertising-aux-ios-limitation.md | sed 's/title: "//; s/"$//')" \
  --body-file 02-extended-advertising-aux-ios-limitation.md \
  --label ble,ios,documentation,extended-advertising

# 3
gh issue create \
  --repo GenericJam/mob \
  --title "$(head -1 03-mb-gatt-as-canonical-full-envelope-path.md | sed 's/title: "//; s/"$//')" \
  --body-file 03-mb-gatt-as-canonical-full-envelope-path.md \
  --label ble,documentation,ios,android

# 4
gh issue create \
  --repo GenericJam/mob_dev \
  --title "$(head -1 04-hybrid-test-scaffolding-for-future-platform-changes.md | sed 's/title: "//; s/"$//')" \
  --body-file 04-hybrid-test-scaffolding-for-future-platform-changes.md \
  --label ble,testing,ios
```

The bodies already contain the `---` frontmatter at the top; `gh` will treat everything after the first `---` block as the body when using `--body-file` (or you can strip the frontmatter first).

Option B — Web UI:

Open each `.md` file, copy the title from the frontmatter and the body (everything below the second `---`), paste into https://github.com/GenericJam/<repo>/issues/new, and apply the suggested labels.

## Notes for the maintainer

- These four issues + the two open PRs (#6 and #5) together form the complete "remove all MeshX downstream patches" roadmap.
- The carrier guidance items (#1–3) are documentation / policy issues. They are independent of the Swift sources change.
- Issue #4 is a "please do not delete the hybrid test scaffolding" request so future iOS platform relaxations can re-use the validation harness with almost zero new work.
- All evidence is from physical devices (iPhone 13, SM-T577U, SM-T390) with archived bundles.

Once the two PRs are merged and released, the MeshX-side migration can be executed via `docs/upstream_mob_migration_checklist.md`.
