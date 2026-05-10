# MeshX Workspace Safety Rules

This document defines the execution contract for autonomous agents operating
inside the MeshX repository. Violating any rule is a bug in the agent, not a
user instruction problem.

## 1. Git Repository Lifecycle

### 1.1 Repository Initialization (`git init`)

**Rule:** An agent MUST NOT run `git init` unless the user **explicitly**
instructs it to create a new repository. The absence of `.git/` is not a
failure condition; it is a boundary condition.

**Rationale:** Initializing a repository changes the workspace's identity,
creates a root commit, and severs provenance with any upstream origin. This
is never an automatic recovery action.

**Correct behavior when `.git/` is absent:**
- Stop.
- Report: "No git repository found at `<path>`."
- Ask the user whether to initialize, clone from an origin, or operate
  without version control.

### 1.2 Commit Preconditions

Before any `git add`, `git commit`, or `git push`, the agent MUST verify
**both** of the following:

1. `.git/` exists at the expected path (or the nearest ancestor with `.git/`).
2. The repository has a known provenance: either a configured `origin` remote,
   or a documented reason why this workspace is intentionally detached.

If either check fails, the agent MUST stop and report the discrepancy before
mutating history.

### 1.3 Root-Commit and Detached-State Ambiguity

**Rule:** If the repository is a root commit (no parent history), or if HEAD
is detached with no branch pointer, the agent MUST refuse to commit further
changes without explicit user confirmation.

**Rationale:** A root commit in an existing project usually means either:
- The workspace was exported/copied without `.git/`
- A previous agent already initialized a repo and broke provenance
- The user genuinely wants a new history line

All three require human confirmation. The agent MUST NOT paper over the
ambiguity by adding more commits.

### 1.4 History Mutation Reporting

Before any commit, the agent MUST display the equivalent of `git status`
(including untracked files, staged changes, and branch state) and present a
summary to the user for confirmation. The user may skip this with an explicit
"commit without confirmation" instruction, but the default is stop-and-report.

---

## 2. Source Files vs Generated Artifacts

### 2.1 Distinction

| Category | Examples | Agent Action |
|----------|----------|--------------|
| **Source files** | `.ex`, `.exs`, `.md`, `.yml`, `mix.exs`, `config/*.exs` | Track in git; review in diffs |
| **Generated artifacts** | `_build/`, `deps/`, `.elixir_ls/`, `erl_crash.dump` | Ignore in git; do not modify without explicit instruction |
| **Lock files** | `mix.lock` | Track in git; only modify via `mix deps.get` / `mix deps.update` |

### 2.2 Cleaning Build Artifacts

**Rule:** An agent MUST NOT run `rm -rf deps/`, `mix deps.clean --all`,
`rm -rf _build/`, or equivalent without explicit user instruction.

**Rationale:** Cleaning dependencies destroys compilation artifacts and
PLT caches that may take minutes to rebuild. In CI or shared workspaces,
this wastes time and may break incremental builds. If stale deps are
suspected, the agent SHOULD report the issue and suggest the clean command
rather than executing it unilaterally.

**Exception:** If the user explicitly asks to "clean and rebuild", the agent
may proceed after confirming the scope (e.g., `deps/` only, `_build/` only,
or both).

---

## 3. Dependency Graph Mutations

### 3.1 Adding or Removing Dependencies

When modifying `mix.exs` or `mix.lock`:

- The agent MUST run `mix deps.get` to validate resolution.
- The agent MUST verify the dependency tree resolves without conflicts.
- The agent MUST verify compilation succeeds with `mix compile` before
  claiming the change is complete.
- The agent MUST report which packages were added or removed.

### 3.2 Transitive Dependency Awareness

The agent MUST distinguish between:
- **Direct dependencies** declared in `mix.exs`
- **Transitive dependencies** pulled in by direct deps (e.g., `jason` via `credo`)

Removing a direct dependency does not guarantee its transitive deps disappear
from `deps/` on disk. The agent MUST NOT report "all traces removed" unless
it has verified `mix.lock` and confirmed no other package references the
supposedly-removed dependency.

---

## 4. Workspace Provenance Verification Checklist

Before any history-mutating operation, the agent MUST run this checklist:

```
[ ] Is .git/ present at the project root or an ancestor?
[ ] Does .git/config contain a remote origin?
[ ] Is HEAD attached to a named branch?
[ ] Does the commit graph have at least one parent (not a root commit)?
[ ] Are there uncommitted changes? If so, what files?
[ ] Are there untracked files that look like source vs artifacts?
[ ] Has the user explicitly authorized this commit?
```

If any check fails, the agent MUST stop and report, not proceed.

---

## 5. Recovery Scenarios

### 5.1 Accidental `git init`

If an agent (or a previous session) accidentally initialized a new repo:

1. **Stop immediately.** Do not add more commits.
2. Report the root commit SHA and the fact that no origin is configured.
3. Ask the user whether:
   - This workspace is canonical and should be pushed to a new remote.
   - The `.git/` directory should be deleted and the workspace reconnected
     to an existing origin.
4. Do not proceed with further commits until provenance is settled.

### 5.2 Detached HEAD or Copied Workspace

If the workspace appears to be a detached copy (no `.git/`, but project
metadata like `.github/workflows/` exists):

1. Report: "Workspace appears to be a detached copy. `.github/workflows/`
   exists but no `.git/` found."
2. Suggest: clone from the repository URL implied by the workflow
   configuration, or verify this is an intentionally ephemeral workspace.
3. Do not initialize a new repository without explicit instruction.

---

## 6. Scope of These Rules

These rules apply specifically to autonomous agents operating on MeshX.
They are **not** general git best-practice advice for human contributors.
Humans may use their judgment; agents must follow the checklist.

*Violations of these rules should be reported as agent bugs, not user
errors.*
