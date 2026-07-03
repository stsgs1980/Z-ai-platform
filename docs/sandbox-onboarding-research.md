# Sandbox onboarding flow — research & variant evaluation

> Tracks **O-021** (`docs/session/DECISIONS_LOG.md`). Deep-dive companion
> to the decision record. Purpose: explore, test, and decide how a fresh
> Z.ai chat sandbox is brought to an organized, rule-enforced state via
> 1-2 short commands.

**Status:** research phase (paused 2026-07-03)
**Owner:** maintainer (stsgs1980)
**Relates to:** O-007 (consumer onboarding, resolved), O-017 Phase E (consumer integration, pending), O-014 (sandbox docs triage)

---

## 1. Current state (what exists today)

Three artifacts address sandbox setup, but they are fragmented and none
delivers the full vision alone.

### 1.1 Canonical `bootstrap.sh` (in Z-ai-platform)

- **What it does:** clones Z-ai-platform (with submodules) into
  `/home/z/my-project/Z-ai-platform/`; symlinks each skill into
  `/home/z/my-project/skills/`; normalizes git `core.fileMode`; prints
  AGENT_RULES.md; runs `verify-standards.js` + `verify-id-graph.js`.
- **Strengths:** in the canonical repo; restores the 35+ skills;
  documented in README; idempotent (pulls if exists).
- **Weaknesses:**
  - Installs NO enforcement (no pre-commit hook, no `.zai.json`).
  - Step 6 verifiers are `warning-only, non-blocking` — a "successful"
    bootstrap does NOT prove the system is healthy.
  - Does not load the `zai-sandbox-rules` skill (agent may still break
    the preview by running dev servers manually).
  - Hardcoded paths `/home/z/my-project/` assume a specific sandbox
    layout.

### 1.2 `zai` CLI prototype (Desktop `sandbox варианты/`, NOT in canonical repo)

- **What it does:** `zai install` populates `~/.zai/` globally
  (bin/lib/templates/config/scripts); `zai init` creates per-project
  `.gitattributes`, `.zai.json`, `.husky/pre-commit`, patches
  `package.json`; `zai verify` runs enabled checks. See arch doc §5,
  §8-§10, §13.
- **Strengths:** real enforcement — husky pre-commit fires
  co-change + worklog + lint-staged automatically on commit; two-level
  config (global default + project override); arch doc §13 records it
  was hand-tested in a sandbox (found 62 HARD + 49 SOFT line-count
  violations).
- **Weaknesses:**
  - NOT in the canonical repo — prototype scripts live on the Desktop,
    not version-controlled in Z-ai-platform.
  - Arch doc §15.6 admits "zero tests" for the checks and orchestrator.
  - Does NOT restore skills (no symlink step).
  - Does NOT load `zai-sandbox-rules`.
  - Persistence of `~/.zai/` across sandbox restarts unverified (§15.2).
  - §15 has 10 open design questions (distribution, ESLint custom rules,
    verifier wiring, snapshot location, telemetry, naming, etc.).

### 1.3 Skill `zai-sandbox-rules` (Desktop `SKILLSET LIBRARY/`)

- **What it does:** agent behavioral guardrails IN the sandbox
  (Rules 1-10 + rationalization table + red flags): never run dev
  servers manually, don't kill processes, don't change ports, wait for
  auto-recovery, module-not-found handling, clone conventions, etc.
- **Strengths:** directly prevents the most common way an agent breaks
  the preview (manual `npm run dev` -> EADDRINUSE -> broken HMR). The
  rationalization table pre-empts LLM bypass attempts.
- **Weaknesses:**
  - NOT an onboarding/setup script — it is prohibitions.
  - Rule 8 ("Init Sandbox") only says "use the sandbox's init flow,
    don't scaffold manually" — a prohibition, not a command.
  - Loading the skill at cold start is itself unsolved (the agent must
    load it before it can follow it — chicken/egg).

### 1.4 The gap

No single mechanism delivers "1-2 commands -> organized, rule-enforced
sandbox". The three pieces are complementary but ununified, untested as
a whole, and partly outside version control. Concretely:

| Capability needed | bootstrap.sh | zai CLI | zai-sandbox-rules |
|---|---|---|---|
| Restore skills | yes | no | no |
| Enforcement (pre-commit) | no | yes | no |
| Agent operational guardrails | no | no | yes |
| In canonical repo | yes | no | no (Desktop) |
| Regression-tested | no | no (§15.6) | no |

---

## 2. Goal — declared end-state (the oracle)

After the 1-2 entry commands run in a FRESH Z.ai chat sandbox, ALL of the
following MUST be true. These become the characterization assertions
(E1-E5) against which every variant is measured.

| # | Assertion | Declared by |
|---|---|---|
| E1 | Custom skills discoverable/invokable by the agent | bootstrap.sh purpose |
| E2 | `git commit` triggers co-change + worklog + lint | PROC-COCHANGE-003, PROC-WORKLOG-005, STD-DOC-003 |
| E3 | `zai verify` (or equivalent) exits 0 | arch doc §10 |
| E4 | Agent has loaded sandbox operational rules (no manual dev server) | zai-sandbox-rules Rules 1-10 |
| E5 | Idempotent, re-runnable on every cold start, < ~5s | usability |

**Principle:** the declaration is the oracle. If a variant's docs claim a
capability, the test asserts it concretely. Discrepancies are flagged,
not silently trusted (the user mandate: "everything declared must be
verified and tested").

---

## 3. Variants to test

| Variant | Entry commands | E1 skills | E2 enforce | E3 verify | E4 rules | In repo |
|---|---|---|---|---|---|---|
| **A. bootstrap-centric** | `bash <(curl .../bootstrap.sh)` | yes | no | partial (non-blocking) | no | yes |
| **B. zai CLI** | `zai install; zai init` | no | yes | yes | no | no (prototype) |
| **C. skill as entry** | trigger `zai-sandbox-rules` | partial | partial | no | yes | n/a |
| **D. hybrid unified** | one unified bootstrap command | yes | yes | yes | yes | to build |

### 3.1 Variant notes

- **A** is the lowest-effort starting point (already works, in repo) but
  leaves E2/E4 entirely unmet. Good baseline, not the destination.
- **B** is the strongest on enforcement (E2/E3) but is out-of-repo,
  untested, and misses E1/E4. Promising core, needs integration + tests.
- **C** makes the skill the entry point. Risk: mixing concerns (a
  behavioral-guardrail skill also driving setup), plus the cold-start
  chicken/egg (skill must load before it can bootstrap). Possibly a
  thin wrapper that CALLS A/B/D, not a replacement for them.
- **D** unifies all three behind one command (or two: global install +
  per-project init). Most complete, most work, must be built AND tested.

---

## 4. Test / evaluation plan

Characterization testing: each variant is driven in a clean environment
and measured against E1-E5. Same assertions for all variants -> directly
comparable results.

### 4.1 Environment

- **Primary:** a fresh/disposable Z.ai chat sandbox (the real target).
- **Fallback (deterministic, no sandbox needed):** a Docker container
  mimicking the layout (`/home/z/my-project/`, bash, node, git). Lets us
  regression-test the onboarding in CI without a live sandbox.

### 4.2 Procedure (per variant)

1. Start from a clean environment (no `~/.zai/`, no `Z-ai-platform/`,
   empty `/home/z/my-project/skills/`).
2. Run the variant's entry command(s).
3. Assert E1-E5:
   - E1: list `/home/z/my-project/skills/` -> expected skill count
     present and symlinked; a sample skill is invokable.
   - E2: stage a code change with no doc update -> `git commit` MUST be
     blocked by co-change; with doc update -> passes; missing worklog
     entry -> blocked.
   - E3: `zai verify` (or the variant's equivalent) exits 0 and prints
     the expected PASS summary.
   - E4: confirm the sandbox-rules content is loaded/available to the
     agent (assertion mechanism TBD — depends on how the agent loads
     skills in the target).
   - E5: run the entry commands a second time -> no error, no duplicate
     state, completes in < ~5s.
4. Record results in the matrix (§5).

### 4.3 Open question for E4

E4 (agent loaded the rules) is the hardest to assert mechanically — it
is behavioral, not filesystem state. Candidate approaches: (a) the
onboarding writes a marker the agent's skill-loader confirms; (b) a
characterization test that gives the agent a task that would tempt a
rule violation (e.g. "preview is blank, fix it") and asserts it does NOT
run `npm run dev`. This needs the agent-driving harness — the most novel
part of the test plan.

---

## 5. Decision criteria & matrix

| Criterion | Weight | A | B | C | D |
|---|---|---|---|---|---|
| Meets E1-E5 (coverage) | high | | | | |
| Reliability (deterministic, no fragile assumptions) | high | | | | |
| Persistence across sandbox restarts | medium | | | | |
| Friction (1-2 short commands, fast) | medium | | | | |
| In canonical repo / version-controlled | medium | | | | |
| Regression-testable in CI | medium | | | | |
| Build effort | low (lower = better) | | | | |

(Filled per-variant after running §4. The recommendation in O-021 is
preliminary; the matrix decides.)

---

## 6. Decision log

| Date | Variant | Result (E1-E5) | Notes |
|---|---|---|---|
| _(to fill after testing)_ | | | |

---

## 7. Open questions (carry into O-021 / future O-NNN)

1. Is `~` persistent in the Z.ai chat sandbox across restarts? (arch
   doc §15.2 — unresolved.) Determines whether global install survives or
   must re-run on every cold start.
2. How does the agent in chat.z.ai actually load skills at cold start?
   (Determines E4 assertion mechanism and whether Variant C is viable.)
3. Does chat.z.ai give the agent FS + shell access at all (the model
   `bootstrap.sh` assumes)? If not, the whole onboarding model changes
   (rules would have to enter via system prompt, not files).
4. Where does the unified onboarding ultimately live — Z-ai-platform
   (extend bootstrap.sh) or a dedicated `zai-cli` repo (arch doc §15.10)?
5. Should E2 enforcement be wired via husky (current zai CLI) or via the
   platform's existing `.githooks/` + `install-hooks.sh`? Two hook
   systems risk divergence.

---

## 8. How to resume

1. Answer open question §7.3 (chat.z.ai sandbox capabilities) — this
   gates everything.
2. Stand up the §4.1 test environment (Docker mimic first — no sandbox
   dependency).
3. Run variant A (lowest effort, in-repo) to calibrate the harness.
4. Run B, C, D; fill the §5 matrix and §6 log.
5. Decide in O-021; record decision + reversal cost.
