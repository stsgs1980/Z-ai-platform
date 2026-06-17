# Decisions Log

> Purpose: Track architectural decisions and open questions for the Z-ai
> platform. Each entry is dated and labelled DECIDED (closed) or OPEN
> (awaiting resolution). Open questions MUST be resolved before the
> affected artifacts can be promoted out of stub state.
>
> Location: `Z-ai-platform/docs/session/DECISIONS_LOG.md`
> Last Updated: 2026-06-17

---

## Index

- [D-001] 4-repo split with submodules (L0-L3) — DECIDED
- [D-002] Atomic per-submodule pointer bumps — DECIDED
- [D-003] Clean HTTPS URLs in .gitmodules (no embedded PATs) — DECIDED
- [D-004] ID graph verifier as the cross-repo enforcement mechanism — DECIDED
- [D-005] `Related:` DAG direction rules (STD→STD only, RULE→anything) — DECIDED
- [D-006] `Aligned_with:` as undirected peer edge (may cross layers) — DECIDED
- [D-007] Compatibility DAG for ZAI skills (both/sandbox/ade) — DECIDED
- [D-008] Soft vs hard warnings (W-checks do not block CI) — DECIDED
- [D-009] CI workflow triggers (push, PR, nightly, manual) — DECIDED
- [D-010] GitHub Actions workflow lives in Z-ai-platform (orchestrator) — DECIDED
- [O-001] STD-ARCH-001 ID collision — OPEN
- [O-002] Import 20 standards from upload/standards-v2/ — strategy not decided — OPEN
- [O-003] Unicode compliance check in verifier — soft or hard — OPEN
- [O-004] Fix Unicode violations in existing 118 MD files — when and how — OPEN
- [O-005] Box-drawing ASCII tree diagrams in README — waiver or convert — OPEN
- [O-006] Local workspace persistence strategy — OPEN
- [O-007] Consumer-project onboarding flow — OPEN

---

## Decided

### D-001: 4-repo split with submodules (L0-L3)

**Date:** 2026-06-17
**Status:** DECIDED
**Decided by:** maintainer (stsgs1980)

The Z-ai ecosystem is split into four repositories:

| Repo | Layer | Purpose |
|---|---|---|
| `Z-ai-platform` | L0 | Orchestrator: pins submodules, runs cross-repo CI |
| `Z-ai-standards` | L1 | Standards (`STD-*`), verifiers (`verify-*.js`) |
| `Z-ai-guard` | L2 | Rules (`RULE-*`), procedures (`PROC-*`), tools (`TOOL-*`) |
| `Z-ai-skills` | L3 | Skills (`ZAI-*`), skill catalog |

**Rationale:** Each layer evolves independently. Standards can be amended
without forcing rule/skill updates. Guard ships rule changes on its own
cadence. Skills can be consumed standalone by the sandbox runtime. The
4-repo split makes the cross-repo ID graph verifier meaningful (a
monorepo would not catch the same class of drift).

**Formalized in:** `Z-ai-standards/standards/STD-ARCH-001-v1.0.md` §4.

**Reversal cost:** High. Renumbering artifacts across repos, updating
all `Related:` edges, breaking consumer project onboarding. Reversal
would require a major-version bump of STD-ARCH-001.

---

### D-002: Atomic per-submodule pointer bumps

**Date:** 2026-06-17
**Status:** DECIDED

A single orchestrator commit touches at most one submodule's pointer.
The orchestrator's own files (README, CI, hooks) MAY be touched in the
same commit, but two submodule pointers in one commit is forbidden.

**Rationale:**
1. Makes `git bisect` possible (which submodule caused the failure?).
2. Makes commit messages unambiguous.
3. Aligns with `verify-id-graph.js` assumption that one bump = one
   logical change.

**Formalized in:** `Z-ai-standards/standards/STD-ARCH-001-v1.0.md` §8.3.

**Violation example (forbidden):**
```
commit abc1234
    Bump standards and guard (combined release)
```

**Compliant example:**
```
commit abc1234
    Bump standards: 447725b → 85df73b (add STD-ARCH-001 v1.0)

commit def5678
    Bump guard: 676bdbe → 97d2911 (add Related: STD-ARCH-001)
```

---

### D-003: Clean HTTPS URLs in .gitmodules (no embedded PATs)

**Date:** 2026-06-17
**Status:** DECIDED

All `url =` lines in `.gitmodules` MUST match
`^https://github\.com/<owner>/<repo>\.git$`. No embedded credentials
(`https://<user>:<token>@github.com/...`).

**Rationale:**
1. GitHub Secret Scanner auto-revokes PATs found in tracked files.
   This happened three times in the initial session before this rule
   was enforced.
2. PATs in `.gitmodules` leak into the commit history permanently
   (short of `git filter-branch`).
3. Submodule operations (`git submodule update`) use `~/.git-credentials`
   or `credential.helper store` for authentication, not embedded URLs.

**Formalized in:** `Z-ai-standards/standards/STD-ARCH-001-v1.0.md` §6.1.

---

### D-004: ID graph verifier as the cross-repo enforcement mechanism

**Date:** 2026-06-17
**Status:** DECIDED

`verify-id-graph.js` (in `Z-ai-standards/scripts/`) is the single
mechanical enforcement of cross-repo invariants. It runs:
- Locally via `node standards/scripts/verify-id-graph.js`
- In CI via `.github/workflows/verify-id-graph.yml`

It enforces 13 HARD checks (G01-G15) and reports 10 soft warnings
(W01-W10). HARD checks block CI; soft warnings do not.

**Rationale:** Without mechanical enforcement, drift between repos is
inevitable. Manual review cannot catch every `Related:` reference that
points to a deleted ID, every cycle in the dependency graph, or every
forbidden layer-crossing edge.

**Limitations:** The verifier does NOT check:
- Prose references (e.g. "see STD-ENV-008" in markdown body text)
- Content consistency between aligned artifacts
- Unicode compliance (yet — see O-003)

These gaps are tracked as open questions or future work.

---

### D-005: `Related:` DAG direction rules

**Date:** 2026-06-17
**Status:** DECIDED

The `Related:` field declares directed dependencies. The allowed edges
are governed by a layer matrix:

| Source \ Target | STD | RULE | PROC | TOOL | ZAI |
|---|---|---|---|---|---|
| STD | yes | no | no | no | no |
| RULE | yes | yes | yes | yes | yes |
| PROC | yes | yes | yes | yes | no |
| TOOL | yes | yes | no | yes | no |
| ZAI | yes | yes | no | yes | yes |

**Key invariant:** STD → STD only. Standards are self-contained; they
describe what is true but do not prescribe behavior, invoke procedures,
or call tools/skills.

**Formalized in:** `Z-ai-standards/standards/STD-META-001-v2.0.md` §6.1.

---

### D-006: `Aligned_with:` as undirected peer edge

**Date:** 2026-06-17
**Status:** DECIDED

`Aligned_with:` declares that two artifacts are kept in sync (typically
a standard and a skill that implements the same thresholds). It is NOT a
dependency; it is a peer relationship.

**Rules:**
1. Symmetric but declared on one side only (warning W08 if not
   reciprocated for human readability).
2. May cross any layers (STD ↔ ZAI, STD ↔ RULE, etc.).
3. Excluded from the DAG cycle check (G11).
4. MUST have a corresponding `Related:` edge in at least one direction
   (enforced by G15).

**Formalized in:** `Z-ai-standards/standards/STD-META-001-v2.0.md` §6.3.

---

### D-007: Compatibility DAG for ZAI skills

**Date:** 2026-06-17
**Status:** DECIDED

ZAI skills with IDs declare a `compatibility` field in YAML frontmatter:
`both` (works in Z.ai Sandbox and ZCode ADE), `sandbox` (Sandbox only),
`ade` (ADE only).

**Allowed edges:**
| Source | May depend on target |
|---|---|
| both | both only |
| sandbox | both, sandbox |
| ade | both, ade |

**Enforced by:** `verify-id-graph.js` G14.

**Formalized in:** `Z-ai-standards/standards/STD-META-001-v2.0.md` §6.4.

---

### D-008: Soft vs hard warnings

**Date:** 2026-06-17
**Status:** DECIDED

- **HARD checks (G01-G15):** Block CI. Must be 13/13 PASS for merge.
- **Soft warnings (W01-W10):** Reported but do not block CI. Indicate
  technical debt that should be addressed but is not blocking.

**Current state (2026-06-17):** 13/13 HARD PASS, 0 soft warnings.

---

### D-009: CI workflow triggers

**Date:** 2026-06-17 (revised)
**Status:** DECIDED

`.github/workflows/verify-id-graph.yml` triggers on:
1. Push to `main` in Z-ai-platform (any path)
2. Pull request to `main`
3. Nightly at 03:00 UTC (= 06:00 Europe/Moscow)
4. Manual dispatch

**Revision history:** Initially, the push trigger had a `paths:` filter
limiting it to `standards/**`, `guard/**`, `skills/**`, `.gitmodules`,
and the workflow file itself. This was discovered to be broken because
GitHub Actions path filters do NOT fire on submodule pointer bumps
(submodule bumps are gitlink changes, not file changes). The filter was
dropped in commit 7c3461f.

---

### D-010: GitHub Actions workflow lives in Z-ai-platform

**Date:** 2026-06-17
**Status:** DECIDED

The cross-repo verifier workflow lives in `Z-ai-platform/.github/workflows/`
because only the orchestrator has all three submodules checked out
together.

**Consequence:** Pushing to `.github/workflows/*` requires a PAT with
`Workflows: Read and write` permission. `Contents: write` alone is
insufficient. Fine-grained PATs without this scope return HTTP 403 on
any push that includes workflow file changes.

---

## Open

### O-001: STD-ARCH-001 ID collision

**Date raised:** 2026-06-17
**Status:** OPEN
**Blocks:** Import of `IMPLEMENTATION_ORDER.md` from upload/standards-v2/

**The conflict:**

The original `IMPLEMENTATION_ORDER.md` (in
`upload/standards-v2/standards/`, 14.2 KB) declares:
```
ID: STD-ARCH-001
Version: 2.2
Title: Implementation Order
Scope: Implementation sequence for all project documents (6-step Path A
       and adapted Path B for existing projects)
```

In this session, I authored a new standard with the same ID:
```
ID: STD-ARCH-001
Version: 1.0.0
Title: Architecture & Repo Layout
Scope: Repository topology, layer assignment, submodule conventions,
       pointer update protocol, recovery procedures
```

Both files claim `STD-ARCH-001` but describe different concerns. The
original is about **deployment sequence**; mine is about **repository
topology**. They are complementary, not duplicates.

**Options:**

| Option | Action | Pros | Cons |
|---|---|---|---|
| (a) | Rename my v1.0 to `STD-ARCH-002` (Repo Topology); give `STD-ARCH-001` back to IMPLEMENTATION_ORDER | Preserves upstream ID assignment; minimal disruption to upload/ sources | My v1.0 was already pushed and referenced by RULE-MONOLITH-016/017 — those `Related:` edges need updating |
| (b) | Make IMPLEMENTATION_ORDER → `STD-META-002` (it is meta-level: deployment sequence for standards themselves) | Cleanly separates topology (ARCH) from deployment (META) | Diverges from upstream ID; future imports of upload/ docs need a mapping table |
| (c) | Make IMPLEMENTATION_ORDER → `STD-PROC-001` (new domain for deployment procedures) | Most semantically accurate (it is a procedure, not a standard) | Requires adding `PROC` domain to STD- prefix (currently PROC- is L2 only, in Z-ai-guard) |
| (d) | Keep my v1.0 as `STD-ARCH-001`; import IMPLEMENTATION_ORDER as an appendix to it | No ID changes | Mixes two concerns in one file; loses the 6-step sequence as a first-class artifact |

**Recommendation:** Option (a). Renaming my v1.0 to `STD-ARCH-002` is
the least-bad option because:
- It preserves the upstream `STD-ARCH-001 = IMPLEMENTATION_ORDER` mapping
- RULE-MONOLITH-016/017 only need their `Related:` field updated
  (mechanical fix, ~2 minutes)
- The topology standard deserves its own ID anyway — it is a distinct
  concern from deployment sequence

**Decision needed from:** maintainer (stsgs1980)

---

### O-002: Import 20 standards from upload/standards-v2/ — strategy

**Date raised:** 2026-06-17
**Status:** OPEN

`upload/standards-v2/standards/` contains 20 ready-to-import standards
(see `SESSION_NOTES.md` §"Available standards inventory"). Decisions
required:

1. **All at once or staged?**
   - (a) All 20 in one PR (large but atomic)
   - (b) Staged by domain (e.g. ENV+SEC first, then DOC+META, then
     FE+DESIGN, then TEST+ERR, then AGENT+GIT)
   - (c) Staged by priority (critical [C] first, then warning [W])

2. **Normalization required per file:**
   - Convert headers to STD-META-001 §5.1 blockquote format
   - Assign correct IDs (some files use old IDs that conflict with our
     current registry)
   - Add `Related:` edges according to the layer matrix (D-005)
   - Fix Unicode violations (em-dash, emoji, smart quotes — see O-004)

3. **Stub replacement:** 4 of our 6 current standards are stubs
   (`STD-DOC-002`, `STD-ENV-001`, `STD-ENV-002`, `STD-ARCH-001` if we
   keep option (a) from O-001). Should stubs be replaced in the same
   PR as the import, or in a follow-up?

4. **New IDs needed:** Some upload/ files have no current ID assignment:
   - `CODE_EXAMPLES_GUIDE.md` → `STD-DOC-005`
   - `DESIGN_SYSTEM_STANDARD.md` → `STD-DESIGN-001`
   - `FRONTEND_STANDARD.md` → `STD-FE-001`
   - `GITHUB_SANDBOX_STANDARD.md` → `STD-GIT-002`
   - `GITHUB_STANDARD.md` → `STD-GIT-001`
   - `ORCHESTRATION_STANDARD.md` → `STD-AGENT-002`
   - `README_TEMPLATE.md` → `STD-DOC-004`
   - `SECURITY_EXTENDED_STANDARD.md` → `STD-SEC-002`
   - `SECURITY_STANDARD.md` → `STD-SEC-001`
   - `SUBAGENT_STANDARD.md` → `STD-AGENT-001`
   - `TESTING_STANDARD.md` → `STD-TEST-001`
   - `WCAG_2.1_AA_STANDARD.md` → `STD-A11Y-001`
   - `ZAI_INTEGRATION_STANDARD.md` → `STD-ENV-002` (already a stub)
   - `ERROR_HANDLING_STANDARD.md` → `STD-ERR-001`
   - `ERROR_RECOVERY_STANDARD.md` → `STD-ERR-002`
   - `REPRODUCIBILITY-STANDARD.md` → `STD-ENV-001` (already a stub)
   - `STANDARD_ID_SYSTEM.md` → already imported as `STD-META-001 v2.0`
   - `MARKDOWN_STANDARD.md` → `STD-DOC-002` (already a stub)
   - `UNICODE_POLICY.md` → `STD-DOC-003` (new ID, not in our registry)
   - `IMPLEMENTATION_ORDER.md` → see O-001

5. **Registry update:** `STD-META-001-v2.0.md` §4 has a partial
   registry. After import, it must list all 20+ standards.

**Recommendation:** Staged by domain (option 1b). Start with DOC
(MARKDOWN, UNICODE, README_TEMPLATE, CODE_EXAMPLES) because they are
prerequisites for compliance checking of all other imports.

**Decision needed from:** maintainer (stsgs1980)

---

### O-003: Unicode compliance check in verifier — soft or hard

**Date raised:** 2026-06-17
**Status:** OPEN

`UNICODE_POLICY.md` (STD-DOC-003) prohibits emoji, box-drawing
characters, em-dash in headings/tables/code, smart quotes in code. The
current `verify-standards.js` does NOT check this — it only checks
header format and registry sync.

**Options:**
- (a) Add Unicode checks as new soft warnings (W11-W15). Non-blocking.
- (b) Add Unicode checks as new HARD checks (G16-G20). Blocking.
- (c) Add as soft first, promote to hard after a cleanup cycle.

**Current violations (from scan on 2026-06-17):**
- 307 emoji occurrences across 118 MD files
- 297 em-dash occurrences
- 28 en-dash occurrences (12 in STD-META-001 itself!)
- 2801 box-drawing characters (mostly ASCII tree diagrams)
- 7 smart quotes

**Recommendation:** Option (c). Add as soft warnings immediately to
get visibility, then promote to hard after O-004 cleanup is complete.
Promoting to hard immediately would block all CI until cleanup is done.

**Decision needed from:** maintainer (stsgs1980)

---

### O-004: Fix Unicode violations in existing 118 MD files

**Date raised:** 2026-06-17
**Status:** OPEN
**Depends on:** O-003

**Strategy options:**
1. Write `scripts/fix-unicode-compliance.js` to auto-fix:
   - Replace `—` (em dash, U+2014) → `--` in headings/tables/code
     (preserve in prose per STD-DOC-002 §4.1)
   - Replace `–` (en dash, U+2013) → `-`
   - Delete emoji
   - Replace smart quotes with straight quotes
2. Manual review for box-drawing tree diagrams (see O-005)
3. Prioritize:
   - First: authored documents (README, CONTRIBUTING, STD-ARCH-001,
     STD-META-001, STD-SKILL-001)
   - Then: rules (RULE-MONOLITH-001 through 017)
   - Then: skills (35 SKILL.md files, many from legacy toolkit)

**Estimated effort:** 1-2 hours for auto-fix script + manual review of
waivers.

---

### O-005: Box-drawing ASCII tree diagrams in README

**Date raised:** 2026-06-17
**Status:** OPEN

`README.md` uses 123 box-drawing characters (`├`, `└`, `│`, `─`) for
the repository layout tree. This violates UNICODE_POLICY §4.2 (table
pseudographics, [W] Warning level).

**Options:**
- (a) Convert to markdown nested lists (compliant but visually less
  clear for directory trees)
- (b) Convert to markdown tables (compliant, but awkward for nested
  trees)
- (c) Request a waiver for ASCII tree diagrams in documentation
- (d) Use plain ASCII (`+--`, `|`, `\--`) instead of box-drawing

**Recommendation:** Option (d). Plain ASCII trees are equally clear,
fully Unicode-compliant, and require no policy waiver.

**Example transformation:**
```
Before:                  After:
Z-ai-platform/           Z-ai-platform/
├── .gitmodules          +-- .gitmodules
├── README.md            +-- README.md
└── standards/           \-- standards/
    └── STD-META-001.md      \-- STD-META-001.md
```

---

### O-006: Local workspace persistence strategy

**Date raised:** 2026-06-17
**Status:** OPEN

The local workspace at `/home/z/my-project/` was wiped between sessions:
- `Z-ai-platform/` directory disappeared
- `worklog.md` was deleted
- `.gitignore` was reset to a minimal version
- Only `upload/` (read-only sources) and `skills/` (sandbox) survived

**Root cause:** Unknown. Possibly a session restart that clears non-
persistent state, possibly a cleanup script.

**Impact:** All local-only artifacts (worklog, session notes, decisions
log, in-progress edits) are lost. Only pushed-to-GitHub content
survives.

**Mitigation options:**
- (a) Push all session artifacts to GitHub after each task (current
  approach with this commit)
- (b) Maintain a `Z-ai-platform/docs/session/` directory that is the
  source of truth for worklog/notes/decisions, cloned fresh each session
- (c) Use a separate `Z-ai-session-state` repo for cross-session state
  (overkill for current needs)

**Recommendation:** Option (b). This commit establishes
`Z-ai-platform/docs/session/` as the canonical location. Future
sessions clone Z-ai-platform with submodules and read the session docs
to recover context.

---

### O-007: Consumer-project onboarding flow

**Date raised:** 2026-06-17
**Status:** OPEN

There is no documented flow for how a consumer project (e.g. a Next.js
app built by an AI agent) consumes Z-ai-skills as a dependency.

**Open questions:**
- Does the consumer clone Z-ai-skills as a submodule, or copy files?
- Does the consumer need Z-ai-standards and Z-ai-guard, or just skills?
- How does the consumer's CI verify that referenced `ZAI-*` IDs still
  exist upstream?
- Is there a `proc-setup-001` (PROC-SETUP-001) procedure for consumer
  onboarding?

**Not blocking current work** but should be addressed before the
platform is advertised as ready for external consumers.

---

## Change History

| Date | Change |
|---|---|
| 2026-06-17 | Initial creation. Added D-001 through D-010 (all decided in this session) and O-001 through O-007 (open questions identified). |
