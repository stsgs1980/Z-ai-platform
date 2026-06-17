# Session Notes

> Purpose: Capture lessons learned during work on the Z-ai platform.
> Each entry is a self-contained observation that does NOT belong in
> the worklog (which is task-specific) or the decisions log (which is
> about architectural choices). These are gotchas, surprises, and
> reusable knowledge for future sessions.
>
> Location: `Z-ai-platform/docs/session/SESSION_NOTES.md`
> Last Updated: 2026-06-17

---

## Table of Contents

1. [GitHub Actions gotchas](#1-github-actions-gotchas)
2. [GitHub PAT gotchas](#2-github-pat-gotchas)
3. [Git submodule gotchas](#3-git-submodule-gotchas)
4. [ID graph verifier gotchas](#4-id-graph-verifier-gotchas)
5. [Markdown / Unicode compliance findings](#5-markdown--unicode-compliance-findings)
6. [Available standards inventory (upload/)](#6-available-standards-inventory-upload)
7. [Local workspace persistence](#7-local-workspace-persistence)
8. [Lessons that became decisions](#8-lessons-that-became-decisions)

---

## 1. GitHub Actions gotchas

### 1.1. Path filters do not fire on submodule pointer bumps

**Discovered:** 2026-06-17, commit 7c3461f

A workflow with:
```yaml
on:
  push:
    branches: [main]
    paths:
      - 'standards/**'
      - 'guard/**'
      - 'skills/**'
```

will NOT trigger when a submodule pointer is bumped. Submodule pointer
updates are gitlink changes (the index records a new commit SHA for the
submodule path), not file content changes. GitHub Actions path filters
match against file paths in the commit, and gitlink changes do not
match any path pattern.

**Symptom:** Push of commits `af0a73f`, `1a82740`, `70fc5f4` (all
submodule bumps) produced no workflow runs. Only manual
`workflow_dispatch` worked.

**Fix:** Drop the `paths:` filter for push triggers. The orchestrator
has low commit noise — every push is either a pointer bump or an
orchestrator file change, both of which warrant re-running the
verifier.

**Alternative (not chosen):** Use a separate workflow that runs on
`repository_dispatch` triggered by webhook from each submodule's CI.
More complex, not worth the complexity for the current orchestrator
size.

### 1.2. Workflow file push requires `Workflows: Read and write` scope

**Discovered:** 2026-06-17, after 3 PAT attempts

A fine-grained PAT with `Contents: write` permission is INSUFFICIENT to
push commits that include changes to `.github/workflows/*`. GitHub
requires a separate `Workflows: Read and write` permission.

**Symptom:** `git push` returns HTTP 403 with a message like:
```
refusing to allow an OAuth App to create or update workflow
`.github/workflows/verify-id-graph.yml` without `workflows` scope
```

**Fix:** When creating a fine-grained PAT for the orchestrator repo,
enable BOTH:
- `Contents: Read and write`
- `Workflows: Read and write`

**Alternative:** Use a classic PAT with the `workflow` scope. Less
secure (classic PATs are not repo-scoped) but simpler to create.

### 1.3. Cached workflow registrations survive file deletion

**Discovered:** 2026-06-17

After deleting a workflow file from the repository and pushing the
deletion, GitHub Actions continues to show the workflow as "active" in
the Actions UI for some time (observed: at least several hours). The
workflow cannot be triggered, but its registration persists.

**Symptom:** A `_permission-test.yml` workflow (created during PAT
debugging) was deleted in commit `53b52b7`. The Actions UI continued
to list it under "All workflows" → "_permission-test.yml" with
`state=active` per the API.

**Workaround:** None needed. The cached registration is harmless. New
runs cannot be triggered for a deleted workflow file.

---

## 2. GitHub PAT gotchas

### 2.1. Secret Scanner auto-revokes PATs in tracked files

**Discovered:** 2026-06-17, three revocations in one session

GitHub's Secret Scanner monitors all pushed content (including
`.env`, `*.txt`, `*.md` files) for token patterns. If a PAT matches
the `github_pat_...` or `ghp_...` pattern, it is automatically revoked
within seconds of the push landing on GitHub.

**Happened three times:**
1. PAT #1: leaked via `/home/z/my-project/upload/PAT.txt` (file
   uploaded by user, accidentally committed when I ran `git init` in
   `/home/z/my-project/`)
2. PAT #2: leaked via the same path after I re-committed
3. PAT #3: valid but lacked `Workflows: Read and write` scope

**Prevention:**
- `.gitignore` MUST include: `.env`, `*.pat`, `*.token`, `PAT*.txt`,
  `*push*.txt`, `upload/`, `download/`, `worklog.md`
- NEVER run `git init` in `/home/z/my-project/` — only in
  `Z-ai-platform/` and its submodules
- Store PATs in `~/.git-credentials` (mode 600) or `.env` (mode 600),
  never in tracked files
- After receiving a PAT from the user, immediately move it out of
  `upload/` (which is user-uploaded and may be committed by accident)

### 2.2. Fine-grained PAT scope checklist

For working with the 4-repo split, the fine-grained PAT MUST have:

| Permission | Scope | Why |
|---|---|---|
| Contents | Read and write | Push commits to all 4 repos |
| Workflows | Read and write | Push changes to `.github/workflows/*` |
| Actions | Read-only | Trigger `workflow_dispatch`, read run status |
| Metadata | Read-only | Required baseline (auto-included) |

Optional but useful:
| Permission | Scope | Why |
|---|---|---|
| Pull requests | Read and write | If PR-based workflow is used |
| Issues | Read and write | For tracking open questions |

**Repository access:** All 4 repos (Z-ai-platform, Z-ai-standards,
Z-ai-guard, Z-ai-skills) MUST be in the PAT's repository access list.

---

## 3. Git submodule gotchas

### 3.1. `git clone` without `--recurse-submodules` leaves empty dirs

**Discovered:** 2026-06-17

A plain `git clone https://github.com/stsgs1980/Z-ai-platform.git`
produces a working tree with empty `standards/`, `guard/`, `skills/`
directories. The submodule metadata is registered but the content is
not checked out.

**Fix:** Always use:
```bash
git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git
```

If already cloned without the flag:
```bash
git submodule update --init --recursive
```

### 3.2. Submodule HEAD is detached by default

**Discovered:** 2026-06-17

After `git submodule update --init`, the submodule's HEAD is detached
at the pinned SHA, not on a branch. Any commit made inside the
submodule goes to a detached HEAD and is lost on the next `git checkout
main`.

**Symptom:** Committed changes inside `standards/`, ran
`git checkout main`, the commit disappeared (it was on the detached
HEAD, not on `main`).

**Fix:** Before committing inside a submodule, explicitly check out
the branch:
```bash
cd standards
git checkout main
# now make changes, commit, push
```

Or, if a commit was already made on detached HEAD, recover it:
```bash
cd standards
NEW_SHA=$(git rev-parse HEAD)
git checkout main
git reset --hard $NEW_SHA
```

### 3.3. Combining two submodule bumps in one commit breaks bisect

**Discovered:** 2026-06-17 (avoided, not experienced)

If a single orchestrator commit bumps two submodules (e.g. standards
AND guard), `git bisect` cannot determine which bump introduced a
failure. The verifier also cannot correlate "which submodule caused
the ID graph break".

**Prevention:** Always make submodule bumps atomic — one bump per
commit. See D-002 in `DECISIONS_LOG.md`.

### 3.4. Submodule path filters in CI are useless

See §1.1 above. Submodule pointer bumps do not match path filters.

---

## 4. ID graph verifier gotchas

### 4.1. The `skills/skills/` doubled path

**Discovered:** 2026-06-17

The skills submodule is registered at path `skills/` (matching the
submodule name). Inside the submodule, the skill catalog root is also
named `skills/`. So the full path from the orchestrator root to a
SKILL.md file is:
```
skills/skills/<skill-name>/SKILL.md
```

This is confusing but intentional: the outer `skills/` is the
submodule path; the inner `skills/` is the catalog root inside the
submodule.

`verify-id-graph.js` has a heuristic to discover this layout — it
checks `skills/skills/INDEX.md` and `skills/skills/<skill-dir>/`
before falling back to `skills/INDEX.md`.

### 4.2. YAML frontmatter `related:` is a list, not a string

**Discovered:** 2026-06-17

The `related:` field in YAML frontmatter is a list:
```yaml
related:
  - RULE-MONOLITH-011
  - STD-ARCH-001
```

NOT a comma-separated string:
```yaml
related: RULE-MONOLITH-011, STD-ARCH-001  # WRONG
```

The verifier's extractor was patched (commit 20c729d) to handle both
forms, but the canonical form is the list.

### 4.3. `Aligned_with:` cross-layer does not require Related

**Discovered:** 2026-06-17, during G15 fix

G15 (Aligned_with MUST have a corresponding Related edge) was
initially too strict — it required Related for ALL Aligned_with pairs,
including cross-layer STD↔ZAI pairs. The fix (commit 447725b) made G15
check Related only for same-layer Aligned_with pairs. Cross-layer
Aligned_with is allowed standalone per STD-META-001 §6.2.

### 4.4. STD→RULE is forbidden, RULE→STD is allowed

**Discovered:** 2026-06-17, during G04/G07 fix

The layer matrix is directional:
- `STD-ARCH-001` (a standard) declaring `Related: RULE-MONOLITH-016`
  is FORBIDDEN (G07).
- `RULE-MONOLITH-016` declaring `Related: STD-ARCH-001` is ALLOWED.

When a standard needs to reference a rule that enforces it, the rule
declares the Related edge, not the standard. This preserves the
principle that standards are self-contained.

---

## 5. Markdown / Unicode compliance findings

### 5.1. Current violation counts (2026-06-17 scan)

Scanned 118 MD files across the 4-repo split:

| Category | Count | Worst offenders |
|---|---|---|
| Emoji / pictograms | 307 | `README.md` (7), `CONTRIBUTING.md` (5), `session-experience/SKILL.md` (9), `humanizer/SKILL.md` (10) |
| Em dash (—, U+2014) | 297 | `skills/skills/INDEX.md` (36), `workflow-discipline_sts/SKILL.md` (20), `session-experience/SKILL.md` (20) |
| En dash (–, U+2013) | 28 | `STD-META-001-v2.0.md` (12!), `verify-id-graph-spec-v1.0.md` (11), `STD-SKILL-001-v1.0.md` (4) |
| Box drawing (U+2500-U+257F) | 2801 | `gepetto/SKILL.md` (693), `gepetto/README.md` (898), `README.md` (123) |
| Smart quotes | 7 | `humanizer/` (7) |

**Most embarrassing:** 12 en-dashes in `STD-META-001-v2.0.md` — the
meta-standard itself violates the Unicode policy it should be
exemplifying.

### 5.2. Policy allows em-dash in prose, forbids in headings/tables/code

Per `MARKDOWN_STANDARD.md` §4.1, typographic symbols (em dash, en dash,
degree, copyright, plus-minus) are ALLOWED in **plain text only**.
They are FORBIDDEN in:
- Headings and subheadings
- Tables
- Inline code and code blocks
- File and folder names

This means the 297 em-dash occurrences are NOT all violations — many
are in prose. A proper compliance check needs context awareness, not
just character matching.

### 5.3. Box-drawing in tree diagrams is a [W] warning, not [C]

Per `UNICODE_POLICY.md` §4.2, table pseudographics (box drawing) is
[W] Warning level, not [C] Critical. This means box-drawing in README
tree diagrams is technically a soft violation, not a hard block.

See O-005 in `DECISIONS_LOG.md` for handling options.

---

## 6. Available standards inventory (upload/)

**Location:** `/home/z/my-project/upload/standards-v2/standards/`

20 ready-to-import standard files, totaling ~440 KB of normative
content. None are currently in the 4-repo split (which has 6 files,
4 of which are stubs).

| # | File | Size | Last modified | Maps to ID | In our split? |
|---|---|---|---|---|---|
| 1 | `STANDARD_ID_SYSTEM.md` | 8.7K | Jun 16 | STD-META-001 | Yes (v2.0, full) |
| 2 | `MARKDOWN_STANDARD.md` | 26.9K | Jun 16 | STD-DOC-002 | Stub only |
| 3 | `UNICODE_POLICY.md` | 26.8K | Jun 16 | STD-DOC-003 | Missing |
| 4 | `CODE_EXAMPLES_GUIDE.md` | 12.3K | May 19 | STD-DOC-005 | Missing |
| 5 | `DESIGN_SYSTEM_STANDARD.md` | 82.9K | Jun 16 | STD-DESIGN-001 | Missing |
| 6 | `ERROR_HANDLING_STANDARD.md` | 16.3K | May 19 | STD-ERR-001 | Missing |
| 7 | `ERROR_RECOVERY_STANDARD.md` | 10.3K | May 19 | STD-ERR-002 | Missing |
| 8 | `FRONTEND_STANDARD.md` | 40.0K | Jun 16 | STD-FE-001 | Missing |
| 9 | `GITHUB_SANDBOX_STANDARD.md` | 23.1K | May 19 | STD-GIT-002 | Missing |
| 10 | `GITHUB_STANDARD.md` | 13.1K | May 19 | STD-GIT-001 | Missing |
| 11 | `IMPLEMENTATION_ORDER.md` | 14.2K | Jun 16 | STD-ARCH-001 (conflict!) | Conflict — see O-001 |
| 12 | `ORCHESTRATION_STANDARD.md` | 12.8K | May 19 | STD-AGENT-002 | Missing |
| 13 | `README_TEMPLATE.md` | 6.5K | Jun 16 | STD-DOC-004 | Missing |
| 14 | `REPRODUCIBILITY-STANDARD.md` | 6.8K | May 19 | STD-ENV-001 | Stub only |
| 15 | `SECURITY_EXTENDED_STANDARD.md` | 15.5K | May 19 | STD-SEC-002 | Missing |
| 16 | `SECURITY_STANDARD.md` | 9.8K | May 19 | STD-SEC-001 | Missing |
| 17 | `SUBAGENT_STANDARD.md` | 11.7K | May 19 | STD-AGENT-001 | Missing |
| 18 | `TESTING_STANDARD.md` | 15.2K | May 19 | STD-TEST-001 | Missing |
| 19 | `WCAG_2.1_AA_STANDARD.md` | 8.6K | May 19 | STD-A11Y-001 | Missing |
| 20 | `ZAI_INTEGRATION_STANDARD.md` | 19.0K | Jun 16 | STD-ENV-002 | Stub only |

**Also in `upload/` (top level, not in standards-v2/):**
- `Hooks-in-Z.ai-Guide.md` (27K) — guide, not a standard
- `Z.ai-Sandbox-Guide.md` (14K) — guide, not a standard
- `SKILL.md` (13K) — skill-creator template

**Age skew:** Files dated May 19 are older (likely from toolkit v2.0.5
or earlier). Files dated Jun 16 are recent (likely from toolkit v2.2+).
The older files may need content review before import.

---

## 7. Local workspace persistence

### 7.1. What survives a session restart

Observed on 2026-06-17 after a session restart:

| Path | Survives? | Notes |
|---|---|---|
| `/home/z/my-project/upload/` | Yes | Read-only user-uploaded content |
| `/home/z/my-project/skills/` | Yes | Sandbox skills (65 directories) |
| `/home/z/my-project/download/` | Yes (but contents wiped) | Only `README.md` survives |
| `/home/z/my-project/.env` | Yes | But PAT may be stale |
| `/home/z/my-project/.git` | Yes | Local sandbox git, not Z-ai-platform |
| `/home/z/my-project/Z-ai-platform/` | NO | Must be re-cloned |
| `/home/z/my-project/worklog.md` | NO | Must be re-created from `docs/session/` |
| `~/.git-credentials` | Yes | Survives if not actively cleared |

### 7.2. Recovery procedure

After a session restart, to recover the working state:

```bash
# 1. Restore PAT to ~/.git-credentials
PAT='<from user or .env>'
echo "https://stsgs1980:$PAT@github.com" > ~/.git-credentials
chmod 600 ~/.git-credentials
git config --global credential.helper 'store --file ~/.git-credentials'

# 2. Clone Z-ai-platform with submodules
cd /home/z/my-project
git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git
cd Z-ai-platform

# 3. Verify state
node standards/scripts/verify-id-graph.js
# Expected: 13/13 HARD PASS, 0 warnings

# 4. Read session docs for context
cat docs/session/DECISIONS_LOG.md
cat docs/session/SESSION_NOTES.md
cat docs/session/worklog.md   # if pushed; else reconstruct from git log
```

### 7.3. What MUST be pushed to GitHub before session ends

To survive a session restart, the following MUST be on GitHub:
- All code changes (committed and pushed to the appropriate repo)
- `Z-ai-platform/docs/session/worklog.md` (this document)
- `Z-ai-platform/docs/session/SESSION_NOTES.md` (this document)
- `Z-ai-platform/docs/session/DECISIONS_LOG.md`
- Any in-progress edits that are not yet "done" but represent
  recoverable state

If a task is mid-flight when the session ends, push it anyway with a
clear commit message noting it is WIP. Better to have recoverable
state than to lose work.

---

## 8. Lessons that became decisions

These lessons were painful enough to formalize as architectural
decisions. See `DECISIONS_LOG.md` for the formal version.

| Lesson | Decision |
|---|---|
| PATs leaked into tracked files get auto-revoked | D-003: Clean HTTPS URLs only |
| Path filters miss submodule bumps | D-009: Push trigger without path filter |
| Two submodule bumps in one commit breaks bisect | D-002: Atomic per-submodule bumps |
| Workflow file push needs separate scope | D-010: Workflow lives in orchestrator; PAT needs Workflows scope |
| STD→RULE edges create cycles in the dependency graph | D-005: STD→STD only; RULE→STD allowed |
| Aligned_with without Related creates "alignment without dependency" | D-006: G15 enforces Related backing |
| Compatibility mismatches between skills break runtime | D-007: G14 enforces compatibility DAG |
| Hard checks block CI, soft warnings indicate debt | D-008: Two-tier strictness |

---

## Change History

| Date | Change |
|---|---|
| 2026-06-17 | Initial creation. Captured all lessons from the 2026-06-17 session: GitHub Actions gotchas (3), PAT gotchas (2), submodule gotchas (4), verifier gotchas (4), Unicode findings (3), standards inventory (20 files), workspace persistence (3 subsections). |
