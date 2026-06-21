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
**Date updated:** 2026-06-21 (sequencing decision after P-MAS_init inspection)
**Status:** OPEN (idea stage, sequenced after skills integration)

**Source:** User wish after V11 implementation: «Было бы конечно круто
иметь что то дашборда, и видеть работу этих 4 модулей и их состояние, и как
это работает в проекте приеммнике. Ведь очень хорошо когда наглядно все.»

**Sequencing decision (2026-06-21):**

After inspecting `github.com/stsgs1980/P-MAS_init.git` (Next.js 16 + Prisma +
shadcn/ui dashboard, currently a Multi-Agent System visualization with 26
agents in 8 role groups), user clarified:
- P-MAS_init is an "experimental init" that will be brought to completion
- Dashboard adaptation comes AFTER skills integration, not before
- User: «Первично нам надо будет разбираться со скилами, и тогда уже можно
  будет затащить дашбборд и видеть работу этих 4 модулей.»

This means:
1. **Next priority:** skills integration work (how skills/ actually wires
   into a consumer project via hooks/eslint/triggers — see O-015 action
   items).
2. **Dashboard adaptation trigger:** triggered by completion of skills
   integration, NOT by calendar date.
3. **P-MAS_init is NOT yet a consumer of Z-ai-standards.** Its `standards/`
   folder contains custom standards (MARKDOWN_STANDARD_RU_v2.1,
   No-Unicode_Policy_v2.1) — NOT submodule pointers to Z-ai-standards.
   Before P-MAS_init can visualize Z-ai-platform state, it must first
   become a consumer (replace custom standards/ with submodule pointer,
   run bootstrap.sh, etc.). This consumer onboarding is part of the
   skills integration work.

**What the dashboard would show (when adapted):**

Source-repo state (read from Z-ai-platform):
- 4 repos × {last commit SHA, last commit message, last commit date,
  verifier pass/fail count, open O-NNN count, version}
- LESSON registry (§12) — current count, last entry
- DECISIONS_LOG — D-NNN decided count, O-NNN open count, recent decisions
- Warnings history (when did W11/W12/W13 first hit 0?)

Consumer-project state (P-MAS_init's own view of itself):
- Which version of each Z-ai module is pinned (submodule SHA)
- Customizations applied (overrides, extensions vs source)
- Verifier pass/fail in consumer context (skills actually trigger
  correctly via hooks/eslint)
- Drift: source moved forward, consumer still on old pointer

**Three adaptation approaches under consideration (decide later):**

| Approach | Form | When to choose |
|---|---|---|
| A1 — Fork P-MAS_init, rewrite domain model | Standalone 4-module dashboard | If P-MAS MAS feature is dropped |
| A2 — Add `/repos` view inside P-MAS_init | Coexist with MAS view | If MAS stays as P-MAS feature |
| A3 — P-MAS_init self-monitoring | Dashboard IS the consumer view | If P-MAS_init becomes primary consumer |

**Rationale for deferring:**

1. **Skills integration shapes the data model.** Until we know how skills
   actually integrate (hook names, eslint rule shape, trigger events), the
   dashboard's data model is speculation. Building now = O(N) rework later.
2. **P-MAS_init needs consumer onboarding first.** Either approach A1/A2/A3
   requires P-MAS_init to be a formal consumer of Z-ai modules. That
   onboarding IS part of skills integration (because skills integration
   testing happens in a real consumer, and P-MAS_init is the candidate).
3. **LESSON-001 applies.** 1-2 days of dashboard work now, before the
   consumer integration defines the data shape, is the same O(N) speculation
   pattern that we have already encoded as an anti-pattern in §12.4-12.6.

**Action items (in execution order):**

- [ ] **Step 1 (skills integration work):** Define how skills/ modules
      integrate into a consumer project — hook naming, eslint rule shape,
      trigger events. Tracked separately, NOT in this O-016.
- [ ] **Step 2 (P-MAS_init consumer onboarding):** Once skills integration
      shape is known, onboard P-MAS_init as the first consumer (replace
      its `standards/` with submodule pointers, run bootstrap.sh, install
      hooks). Tracked in O-015 action items.
- [ ] **Step 3 (dashboard adaptation):** Once P-MAS_init is a live consumer
      and skills integration produces real events to display, decide
      approach A1/A2/A3 and adapt P-MAS_init dashboard. THIS O-016.
- [ ] Until Step 3, the existing verifier outputs (8/8, 13/13, 0 warnings)
      serve as the lightweight dashboard — they are regenerated on every
      commit and visible in CI logs.

---

### O-017: Skills execution contract — cascade plan for governance-to-execution bridge

**Date raised:** 2026-06-21
**Status:** OPEN — Phase A + Phase B COMPLETE (2026-06-21), awaits Phase C approval

**Source:** User confirmation after V11 + O-015/O-016 work: «если эти 4
модуля (как мозговой нейоро центр) будет работать как задумано, ничего не
помешает построить систему автономных агентов». User explicitly authorized
cascade drafting: «можешь сам набросать какскад задач. это говорит только
о том что ты видишь систему а не просто файлы и папки».

**Phase A outcome (2026-06-21):**

Phase A executed in a single session after user said «давай начнем с A».
Both deliverables produced:

- **A1 — Catalog:** `skills/docs/CATALOG.md` (374 lines). Machine-generated
  by `scripts/catalog_skills.py` then hand-curated. Found 36 skills (not 35
  — INDEX.md was stale, missing `zai-skill-registry`). Found skill-creator
  ID misregistration (ZAI-STS-008 in SKILL.md vs ZAI-META-002 in INDEX.md).
  Classified 30 active / 5 stale / 1 duplicate-candidate (phi-layout vs
  phi-layout_sts, interpreted as convergent STS re-registration). INDEX.md
  corrected in the same commit.
- **A2 — Gap audit:** `SESSION_NOTES.md` §13 (new). Audited the 6-row
  governance/execution gap table against actual repo state. Result: 4
  BLOCKING / 1 PARTIAL-ACCEPTABLE / 1 ACCEPTABLE. Confirms cascade
  ordering. Surfaces 2 new open question candidates: O-019 (guard/
  execution contract, parallel to skills contract) and O-020 (feedback-
  loop mechanism, long-term).

Phase A confirmed 3 unanticipated findings that affect Phase B:

1. **Only 3 of 36 skills (8%) have callable `scripts/`.** The contract
   layer Phase B designs will be the FIRST execution layer for 33 of
   36 skills. The 3 existing scripts-bearing skills (skill-creator,
   session-handoff, qa-test-planner) are the only models. Phase B's
   commit-work pilot will not have a sibling to copy from — it will
   set the precedent.
2. **session-handoff is the most execution-ready skill in the repo.**
   4 Python scripts, evals/ directory, references/. It is the model
   to follow for Phase C2 generalization, not Phase B pilot (commit-work
   remains the pilot per O-017 original design).
3. **5 stale skills need frontmatter remediation.** api-retry, dev-
   watchdog, fallback, health-check, z-ai-web-dev-sdk. Real body
   content (290-781 lines) but no frontmatter `description:`, no ZAI-ID,
   version=v?. Estimated 15 min/skill × 5 = 75 min. Can be done in
   parallel with Phase B (independent of contract shape).

   **Update 2026-06-21 (post-Phase-B honest remediation):** the
   "5 stale skills" finding was a **false positive** caused by a
   bug in `catalog_skills.py` (it did not parse YAML folded-scalar
   `description: >` syntax, so it saw the description as the literal
   string ">"). All 5 skills (api-retry, dev-watchdog, fallback,
   health-check, z-ai-web-dev-sdk) are documented in
   `skill-id-system/SKILL.md` §4 as sandbox system skills that
   intentionally do NOT receive ZAI- prefix IDs. Fix: rewrote
   `parse_frontmatter()` to handle folded/literal scalars, added
   `version: 1.0` to each of the 5 skills' frontmatter (the only
   real gap). Result: classification changed from 30 active / 5 stale
   / 1 dup → 35 active / 0 stale / 1 dup. Honest postmortem in
   `skills/docs/CATALOG.md` §10. This item is now **CLOSED — false
   positive retracted**. The 4 remaining `v?` skills (gepetto,
   phi-layout, reducing-entropy, session-handoff) are legitimate
   Phase C candidates (~5 min each).

**Status of cascade phases (as of 2026-06-21):**

- [x] **Phase A (discovery):** COMPLETE.
  - [x] A1: Catalog 36 skills → `skills/docs/CATALOG.md`
  - [x] A2: Audit governance/execution gap → SESSION_NOTES §13
- [x] **Phase B (pilot):** COMPLETE.
  - [x] B1: Design commit-work execution contract → `skills/skills/commit-work/CONTRACT.md` (368 lines, 5-tuple shape: trigger/hook/guard-check/standard-check/success-criterion)
  - [x] B2: Implement pilot — `skills/skills/commit-work/scripts/run-contract.sh` (callable runtime, --dry-run + --commit modes) + `.githooks/commit-msg` (new, Conventional Commits G4/G5/G6) + `.githooks/pre-commit` updated (Phase 0 worklog freshness WARN). Smoke-tested: bad message → BLOCK, good message → PASS.
- [ ] **Phase C (generalize, after B):**
  - [ ] C1: Extract template from B2 → `skills/templates/CONTRACT_TEMPLATE.md`
  - [ ] C2: Apply to session-handoff (first generalization target, per Phase A finding)
- [ ] **Phase D (governance, parallel after B1):**
  - [ ] D1: `skills/scripts/verify-skills.js`
  - [ ] D2: Tiered hard caps (V12 equivalent)
- [ ] **Phase E (consumer, after C2+D1):**
  - [ ] E1: Onboard P-MAS_init as first consumer
  - [ ] E2: Define install-and-use tutorial format
- [ ] **Phase F (dashboard, after E1):**
  - [ ] F1: Decide A1/A2/A3 dashboard approach (O-016 Step 3)
  - [ ] F2: Implement dashboard adaptation

**Phase B outcome (2026-06-21):**

Phase B executed after user said «Оk» to the Phase A summary. Both
deliverables produced and smoke-tested:

- **B1 — Contract design:** `skills/skills/commit-work/CONTRACT.md`
  (368 lines). First concrete instance of the 5-tuple execution
  contract shape proposed in O-017. 10 sections: trigger, hook,
  guard checks (G1-G6 with BLOCK/WARN levels), standard checks
  (S1-S3 with verifier mapping), success criterion, runtime modes,
  contract versioning, cross-references, honest uncertainties,
  change history. YAML frontmatter makes it machine-readable.
  `SKILL.md` frontmatter updated with `contract: CONTRACT.md` and
  `contract_version: 1.0` fields. Body of SKILL.md gained an
  "Execution Contract" section pointing to CONTRACT.md as source of
  truth for runtime behavior.

- **B2 — Pilot implementation:** 4 artifacts.
  1. `skills/skills/commit-work/scripts/run-contract.sh` (270 lines,
     bash). Callable runtime with 3 modes: `--dry-run` (preview
     checks), `--commit "<msg>"` (validate + create commit), `--help`.
     Color-coded output ([OK]/[WARN]/[FAIL]/[i]). Tracks PASS/WARN/
     FAIL counts. Phase 0 guard checks → Phase 1+2 standard checks
     → commit creation (only in --commit mode, only if 0 FAIL).
  2. `.githooks/commit-msg` (new, 120 lines). Validates Conventional
     Commits format on commit message. G4 (format regex) BLOCK, G5
     (subject ≤72) BLOCK, G6 (body wrap 72) WARN. Skips merge/revert/
     squash/fixup commits (git-generated messages).
  3. `.githooks/pre-commit` updated (was 91 lines, now 122). Added
     Phase 0: worklog freshness check (find -mmin -60). WARN only —
     false positives are common. Existing Phase 1 (verify-standards)
     and Phase 2 (verify-id-graph) preserved unchanged.
  4. `install-hooks.sh` updated. Now lists both hooks with their
     responsibilities. Points to CONTRACT.md and run-contract.sh.

- **Smoke testing (4 tests, all pass):**
  1. `run-contract.sh --dry-run` → 3 PASS, 0 WARN, 0 FAIL.
  2. `run-contract.sh --commit "bad message"` → G4 FAIL, commit NOT
     created. Correct behavior.
  3. `git commit -m "bad message"` (real git) → pre-commit PASS,
     commit-msg BLOCK. Commit NOT created. Correct behavior.
  4. `git commit -m "test(contract): good message"` (real git) →
     pre-commit PASS, commit-msg PASS. Commit created. Correct.

- **Gotcha discovered during smoke testing:** `git reset --hard HEAD~1`
  (used to undo a smoke-test commit) wipes uncommitted working-tree
  changes — including edits to .githooks/pre-commit and install-hooks.sh.
  This happened twice during Phase B. LESSON candidate: when undoing
  a smoke-test commit on files that also have uncommitted edits, stash
  first, reset, then stash pop. Or: commit edits to a separate branch
  first, then smoke-test on top.

**Phase B validated the 5-tuple contract shape.** The shape worked
for commit-work. Phase C will test whether it generalizes:
- C1 extracts the shape into a template.
- C2 applies the template to session-handoff (the most execution-
  ready skill per Phase A finding — has 4 Python scripts, evals/,
  references/). If the shape fits session-handoff without
  modification, the shape is validated. If session-handoff needs a
  6th field (e.g., `cleanup` for resource teardown), the shape will
  be revised.

**Contract shape validated (B1 hypothesis confirmed for commit-work):**
1. `trigger` — event that invokes the skill. Works: git commit event.
2. `hook` — runtime hook that fires. Works: pre-commit + commit-msg.
3. `guard-check` — pre-flight checks (RULE-NNN semantics). Works: G1-G6.
4. `standard-check` — invariant checks (STD-NNN semantics). Works: S1-S3.
5. `success-criterion` — definition of done. Works: 5 conditions.

**Open question candidates from Phase B:**
- The runner script (`run-contract.sh`) duplicates logic that also
  lives in the hooks. Should the hooks call the runner? Currently
  they're parallel implementations. DRY would suggest hooks invoke
  `run-contract.sh --dry-run` mode. Deferred to Phase C1 — when
  extracting the template, decide whether runner is the single source
  of truth or hooks are.
- commit-msg hook skips merge/revert/squash/fixup commits. This is
  necessary (git generates those messages) but means those commit
  types bypass Conventional Commits enforcement. Acceptable for now;
  revisit if merge-commit hygiene becomes an issue.

**New open question candidates surfaced by Phase A (not yet raised as
O-019/O-020 — pending user approval to formalize):**

- **O-019 candidate** — guard/ execution contract. Apply the same
  5-tuple shape (trigger/hook/guard-check/standard-check/success-
  criterion) to RULE-NNN. Pilot: RULE-MONOLITH-004 (one logical block,
  one commit). Natural fit with commit-work Phase B pilot — the same
  pre-commit hook could enforce both.
- **O-020 candidate** — feedback-loop mechanism. How does experience
  (worklog/SESSION_NOTES §12) feed back into rules (RULE-NNN) and
  invariants (V01-V11)? Long-term, depends on Phase F dashboard +
  Phase G memory layer (not yet in cascade).

**Context — governance/execution gap (documented as near-term goals):**

The 4 modules currently provide governance (rules as markdown), not
execution (runtime enforcement). Both layers are needed for autonomous
agents.

| What we have (governance) | What we lack (execution) | Why it matters |
|---|---|---|
| skills/ as descriptive .md | Runtime that loads skill by name and invokes it | Without runtime, skills are inert text |
| guard/ as RULE-NNN markdown | Pre-flight check that blocks action before execution | Without pre-flight, RULE-NNN is advisory, not enforced |
| standards/ as STD-NNN | Linter/loader that checks agent follows standard in real-time | Without linter, standards are enforced only by verifier runs |
| worklog.md as append-only log | Memory: what agent tried, what worked, what didn't (RAG-style) | Without memory, agent repeats mistakes |
| DECISIONS_LOG D-NNN | Decision mechanism: how agent chooses between alternatives | Without mechanism, decisions are LLM-guessed, not structured |
| SESSION_NOTES §12 LESSON | Feedback loop: how experience becomes updated rule | Without loop, lessons stay in markdown, never feed back into rules |

**Bridge insight:** skills/ is the critical bridge between governance and
execution. When a skill is just .md, agent can read it but not invoke it.
When a skill defines trigger/hook/guard-check/standard-check/success-
criterion, .md becomes a callable capability. Defining this execution
contract shape IS the gateway to building execution layer for the other
3 modules.

**Cascade — 6 phases, ~12 tasks, iterative (not strictly linear):**

```
Phase A (discovery, parallel)         Phase B (pilot, sequential)
  A1 catalog 35 skills                  B1 design contract (commit-work)
  A2 audit gap table                    B2 implement pilot
         |                                    |
         v                                    v
Phase C (generalize, sequential)       Phase D (governance, parallel after B1)
  C1 extract template from B2           D1 skills/scripts/verify-skills.js
  C2 apply to next 2-3 skills           D2 hard caps for skills/ (V12 equiv)
         |                                    |
         +-------------+----------------------+
                       v
                Phase E (consumer, sequential)
                  E1 onboard P-MAS_init as first consumer
                  E2 define install-and-use tutorial format
                       |
                       v
                Phase F (dashboard, sequential)
                  F1 decide A1/A2/A3 approach (O-016)
                  F2 implement dashboard adaptation (O-016 final)
```

**Phase A — Discovery (parallel-safe, no dependencies):**

- **A1: Catalog all 35 skills.** For each skill in skills/skills/INDEX.md,
  record: name, ZAI-ID (or none), domain, current state (active/skeleton/
  duplicate/stale), source line count, has-SKILL.md, has-references/. This
  is O-011's "35-skill catalog" formalized as a structured table, not just
  INDEX.md prose. Output: `skills/docs/CATALOG.md`.
- **A2: Audit governance/execution gap.** Confirm the 6-row table above by
  checking each row against actual repo state. For each gap, classify as
  "blocking autonomous agents" vs "acceptable for now". Output: section in
  SESSION_NOTES §13 (new) or this O-017 update.

**Phase B — Pilot (sequential, depends on A1+A2):**

- **B1: Design execution contract for `commit-work` skill.** Define the
  5-tuple shape concretely:
  - trigger: what event invokes this skill (e.g., `git commit` intent)
  - hook: what runtime hook this connects to (e.g., pre-commit)
  - guard check: which RULE-NNN(s) pre-flight (e.g., RULE-012 block-mode)
  - standard check: which STD-NNN(s) validate output (e.g., STD-DOC-002
    commit message format)
  - success criterion: what counts as "skill executed successfully"
    (e.g., commit passed verifier, no rule violations)
  Output: `skills/skills/commit-work/CONTRACT.md` (new file, becomes the
  reference template for all future contracts).
- **B2: Implement commit-work execution contract.** Eat our own dogfood —
  Z-ai-platform itself becomes the consumer of commit-work skill. Install
  the pre-commit hook in Z-ai-platform, wire it to verify-standards.js +
  verify-id-graph.js + RULE-012 check. Prove the contract shape works
  end-to-end on one skill before generalizing.

**Phase C — Generalize (sequential, depends on B2):**

- **C1: Extract execution contract template.** From commit-work pilot,
  extract the abstract shape (5-tuple) into a template any skill can fill.
  Output: `skills/templates/CONTRACT_TEMPLATE.md` + update STD-SKILL-001
  to require CONTRACT.md as mandatory skill file (alongside SKILL.md).
- **C2: Apply template to 2-3 highest-value skills.** Candidates:
  `database-schema-designer` (high-value, clear trigger = "design DB"),
  `gepetto` (planning skill, clear trigger = "before multi-step task"),
  `qa-test-planner` (clear trigger = "before QA pass"). Validates that
  the template is portable, not commit-work-specific.

**Phase D — Governance (parallel-safe after B1):**

- **D1: Create skills/scripts/verify-skills.js.** First verifier for
  skills/ subtree, mirror of standards/scripts/verify-standards.js. Initial
  checks (informed by B1's contract shape): every skill has SKILL.md, every
  skill has CONTRACT.md (post-C1), file size caps, INDEX.md presence.
- **D2: Add hard caps for skills/ (V12 equivalent).** Tiered caps (e.g.,
  SKILL.md ≤ 800, references ≤ 2000, CONTRACT.md ≤ 200) — informed by A1
  catalog and B1 contract shape. NOT a flat 1000-line cap (per O-015
  rationale: reference docs may legitimately be long).

**Phase E — Consumer integration (sequential, depends on C2 + D1):**

- **E1: Onboard P-MAS_init as first consumer.** Replace P-MAS_init's
  custom `standards/` folder with submodule pointers to Z-ai-standards.
  Run bootstrap.sh. Install hooks. Verify skills trigger correctly in
  P-MAS_init context. This is the action item from O-015 and O-016.
- **E2: Define install-and-use tutorial format.** Based on real E1
  experience, write the first "how to consume skill X in your project"
  tutorial. Output: `skills/docs/CONSUMER_GUIDE.md` + per-skill
  INSTALL.md where non-trivial.

**Phase F — Dashboard (sequential, depends on E1):**

- **F1: Decide A1/A2/A3 approach for P-MAS_init.** With P-MAS_init as a
  live consumer producing real events (skill invocations, verifier runs,
  drift signals), decide which dashboard approach fits. This is O-016's
  Step 3.
- **F2: Implement dashboard adaptation.** Final O-016 execution.

**Iterative (not strictly linear):**

The cascade has feedback loops, not just forward edges:
- B2 (pilot implementation) may reveal contract shape issues that
  require revising B1 (and propagating to C1 template).
- D1 (verify-skills.js) may surface governance gaps that feed back into
  B1 contract shape (e.g., "verify-skills.js can't check X because
  CONTRACT.md doesn't declare it").
- E1 (P-MAS_init onboarding) may surface integration issues that
  require revising C1 template or D2 caps.

Each phase's output is the next phase's input, but each phase may also
send corrections backward. Treating this as waterfall would be wrong;
treating it as completely ad-hoc would also be wrong. The cascade
provides structure; iteration provides correction.

**Honest uncertainties:**

1. **Contract shape is a hypothesis, not confirmed design.** The 5-tuple
   (trigger/hook/guard/standard/success) is my proposed shape based on
   the commit-work example. B1 will validate or revise it. If B1 reveals
   the shape is wrong (e.g., needs 7 fields, or 4), the cascade from B1
   forward gets revised.
2. **35-skill catalog may not match execution reality.** A1 may discover
   that some "skills" in INDEX.md are documentation, not callable
   capabilities — and some callable capabilities exist as scripts/ but
   aren't in INDEX.md. Catalog may grow or shrink.
3. **P-MAS_init onboarding may surface architectural issues.** E1 is the
   first real consumer integration. It may reveal that our 4-repo split
   (D-001) has flaws when actually consumed, requiring fixes back at the
   source-repo layer.

**Cross-references:**

- Closes O-011 (35-skill catalog) by formalizing it as Phase A1.
  **Phase A1 confirmed 36 skills (not 35)** — see CATALOG.md §6.
- Feeds O-015 (W11 scope) by defining skills/ governance in Phase D.
- Enables O-016 (dashboard) by producing real consumer events in Phase E1.
- Applies LESSON-001 (root-cause encoded fix) by encoding the contract
  shape as a template (Phase C1), not as per-skill ad-hoc design.

---

## Change History

| Date | Change |
|---|---|
| 2026-06-17 | Initial creation. Added D-001 through D-010 (all decided in this session) and O-001 through O-007 (open questions identified). |
| 2026-06-18 | Resolved O-006 and O-007 (sandbox persistence + consumer onboarding) via extraction from "Про скилы" package -- see SESSION_NOTES §9. Added O-008 (MAS roadmap), O-009 (standard typology), O-010 (R1-R18 recommendations triage), O-011 (88 vs 35 skill reconciliation), O-012 (ui-clarity_sts adoption), O-013 (MAS agent ID reservation), O-014 (Sandbox Documentation final triage -- DECIDED: keep 6/7, drop commands_reference). |
| 2026-06-21 | Added O-015 (W11 scope = standards/ only — explicitly document, do NOT extend to skills/guard/platform; defer to consumer-integration phase). Added O-016 (dashboard for 4-module state — idea stage, 3 tiers under consideration T1/T2/T3, deferred pending first consumer project). Both raised as a result of V11 implementation investigation that revealed W11 was never project-wide — its scope was always standards/ subtree only. |
| 2026-06-21 | Updated O-016 with sequencing decision after P-MAS_init inspection. P-MAS_init is "experimental init" Next.js dashboard (currently MAS visualization, 26 agents in 8 role groups). User clarified: skills integration comes first, dashboard adaptation after. Three approaches A1/A2/A3 deferred until P-MAS_init becomes a formal consumer (its `standards/` currently has custom files, not submodule pointers to Z-ai-standards). O-016 action items restructured into 3-step execution order: (1) skills integration, (2) P-MAS_init onboarding as first consumer, (3) dashboard adaptation. |
| 2026-06-21 | Added O-017 (Skills execution contract — cascade plan). 6-phase cascade (A discovery, B pilot on commit-work, C generalize, D governance, E consumer integration, F dashboard) bridging governance (markdown rules) to execution (runtime enforcement). Governance/execution gap table documented as near-term goals context. Closes O-011 (formalizes 35-skill catalog as Phase A1), feeds O-015 (Phase D defines skills/ governance), enables O-016 (Phase E1 produces real consumer events). Cascade is iterative not waterfall — B2/D1/E1 may send corrections backward to B1 contract shape. Status: OPEN, awaits approval before Phase A execution. |
| 2026-06-21 | Updated O-017 — Phase A COMPLETE. A1 produced `skills/docs/CATALOG.md` (36 skills, not 35 — INDEX.md was stale, missing `zai-skill-registry`; also corrected skill-creator ID from ZAI-META-002 to actual ZAI-STS-008). A2 produced SESSION_NOTES §13 (gap audit: 4 BLOCKING / 1 PARTIAL-ACCEPTABLE / 1 ACCEPTABLE; confirms cascade ordering). 3 unanticipated findings: (1) only 3/36 skills have callable scripts/, (2) session-handoff is the most execution-ready skill, (3) 5 stale skills need frontmatter remediation. Removed original "Action items" checklist (now replaced by "Status of cascade phases" with [x]/[ ] marks). Surfaces 2 new open question candidates: O-019 (guard/ execution contract), O-020 (feedback-loop mechanism) — not yet formalized. Verifier status unchanged: 8/8 + 13/13, 0 warnings. |
| 2026-06-21 | Updated O-017 — Phase B COMPLETE. B1 produced `skills/skills/commit-work/CONTRACT.md` (368 lines, first concrete 5-tuple execution contract: trigger/hook/guard-check/standard-check/success-criterion). B2 produced 4 artifacts: `scripts/run-contract.sh` (callable runtime, --dry-run + --commit modes), `.githooks/commit-msg` (new, Conventional Commits G4/G5/G6 enforcement), `.githooks/pre-commit` updated (Phase 0 worklog freshness WARN), `install-hooks.sh` updated. 4 smoke tests all pass: dry-run PASS, bad message BLOCK, real-git bad commit BLOCK, real-git good commit PASS. 5-tuple shape validated for commit-work. Phase C will test generalization to session-handoff. Gotcha discovered: `git reset --hard HEAD~1` wipes uncommitted edits (happened twice during smoke testing) — LESSON candidate for SESSION_NOTES §12. |
| 2026-06-21 | Three-item "honest remediation" batch (user authorized with «принимаю, делай» after I proposed pausing O-017 cascade to do hygiene work). (1) Added LESSON-004 to SESSION_NOTES §12.7 — `git reset --hard` is two-axis destructive (moves branch pointer + overwrites working tree); stash before reset. Operational recipe: `git stash push -u -m "pre-reset-safety"` → `git reset --hard HEAD~1` → `git stash pop`. Triggered twice in Phase B smoke testing. (2) Discovered "5 stale skills" finding from Phase A1 was a **false positive** caused by my own `catalog_skills.py` bug (did not parse YAML folded-scalar `description: >` syntax). All 5 are correctly documented as sandbox system skills (no ZAI- prefix per skill-id-system §4). Real gap was only missing `version:` field. Fix: rewrote parse_frontmatter() to handle folded/literal scalars + added `version: 1.0` to all 5 skills. Catalog reclassified from 30 active/5 stale/1 dup → 35 active/0 stale/1 dup. Honest postmortem in CATALOG.md §10. Less work than originally scoped (75 min → 30 min). (3) Wrote `standards/docs/CI-AND-TESTING.md` (483 lines, 12 sections) — merges two uploaded drafts into one canonical doc, documents actual existing workflow (`.github/workflows/verify-id-graph.yml`, 250 lines), includes §11 bug audit table documenting 12 factual errors in the drafts against actual repo state. Verifier status: 8/8 + 13/13 PASS, 1 benign soft warning (W01 cross-submodule reference to run-contract.sh). |
