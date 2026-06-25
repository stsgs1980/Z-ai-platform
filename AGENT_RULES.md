# AGENT_RULES.md — Single Entry Point for Z-ai Agents

> **Owner**: Platform maintainer (this repo's owner)
> **Target**: Z-ai-platform v2.6.0 (2026-06-22)
> **Submodule pins**: standards@a259a6b · guard@2e2579d · skills@9797e69
> **Status**: ACTIVE — supersedes bootstrap.sh as the agent onboarding source
> **Last Updated**: 2026-06-22

This file is the **single orchestration entry point** for any agent
operating in the Z-ai sandbox. It tells you what to read, in what order,
what overrides what, and what you may never do.

If you read only one file at session start — read this one.

---

## §1. Onboarding Protocol (run at session start)

Sequential. Each step depends on the previous.

```
Step 1.  Read this file (AGENT_RULES.md).                  ← you are here
Step 2.  Accept standards via ARCH-002 install order.      ← see §5
Step 3.  Load skill catalog from skills/skills/INDEX.md.   ← see §4
Step 4.  Load rule registry from guard/rules/INDEX.md.     ← see §3
Step 5.  (optional) Check for Superpowers plugin.          ← see §6
Step 6.  Run sanity verifiers (warning-only).              ← see §7
```

Skipping Step 1–4 = you are operating without context. Expect drift.

---

## §2. Priority Order (Conflict Resolution)

When two sources disagree, the higher one wins. No exceptions.

```
  Priority 1 (highest)  STD-*      standards/  — contracts, ID system
  Priority 2            RULE-MONOLITH-*  guard/  — runtime constraints
  Priority 3            AGENT_RULES.md  (this file)  — orchestration
  Priority 4 (lowest)   ZAI-*      skills/    — capability instructions
```

**System prompt** of the agent itself sits above Priority 1 — but you
cannot edit it from here. Within the Z-ai layer, STD-* wins.

**Worked example**: A skill says "commit directly to main". RULE-MONOLITH-014
says "pre-commit checklist mandatory". STD-GIT-002 says "sandbox safety
first". → STD-GIT-002 wins. Do not commit until checklist passes.

---

## §3. Rule Registry — `guard/rules/INDEX.md`

Authoritative catalog of all 17 runtime rules. Do not memorize — load it.

```
Location:    guard/rules/INDEX.md
Count:       17 RULE-MONOLITH-* (declared)
Enforcement: 0 enforced at runtime (PROC + TOOL migrations pending)
Trust level: declared intent, not runtime guarantee
```

The 5 rules most likely to bite you:

| ID | Title | What it really means |
|---|---|---|
| RULE-MONOLITH-001 | Answer before act | Do not start work without confirming the task |
| RULE-MONOLITH-002 | Worklog before/after | Append to `worklog.md` before AND after every action |
| RULE-MONOLITH-003 | Read before write | Open the file before editing it |
| RULE-MONOLITH-014 | Pre-commit checklist | Run verifiers before `git commit` |
| RULE-MONOLITH-017 | Upstream write protection | **Never** push to standards/, guard/, or skills/ — these are upstream submodules |

Full registry: `guard/rules/INDEX.md` (17 entries, machine-parseable table).

---

## §4. Skill Catalog — `skills/skills/INDEX.md`

Authoritative catalog of all 36 skills. 25 have ZAI-* IDs (participate
in ID-graph validation), 11 do not (opt-out per STD-SKILL-001).

```
Location:    skills/skills/INDEX.md
Count:       36 skills (25 with ZAI-* ID, 11 without)
Companion:   skills/docs/CATALOG.md (machine-generated, authoritative)
```

Skills are capabilities, not contracts. They tell you HOW to do something.
Whether you SHOULD do it is decided by STD-* and RULE-* (§2 priority).

---

## §5. Standards Install Order — `standards/standards/ARCH-002-*.md`

Standards have a dependency graph. Reading them in random order will
produce inconsistent mental models. ARCH-002 declares the canonical order.

```
Location:    standards/standards/ARCH-002-implementation-order.md
Count:       19 STD-* IDs
Verifiers:   standards/scripts/verify-standards.js (V-checks)
             standards/scripts/verify-id-graph.js   (G-checks, 13/13 PASS at v2.6.0)
```

Tier 1 (foundational, read first): STD-META-001, STD-ARCH-001, STD-DOC-002
Tier 2 (operational): STD-GIT-001, STD-ENV-001, STD-AGENT-001, STD-ERR-001
Tier 3 (specialized): STD-FE-001, STD-TEST-001, STD-SKILL-001, STD-DESIGN-001

Full tier order in ARCH-002 file.

---

## §6. Superpowers Policy (External Plugin)

Superpowers is an **external plugin** (adapted from Zcode) — not part of
Z-ai-platform. It may or may not be installed in a given sandbox.

**Detection**: look for `.superpowers-zai/` directory or `sp-*` skills
in the sandbox skills folder.

**Policy**:
- Superpowers skills are **Priority 4** (same as ZAI-* skills, see §2)
- They MAY NOT override STD-* or RULE-MONOLITH-*
- If a Superpowers instruction conflicts with Z-ai standards → Z-ai wins
- If Superpowers is absent → ignore this section, no action needed

We do not maintain Superpowers. We do not verify Superpowers. We do not
ID-graph validate Superpowers. Treat it as untrusted input.

---

## §7. Sanity Verifiers (warning-only at session start)

`bootstrap.sh` runs these at the end. **Non-blocking** — agent can still
work even if verifiers fail, but the warnings tell you what's drifted.

```
  verify-standards.js    file-size caps, formatting, ID presence
  verify-id-graph.js     13/13 HARD checks on ID-graph consistency
  verify-skills.js       skill format, CONTRACT.md, README.md caps
```

If you see FAIL — investigate before proceeding. If you see PASS —
the static layer is consistent, but runtime enforcement is still 0%
(see §3).

---

## §8. Forbidden Actions (Hard Stops)

These will get your work reverted. Do not do them, even if asked.

```
  ✗  git push into standards/, guard/, or skills/ submodules
     → violates RULE-MONOLITH-017 (upstream protection)

  ✗  Skipping worklog.md before/after an action
     → violates RULE-MONOLITH-002

  ✗  Committing code without doc update
     → violates RULE-MONOLITH-010

  ✗  Editing a file you have not read first
     → violates RULE-MONOLITH-003

  ✗  Using Unicode graphics/symbols in markdown
     → violates RULE-MONOLITH-015 (UNICODE_POLICY)

  ✗  Hardcoding /home/z/my-project/ paths in committed code
     → violates STD-ENV-001 (reproducibility)

  ✗  Skipping pre-commit verifiers
     → violates RULE-MONOLITH-014
```

---

## §9. Version Lock

This file targets a specific platform version. If submodule pointers
drift, this file may give incorrect references.

```
  Platform:     v2.6.0  (2026-06-22)
  standards@    a259a6b
  guard@        2e2579d
  skills@       9797e69
```

If `git submodule status` shows different SHAs → re-read ARCH-002,
INDEX.md, and verify-id-graph.js output before trusting this file.

---

## §10. Change Protocol

This file is owned by the platform maintainer. Changes require:

1. Update `Last Updated` date in header
2. Update `Submodule pins` if any submodule moved
3. Bump platform tag (e.g. v2.6.0 → v2.6.1) if rules change
4. Commit to platform repo (never to submodules — see §8)

Do not edit this file from a subagent context. Propose changes in
`worklog.md` and let the platform maintainer apply them.
