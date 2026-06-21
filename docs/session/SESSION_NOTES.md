# Session Notes

> Purpose: Capture lessons learned during work on the Z-ai platform.
> Each entry is a self-contained observation that does NOT belong in
> the worklog (which is task-specific) or the decisions log (which is
> about architectural choices). These are gotchas, surprises, and
> reusable knowledge for future sessions.
>
> Location: `Z-ai-platform/docs/session/SESSION_NOTES.md`
> Last Updated: 2026-06-21

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
9. [Sandbox persistence model (mount points)](#9-sandbox-persistence-model-mount-points)
10. [Z.ai Sandbox Documentation — keep / drop decision](#10-zai-sandbox-documentation--keep--drop-decision)
11. [Ready-to-use Unicode regex filters](#11-ready-to-use-unicode-regex-filters)
12. [Structured lessons registry](#12-structured-lessons-registry)

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

## 9. Sandbox persistence model (mount points)

**Source:** package "Про скилы" (`Архитектура хранения skills в песочнице.md`).
Extracted 2026-06-18. Closes O-006 (workspace persistence) and
O-007 (consumer onboarding).

### 9.1. Mount map (what survives a session restart)

| Path | Filesystem | Persistent? | Contents |
|---|---|---|---|
| `/home/official_skills/*.zip` | fuse.ossfs (read-only) | YES (Z.ai managed) | 69 official Z.ai skill zips |
| `/home/user_skills/*.zip` | PolarFS (read-write) | YES (yours) | ~17 user-uploaded skill zips |
| `/home/z/my-project/upload/` | tmpfs + ossfs rw | YES (OSS-backed) | Files uploaded via the chat UI |
| `/home/z/my-project/skills/` | local overlay FS | **NO** (rebuilt each start) | Disposable runtime view of extracted skills |
| `/tmp/my-project/` | PolarFS (read-write) | YES | `.initial_snapshot.json` with file timestamps |
| `~/.git-credentials` | local FS | YES (unless actively cleared) | Git PAT storage |
| GitHub repos | external | YES | 4-repo split (Z-ai-platform + submodules) |

### 9.2. Session startup sequence

1. Sandbox mounts `/home/official_skills/` (read-only OSS).
2. Sandbox mounts `/home/user_skills/` (PolarFS, read-write).
3. Sandbox mounts `/tmp/my-project/` (PolarFS, with `.initial_snapshot.json`).
4. `extract-official-skills.sh` runs: `unzip -qq -o <zip> -d /home/z/my-project/skills/`
   with `-o` (force overwrite). The `default:` stage in `stages.yaml` lists
   ~10 always-extracted skills (skill-creator, docx, pdf, pptx, ...).
5. Presumably the same script extracts user_skills/*.zip into the same target.
6. `.initial_snapshot.json` is read; project files listed there are restored
   by timestamp.

### 9.3. Critical implications for our 4-repo architecture

1. **`/home/z/my-project/skills/` is disposable.** Anything placed there
   directly is wiped on the next session start. This is not a bug, it is
   the sandbox guaranteeing official skills are always current.

2. **To survive between sessions, a user-authored skill must be either:**
   - Packaged as `.zip` and placed in `/home/user_skills/` (sandbox auto-extracts), OR
   - Stored in a git repo (e.g. `Z-ai-skills`) and cloned on demand, OR
   - Placed in `/tmp/my-project/` (PolarFS, but size-limited).

3. **Name collision is a real risk.** Z.ai's official `skill-creator.zip`
   and a user-authored `skill-creator.zip` would both extract to the same
   path `/home/z/my-project/skills/skill-creator/`. The last writer wins.
   Currently Z.ai wins because the container extracts its own zips last.
   **Mitigation:** user-authored skills should use distinct names
   (e.g. `toolkit-skill-creator`, not `skill-creator`).

4. **ZAI-* IDs are source-layer only.** The runtime sandbox addresses
   skills by their `name:` field (from YAML frontmatter), not by ID.
   `verify-id-graph.js` validates the source repo, not the runtime.
   `MIGRATIONS.md` in `Z-ai-skills` should map `ZAI-XXX-NNN <-> runtime name:`
   as the bridge between the two layers.

5. **Recommended install procedure for `Z-ai-skills`:**
   - At session start, after official extraction runs, clone `Z-ai-skills`
     and copy needed skills into `/home/z/my-project/skills/`.
   - Do NOT attempt to write into `/home/official_skills/` (no permissions).
   - Do NOT rely on `/home/z/my-project/skills/<name>/` preserving edits
     across sessions.

### 9.4. Action items captured as open questions

- O-006 (workspace persistence strategy) -> resolved by §9.1 + §9.3 above.
- O-007 (consumer onboarding) -> resolved by §9.3 item 5 (install procedure).
- O-008 (MAS roadmap) -> see DECISIONS_LOG.md, we are at Phase 1 (monolith).
- New: O-013 (reserve MAS agent IDs) -> see DECISIONS_LOG.md.

---

## 10. Z.ai Sandbox Documentation -- keep / drop decision

**Source:** `Z.ai Sandbox Documentation.zip` (7 files in `upload/`).
Analyzed in `docs/sandbox-docs-analysis.md` (2026-06-18). This section
records the final triage decision so future sessions do not re-analyze.

### 10.1. Decision matrix

| File | Size | Decision | Rationale |
|---|---|---|---|
| `Z.ai-Sandbox-Guide.md` | 24K | **KEEP** in `upload/` | Only known systematic doc of sandbox internals (idle timeout, allowedDevOrigins, port 81 proxy). Needed for fullstack sessions. |
| `Z.ai-Sandbox-Guide-Hooks.md` | 25K | **KEEP** in `upload/` | React hooks cookbook + z-ai-web-dev-sdk API routes. Copy-paste ready. Needed for AI-integrated fullstack sessions. |
| `Z.ai-Sandbox-Migration Guide.md` | 9.8K | **KEEP**, needs update | Migration procedure between sandbox sessions. STALE: uses `npm install --legacy-peer-deps` instead of `bun install`. Must be patched before next use. |
| `Z.ai-Sandbox-Super-Z-Subagents-Education.md` | 10K | **KEEP** | Architectural primer for Super Z + subagents. Required reading for understanding our own environment. STALE on one point: contradicts skill-creator on progressive disclosure (Subagents-Education is from March 2025, predates skill-creator). |
| `Z.ai-Sandbox-Guide_commands_reference.md` | 47K | **DROP** from active use | 1321 Linux commands catalog. The agent already knows these. 47K is too large for skill context. Keep on disk as `upload/`-only reference if disk space allows; do not turn into a skill. |
| `RELATIONS.md` | 2.5K | **KEEP** | PlantUML diagram of doc relationships + contradictions table. Acts as navigator. |
| `verify.sh` | 8.5K | **KEEP**, needs refresh | 11-group sanity check script. STALE: check 1 (dev.sh manager) and check 6 (build command) assume npm, current stack uses bun. Should be patched before relying on it. |

### 10.2. Overall decision

**KEEP 6 of 7 files** in `upload/` as reference material. **DROP** only
`commands_reference.md` from active use (it may remain on disk as an
offline man-page substitute, but should not be turned into a skill or
loaded into context).

**Do NOT package any of these as skills in their current form.** They
are too large (10K-47K each), pre-date the skill-creator progressive
disclosure pattern, and partially contradict current Z.ai infrastructure
(npm vs bun; Subagents-Education vs skill-creator). If skill wrappers
are needed later, write three short ones (< 500 lines each, per
skill-creator style) that reference the docs on demand:
`zai-fullstack-init`, `zai-sandbox-migration`, `zai-subagents-architecture`.

### 10.3. Internal contradictions to remember

1. **npm vs bun:** Guide.md -> bun; Migration Guide -> npm.
   Resolution: use bun (current stack). Migration Guide needs update.
2. **API routes:** Guide.md -> "DO NOT create other routes"; Hooks.md ->
   creates `/api/ai/chat`. Resolution: API routes for AI integrations
   via `z-ai-web-dev-sdk` are normal and work; Guide is overly strict.
3. **allowedDevOrigins:** Guide.md -> required; init-fullstack template
   -> missing. Resolution: add manually after every `init-fullstack`
   run (this is a documented Z.ai infra bug).

### 10.4. Session-type applicability (when to consult which file)

| Session type | Files to consult |
|---|---|
| Fullstack web-dev (Next.js + AI) | All 6 kept files |
| Docs / PPT / PDF / charts | Subagents-Education.md + RELATIONS.md only |
| Migration between sandboxes | Migration Guide.md + verify.sh |
| Code-only without AI (Vercel deploy) | Guide.md + Migration Guide + verify.sh |
| Learning Super Z architecture | Subagents-Education.md |

---

## 11. Ready-to-use Unicode regex filters

**Source:** "Skill assembler.txt" (package "Про скилы"), section 6.1.
These are the canonical upstream regexes from MARKDOWN_STANDARD.md.
Extracted 2026-06-18 to close O-004 (fix Unicode in 118 MD files).

### 11.1. Emoji pre-analysis cleanup

```javascript
// Removes emoji and Unicode pictographic symbols.
// Ranges: U+1F000-1FFFF, U+2600-27BF, U+FE00-FEFF, U+1F900-1F9FF, U+2702-27B0
const EMOJI_REGEX = /[\u{1F000}-\u{1FFFF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FEFF}]|[\u{1F900}-\u{1F9FF}]|[\u{2702}-\u{27B0}]/gu;
text.replace(EMOJI_REGEX, '');
```

### 11.2. Final sanitization (DESTRUCTIVE)

```javascript
// Allows only printable ASCII (0x20-0x7E) + Cyrillic (U+0400-04FF).
// WARNING: strips em-dash, en-dash, smart quotes, box-drawing, etc.
// Do NOT apply blindly; use targeted fixers instead.
const FINAL_SANITIZE_REGEX = /[^\x20-\x7E\u0400-\u04FF]/g;
text.replace(FINAL_SANITIZE_REGEX, '');
```

### 11.3. Implemented as a script

These regexes are wired into `Z-ai-platform/scripts/fix-unicode-compliance.js`
with context-aware targeted fixers (em-dash -> `--`, en-dash -> `-`,
smart quotes -> straight, box-drawing -> ASCII tree equivalents).

Run report-only:
```bash
node scripts/fix-unicode-compliance.js --path standards/
```

Apply fixes:
```bash
node scripts/fix-unicode-compliance.js --apply --path standards/
```

### 11.4. Current scan baseline (2026-06-18)

Running the script on `standards/` (9 MD files) reports 727 violations:
- emoji: 25 (all in `STD-META-001-v2.0.md`)
- em-dash: 135
- en-dash: 27 (12 in `STD-META-001-v2.0.md` -- the meta-standard violates its own policy)
- smart-quotes: 0
- box-drawing: 540 (mostly ASCII tree diagrams in `STD-SKILL-001-v1.0.md`, 343 occurrences)

Full 4-repo scan is pending O-003/O-004 decision in DECISIONS_LOG.md.

---

## 12. Structured lessons registry

### 12.1. Purpose and layering

This section is the **structured registry** for cross-cutting lessons that
emerge from real work but are not yet formal architectural decisions.
It sits between two existing layers:

- **§1-5** = topic-organized operational gotchas (GitHub Actions, PAT,
  submodules, ID graph, Unicode). Each entry is a self-contained surprise
  tied to a specific tool or subsystem.
- **§8** = bridge table "Lesson → Decision". Each row is a one-line
  summary of a lesson that has already been promoted to a formal D-NNN
  entry in `DECISIONS_LOG.md`.

§12 fills the gap between these two: a lesson may be **more than a
topic-specific gotcha** (it generalises across multiple subsystems) but
**not yet mature enough to formalise** as D-NNN (the pattern hasn't
repeated enough, or the right normative shape isn't clear). §12 captures
such lessons with explicit structured fields so they are searchable,
comparable, and ready to promote when the pattern crystallises.

The promote path is:

```
§1-5 (topic gotcha)
  → §12 (structured registry entry, status DRAFT or RECOGNIZED)
    → §8 (bridge row, when promoted)
      → D-NNN in DECISIONS_LOG.md (formal ADR)
        → optional: RULE-NNN in guard/ (normative enforcer)
```

### 12.2. Entry format

Each entry uses these fields:

| Field | Meaning |
|---|---|
| `ID` | `LESSON-YYYY-MM-DD-NNN`, monotonic |
| `Status` | DRAFT / RECOGNIZED / PROMOTED |
| `Trigger` | What observable event fires the lesson |
| `Root cause` | Why the event happened, in structural terms |
| `Fix principle` | The generalisable rule (not the specific patch) |
| `Applies-to` | Which kinds of systems / checks / processes this generalises to |
| `Source` | Worklog Task ID or commit SHA where the lesson was learned |
| `Promoted-to` | D-NNN / RULE-NNN if status == PROMOTED; else empty |

### 12.3. Portability and the toolkit-deprecation note

Earlier drafts of this section proposed a third tier T3 = ChromaDB via
the `session-experience` skill for cross-project semantic search. That
plan is **deprecated**: the Z.ai Agent Toolkit itself may be killed or
substantially reworked, and architecting the lessons layer around a
toolkit-dependent runtime creates a coupling that survives only as long
as the toolkit does.

Instead, §12 is **portable markdown**: this file travels with the repo,
and "export to another project" means "copy the markdown bundle". If a
future project wants semantic search over lessons, it can index this
markdown into whatever DB it prefers — but the source of truth stays
plain text. This keeps the lessons layer format-agnostic and decoupled
from any specific runtime.

### 12.4. LESSON-001: root-cause fix scales O(1), whitelist scales O(N)

- **ID:** LESSON-2026-06-21-001
- **Status:** RECOGNIZED
- **Trigger:** `verify-id-graph.js` W13 (stale-path warning) fired on
  legitimate changelog entries in `META-001` §15 that mentioned old
  filenames like `react-components.md` (was 1449 lines, became a 55-line
  INDEX after the pilot split). The initial reaction was to add the
  offending basenames to `W13_WHITELIST`.
- **Root cause:** The W13 check scanned the entire file body for
  filename-like tokens, with no scope exclusion for change-history
  sections. Such sections *naturally* mention old, renamed, or split
  filenames as historical facts — these are not navigational references
  and should not trigger W13.
- **Fix principle:** When an automated check fires on a legitimate use
case, **refine the check's scope** (skip change-history sections), NOT
whitelist each new trigger. Whitelist approaches scale O(N) with the
number of mentions; root-cause fixes scale O(1) and generalise to any
future changelog entry mentioning any filename.
- **Applies-to:** Any validator that scans free-text markdown for
structural references (file paths, IDs, links). Concretely in our stack:
W11 (long-file warning), W13 (stale-path), W14 (orphan-ID), and any
future check in the same family.
- **Source:** Worklog Task ID `pilot-split-3-long-files-2026-06-21`,
commit `362c65d` (worklog update reflecting W13 root-cause fix). User
directive at the time: «максимально автоматизировать, или я плакать
буду от роста проблем».
- **Promoted-to:** (empty; candidate for a future RULE-NNN on
"automated check design — scope refinement over whitelisting")

### 12.5. LESSON-002: core.fileMode=false beats repeated `git checkout .`

- **ID:** LESSON-2026-06-21-002
- **Status:** RECOGNIZED (corroborates LESSON-001 — same principle in a
different domain)
- **Trigger:** 17 files in `git status` of Z-ai-platform flagged as
modified with `0 insertions, 0 deletions` — pure mode bit changes
(100644 in index -> 100755 in working tree). Affected files: .gitmodules,
.github/workflows/*.yml, *.md, *.mmd, *.dot, *.png, *.svg.
- **Root cause:** Sandbox fs mount sets +x bit on all files (presumably
so .sh scripts can run without per-file chmod). Git's default
`core.fileMode=true` flags the mismatch between index (644) and
working tree (755) as 'modified'. The noise was environmental, not
from any script in the repo — confirmed by grep on all .sh files:
only `chmod +x .githooks/*` calls in install-hooks.sh, which doesn't
 touch the 17 noisy files.
- **Fix principle:** `git config core.fileMode false` makes git ignore
mode bit changes entirely (O(1) one-time config per clone). Beats:
  - `git checkout .` repeated cleanup (O(N) per session, symptom not
    cause)
  - `.gitattributes` (wrong tool — controls text/binary detection and
    line endings, not executable bits)
  - `git config --global core.fileMode false` (too broad — would affect
    repos where mode bits matter)
Existing index modes are preserved: 4 .sh files stay 100755, 16 docs
stay 100644. New .sh files need explicit `git update-index --chmod=+x`.
- **Applies-to:** Any git repo on a fs that doesn't preserve mode bits
correctly — sandbox mounts, Windows shares, certain container fs.
Concretely in our setup: platform repo + each of 3 submodules
(standards, guard, skills), each has own .git/config. Fix is local-only
(.git/config is not tracked), so must be re-applied on fresh clones —
this is what bootstrap.sh Step 2 now does automatically.
- **Source:** Worklog Task ID `mode-bit-noise-cleanup-2026-06-21`. User
directive: "да" after I proposed `.gitattributes` — which was the
wrong tool, corrected after investigating root cause. Same lesson as
LESSON-001: investigate before fixing, root-cause over symptom.
- **Promoted-to:** (empty; baked into bootstrap.sh Step 2 as automatic
application, no separate RULE-NNN needed unless the principle
generalises beyond fs-mount scenarios)

### 12.6. LESSON-003: promote soft warning to hard invariant (W11 → V11)

- **ID:** LESSON-2026-06-21-003
- **Status:** RECOGNIZED (corroborates LESSON-001 — same O(1)/O(N) principle
in a third domain: verifier design)
- **Trigger:** After pilot split of 3 long standards files (DESIGN-001,
DOC-002, META-001), `verify-id-graph.js` reported `13/13 HARD PASS, 0
warnings` — the cleanest result in project history. User asked: «это
система работает?» I diagnosed that W11=0 was **fragile**: W11 is a SOFT
warning (does not fail CI), so any future commit could add a >1000-line
file and silently regress to W11>0 without the pipeline objecting.
- **Root cause:** Two-layer verifier design where SOFT warnings (W-prefix,
exit 0) detect anomalies but cannot enforce prevention. The 1000-line
markdown cap existed as W11 since v1.1.0, but stayed a suggestion, not a
gate. The pilot split fixed the 3 existing offenders, but the next
contributor writing a 1100-line file would slip through unless they
happened to run the verifier and read its output.
- **Fix principle:** Promote W11's 1000-line markdown soft cap to V11, a
HARD invariant in `verify-standards.js` that exits 1 on violation. The
check uses `fs.readdirSync` (not an enumerated target list like V04/V08/V09)
so any NEW .md file added to `standards/` + `docs/sandbox/` + `templates/`
is automatically subject to the cap. This is the LESSON-001 pattern applied
to verifier design itself: O(1) encoded check beats O(N) manual review.
Beats the alternative (option A: cosmetic split of 2 long skills files)
which would have been O(N) — fix the 2 today, but the 3rd, 4th, 5th long
file could appear without resistance.
- **Applies-to:** Any SOFT warning that has fired ≥2 times in project
history and whose threshold has a clear "right answer" (split the file,
extract a sub-module, etc.). Candidate future promotions: W12 (§XA Known
Issues missing) → V12 if pattern recurs; W14 (excessive OPEN issues) → V14
if the open-issue backlog ever crosses the threshold twice in a quarter.
W13 was NOT promoted because it was already root-cause-fixed (LESSON-001)
— it cannot recur structurally, so a V13 hard check would add no value.
- **Scope of V11:** `standards/` + `docs/sandbox/` + `templates/` only.
Deliberately EXCLUDED: `docs/session/*.md` (worklog/SESSION_NOTES/
DECISIONS_LOG are append-only journals that grow by design); `scripts/*.js`
(verifier self-checking is a chicken-egg); `README.md` at repo root
(project landing page, not a standard). Threshold = 1000 lines (matches
W11 soft cap exactly — no threshold inflation).
- **Smoke test:** Created `templates/_v11_smoketest.md` with 1004 lines,
ran `verify-standards.js` → V11 FAIL (7/8). Removed file → 8/8 PASS.
Negative path verified.
- **Source:** Worklog Task ID `v11-hard-cap-promotion-2026-06-21`. User
chose option B over option A after I framed both: «A = O(N) cosmetic
split of 2 skills files; B = O(1) encoded prevention». Decision aligned
with LESSON-001 principle already encoded in §12.4.
- **Promoted-to:** (empty; the principle is now self-documenting via V11
itself — any future SOFT→HARD promotion follows the same recipe)

---

## 13. Phase A2 — Governance/execution gap audit

> Source: O-017 Phase A2 (skills execution contract cascade).
> Date: 2026-06-21.
> Companion file: `skills/docs/CATALOG.md` (Phase A1 deliverable).

This section audits the 6-row governance/execution gap table documented
in O-017's context section. For each row, it asks: does the repo today
contain ANY execution mechanism for this governance artifact? If yes,
how partial? If no, is the gap **blocking autonomous agents** or
**acceptable for now** (manual lookup works at current scale)?

The audit uses Phase A1's catalog findings (see CATALOG.md §5 — only
3 of 36 skills have `scripts/`, only 1 has `evals/`) as evidence.

### 13.1 Summary table

| # | Governance artifact | Execution mechanism present? | Classification |
|---|---|---|---|
| 1 | skills/ as descriptive .md | **Partial** — sandbox `Skill()` tool loads SKILL.md, but no contract (trigger/hook/guard-check). Only 3/36 skills have callable `scripts/`. | **BLOCKING** for autonomous agents |
| 2 | guard/ as RULE-NNN markdown | **None** — pre-commit hook enforces standards invariants (V01-V11, G01-G15), NOT RULE-NNN semantics. RULE-NNN is advisory only. | **BLOCKING** for autonomous agents |
| 3 | standards/ as STD-NNN | **Partial** — pre-commit hook runs `verify-standards.js` + `verify-id-graph.js` at commit boundary. This IS runtime (vs only-on-CI). No real-time linter (no eslint integration despite STD-DOC-002 existing). | **ACCEPTABLE FOR NOW** (pre-commit is strong; real-time linter is Phase D work) |
| 4 | worklog.md as append-only log | **None** — 3554-line append-only markdown. No ChromaDB instance. `memory-store`/`session-log`/`session-experience` skills describe the target architecture but no runtime wires it up. | **BLOCKING** for autonomous agents |
| 5 | DECISIONS_LOG D-NNN | **None** — 1157-line append-only markdown. No retrieval-by-context mechanism. No "trigger condition" on open questions (O-NNN). | **ACCEPTABLE FOR NOW** at current scale (~30 items); becomes blocking at 100+ decisions |
| 6 | SESSION_NOTES §12 LESSON | **None** — 3 LESSON entries in markdown. LESSON-003 → V11 promotion was done MANUALLY by user+agent. No automatic "pattern fired N times, promote to invariant". No reverse feedback (V11 blocking doesn't generate a new lesson). | **BLOCKING** for autonomous agents (the most sophisticated gap to close) |

**Score: 4 BLOCKING / 1 PARTIAL-ACCEPTABLE / 1 ACCEPTABLE.**

### 13.2 Per-row findings

#### Row 1 — skills/ runtime

**Evidence from CATALOG.md §5:**
- 3 of 36 skills (8%) have `scripts/` — real callable code:
  `skill-creator` (9 scripts), `session-handoff` (4), `qa-test-planner` (2).
- 1 of 36 skills (3%) has `evals/` — `session-handoff` only.
- 1 of 36 skills (3%) has `agents/` — `skill-creator` only.
- 33 of 36 skills (92%) are pure markdown — agent must read,
  interpret, and act manually.

**What's missing for autonomy:** A contract layer (the 5-tuple proposed
in O-017: trigger / hook / guard-check / standard-check / success-
criterion). Without it, agent must self-select which skill to invoke
for which situation, which is exactly what an autonomous runtime
should NOT do — it should be told.

**Closing phase:** O-017 Phase B (commit-work pilot contract) + Phase
C (generalize template). The 3 skills with `scripts/` are the only
existing models; `session-handoff` in particular is the model to
follow because its 4 scripts already implement create/validate/list/
check-staleness — the contract layer would wrap these, not invent them.

#### Row 2 — guard/ pre-flight

**Evidence from `.githooks/pre-commit`:** The pre-commit hook runs
`verify-standards.js` and `verify-id-graph.js`. Neither enforces
RULE-MONOLITH-NNN semantics. Examples of unenforced rules:
- `RULE-MONOLITH-001` (answer before act): no runtime checks "is agent
  about to take action without being asked? BLOCK."
- `RULE-MONOLITH-002` (worklog before/after every action): no runtime
  injects worklog checkpoints.
- `RULE-MONOLITH-003` (read before write): no pre-flight check exists
  that fails a write when no preceding read was logged.
- `RULE-MONOLITH-004` (one logical block, one commit): no commit-size
  check exists in the pre-commit hook.

**What's missing for autonomy:** A pre-flight checker that maps
RULE-NNN semantics to runtime guards. The guard format already
includes `level: [C|W|I]` (critical/warning/info) — the runtime needs
to respect this. Critical rules block; warning rules log.

**Closing phase:** Not directly in the O-017 cascade. Phase D
(governance) addresses skills/ governance; guard/ governance is a
parallel track that should be raised as a new open question (O-019
candidate) once Phase B's contract shape is validated. The contract
shape itself can be reused for guard rules: trigger / hook / guard-
check / standard-check / success-criterion applies just as well to
RULE-NNN as to skills.

#### Row 3 — standards/ linter

**Evidence from `.githooks/pre-commit` + `standards/scripts/`:** The
pre-commit hook is a real runtime enforcement layer — it runs at
every `git commit` (not just CI), blocks on failure (exit 1), and
covers 11 invariants (V01-V11) plus 15 hard structural checks
(G01-G15) plus 5 soft warnings (W11-W15). This is the **strongest
execution layer in the 4-module system today**.

**What's missing for autonomy:** Real-time linter integration. The
agent writes code/commits without immediate feedback; the pre-commit
hook catches issues only at commit time. STD-DOC-002 already specifies
eslint integration but no `.eslintrc` exists in the platform.

**Closing phase:** Phase D (governance). Specifically:
- D1 (`verify-skills.js`) creates a skills-side verifier analogous to
  `verify-standards.js`. Same pre-commit runtime, new check surface.
- A separate task (not yet in O-017 cascade, candidate for O-020)
  would add the actual eslint integration — this is downstream of
  Phase D1 because eslint rules may reference skill contracts.

**Why "acceptable for now":** Pre-commit is a strong boundary. Real-
time linter is a quality-of-life improvement, not a blocker for
autonomous agents. The agent CAN commit broken work and fix it on the
next iteration; what it cannot do is commit work that violates
invariants (V01-V11, G01-G15 block).

#### Row 4 — worklog.md memory

**Evidence from `docs/session/worklog.md`:** 3554-line append-only
markdown with structured per-task entries (Task ID / Agent / Task /
Work Log / Stage Summary). No semantic-retrieval layer.

**Evidence from skills/:** Three skills describe the target architecture:
- `session-log` (ZAI-SESSION-001) — auto-log session activity to ChromaDB.
- `session-experience` (ZAI-SESSION-003) — extract lessons via GLM-4.5,
  one lesson per ChromaDB record.
- `memory-store` (ZAI-MEM-001) — references `~/.zcode/tools/memory_cli.py`
  for ChromaDB access.

None of these skills is wired up in Z-ai-platform. `~/.zcode/tools/
memory_cli.py` does not exist. No ChromaDB instance is running. The
skills are governance (how to use memory if you have it); the runtime
(actual ChromaDB) is missing.

**What's missing for autonomy:** Persistent memory with semantic
retrieval. Without it, agent repeats mistakes — it cannot ask "what
did I try last time I hit this bug?" or "what was the rationale for
D-005?".

**Closing phase:** Phase E (consumer integration). Specifically:
- E1 (onboard P-MAS_init as first consumer) will install ChromaDB in
  a real consumer context. The session-* skills will become callable
  for the first time.
- Until E1, the gap stays blocking. The 3554-line worklog is a
  fallback (full-text search works at this scale), but it doesn't
  scale to "agent retrieves relevant past experience by semantic
  similarity".

#### Row 5 — DECISIONS_LOG decision mechanism

**Evidence from `docs/session/DECISIONS_LOG.md`:** 1157-line markdown
with structured entries (D-NNN decided, O-NNN open). Includes Date,
Status, Context, Decision, Rationale, Trade-offs, Cross-references.

**What's missing for autonomy:** Two things:
1. **Retrieval-by-context.** Agent must read the entire log to find a
   relevant decision. At 30 items, this is fine. At 100+, it becomes
   a real cost.
2. **Trigger conditions on open questions.** O-NNN entries sit in
   markdown. No mechanism auto-resurfaces O-NNN when its trigger
   condition is met (e.g., O-015 said "defer to consumer-integration
   phase" — nothing automatically reopens O-015 when Phase E starts).

**Why "acceptable for now":** At 1157 lines / ~30 items, manual lookup
works. The cost of building retrieval infrastructure exceeds the cost
of manual lookup. This changes when DECISIONS_LOG grows past ~100
items, OR when an autonomous agent needs to make decisions faster than
human-reads-markdown speed.

**Closing phase:** Not directly in O-017 cascade. Candidate for a
future Phase G (memory layer) that would address Rows 4+5+6 together
since all three need a persistent semantic store. The session-*
skills + memory-* skills already define the API; what's missing is
the runtime. P-MAS_init onboarding (Phase E1) will surface this need
concretely.

#### Row 6 — SESSION_NOTES §12 feedback loop

**Evidence from §12 of this file:** 3 LESSON entries (LESSON-001/002/
003). Each follows the pattern: Problem → Wrong fix → Root-cause fix
→ Pattern → Cross-references → Promoted-to. The pattern across all 3
is "root-cause fix scales as O(1), symptom/whitelist fix scales as
O(N)" — three corroborations in three domains (W13 stripCh,
core.fileMode, V11 promotion).

**What's missing for autonomy:** The feedback loop is the most
sophisticated gap. Three missing pieces:
1. **Detection.** No mechanism that recognizes "this pattern has fired
   N times" automatically. LESSON-001/002/003 were all recognized by
   the human+agent pair, not by a runtime.
2. **Promotion.** No mechanism that promotes a lesson into a runtime
   rule. LESSON-003 → V11 was done manually (user asked "is the system
   really working?", agent diagnosed W11=0 as fragile, agent proposed
   V11, user approved, agent implemented, agent ran smoke test).
3. **Reverse feedback.** V11 blocking a commit doesn't generate a new
   lesson. The hard cap just fires; the agent doesn't learn "this is
   the 3rd time a 1200-line file was attempted, maybe the cap should
   be raised" or "this is the 1st time a 1100-line file was attempted,
   maybe it should be split into 2 files of 550 each".

**Why BLOCKING:** Without the feedback loop, the system can grow
governance (more rules, more invariants) but cannot grow execution
(better runtime decisions). The 4-module system today is in a state
where every improvement is manual — agent proposes, user approves,
agent implements. That is not autonomous.

**Closing phase:** Long-term. Phase F (dashboard) is a prerequisite —
the dashboard visualizes the gap, making detection possible. Phase G
(memory layer, candidate) is the actual implementation. Realistically
this is 6-12 months out, post-Phase E. The LESSON-001 pattern (root-
cause beats symptom) is the principle that should guide every closure:
don't build a mechanism that catches violations, build a mechanism
that makes violations impossible.

### 13.3 Cascade implications

The audit confirms O-017's cascade is correctly ordered:

- **Phase B (commit-work pilot)** addresses Row 1 directly.
- **Phase C (generalize template)** addresses Row 1 for the next 2-3
  skills, building evidence for the contract shape.
- **Phase D (governance: verify-skills.js + tiered caps)** addresses
  Row 3's skills-side runtime (analogous to verify-standards.js).
- **Phase E (consumer integration)** addresses Row 4 (memory runtime
  gets wired up in a real consumer context) and surfaces Rows 5+6 as
  concrete needs.
- **Phase F (dashboard)** addresses Row 6's detection gap by making
  patterns visible.

Rows 2 (guard pre-flight) and 6 (feedback loop) are NOT directly in
the cascade. They should be raised as new open questions:
- **O-019 candidate** (Row 2): guard/ execution contract. Same 5-
  tuple shape as skills contract, applied to RULE-NNN. Pilot rule:
  RULE-MONOLITH-004 (one logical block, one commit) — natural fit
  with commit-work Phase B pilot.
- **O-020 candidate** (Row 6): feedback-loop mechanism. Long-term,
  depends on Phase F dashboard + Phase G memory layer.

### 13.4 Honest uncertainties

1. **"Blocking for autonomous agents" is a threshold call.** A system
   without Row 1 (skills contract) is clearly not autonomous. A
   system without Row 5 (decision retrieval) is arguably still
   autonomous at small scale — the agent can read all 30 decisions
   in 2 minutes. The classification "blocking" assumes target scale
   of 100+ decisions / 100+ skills / multiple consumer projects.

2. **Closing order may diverge from cascade order.** Phase B might
   reveal that the contract shape doesn't generalize, forcing a
   redesign that affects Phase D's verifier. Phase E might surface
   that P-MAS_init's dashboard needs feedback-loop data (Row 6) that
   doesn't exist yet, pulling Phase G forward.

3. **Row 6 (feedback loop) is genuinely hard.** It requires the agent
   to recognize patterns, abstract them, and propose rule updates —
   exactly the cognitive task that distinguishes "agent" from
   "script". A partial implementation (e.g., "log every V11 trigger
   to a file; agent reviews weekly") is achievable; a full
   implementation (agent proposes rule updates autonomously) is
   research-grade.

---

## Change History

| Date | Change |
|---|---|
| 2026-06-17 | Initial creation. Captured all lessons from the 2026-06-17 session: GitHub Actions gotchas (3), PAT gotchas (2), submodule gotchas (4), verifier gotchas (4), Unicode findings (3), standards inventory (20 files), workspace persistence (3 subsections). |
| 2026-06-18 | Added §9 (sandbox persistence model from "Про скилы" package), §10 (final keep/drop decision for Z.ai Sandbox Documentation), §11 (ready-to-use Unicode regex filters with implementation pointer). Closes O-006, O-007; introduces O-008..O-014 in DECISIONS_LOG.md. |
| 2026-06-21 | Added §12 (Structured lessons registry) with LESSON-001 (W13 stripCh root-cause fix vs whitelist). Fills the layer between §1-5 topic gotchas and §8 bridge table to D-NNN. T3 = ChromaDB-via-toolkit plan explicitly deprecated per user guidance (toolkit may be killed/reworked); §12 stays portable markdown. |
| 2026-06-21 | Added §12.5 LESSON-002 (core.fileMode=false beats repeated `git checkout .` for sandbox fs-mount mode-bit noise). Corroborates LESSON-001: same principle (root-cause fix O(1) beats symptom cleanup O(N)) in a different domain. Fix baked into bootstrap.sh Step 2 for durability across session restarts. |
| 2026-06-21 | Added §12.6 LESSON-003 (promote W11 soft warning to V11 hard invariant). Corroborates LESSON-001 in a third domain (verifier design): O(1) encoded check beats O(N) manual review. V11 implemented in `verify-standards.js` (8/8 PASS, smoke-tested with 1004-line file → FAIL as expected). Closes the "W11=0 fragile" gap diagnosed when user asked «это система работает?» after the pilot split reached 13/13 PASS, 0 warnings. |
| 2026-06-21 | Added §13 (Phase A2 governance/execution gap audit). O-017 Phase A2 deliverable. Audits the 6-row gap table from O-017 context against actual repo state. Result: 4 BLOCKING / 1 PARTIAL-ACCEPTABLE / 1 ACCEPTABLE. Confirms cascade ordering (Phase B→C→D→E→F). Surfaces 2 new open question candidates: O-019 (guard/ execution contract, parallel to skills contract) and O-020 (feedback-loop mechanism, long-term). Companion to `skills/docs/CATALOG.md` (Phase A1 deliverable). |
