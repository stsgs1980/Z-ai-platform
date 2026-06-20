# Decisions Log

> Purpose: Track architectural decisions and open questions for the Z-ai
> platform. Each entry is dated and labelled DECIDED (closed) or OPEN
> (awaiting resolution). Open questions MUST be resolved before the
> affected artifacts can be promoted out of stub state.
>
> Location: `Z-ai-platform/docs/session/DECISIONS_LOG.md`
> Last Updated: 2026-06-18

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
- [O-006] Local workspace persistence strategy — RESOLVED (see SESSION_NOTES §9)
- [O-007] Consumer-project onboarding flow — RESOLVED (see SESSION_NOTES §9.3)
- [O-008] MAS "Skill & Standard Factory" as long-term roadmap — OPEN
- [O-009] Standard typology (TECHNICAL/MANAGEMENT/COMPLIANCE/GUIDANCE) — OPEN
- [O-010] Recommendations R1-R18 from WIKI structure doc — OPEN
- [O-011] Reconcile our 35-skill catalog with 88-skill inventory — OPEN
- [O-012] Add ui-clarity_sts (6-phase UI redesign methodology) to catalog — OPEN
- [O-013] Reserve MAS agent IDs (ZAI-ORCH-001, ZAI-META-003/004, ZAI-CORE-001) — OPEN
- [O-014] Z.ai Sandbox Documentation final triage — DECIDED

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

### O-008: MAS "Skill & Standard Factory" as long-term roadmap

**Date raised:** 2026-06-18
**Status:** OPEN (long-term roadmap, not blocking)

**Source:** `Архитектура полноценной агентной системы MAS для создания_валидации_поддержки жизненного цикла скиллов и стандартов.MD` (package "Про скилы").

The source proposes a 5-agent Multi-Agent System for skill/standard lifecycle:

| Agent | Role | Proposed ID | Safety level |
|---|---|---|---|
| Orchestrator | Routes requests, holds context, gatekeeper | `ZAI-ORCH-001` | L2 (User-approved) |
| Skill Forge | Authors skills (knows 9 skill types) | `ZAI-META-003` | L1 (Sandboxed) |
| Standardizer | Authors standards (TECH/MGMT/COMP/GUIDANCE) | `ZAI-STD-001` | L1 (Sandboxed) |
| Guardian | QA + security auditor, read-only | `ZAI-META-004` | L0 (Read-only) |
| Registry Manager | Single writer for `skill-registry.json` | `ZAI-CORE-001` | L2 (User-approved) |

**Phased roadmap proposed by the source:**

| Phase | Duration | Scope | Our status |
|---|---|---|---|
| Phase 1: Monolith | 1-2 days | One big SKILL.md with branching logic ("if skill then template A, if standard then template B, always self-check at end") | **WE ARE HERE** (skill-creator + verify-id-graph.js + verify-standards.js form a monolithic pipeline) |
| Phase 2: Separation of duties | ~1 week | Extract Guardian as standalone script called via tool-calling | Partially done (`verify-standards.js` is L0 read-only), but not yet invoked through tool-calling |
| Phase 3: Full MAS | ~1 month | All 5 agents, external coordination (LangGraph/AutoGen), needed at >100 skills + >20 standards | NOT STARTED (we have 35 skills + 6 standards) |

**Decision points (not yet made):**

1. Do we adopt this roadmap formally as the long-term evolution path?
2. Should the source artifact (MAS MD + PlantUML sequence diagram) be preserved in `Z-ai-platform/docs/` as a reference, or only summarized in SESSION_NOTES?
3. Phase 2 extraction: should `verify-id-graph.js` + `verify-standards.js` be moved to a dedicated `guardian/` subagent directory with explicit tool-calling interface?

**Recommendation:** Adopt as roadmap. Mark Phase 1 complete (current state). Defer Phase 2/3 until skill count exceeds 50 (currently 35).

**Source artifact preservation:** The PlantUML sequence diagram (`Архитектура полноценной агентной системы MAS plant uml.txt`) is the only known formalization of the 4-phase, 22-step skill-creation lifecycle. It should NOT be lost. Decision: keep the source files in `upload/Про скилы unpacked/` until O-013 (ID reservation) is resolved, then archive the extracted knowledge into the appropriate `Z-ai-skills/skills/<agent>/SKILL.md` files.

---

### O-009: Standard typology (TECHNICAL / MANAGEMENT / COMPLIANCE / GUIDANCE)

**Date raised:** 2026-06-18
**Status:** OPEN (informational, may inform O-002)

**Source:** `ЕДИНАЯ МНОГОУРОВНЕВАЯ СТРУКТУРА WIKI ...md` §5 (package "Про скилы").

The source proposes a 4-type taxonomy for standards:

| Type | What it covers | Required components |
|---|---|---|
| TECHNICAL | How to do (implementation) | Metric threshold, Code example, Linter/CI rule, Exception process |
| MANAGEMENT | Who is responsible + what to do on failure | RACI matrix, Escalation path, SLA/SLO, Consequence ladder |
| COMPLIANCE | Conformance to external requirements | External mapping, Evidence artifact, Control objective, Audit procedure |
| GUIDANCE | Process, recommendation, best practice | (informal, no mandatory components) |

**Current state of our 6 standards:**

| ID | Title | Current type (implicit) | Should be |
|---|---|---|---|
| STD-META-001 | Standard ID System | TECHNICAL | TECHNICAL |
| STD-ARCH-001 | Architecture & Repo Layout | TECHNICAL | TECHNICAL |
| STD-SKILL-001 | Skill Catalog | TECHNICAL | TECHNICAL |
| STD-ENV-001 | Reproducibility | TECHNICAL | TECHNICAL |
| STD-ENV-002 | ZAI Integration | TECHNICAL | TECHNICAL |
| STD-DOC-002 | Markdown Standard | TECHNICAL | TECHNICAL |

All 6 of ours are TECHNICAL. The 20 upload/standards-v2/ files (O-002) are also predominantly TECHNICAL, with potential MANAGEMENT candidates in `GITHUB_STANDARD.md` (RACI for repo maintainers) and `SUBAGENT_STANDARD.md` (escalation paths).

**Decision points:**

1. Should we add a `type:` field to the standard YAML frontmatter? (currently absent)
2. Should STD-META-001 §4 (the registry) gain a `type` column?
3. Should we import the typology into STD-META-001 §2 (scope) as informative subsection?

**Recommendation:** Add `type:` field to standard frontmatter in the next STD-META-001 revision (v2.1). Default to TECHNICAL. Add the 4-type table as §2.1 informative subsection. No hard enforcement initially — this is a tagging aid for O-002 import prioritization.

---

### O-010: Recommendations R1-R18 from WIKI structure doc

**Date raised:** 2026-06-18
**Status:** OPEN (cataloged, individual recommendations need triage)

**Source:** `ЕДИНАЯ МНОГОУРОВНЕВАЯ СТРУКТУРА WIKI ...md` §"РЕКОМЕНДАЦИИ" (package "Про скилы").

18 recommendations proposed. Triage against our current state:

#### Critical priority

| # | Recommendation | Our status | Action |
|---|---|---|---|
| R1 | Add `verifiable_assertions` to all skills | NOT DONE. Not in STD-SKILL-001 v1.0 frontmatter schema | Add as optional field in STD-SKILL-001 v1.1 |
| R2 | Add PII scanner to session-experience | NOT DONE. session-experience v4.0 has no PII filter | Add `scripts/pii-scanner.py` to session-experience assets |
| R5 | Add `stop_condition` to all skills | NOT DONE. Not in STD-SKILL-001 v1.0 frontmatter schema | Add as optional field, required for Active skills |

#### High priority

| # | Recommendation | Our status | Action |
|---|---|---|---|
| R6 | Baseline comparison via agent-skills-eval | NOT DONE. No eval harness in our 4-repo split | Defer until Phase 2 (O-008) |
| R8 | Add Metrics block (Before/After/Target) | PARTIAL. Some skills have it ad-hoc | Standardize in STD-SKILL-001 v1.1 |
| R9 | Machine-readable registry (`registry.json`) | NOT DONE. INDEX.md is the only registry | Add `Z-ai-skills/registry.json` generated from INDEX.md |
| R10 | Add skill validation script | DONE. `verify-standards.js` covers this for standards; `verify-id-graph.js` covers cross-repo IDs | Extend `verify-standards.js` to also lint skills |

#### Medium priority

| # | Recommendation | Our status | Action |
|---|---|---|---|
| R11 | Add Changelog to skills | PARTIAL. Some skills have it (humanizer v2.1.1) | Standardize in STD-SKILL-001 v1.1 |
| R12 | Add `deprecated` + `replaced_by` fields | DONE. `MIGRATIONS.md` covers lifecycle; STD-META-001 v2.0 §7 defines status | Already covered |
| R13 | Add pre-commit hook | DONE. `install-hooks.sh` exists in `Z-ai-platform/` | Already covered |

#### Specific to standards

| # | Recommendation | Our status | Action |
|---|---|---|---|
| R16 | Rewrite STD-FE-001 away from "sections have no state" | N/A. STD-FE-001 not yet imported (O-002) | Consider during import |
| R17 | Demather UNICODE_POLICY for AI chat/logs | REJECTED. UNICODE_POLICY is intentionally strict | Do not implement |
| R18 | Add MIGRATION_GUIDE.md with codemods and grace period | PARTIAL. `MIGRATIONS.md` covers grace period but no codemods | Add codemod examples to MIGRATIONS.md |

#### Not applicable / rejected

| # | Recommendation | Reason |
|---|---|---|
| R3 | Deduplication via embeddings in session-experience | Over-engineering for current scale (35 skills, <100 sessions) |
| R4 | Switch MUST auto-activate to SHOULD + confirm-first in anti-monolith | anti-monolith already auto-activates with announcement; current behavior is correct |
| R7 | Reduce phi-layout to top-6 patterns | phi-layout is a third-party skill, not ours to refactor |
| R14 | Browser fallback for subgrid in phi-layout | Same as R7 |
| R15 | Reduce cognitive formulas to top-10 in prompt-engineering | Same as R7 |

**Decision needed from:** maintainer (stsgs1980). The R1/R2/R5 critical items should be folded into STD-SKILL-001 v1.1 revision.

---

### O-011: Reconcile our 35-skill catalog with 88-skill inventory

**Date raised:** 2026-06-18
**Status:** OPEN (informational, gap analysis)

**Source:** `skills-inventory.md` (package "Про скилы"), dated 2026-05-23.

The source catalogs 88 skills across 21 categories from `/home/z/my-project/skills/` (the disposable runtime view, see SESSION_NOTES §9). Our `Z-ai-skills/skills/INDEX.md` lists 35 skills (24 with ZAI-* IDs, 11 without).

**Gap explanation (not a defect):**

| Set | Count | What it represents |
|---|---|---|
| Source inventory (88) | 88 | All skills visible at runtime (Z.ai official + user-uploaded + third-party) |
| Our catalog (35) | 35 | Only skills we own and version-control in `Z-ai-skills` git repo |
| Delta (53) | 53 | Z.ai official skills + third-party skills we use but don't own |

The delta is expected and healthy. Our 35 includes user-authored skills (ZAI-STS-*, ZAI-META-*, ZAI-DEV-*, etc.) that the source inventory classifies as `[STS]` or `!`. The source's `[S]` (system) and `[3P]` (third-party) entries are not in our catalog by design.

**Useful patterns from the source to adopt:**

1. The 5-axis skill typology (interaction, role, I/O structure, autonomy level, activation) — see O-009 for analogous standard typology. Could enrich STD-SKILL-001.
2. The `[S]/[STS]/[3P]/[!]/[?]` ownership tag system — useful for our INDEX.md.
3. The category-based grouping (21 categories) — our INDEX.md uses domain-prefix grouping (ARCH, DEV, FS, MEM, META, QA, SESSION, STS) which is flatter but mechanically verifiable.

**Decision points:**

1. Should we add an `ownership:` field (S/STS/3P) to skill frontmatter?
2. Should we adopt any of the 5-axis typology dimensions as optional metadata?
3. Should we mirror the source's 21-category structure as a secondary view in INDEX.md?

**Recommendation:** Defer until skill count exceeds 50. Current 35 is manageable in the flat domain-prefix view.

---

### O-012: Add ui-clarity_sts (6-phase UI redesign methodology) to catalog

**Date raised:** 2026-06-18
**Status:** OPEN (skill adoption decision)

**Source:** `ui-clarity_sts.txt` (package "Про скилы").

The source describes a skill `ui-clarity_sts` (proposed ID `ZAI-STS-007`) with a 6-phase methodology for transforming "broken UI" into a coherent design system:

| Phase | Action | Output |
|---|---|---|
| 1. Audit | Catalog all inconsistencies (typography, color, spacing, themes) | Comparison table |
| 2. Propose | Design token system (typography + color + spacing) | Token spec |
| 3. Wireframe | Generate HTML before/after presentation | `wireframe-design-system.html` |
| 4. Implement | Apply tokens to all components | Clean code without hardcode |
| 5. Verify | Test both themes, linter, compile | All passing |
| 6. Document | Write worklog migration guide | Worklog entry |

Key principles: semantic tokens instead of hardcode, intent-based naming, wireframe-first (show user before touching code), replacement table for typical patterns.

**Current state in our catalog:** `ZAI-STS-007` is already assigned to `workflow-discipline_sts` (see `INDEX.md` line 49). The proposed ID in the source collides with our existing assignment.

**Decision points:**

1. Should we adopt the 6-phase methodology as a new skill?
2. If yes, what ID? Options:
   - (a) `ZAI-STS-008` (next free STS slot) -- preferred
   - (b) `ZAI-UI-001` (new UI domain) -- cleaner semantically but adds a domain
   - (c) Skip the ID, keep as a reference document in `Z-ai-skills/docs/`
3. Should the wireframe template (110KB HTML) be committed to git, or referenced externally?

**Recommendation:** Defer adoption. The methodology is valuable but we have no active UI redesign project. When the first such project arises, create `ZAI-STS-008 ui-clarity_sts` with the 6-phase methodology, citing the source package. Do NOT take the proposed `ZAI-STS-007` ID — it is taken.

---

### O-013: Reserve MAS agent IDs

**Date raised:** 2026-06-18
**Status:** OPEN (ID registry hygiene)

**Source:** `Архитектура полноценной агентной системы MAS ...MD` (package "Про скилы"), §2.

The source proposes 5 agent IDs for the MAS architecture (see O-008). Triage against our current registry:

| Proposed ID | Source role | Currently in our INDEX.md? | Conflict? |
|---|---|---|---|
| `ZAI-ORCH-001` | Orchestrator | NO | NO -- free to reserve |
| `ZAI-META-003` | Skill Forge | NO | NO -- free to reserve |
| `ZAI-STD-001` | Standardizer | NO (ZAI-STD-* prefix unused) | NO -- but prefix `STD` may collide with standards (STD-ARCH-001 etc.). Recommend reserving `ZAI-META-005` instead to keep `STD` prefix exclusive to standards |
| `ZAI-META-004` | Guardian | NO | NO -- free to reserve |
| `ZAI-CORE-001` | Registry Manager | NO | NO -- free to reserve (but `CORE` is a new domain) |

**Decision points:**

1. Reserve all 5 IDs now (placeholder entries in INDEX.md with `status: reserved`)?
2. Rename `ZAI-STD-001` to `ZAI-META-005` to avoid STD-prefix confusion?
3. Add `CORE` as a new ZAI domain, or move Registry Manager under `META`?
4. Should `ZAI-ORCH-001` be reserved for the Super Z orchestrator itself (the platform we run on), or only for our future Orchestrator agent?

**Recommendation:**

- Reserve `ZAI-ORCH-001`, `ZAI-META-003`, `ZAI-META-004`, `ZAI-CORE-001` as placeholder entries with `status: reserved` and `note: "MAS Phase 3, see O-008"`.
- Do NOT reserve `ZAI-STD-001`. Use `ZAI-META-005` for Standardizer instead. The `STD-*` prefix must remain exclusive to standards (STD-ARCH-001, STD-META-001, etc.) to avoid ambiguity in `verify-id-graph.js`.
- Add `CORE` as a new ZAI domain (currently: ARCH, DEV, FS, MEM, META, QA, SESSION, STS).

**Decision needed from:** maintainer (stsgs1980)

---

### O-014: Z.ai Sandbox Documentation final triage -- DECIDED

**Date raised:** 2026-06-18
**Date decided:** 2026-06-18
**Status:** DECIDED

**Source:** `Z.ai Sandbox Documentation.zip` (7 files in `upload/`).
Full analysis: `docs/sandbox-docs-analysis.md` (2026-06-18).
Final decision recorded in `SESSION_NOTES.md` §10.

**Decision:**

KEEP 6 of 7 files in `upload/` as reference material:

| File | Verdict | Notes |
|---|---|---|
| `Z.ai-Sandbox-Guide.md` | KEEP | Reference for fullstack sessions |
| `Z.ai-Sandbox-Guide-Hooks.md` | KEEP | React hooks + z-ai-web-dev-sdk API routes cookbook |
| `Z.ai-Sandbox-Migration Guide.md` | KEEP, needs update | STALE: replace `npm install --legacy-peer-deps` -> `bun install` |
| `Z.ai-Sandbox-Super-Z-Subagents-Education.md` | KEEP | Architectural primer; partially stale on progressive disclosure |
| `RELATIONS.md` | KEEP | Navigator + contradictions table |
| `verify.sh` | KEEP, needs refresh | STALE: checks 1 and 6 assume npm |
| `Z.ai-Sandbox-Guide_commands_reference.md` | DROP from active use | 47K, agent already knows these commands. May remain on disk as offline reference. |

**Rationale:**

1. The 6 kept files are the only known systematic documentation of Z.ai sandbox internals (idle timeout, allowedDevOrigins, port 81 proxy, migration procedure, subagent architecture, verify harness).
2. None should be packaged as skills in their current form -- too large (10K-47K each), pre-date skill-creator progressive disclosure, partially contradict current Z.ai infrastructure.
3. The dropped `commands_reference.md` is redundant with the agent's existing Linux knowledge; loading 47K into context violates skill-creator's "lean, < 500 lines" principle.
4. If skill wrappers are needed later, write three short ones (< 500 lines each) that reference the docs on demand: `zai-fullstack-init`, `zai-sandbox-migration`, `zai-subagents-architecture`.

**Action items:**

- [ ] Patch `Z.ai-Sandbox-Migration Guide.md`: replace `npm install --legacy-peer-deps` -> `bun install`, `npm run build` -> `bun run build`.
- [ ] Patch `verify.sh` checks 1 and 6: accept `bun` as primary, `npm` as fallback.
- [ ] When fullstack session begins, write `zai-fullstack-init` skill wrapper.
- [ ] When migration between sandboxes is needed, write `zai-sandbox-migration` skill wrapper.

**No deletion of source files at this time.** The `upload/Z.ai-Sandbox-*.md` files and the `upload/Z.ai Sandbox Documentation.zip` are preserved as canonical reference.

---

### O-015: W11 scope = standards/ only — explicitly document, do not extend

**Date raised:** 2026-06-21
**Status:** OPEN (deferred to consumer-integration phase)

**Source:** Discovered during V11 implementation (LESSON-003). When user asked
«это система работает?» after pilot split reached 13/13 PASS, 0 warnings, I
diagnosed W11=0 as fragile. Investigation of `verify-id-graph.js` line 1046
(`if (!repos.standards) return; const standardsTreeRoot = repos.standards;`)
revealed W11 has ALWAYS scoped to standards/ subtree only. skills/, guard/,
platform/ structural files were never subject to W11 — neither as soft nor
as hard. The "13/13 PASS, 0 warnings" was technically correct, but did not
mean "everything in the project is ≤ 1000 lines" — it meant "everything
under standards/ is ≤ 1000 lines".

**Question:** Should W11 (and now V11) be extended to cover skills/,
guard/, and platform/ structural .md files?

**Decision: NO — defer until consumer-integration phase.**

**Rationale:**

1. **W11 was designed for normative standards**, where lencoon = clarity and
   long = monolithic = bad standard. skills/, guard/, platform/ are different
   artifact types — consumer-facing patterns, rule files, orchestrator docs
   — and may have different legitimate size envelopes.

2. **Cross-repo invariant smell**: A verifier in standards/ reaching into
   skills/ submodule creates a coupling that violates the 4-repo split
   principle (D-001). Each repo should own its own invariants. If skills/
   ever needs a 1000-line (or any-line) cap, it should be implemented as a
   verifier inside skills/scripts/, not extended from standards/.

3. **skills/ structure is still in flux.** User context: «когда начнем
   разбирать скилы они тоже начнут о себе напоминать, и они встроятся в
   систему как надо, триггерами хуками, eslint и тд. Как только возьмем
   наши модули встроим в проект, там щепки летать будут.» Adding a hard
   cap to skills/ now would be premature — the right cap (and the right
   threshold) will be informed by how skills actually integrate into
   consumer projects via hooks/eslint/triggers.

4. **2 currently-long skills files** (`grid-patterns.md` 1393,
   `react-router.md` 1002) are reference docs, not narrative standards.
   Forcing them under a 1000-line cap would split comprehensive reference
   material into artificial chunks — likely degrading discoverability, not
   improving it.

**Action items:**

- [ ] When consumer project onboards and starts consuming skills/ as
      hooks/eslint/triggers, revisit: what is the right invariant for
      skills/? Possibly tiered: SKILL.md ≤ 800, references ≤ 2000,
      INDEX.md ≤ 200.
- [ ] If a skills/ verifier is needed, implement as
      `skills/scripts/verify-skills.js` (mirror of standards/scripts/
      verify-standards.js), NOT as an extension to standards/ verifier.
- [ ] Update verifier output wording (both verify-id-graph.js and
      verify-standards.js) to make scope explicit: e.g. "scanned N files
      in standards/ subtree" rather than implying project-wide coverage.

---

### O-016: Dashboard for 4-module state visualization

**Date raised:** 2026-06-21
**Status:** OPEN (idea stage, no commitment)

**Source:** User wish after V11 implementation: «Было бы конечно круто
иметь что то дашборда, и видеть работу этих 4 модулей и их состояние, и как
это работает в проекте приеммнике. Ведь очень хорошо когда наглядно все.»

**Question:** Should we build a dashboard to visualize the state of the 4
modules (platform, standards, guard, skills) and their consumer-project
integration?

**Decision: OPEN — needs design exploration before commitment.**

**What the dashboard would show (if built):**

Source-repo state (Phase 1 — could be done now):
- 4 repos × {last commit SHA, last commit message, last commit date,
  verifier pass/fail count, open O-NNN count, version}
- LESSON registry (§12) — current count, last entry
- DECISIONS_LOG — D-NNN decided count, O-NNN open count, recent decisions
- Warnings history (when did W11/W12/W13 first hit 0?)

Consumer-project state (Phase 2 — needs consumer project first):
- Which version of each module is pinned
- Customizations applied (overrides, extensions)
- Verifier pass/fail in consumer context
- Drift: source moved forward, consumer still on old pointer

**Three complexity tiers under consideration:**

| Tier | Form | Effort | Maintenance | Toolkit-deprecation safe? |
|---|---|---|---|---|
| T1 | Markdown digest, regenerated by script, committed to repo | 1-2h | Per-commit script run | YES (pure markdown) |
| T2 | Static HTML report, regenerated by script, opens in browser | 4-6h | Per-commit script run | YES (static HTML, no DB) |
| T3 | Live Next.js dashboard, reads git state on demand | 1-2 days | Running server required | RISKY (toolkit may be killed) |

**Rationale for deferring:**

1. **No consumer project exists yet.** Phase 1 alone (source-repo state)
   has limited value — the verifiers already print this on every run. A
   dashboard adds value only when state changes BETWEEN verifier runs
   (drift, integration, multi-project).

2. **Toolkit deprecation constraint (§12.3).** Any T3 (live dashboard)
   that depends on ChromaDB-via-toolkit would be at risk. T1/T2 are
   portable markdown/HTML, safe.

3. **LESSON-001 applies.** Building T3 now (1-2 days) before knowing
   what the consumer integration actually looks like is O(N) speculation
   — we'd likely rebuild it once real consumer data arrives. Better to
   wait for the first consumer project, then build the dashboard against
   real data shapes.

**Action items:**

- [ ] When first consumer project onboards, decide tier based on actual
      need (does the user open a browser? does CI status page suffice?
      does the dashboard need to compare multiple consumers?).
- [ ] Until then, the existing verifier outputs (8/8, 13/13, 0 warnings)
      serve as the lightweight dashboard — they are regenerated on every
      commit and visible in CI logs.
- [ ] Consider T1 (markdown digest) as low-cost interim if visual
      tracking becomes valuable before consumer project arrives.

---

## Change History

| Date | Change |
|---|---|
| 2026-06-17 | Initial creation. Added D-001 through D-010 (all decided in this session) and O-001 through O-007 (open questions identified). |
| 2026-06-18 | Resolved O-006 and O-007 (sandbox persistence + consumer onboarding) via extraction from "Про скилы" package -- see SESSION_NOTES §9. Added O-008 (MAS roadmap), O-009 (standard typology), O-010 (R1-R18 recommendations triage), O-011 (88 vs 35 skill reconciliation), O-012 (ui-clarity_sts adoption), O-013 (MAS agent ID reservation), O-014 (Sandbox Documentation final triage -- DECIDED: keep 6/7, drop commands_reference). |
| 2026-06-21 | Added O-015 (W11 scope = standards/ only — explicitly document, do NOT extend to skills/guard/platform; defer to consumer-integration phase). Added O-016 (dashboard for 4-module state — idea stage, 3 tiers under consideration T1/T2/T3, deferred pending first consumer project). Both raised as a result of V11 implementation investigation that revealed W11 was never project-wide — its scope was always standards/ subtree only. |
