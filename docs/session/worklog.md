# Worklog

> Purpose: Append-only work log for the Z-ai platform. Each entry is a
> single task with a Task ID, the agent that performed it, what was
> done, and the resulting state. Read this file first when resuming
> work to understand what has already happened.
>
> Location: `Z-ai-platform/docs/session/worklog.md`
> Protocol:
>   1. Before starting work, read this file to understand prior context.
>   2. After finishing a task, append a new section starting with `---`.
>   3. NEVER overwrite existing content. Append only.
>   4. Each section MUST include: Task ID, Agent, Task, Work Log, Stage Summary.

---

Task ID: session-start-2026-06-17
Agent: main
Task: Initial session — set up 4-repo split, ID graph verifier, CI

Work Log:
- Created 4-repo split: Z-ai-platform (L0) + Z-ai-standards (L1) +
  Z-ai-guard (L2) + Z-ai-skills (L3)
- Z-ai-standards: 6 STD-* files (4 stubs + STD-META-001 v2.0 + STD-SKILL-001 v1.0)
- Z-ai-guard: 17 RULE-MONOLITH-* rules with YAML frontmatter
- Z-ai-skills: 35 skill directories (24 with ZAI-* IDs)
- Wrote verify-id-graph.js: 13 HARD checks (G01-G15) + 10 soft warnings
- Resolved 5 design issues for ID graph: G02 (stubs created), G03 (cycles
  broken), G04/G07 (layer violations reversed), G15 (same-layer-only check)
- Closed W08 (Aligned_with reciprocation for ZAI-META-001/002)
- Closed W04 (Related: edges added to 22 ZAI skills, one-directional)
- PAT got revoked 3 times before .gitignore was hardened
- Pushed all 4 repos to GitHub
- Authored Z-ai-platform README + CONTRIBUTING
- Created GitHub Actions workflow verify-id-graph.yml

Stage Summary:
- All 4 repos live on GitHub
- ID graph: 47 IDs, 13/13 HARD PASS, 1 soft warning (W03 dead stub)
- CI workflow active, 3 successful runs confirmed
- Open: workflow file push needed PAT with Workflows: Read and write scope

---

Task ID: std-arch-001-v1
Agent: main
Task: Promote STD-ARCH-001 from v0.1 stub to v1.0 full standard; close W03

Work Log:
- Read current stub + STD-META-001 v2.0 for context
- Confirmed W03 dead-standard warning (no RULE/ZAI declared Related: STD-ARCH-001)
- Wrote STD-ARCH-001 v1.0 (602 lines, 12 sections):
  - Purpose, Scope, Definitions
  - Repository Topology (4-repo split rationale, .gitmodules hygiene)
  - Layer Assignment (L0/L1/L2/L3, layer exclusivity)
  - Submodule Conventions (clean URLs, no inlined copies, recursive clone)
  - Cross-Repo Path References (ID form mandatory in headers)
  - Pointer Update Protocol (6-step procedure, atomicity rule)
  - Recovery Procedures (CI failure, recursive clone failure, pointer drift)
  - Validation Matrix (per-repo + cross-repo checks, CI triggers)
  - Related Artifacts, Change History
- Promoted from [B] Recommended to [C] Critical
- Deleted v0.1 stub
- Added Related: STD-ARCH-001 to RULE-MONOLITH-016 (submodule immutability)
  and RULE-MONOLITH-017 (upstream write protection) — both rules already
  enforce the architecture that STD-ARCH-001 v1.0 now formalizes
- Verified locally: 13/13 HARD PASS, 0 warnings (W03 closed)
- Pushed Z-ai-standards: 447725b → 85df73b
- Pushed Z-ai-guard: 676bdbe → 97d2911
- Pushed Z-ai-platform (3 atomic submodule bumps per §8.3):
  - af0a73f: bump standards
  - 1a82740: bump guard
  - 70fc5f4: bump skills (also picks up W04 fix from f3ab7df)
- Discovered CI push-trigger was broken: GitHub Actions paths filter
  ('standards/**') does not fire on submodule pointer bumps (gitlink
  change, not file change)
- Fixed workflow: dropped paths filter for push trigger
- Pushed Z-ai-platform: 70fc5f4 → 7c3461f (workflow fix)
- CI confirmed: Run #5 event=push head_sha=7c3461f conclusion=success

Stage Summary:
- STD-ARCH-001 v1.0 live on GitHub
- ID graph state: 47 IDs, 65 Related edges, 2 Aligned_with, 13/13 HARD PASS, 0 warnings
- CI workflow triggers correctly on push, PR, nightly 03:00 UTC, manual dispatch
- All 4 repos synchronized: platform@7c3461f, standards@85df73b, guard@97d2911, skills@f3ab7df
- All debts from previous session closed

---

Task ID: compliance-audit-2026-06-17
Agent: main
Task: Audit Markdown/Unicode compliance across 4-repo split; locate importable standards

Work Log:
- User asked: "Are all MD documents written strictly per MARKDOWN_STANDARD and UNICODE_POLICY?"
- Searched 4-repo split: no MARKDOWN_STANDARD or UNICODE_POLICY files present
  (only stub STD-DOC-002-v0.1.md; STD-DOC-003 missing entirely)
- Found standards in /home/z/my-project/upload/:
  - Top level: MARKDOWN_STANDARD.md (26.8K), UNICODE_POLICY.md (26K)
  - Subdir upload/standards-v2/standards/: 20 standard files totaling ~440K
- Confirmed verify-standards.js references UPLOAD_DIR for these standards
  (i.e. verifier knows about them, but they are not imported into 4-repo split)
- Scanned 118 MD files in 4-repo split for Unicode violations:
  - 307 emoji occurrences (README.md 7, CONTRIBUTING.md 5, session-experience 9, humanizer 10)
  - 297 em dash occurrences (INDEX.md 36, workflow-discipline_sts 20)
  - 28 en dash occurrences (12 in STD-META-001 itself!)
  - 2801 box drawing characters (gepetto 1591, README 123)
  - 7 smart quotes (humanizer 7)
- Reported findings to user with 3 options (import+fix, import-only, leave as-is)
- Recommended staged approach: import standards first, add verifier check as
  soft warning, then gradually clean up violations

Stage Summary:
- Confirmed: MD files are NOT strictly compliant with MARKDOWN_STANDARD/UNICODE_POLICY
- 20 standards available for import from upload/standards-v2/standards/
- Compliance scan complete; violations quantified
- User chose to defer action pending documentation of session state

---

Task ID: implementation-order-discovery-2026-06-17
Agent: main
Task: Locate and document implementation order for standard installation

Work Log:
- User asked: "Is the installation order of these standards documented anywhere?"
- Searched upload/ and 4-repo split for implementation order references
- Found: upload/standards-v2/standards/IMPLEMENTATION_ORDER.md (14.2K, STD-ARCH-001 v2.2)
- Read full document: defines 6-step Path A (new project) and adapted Path B (existing project)
  - Step 1: Accept Standards (Group B)
  - Step 2: Deploy Worklog System (Group A)
  - Step 3: Reproducibility (STD-ENV-001)
  - Step 4: Unicode Policy [C] (STD-DOC-003)
  - Step 5: Markdown Standard [W] (STD-DOC-002)
  - Step 6: README Template (STD-DOC-004)
- Document includes explicit "what happens when order is violated" table
- Confirmed: IMPLEMENTATION_ORDER.md is NOT imported into 4-repo split
- Discovered ID collision: my STD-ARCH-001 v1.0 (repo topology) conflicts
  with upstream STD-ARCH-001 (implementation order) — different concerns,
  same ID
- Documented 4 resolution options in DECISIONS_LOG.md O-001
- Recommended option (a): rename my v1.0 to STD-ARCH-002 (Repo Topology),
  give STD-ARCH-001 back to IMPLEMENTATION_ORDER

Stage Summary:
- Implementation order IS documented (in upload/, not in 4-repo split)
- 6-step sequence for new projects + adapted sequence for existing projects
- ID collision identified; resolution pending maintainer decision (O-001)
- No action taken yet; awaiting user direction

---

Task ID: session-docs-2026-06-17
Agent: main
Task: Create persistent session documentation; push to GitHub

Work Log:
- User asked: "Do you document your conclusions/experience anywhere?"
  Then: "Do it, document and push to repo. You have many files for analysis ahead."
- Honest answer: worklog.md was wiped in session restart; no session notes
  or decisions log existed
- Cloned Z-ai-platform back to /home/z/my-project/ (was wiped)
- Verified state: 13/13 HARD PASS, 0 warnings (all prior work safe on GitHub)
- Created docs/session/ directory in Z-ai-platform for session artifacts
- Wrote DECISIONS_LOG.md:
  - 10 DECIDED entries (D-001 through D-010) capturing architectural decisions
  - 7 OPEN entries (O-001 through O-007) capturing unresolved questions
  - Index, change history
- Wrote SESSION_NOTES.md:
  - 8 sections: GitHub Actions gotchas, PAT gotchas, submodule gotchas,
    verifier gotchas, Markdown/Unicode findings, standards inventory,
    workspace persistence, lessons-that-became-decisions
  - 20 standards inventoried with size/date/ID mapping
  - Recovery procedure for session restart documented
- Wrote worklog.md (this file):
  - Reconstructed 5 prior task entries from chat context
  - Established append-only protocol for future tasks

Stage Summary:
- 3 session documents created in Z-ai-platform/docs/session/
- All prior work documented and recoverable after session restart
- Ready for next phase: import 20 standards from upload/ (pending O-001, O-002)
- Next session can resume by cloning Z-ai-platform and reading docs/session/

---

Task ID: session-docs-push-2026-06-17
Agent: main
Task: Push session docs to GitHub; verify CI

Work Log:
- Committed docs/session/ (3 files, 1161 insertions) to Z-ai-platform
- Commit: f2ee6e1 "Add docs/session/: worklog, SESSION_NOTES, DECISIONS_LOG"
- Pushed to origin/main: 7c3461f → f2ee6e1
- CI Run #6: event=push, head_sha=f2ee6e1, conclusion=success (45 sec after push)
- Created symlink /home/z/my-project/worklog.md → docs/session/worklog.md
  for cross-session discoverability

Stage Summary:
- Session documentation live on GitHub:
  https://github.com/stsgs1980/Z-ai-platform/tree/main/docs/session
- 3 files: worklog.md (8.7K), SESSION_NOTES.md (17K), DECISIONS_LOG.md (19K)
- CI still green: 13/13 HARD PASS, 0 warnings
- Next session can resume by:
  1. git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git
  2. Read docs/session/DECISIONS_LOG.md for open questions (O-001..O-007)
  3. Read docs/session/SESSION_NOTES.md for lessons learned
  4. Read docs/session/worklog.md for task history
  5. Run node standards/scripts/verify-id-graph.js to confirm state

---

Task ID: superpowers-zai-analysis-2026-06-18
Agent: main
Task: Install and analyze Superpowers-Z.ai package; assess applicability to Z.ai environment

Work Log:
- Inspected install-zai.sh before running — confirmed clean (no network calls, no sudo,
  no system file edits, just markdown copy)
- Added Superpowers-Z.ai as git submodule: .superpowers-zai/
- Ran bash .superpowers-zai/install-zai.sh — installed 14 sp-* skills into skills/
- Verified install status: all 14 skills [OK] up to date
- Read all 14 SKILL.md files + README.md + references/zcode-tools.md
- Compared Superpowers style (ALL-CAPS, <HARD-GATE>, Iron Law, dense anti-pattern tables)
  against ZCode native style (from skill-creator: imperative form, <500 lines, no MUSTs,
  examples beat rules, "remove what isn't pulling their weight")
- Identified 5 conflicts with existing Z.ai gate-process:
  1. sp-brainstorming "one question at a time" vs our AskUserQuestion batch-of-6-8
  2. sp-writing-plans vs our Outline tool (duplication)
  3. sp-using-superpowers aggressive triggering vs existing system prompt gate
  4. sp-using-git-worktrees file pollution in /home/z/my-project/
  5. sp-subagent-driven-development token cost on non-coding tasks
- Tiered all 14 skills by applicability:
  - Tier 1 (active use): systematic-debugging, verification-before-completion,
    test-driven-development (code only), writing-skills
  - Tier 2 (targeted use): brainstorming (adapted), writing-plans (code projects),
    subagent-driven-development, dispatching-parallel-agents, receiving-code-review
  - Tier 3 (ignore/rare): using-superpowers (no auto-inject hook), executing-plans
    (redundant), finishing-a-development-branch (not our env), using-git-worktrees
    (caveats in Z.ai sandbox)
- Resolved philosophical question: "true Superpowers or intercepted-by-ZCode?"
  Answer: intercepted (adapted to ZCode native style) is correct, because:
  - Target model is GLM not Claude (engineered, not taste)
  - ZCode has existing gate-process (AskUserQuestion, Outline, Skill, Complete)
  - Official skill-creator explicitly opposes Obra-style enforcement
  - No parallel evaluation subagents infrastructure available
- Documented findings in /home/z/my-project/docs/superpowers-zai-analysis.md
  (9 sections: what's installed, content overview, tier assessment, conflicts,
  philosophical comparison, structural formula for own skills, plan for first
  4 own skills, 7 open questions, one-line summary)

Stage Summary:
- Superpowers-Z.ai installed as submodule + 14 sp-* skills in skills/
- Full analysis written to docs/superpowers-zai-analysis.md (worknote for further Q&A)
- Conclusion: keep Superpowers as methodology reference, write own skills in ZCode
  native style (skill-creator aesthetic), not Obra/Superpowers style
- Plan: pilot with zai-debugging (4-phase from sp-systematic-debugging, rewritten
  in ZCode style), then zai-verify-before-claim, zai-skill-authoring,
  zai-document-generation
- 7 open questions for user review before proceeding (in §8 of analysis doc)

---

Task ID: sandbox-docs-analysis-2026-06-18
Agent: main
Task: Analyze Z.ai Sandbox Documentation zip — assess applicability to our work

Work Log:
- Unpacked Z.ai Sandbox Documentation.zip to /tmp/sandbox-docs/ (7 files, identical
  to existing upload/Z.ai-Sandbox-*.md — diff confirmed identical)
- Read all 7 files in full:
  - Z.ai-Sandbox-Guide.md (937 lines, 17 sections — Next.js + bun + Prisma + Preview Panel)
  - Z.ai-Sandbox-Guide-Hooks.md (1011 lines — React hooks cookbook + z-ai-web-dev-sdk API routes)
  - Z.ai-Sandbox-Guide_commands_reference.md (679 lines preview, 1321 Linux commands catalog)
  - Z.ai-Sandbox-Migration Guide.md (223 lines — Next.js/Vercel migration with safety checks)
  - Z.ai-Sandbox-Super-Z-Subagents-Education.md (240 lines — Super Z + subagents architecture)
  - RELATIONS.md (47 lines — PlantUML diagram of doc relationships + contradictions table)
  - verify.sh (202 lines — 11 groups of checks for sandbox state)
- Checked current sandbox state: NO .zscripts/, NO src/app/, NO next.config.ts
  → current session is docs/methodology, NOT fullstack web-dev
- Identified 3 internal contradictions (per RELATIONS.md):
  1. npm vs bun (Guide says bun, Migration Guide says npm)
  2. API routes (Guide forbids, Hooks cookbook creates /api/ai/*)
  3. allowedDevOrigins (Guide requires, init-fullstack template lacks)
- Identified 1 stale doc: Subagents-Education (March 2025) contradicts skill-creator
  on progressive disclosure vs single-file skills
- Wrote analysis to docs/sandbox-docs-analysis.md (10 sections, ~6KB):
  - File-by-file assessment (needed / not needed / where to store)
  - Per-scenario applicability matrix
  - Specific recommendation: docs/sandbox/ + 3 short wrapper-skills
  - 5 open questions for user

Stage Summary:
- Conclusion: package needed as reference documentation for fullstack web-dev in Z.ai
  sandbox (especially Guide, Hooks, Migration, Subagents-Education, verify.sh)
- BUT should NOT be installed as skills in current form — too large (47K for
  commands_reference alone), partially stale, contradicts skill-creator style
- Recommendation: unpack to docs/sandbox/, write 3 short wrapper-skills
  (zai-fullstack-init, zai-sandbox-migration, zai-subagents-architecture) that
  reference the docs on demand
- For current docs session: only Subagents-Education.md + RELATIONS.md give
  immediate value (architectural understanding); rest is for future fullstack work
- 5 open questions for user (in §9 of analysis doc) before proceeding

---

Task ID: extract-pro-skilli-and-sandbox-triage-2026-06-18
Agent: main
Task: Extract all valuable content from "Про скилы" package into existing md
infrastructure (no new docs in /docs/), and make a final keep/drop decision
on Z.ai Sandbox Documentation

Work Log:
- Read all 9 files in "upload/Про скилы unpacked/" to identify extractable value
- Read existing SESSION_NOTES.md (sections 1-8 + Change History) and
  DECISIONS_LOG.md (D-001..D-010, O-001..O-007) to understand injection points
- Created `Z-ai-platform/scripts/fix-unicode-compliance.js` (300+ lines):
  - Extracted canonical emoji regex from "Skill assembler.txt" §6.1
    (U+1F000-1FFFF, U+2600-27BF, U+FE00-FEFF, U+1F900-1F9FF, U+2702-27B0)
  - Extracted final sanitization regex (ASCII + Cyrillic only)
  - Added context-aware targeted fixers: em-dash -> "--", en-dash -> "-",
    smart quotes -> straight, box-drawing -> ASCII tree equivalents
  - CLI: --apply, --path, report-only mode
  - Tested on standards/: 727 violations in 9 files (25 emoji, 135 em-dash,
    27 en-dash, 0 smart-quotes, 540 box-drawing) -- numbers match prior scan
- Appended 3 new sections to SESSION_NOTES.md:
  - §9 "Sandbox persistence model (mount points)" -- extracted from
    "Архитектура хранения skills в песочнице.md". Documents the 4 mount points
    (OSS / PolarFS / overlay / tmpfs), the startup sequence, the disposability
    of /home/z/my-project/skills/, the name-collision risk, and the install
    procedure for Z-ai-skills. Closes O-006 and O-007.
  - §10 "Z.ai Sandbox Documentation -- keep / drop decision" -- final triage
    matrix for the 7 sandbox docs. Decision: KEEP 6, DROP 1
    (commands_reference.md, 47K, redundant with agent's Linux knowledge).
    Records the 3 internal contradictions (npm vs bun, API routes,
    allowedDevOrigins) and the session-type applicability matrix.
  - §11 "Ready-to-use Unicode regex filters" -- documents the two canonical
    regexes from upstream MARKDOWN_STANDARD.md with usage warnings, points
    to scripts/fix-unicode-compliance.js for the implementation
- Appended 7 new entries to DECISIONS_LOG.md:
  - O-008: MAS "Skill & Standard Factory" roadmap (5 agents, 3 phases, we are at Phase 1)
  - O-009: Standard typology TECHNICAL/MANAGEMENT/COMPLIANCE/GUIDANCE (proposed for STD-META-001 v2.1)
  - O-010: R1-R18 recommendations triage -- 3 critical (R1/R2/R5), 4 high, 3 medium, 3 standards-specific, 5 rejected as N/A
  - O-011: 88-skill inventory vs our 35-skill catalog -- gap is healthy (delta = Z.ai official + 3P)
  - O-012: ui-clarity_sts 6-phase UI redesign methodology -- defer adoption, ID collision (ZAI-STS-007 taken by workflow-discipline_sts), use ZAI-STS-008 when needed
  - O-013: Reserve MAS agent IDs ZAI-ORCH-001, ZAI-META-003/004/005, ZAI-CORE-001. Avoid ZAI-STD-001 to keep STD-* prefix exclusive to standards.
  - O-014: Z.ai Sandbox Documentation final triage -- DECIDED (keep 6/7, drop commands_reference, do not package as skills, write 3 wrapper-skills later)
- Marked O-006 and O-007 as RESOLVED in the Index (they are now answered in SESSION_NOTES §9)
- Updated Change History in both SESSION_NOTES.md and DECISIONS_LOG.md
- Verified the fix-unicode-compliance.js script works in report-only mode

Stage Summary:
- Extraction complete: 9 source files -> 1 script + 3 new SESSION_NOTES sections + 7 new DECISIONS_LOG entries
- No new docs files created in /docs/ (per user instruction "без явной задачи никаких DOCS не создавать")
- Z.ai Sandbox Documentation triage DECIDED: keep 6 of 7 files in upload/, drop commands_reference.md from active use, do not package as skills
- "Про скилы" package source files preserved in upload/ (not deleted) because O-008 (MAS roadmap) and O-013 (ID reservation) still reference them
- Open items for maintainer: confirm O-008 (adopt MAS roadmap), O-009 (add type: field to standards), O-010 (R1/R2/R5 -> STD-SKILL-001 v1.1), O-013 (reserve MAS IDs)
- Next session can resume by: reading SESSION_NOTES §9-11 + DECISIONS_LOG O-008..O-014, running `node scripts/fix-unicode-compliance.js --path standards/` to verify the 727-violation baseline

---

Task ID: sandbox-archive-bootstrap-2026-06-18
Agent: main
Task: Move Z.ai Sandbox Documentation (7 files) into standards/docs/sandbox/; add thin §3.0 Bootstrap Procedure to ENV-002; harden verify-id-graph.js with new SOFT warnings W11-W15 so the guard catches project growth / inconsistencies that G01-G15 currently miss.

Plan (committed BEFORE execution, per user instruction "профессионально = дублировать план в worklog"):
1. Create `Z-ai-platform/standards/docs/sandbox/` directory.
2. Move 7 files from `upload/` to `standards/docs/sandbox/` with standardized snake-case names:
   - Z.ai-Sandbox-Guide.md → sandbox-guide.md
   - Z.ai-Sandbox-Guide-Hooks.md → sandbox-hooks-cookbook.md
   - Z.ai-Sandbox-Guide_commands_reference.md → sandbox-commands-cheatsheet.md
   - Z.ai-Sandbox-Migration Guide.md → sandbox-migration.md
   - Z.ai-Sandbox-Super-Z-Subagents-Education.md → sandbox-subagents-architecture.md
   - RELATIONS.md → INDEX.md (renamed + updated internal links to new filenames)
   - verify.sh → verify-sandbox.sh
3. Add §3.0 "Bootstrap Procedure for New Project" to ENV-002-zai-integration.md:
   - Thin (< 60 lines), 7-step bootstrap flow, references docs/sandbox/* on demand.
   - Inserts BEFORE existing §3 "Project Directory" so bootstrap→directory ordering is preserved.
   - Existing §3 / §3.1 numbering UNCHANGED (no broken cross-references).
4. Harden verify-id-graph.js with new SOFT warnings (do NOT promote to HARD — would break CI):
   - W11: Size anomaly. Standard .md > 1000 lines → warn; > 1500 lines → critical warn.
     Rationale: DESIGN-001 is 1780 lines (anomaly); median is ~640 lines.
   - W12: Missing §XA Known Issues section. Every standard MUST have a Known Issues section
     (per doc convention established in ENV-002 v1.2 §10A).
   - W13: Broken cross-doc file references. If a standard's body links to a .md file path
     that does not exist in standards/ or docs/, warn.
   - W14: Excessive OPEN Known Issues. If a single standard has > 5 OPEN issues in §XA,
     warn (debt accumulation signal).
   - W15: Naming drift. Files in standards/ that do not match `<DOMAIN>-<NNN>-<name>.md`
     pattern (13 domains: META, ARCH, DOC, SKILL, ENV, GIT, DESIGN, FE, A11Y, ERR, SEC, TEST, AGENT).
5. Run verify-id-graph.js: expect 13/13 HARD PASS (unchanged), expect new W11-W15 to surface
   (specifically W11 on DESIGN-001, W12 on any new standard missing §XA).
6. Commit Z-ai-standards, push, bump submodule pointer in Z-ai-platform, push parent.
7. Append final Stage Summary to this worklog section.

Stage Summary (planned):
- docs/sandbox/ populated with 7 standardized-name reference files + INDEX.md.
- ENV-002 v1.3 published with §3.0 Bootstrap Procedure.
- verify-id-graph.js v1.1.0 published with W11-W15 soft warnings.
- CI remains green (HARD checks untouched). New warnings surface as actionable debt.

Work Log (execution):
- Read worklog.md (359 lines, full prior context).
- Read ENV-002-zai-integration.md v1.2 fully (260 lines, 9 sections + Known Issues).
  Confirmed: NO bootstrap section existed. §6 "Session Continuity" was the closest,
  but it covers RESUMING a session, not BOOTSTRAPPING a new project.
- Located 7 sandbox-archive files in `/home/z/my-project/upload/` (analysis already
  done in `docs/sandbox-docs-analysis.md` from prior session).
- Created `Z-ai-platform/standards/docs/sandbox/` and copied 7 files with standardized names:
  - Z.ai-Sandbox-Guide.md -> sandbox-guide.md
  - Z.ai-Sandbox-Guide-Hooks.md -> sandbox-hooks-cookbook.md
  - Z.ai-Sandbox-Guide_commands_reference.md -> sandbox-commands-cheatsheet.md
  - Z.ai-Sandbox-Migration Guide.md -> sandbox-migration.md
  - Z.ai-Sandbox-Super-Z-Subagents-Education.md -> sandbox-subagents-architecture.md
  - verify.sh -> verify-sandbox.sh
  - RELATIONS.md -> INDEX.md (rewritten with new filenames + authority order + maintenance rules)
- Edited ENV-002-zai-integration.md via MultiEdit (5 atomic edits in one operation):
  - Bumped version 1.2 -> 1.3 in header
  - Updated Related: field (added ARCH-002-implementation-order.md, docs/sandbox/INDEX.md;
    removed stale sandbox-rules.md (instructions/) reference)
  - Inserted §3.0 "Bootstrap Procedure for a New Project" BEFORE existing §3
    (3 subsections: 7-step flow, guarantees, failure handling)
  - Added v1.3 row to Version History table
  - Added ZAI-008 Known Issue (unpinned init-fullstack_*.sh version)
  Existing §3 / §3.1 numbering UNCHANGED -> no broken cross-references.
- Hardened verify-id-graph.js via MultiEdit (5 atomic edits in one operation):
  - Bumped VERSION 1.0.0 -> 1.1.0
  - Added W11-W15 description to header comment
  - Added SOFT (W11-W15) entry to TWO-LEVEL STRICTNESS block
  - Inserted new function phase10_healthWarnings(repos) after phase9_orphanWarnings
    (with VALID_DOMAINS constant: 13 domains)
  - Added phase10 call in main() after phase9
  - Updated output section title "Soft Warnings (W01-W10)" -> "Soft Warnings (W01-W15)"
- Ran `node standards/scripts/verify-id-graph.js` from platform root.

Verification results:
  - HARD: 13/13 PASS (G01-G15, unchanged — CI stays green)
  - W11 (size anomaly): 2 warnings
      * DESIGN-001-design-system.md: 1781 lines (CRITICAL — exceeds 1500-line cap)
      * sandbox-hooks-cookbook.md: 1011 lines (soft cap)
  - W12 (missing §XA Known Issues): 2 warnings
      * ARCH-001-architecture-and-repo-layout.md
      * SKILL-001-skill-format.md
  - W13 (broken cross-doc references): 75 warnings
      * Mostly from README.md referencing old filenames (IMPLEMENTATION_ORDER.md,
        STANDARD_ID_SYSTEM.md, etc. — pre-restructure names)
      * Some from individual standards referencing renamed/removed files
  - W14 (excessive OPEN): 0 warnings
  - W15 (naming drift): 0 warnings (flat layout is consistent)
  - W03 (pre-existing dead-standard): 5 warnings (unchanged)
  - Total: 84 SOFT warnings, 0 HARD failures

Commit + push:
- Standards submodule: 5d9be05 -> c0d1dbe ("feat(verify): W11-W15 + ENV-002 §3.0 + docs/sandbox/")
- Pushed to GitHub stsgs1980/Z-ai-standards (main): SUCCESS
- Parent (Z-ai-platform): bumping standards submodule pointer + this worklog entry
  in one atomic commit.

Stage Summary (actual):
- docs/sandbox/ live with 7 standardized-name reference files + INDEX.md.
- ENV-002 v1.3 published with §3.0 Bootstrap Procedure (thin, 7-step flow,
  references docs/sandbox/ on demand).
- verify-id-graph.js v1.1.0 published with W11-W15 soft warnings. HARD checks
  untouched — CI remains green. New warnings surface actionable debt:
  - DESIGN-001 1781 lines -> split required (W11 CRITICAL)
  - ARCH-001, SKILL-001 missing §XA Known Issues -> add (W12)
  - README.md + 20 standards reference old pre-restructure filenames -> fix
    cross-doc links (W13, 75 occurrences) — this is exactly the "project is
    growing and not everything matches" signal the user asked the guard to catch.
- Next debt cleanup targets (in priority order):
  1. W13 sweep: fix 75 broken cross-doc references (mostly README.md rename sweep)
  2. W11 CRITICAL: split DESIGN-001 into normative + tokens appendix
  3. W12: add §XA Known Issues to ARCH-001 and SKILL-001
  4. ZAI-005, ZAI-006, ZAI-007, ZAI-008 (open issues in ENV-002)
- Guard now catches project-growth inconsistencies. User complaint
  "guard пиздюлей не дает" resolved: 84 actionable warnings emitted, was 5 before.
