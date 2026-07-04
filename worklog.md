# WORKLOG

## Work Notes for Z-ai-platform

**Format:**
Sections separated by ---

**Content:** specific facts (files, commands, results)

---

## Sessions

### 2026-07-02
**Entry:** Starting work in Z-ai-platform

Read README.md, analyzed site structure, analyzed package.json.

Added worklog.md and changelog.md files to all four Z-ai modules:

- [OK] Z-ai-guard (worklog.md and CHANGELOG.md added)
- [OK] Z-ai-platform (worklog.md and CHANGELOG.md added)
- [OK] Z-ai-skills (worklog.md and CHANGELOG.md added)
- [OK] Z-ai-standards (worklog.md and CHANGELOG.md added)

**Next steps:** Complete work on adding worklog.md and CHANGELOG.md to all Z-ai modules.

---

### 2026-07-02 15:30
**Entry:** Continuing work in Z-ai-platform

Added worklog.md and CHANGELOG.md to Z-ai-platform.

**Work content:** Created files per RULE-MONOLITH-010 (documentation sync) and RULE-MONOLITH-002 (maintain worklog).

**Next steps:** Add worklog.md and CHANGELOG.md to Z-ai-guard (if missing) and complete work.

---

### 2026-07-02 15:45
**Entry:** Creating worklog.md and changelog.md in Z-ai-platform

**Work content:** Created worklog.md and CHANGELOG.md in Z-ai-platform root directory.

**Format:** Follows Z-ai standards, includes --- separators for new entries, contains specific facts about work.

**Next steps:** Add worklog.md and CHANGELOG.md to Z-ai-guard (if missing) and complete work.

---

### 2026-07-02 18:00-22:00
**Entry:** CI pipeline fix + control mechanisms setup

**Context:** Verify ID Graph CI was failing for 98+ runs. Root-cause analysis and fix.

**Work completed:**

1. **Renamed ESLint rule** `no-unicode-policy` -> `unicode-policy` in `eslint.config.js`
   - Deleted `eslint-rules/no-unicode-policy.js`, created `eslint-rules/unicode-policy.js`
   - Updated all rule names: `no-emoji` -> `emoji`, `no-unicode-graphics` -> `unicode-graphics`

2. **Added workspace boundary rule** to `AGENT_RULES.md` section 8

3. **Wired PROC-COCHANGE-003** into `.husky/pre-commit`
   - Before: only `npx lint-staged`
   - After: `co-change-check.sh --hard` then `npx lint-staged`
   - Confirmed working: blocks code-without-docs commits

4. **Fixed 3 root-cause bugs in verifiers** (via standards submodule):
   - `parseBlockquoteHeader`: regex `$` fails before `\r` (CRLF) -> added `\r?` normalization
   - `parseYAMLFrontmatter`: regex `/^---\n/` fails on Windows CRLF -> added `\r?\n`
   - `file-scanner.js`: `path.relative()` returns backslashes on Windows -> normalized to forward slashes

5. **Fixed graph-deps.sh ESM compatibility**: `.graph-transform.js` -> `.graph-transform.cjs`
   - Z-ai-platform `package.json` has `"type": "module"`, so `.js` files are ESM
   - Generated transform script uses `require()` (CommonJS), needs `.cjs` extension

6. **Updated snapshot baseline**: 66 IDs, 129 edges, 0 warnings
   - Previous baseline was stale (65 IDs, pre-META-002)

**Files modified:**
- `AGENT_RULES.md` -- workspace boundary rule added
- `eslint.config.js` -- rule names updated
- `eslint-rules/unicode-policy.js` -- renamed from no-unicode-policy.js
- `.husky/pre-commit` -- PROC-COCHANGE-003 wired in
- `CHANGELOG.md` -- updated

**Verification:**
```bash
node standards/scripts/verify-id-graph.js      # 13/13 PASS, 0 warnings
node standards/scripts/verify-standards.js     # 8/8 PASS
node standards/scripts/verify-skills.js        # 9/9 PASS
```

**CI result:** Run #28614645655 = first GREEN run (58s). Previous 98 runs all failed.

**Submodule pointers at session end:**
- standards: `f5a5bd4` (CRLF fixes + Unicode cleanup + snapshot update)
- guard: `a624215` (co-change-check.sh auto-detect + LF)
- skills: `59b4a89` (Unicode cleanup)

**Next steps:** Push workflow files for guard/skills (need PAT with `workflow` scope)

---

### 2026-07-03 00:15-00:30
**Entry:** Push workflow files for guard/skills (next step from previous session)

**Context:** CI workflows for submodules guard and skills. Skills already had `lint-markdown.yml` on remote but CI was RED. Guard had no workflow at all.

**Work completed:**

1. **GitHub CLI auth:** added `workflow` scope to active account `stsgs1980` via `gh auth refresh -h github.com -s workflow`

2. **Guard: created lint-markdown workflow**
   - Synced local `main` to `origin/main` (was 5 commits behind, detached HEAD)
   - Created `.github/workflows/lint-markdown.yml` (modeled on skills workflow)
   - Verified locally: `npm run lint` passes clean
   - Committed `9d5e889`: `ci: add lint-markdown workflow (STD-DOC-002, STD-DOC-003)`
   - Pushed; CI run #28630011239 = GREEN (14s)

3. **Skills: fixed RED CI (emoji violations)**
   - CI run #28616182908 failed: emoji in `CHANGELOG.md:25` and `worklog.md:40`
   - Root cause: previous Unicode cleanup (59b4a89) documented removed emoji but left the actual emoji characters in worklog/CHANGELOG
   - Replaced `log-emoji`/`star+log-emoji` characters with ASCII descriptions
   - Verified locally: `npx eslint . --max-warnings=0` = 0 errors
   - Committed `50773af`: `fix: replace remaining emoji in worklog/CHANGELOG (STD-DOC-003)`
   - Pushed; CI run #28630139493 = GREEN (16s)

4. **Bumped submodule pointers** in Z-ai-platform (guard + skills)

**Submodule pointers at session end:**
- guard: `9d5e889` (lint-markdown workflow added)
- skills: `50773af` (emoji fix)
- standards: `e1e68fa` (unchanged)

**Known issue (non-fatal):** both workflows use `actions/checkout@v4` which triggers Node 20 deprecation warning. Optional: bump to `checkout@v5`.

**Next steps:** Optional workflow version bump to silence Node 20 deprecation.

---

### 2026-07-03 00:35-00:40
**Entry:** Fix Z-ai-platform CI failures (checkout auth + release-please permissions)

**Context:** Push `7c59271` triggered 4 CI errors: `actions/checkout@v4` failed with `could not read Username for 'https://github.com': terminal prompts disabled` (exit code 128). Verify ID Graph and Release Please both RED.

**Root cause investigation (systematic-debugging):**
1. Checked checkout logs: `token: ***` was passed but fetch of the main repo failed with 401
2. All 4 repos (Z-ai-platform + 3 submodules) are PUBLIC -> anonymous clone works, no token needed
3. PAT_TOKEN secret existed (set 2026-07-02T14:49) but became invalid (likely an auto-rotating gh CLI OAuth token `gho_`)
4. Invalid token sent bad Authorization header -> GitHub 401 -> git prompts disabled -> fatal
5. Confirmed: workflow file unchanged between success (19:19) and failure (19:28) -> token rotated, not config change

**Fix 1: removed `token: ${{ secrets.PAT_TOKEN }}`** from all 3 checkout steps
- `verify-id-graph.yml`, `e2e-verifiers.yml`, `release-please.yml`
- Public repos clone anonymously; removes dependency on rotating token
- Commit `ee3c64d`: `fix(ci): remove invalid PAT_TOKEN from checkout (repos are public)`

**Fix 2: enabled repo setting** `can_approve_pull_request_reviews`
- After checkout fix, release-please got further but failed: `GitHub Actions is not permitted to create or approve pull requests`
- Root cause: repo setting `can_approve_pull_request_reviews: false` (was masked by earlier checkout failure)
- Applied via API: `gh api -X PUT repos/stsgs1980/Z-ai-platform/actions/permissions/workflow -F can_approve_pull_request_reviews=true`
- Kept `default_workflow_permissions: read` (least privilege; workflows specify own perms)

**Verification:**
- Verify ID Graph run #28630522838 = GREEN (1m1s)
- Release Please run #28630522907 (rerun) = GREEN (42s), created release PR #1 "chore(main): release 2.7.0"

**Remaining (non-fatal):**
- Node 20 deprecation warning on `actions/checkout@v4`
- Husky deprecated shebang lines in `.husky/*` (will break in v10.0.0)
- Release PR's Verify ID Graph shows `action_required` (expected: first PR needs workflow approval)

**Next steps:** Optional cleanup of deprecation warnings.

---

### 2026-07-03 00:44-00:55
**Entry:** Resolve all remaining deprecation warnings (checkout v4, upload-artifact v5, husky v9)

**Context:** User requested fixing all remaining warnings: Node 20 deprecation on actions + husky deprecated shebang.

**Work completed:**

1. **`actions/checkout@v4` -> `v5`** (drops Node 20 runtime deprecation)
   - 5 files: platform (e2e-verifiers, release-please, verify-id-graph) + guard lint-markdown + skills lint-markdown
   - Submodules committed/pushed: guard `a2e4147`, skills `217626e`
   - Platform commit `5cea187`

2. **`actions/upload-artifact@v5` -> `v7`** (last action on Node 20, surfaced after checkout bump)
   - verify-id-graph.yml (2 usages: graph artifact + verifier output)
   - Commit `7f6dc88`
   - After this: NO "forced to run on Node.js 24" warnings remain (verified empty grep on run #28631115201)

3. **Husky v9 deprecated shebang removed** from `.husky/pre-commit` and `.husky/pre-push`
   - Removed `#!/usr/bin/env sh` + `. "$(dirname -- "$0")/_/husky.sh"` (v9 runs hooks via `.husky/_/h` wrapper)

4. **Fixed corrupted `core.hooksPath`** (root-caused via systematic-debugging)
   - Found: `core.hooksPath = --version/_` (corrupted, caused `env: unknown option -- version` on commit)
   - Correct value: `.husky/_` (git runs `.husky/_/pre-commit` -> sources `h` -> runs user `.husky/pre-commit`)
   - Fixed: `git config core.hooksPath .husky/_`
   - Reproduced: `npm run prepare` does NOT re-corrupt (sets `.husky/_` correctly) -> corruption was a one-time glitch
   - Note: this is local-only config (CI uses its own checkout, no husky)

**Verification:**
- Local commit `5cea187`: pre-commit ran with NO "husky - DEPRECATED" warning, NO env error
- Verify ID Graph #28631115201 = GREEN (47s), grep for "forced to run on Node.js 24" = empty
- Guard #28630864660 = GREEN, Skills #28630871672 = GREEN

**Remaining (not actionable in workflow config):**
- Node-internal `punycode` (DEP0040) and `url.parse()` (DEP0169) warnings from JS dependencies (harmless, require dependency updates to silence)

---

### 2026-07-03 01:00
**Entry:** Disable release-please (semver not meaningful for private monorepo)

**Context:** release-please had auto-created PR #1 "chore(main): release 2.7.0" (version jumped 0.1.0 -> 2.7.0 from accumulated feat: commits). User decided it adds noise without value.

**Rationale for removal:**
- Repo is `"private": true`, not published -> semantic versions meaningless
- Version jump 0.1.0 -> 2.7.0 proves versioning is arbitrary
- Manual worklog.md already documents work in detail
- release-please created/updated a PR on every feat:/fix: push = ongoing noise

**Work completed:**
- Deleted `.github/workflows/release-please.yml` (commit `623280f`)
- Closed PR #1 with explanatory comment, deleted branch `release-please--branches--main--components--z-ai-dense-graph`
- Removed `autorelease: pending` label from closed PR
- Verified: no open PRs, only `main` branch remains

**Result:** Active workflows now = verify-id-graph.yml + e2e-verifiers.yml. CHANGELOG.md remains manually maintained.

---

### 2026-07-03 01:11
**Entry:** Add lint-markdown workflow to standards (close last consistency gap)

**Context:** Audit found standards was the only repo without CI markdown lint, despite having an identical eslint.config.js (unicode-policy for `**/*.md`) as guard/skills. Decision: close the gap for completeness ("rules apply to the rule-maker").

**Note:** Verified standards currently passes its own lint (exit 0) -> no active violation, this is preventive.

**Work completed:**
- Synced standards local `main` to `origin/main` (was 7 commits behind, detached HEAD)
- Restored package.json/package-lock.json (side-effect of local npm install had added spurious `z-ai-dense-graph: file:..` dependency)
- Created `.github/workflows/lint-markdown.yml` (same template as guard/skills, `checkout@v5`)
- Committed `3f2bfce`: `ci: add lint-markdown workflow (STD-DOC-002, STD-DOC-003)`
- Standards CI run #28631805161 = GREEN (13s)
- Bumped platform submodule pointer: standards `e1e68fa` -> `3f2bfce`

**Result:** All 4 repos now have consistent markdown-lint CI enforcement (platform via verify-id-graph submodules check; guard/skills/standards each have their own lint-markdown workflow).

**System status:** All verifiers PASS (8/8 standards, skills OK, 13/13 id-graph), all CI green across 4 repos, all submodule pointers consistent, platform working tree clean.

---

### 2026-07-03 02:00-03:00
**Entry:** O-021 sandbox onboarding flow research (paused)

**Context:** Three fragmented artifacts exist for agent sandbox onboarding: `bootstrap.sh` (Desktop), `zai` CLI prototype (Desktop/sandbox variants/), `zai-sandbox-rules` skill (Desktop/SKILLSET LIBRARY/). None form a unified "1-2 commands → organized sandbox" experience. Decision O-021: research and unify.

**Research doc created:** `docs/sandbox-onboarding-research.md` (309 lines)
- 5-point oracle (E1-E5): agent gets FS access, shell, structured dirs, rule loading, verification
- 4 variants (A/B/C/D) for empirical testing
- Test plan with measurable acceptance criteria
- Decision matrix template (§5)
- Resume steps (§7): open questions re: chat.z.ai sandbox FS+shell access

**Decision recorded:** DECISIONS_LOG.md entry O-021 added + index corrected (missing O-015/016/017 added)

**Status:** Paused. Resume gated on answering §7.3 (does chat.z.ai give agent FS+shell access?).

---

### 2026-07-03
**Entry:** Variant D governance system development and integration

Built complete governance system (v1-v7) in Test/.zai/ with 70+ tests.
Key features: config.json, emoji check, verify orchestrator, semver validation.
Integrated into Z-ai-platform as .zai/ layer (adds emoji check to existing hooks).
Existing .husky/pre-commit preserved (co-change + worklog + lint-staged).
Ready for sandbox testing.

---

### 2026-07-03 (fix)
**Entry:** check-emoji.sh now reads emoji.extensions from config.json

Fixed: staged mode was hardcoding `grep '\.md$'` instead of reading extensions from config.json.
Now reads emoji.extensions array and builds grep pattern dynamically.

---

### 2026-07-03 (integration test)
**Entry:** .zai/ integration into Z-ai-platform — live sandbox test

What was done:
- Cloned Z-ai-platform into fresh sandbox via `git clone --recurse-submodules`
- Ran `bash .zai/setup.sh` — all 6 phases passed
- emoji check added to .husky/pre-commit (co-change + worklog + lint-staged + emoji)
- Tested emoji detection: `--file` mode works (exit 1), `--staged` mode works when file is actually modified
- Fixed check-emoji.sh to read emoji.extensions from config.json (was hardcoded `\.md$`)
- Verified: hook blocks emoji in .md files when config has `.md` in emoji.extensions

Key findings:
- `git diff --cached` only shows files with actual changes — re-staging committed file = empty diff
- Worklog-check.sh requires root `worklog.md` (not `docs/session/worklog.md`)
- Co-change-check counts `.md` as docs — worklog.md satisfies it

Files modified:
- `.zai/lib/check-emoji.sh` — reads extensions from config.json
- `worklog.md` — added entries for worklog-check compliance
- `docs/session/worklog.md` — added detailed session notes

Stage Summary:
- .zai/ fully integrated into Z-ai-platform
- Emoji check works in hook (reads config.json)
- All existing hooks preserved (co-change + worklog + lint-staged)
- Ready for zai-sandbox-rules skill development

---

### 2026-07-03 (zai-skill-creator)
**Entry:** Next step — build zai-sandbox-rules skill using zai-skill-creator

Plan:
- Use `C:\Users\stsgr\Desktop\SKILLSET LIBRARY\zai-skill-creator` to create proper skill
- Add YAML frontmatter (name, description, triggers)
- Create evals/tests in `evals/evals.json`
- Run fact-check against actual sandbox behavior
- Package for distribution

Dependencies:
- zai-skill-creator: 438 lines, includes eval-viewer, scripts, agents
- zai-sandbox-rules: 170 lines SKILL.md (existing draft at Desktop/SKILLSET LIBRARY/)
- Sandbox probing results: `Test/sandbox-capabilities-report.md`

---

### 2026-07-03 (zai-sandbox-rules现状)
**Entry:** zai-sandbox-rules — текущее состояние перед сборкой через zai-skill-creator

**YAML frontmatter:**
```yaml
name: zai-sandbox-rules
version: "1.1.0"
description: "Use BEFORE any dev server action..."
triggers: [dev server, preview not working, EADDRINUSE, HMR crash, port 3000, module not found, init sandbox, restart dev, sandbox broken, white screen, 500 error]
```

**Структура SKILL.md (170 строк):**
- Purpose (строка 19-23)
- When NOT to Use (строка 25-34) — 6 исключений
- Rule 1-10 (строка 36-128):
  - Rule 1: NEVER Run Dev Servers Manually
  - Rule 2: Before Checking Dev Logs
  - Rule 3: When Preview Is Not Working
  - Rule 4: Port Conflicts (EADDRINUSE)
  - Rule 5: HMR Crash
  - Rule 6: Module Not Found
  - Rule 7: Cloning Repos and Submodules
  - Rule 8: Init Sandbox
  - Rule 9: White Screen / 500 Error Debugging
  - Rule 10: File System Constraints
- Rationalization Table (строка 130-144) — 9 записей
- Red Flags: STOP (строка 146-161) — 10 фраз
- Stack Signature Override (строка 165-168)

**Что есть:**
- Полные 10 правил с конкретными инструкциями
- Rationalization table (анти-обход правил)
- Red flags (сигналы остановки)
- YAML frontmatter с triggers

**Чего НЕТ (нужно через zai-skill-creator):**
- Eval tests (`evals/evals.json`) — нет тестов
- Fact-check — не проверено против реального поведения песочницы
- Scripts — нет исполняемых скриптов
- References — нет справочных документов
- Packaging — не упаковано для дистрибуции

**План через zai-skill-creator:**
1. Проверить YAML frontmatter (name <=64 chars, description <=1024 chars)
2. Создать `evals/evals.json` с 2-3 тестами
3. Запустить fact-checker против `Test/sandbox-capabilities-report.md`
4. Добавить scripts/ если нужны исполняемые проверки
5. Упаковать через `python -m scripts.package_skill`

---

### 2026-07-03 (zai-sandbox-rules-plan)
**Entry:** Plan committed before execution — fact-check + refactor + package zai-sandbox-rules

**Context:** User decided: stay on Windows, sync via GitHub, experiments in Test/. Implement zai-sandbox-rules "по уму" using zai-skill-creator methodology. Stopped prior session at "need to build zai-sandbox-rules via zai-skill-creator".

**Purpose clarified by user:** zai-sandbox-rules = ONE-COMMAND bootstrap for behavioral rules (single skill trigger loads all rules into agent context, instead of repeating a 500-line prompt every session). NOT a duplication of .zai/ (filesystem enforcement) or bootstrap.sh (technical setup) — three ORTHOGONAL layers serving different consumers (agent / git / user).

**Decisions (to be logged in DECISIONS_LOG.md):**
- Stack Signature footer STAYS in skills; DOC-002 v2.3.2 §8 to be revised separately to allow skills in scope
- ID assignment for skills DEFERRED to separate revision task
- ALL-CAPS in headers KEPT (justified for guardrail skill with Rationalization Table)
- Layer "overlap" with .zai/ + bootstrap.sh is NON-ISSUE (orthogonal layers, different consumers)

**Issues to fix in zai-sandbox-rules/SKILL.md:**
- HARD: frontmatter `triggers:` (plural) -> `trigger:` (singular); fails quick_validate.py otherwise
- STRUCTURAL: cold-start chicken/egg (skill reactive on problem phrases, Rule 1 needs BEFORE action) — mitigate via early triggers + "if already violated" recovery section
- TBC via fact-check: any contricted claims about sandbox behavior

**Plan (6 steps):**
0. THIS ENTRY — append Plan to both worklogs (root + docs/session)
1. Setup workspace Test/zai-sandbox-rules-workspace/ (copy skill + skill-creator bits)
2. Fact-check Rules 1-10 against Test/sandbox-capabilities-report.md -> fact-check.json (GATE)
3. Apply fixes (frontmatter + cold-start + fact-check contradictions)
4. Validate: quick_validate.py + check-md.sh + DOC-002/003 compliance
5. Package via package_skill.py -> .skill zip
6. Stage Summary + DECISIONS_LOG entries + push to GitHub

**Documents to be touched:**
- worklog.md (root) + docs/session/worklog.md (progress)
- docs/session/DECISIONS_LOG.md (2 new entries: Stack Signature policy, sandbox-rules layer role)
- docs/session/SESSION_NOTES.md (if any LESSON-NNN emerges)
- standards/DOC-002-markdown-standard.md (SEPARATE task: reverse skill-scope exclusion)
- zai-sandbox-rules/SKILL.md (Desktop source, edited via Test/ workspace)
- CHANGELOG.md

---

## 2026-07-03 — zai-sandbox-rules v1.2.0 (fact-check + rewrite)

**Task:** Implement zai-sandbox-rules skill using zai-skill-creator methodology.

**What was done:**
- Fact-checked 19 claims against sandbox-guide.md + live probe. Found 10 contradictions (3 critical).
- Rewrote SKILL.md v1.1.0 -> v1.2.0: fixed all 10 contradictions + added 2 new sections.
- Key fixes: Rule 4 now prescribes pkill+reinit (was passive report), Rule 5 now says HMR does NOT auto-recover (was "wait for sandbox"), Rule 7 now clones to /tmp (was "clone into project dir"), Rule 10 now allows /tmp for transient work (was blanket ban).
- Added: "Why Dev Servers Are Forbidden" section (explains dev.sh -> bun -> next-server stack).
- Frontmatter: `triggers:` -> `trigger:` (validator requires singular).
- Validation: quick_validate.py passed, ESLint DOC-002/003 passed.
- Packaged: skill.skill in Test/zai-sandbox-rules-workspace/

**Test results (Z.ai chat):**
- Rule 2 (filesystem check): PASSED
- Rule 1 (dev server refusal): pending user report
- Rule 4 (EADDRINUSE recovery): pending user report

**Artifacts:**
- Test/zai-sandbox-rules-workspace/skill/SKILL.md (working copy)
- Test/zai-sandbox-rules-workspace/skill.skill (package)
- Test/zai-sandbox-rules-workspace/fact-check.json (19 claims)

---

### 2026-07-03
**Entry:** Skills monorepo conversion — removed submodule, moved skills into Z-ai-platform

Converted skills from separate git submodule (Z-ai-skills) to monorepo structure.

Changes:
- Removed `skills` git submodule from Z-ai-platform
- Moved 14 skills directly into `skills/` directory
- Updated `bootstrap.sh`: changed path from `skills/skills` to `skills`
- Removed `skills/` from `.gitignore` (now a regular directory)
- Added `__pycache__/` to `.gitignore`

Skills included: zai-anti-monolith, zai-debugging, zai-frontend-styling-expert, zai-md-std, zai-mermaid-diagrams, zai-performance-code-generator, zai-phi-layout, zai-project-clone, zai-prompt-engineering, zai-sandbox-rules, zai-skill-creator, zai-skill-registry, zai-ui-composer, zai-workflow-discipline.

All skills have consistent frontmatter: name (zai-*), author: StsDev, version.

---

## 2026-07-04 — worklog dedup (single canonical path)

**Task:** Resolve duplicate worklog registration; keep root `worklog.md` as the only canonical path per AGENTS.md §4.

**What was done:**
- Deleted `docs/session/worklog.md` (was already removed in WT; staged the deletion).
- `.zai/lib/check-worklog.sh:16`: default `WORKLOG_PATHS` reduced from `worklog.md,docs/session/worklog.md` to `worklog.md`.
- `.zai/setup.sh:95`: config template now emits `"paths": ["worklog.md"]` only.
- `.zai/config.json`: `worklog.paths` already trimmed to `["worklog.md"]` (staged).

**Verified:**
- `bash .zai/lib/check-worklog.sh` -> PASS on root `worklog.md` (469 lines).
- `validate-config` fails on a pre-existing path-portability bug (MSYS `/c/...` vs Windows), unrelated to this change.

---

## 2026-07-04 — Node version pin (local + sandbox)

**Task:** Make the Node requirement honest. `lint-staged@17`/`listr2` use
`node:util.styleText`, available since Node 20.12. Local Windows dev on
Node 20.11.1 silently fails the pre-commit hook.

**Sandbox check (2026-07-04):** Node v24.16.0 at `/usr/bin/node`, no
fnm/nvm. Sandbox is unaffected; problem is local Windows only.

**What was done:**
- `package.json`: `engines.node` bumped from `>=20.0.0` to `>=20.12.0`.
- `.node-version` (new): `22.22.3` for local Windows dev via fnm.
- `AGENT_RULES.md` §9 Version Lock: added Node row + explanation paragraph.

**Not done:**
- `~/.bashrc` fnm setup for Git Bash on Windows — out of repo scope, user's local environment.

---

## 2026-07-04 — stale-references cleanup (4-task batch)

**Task:** Resolve drift accumulated since the monorepo conversion (a3d358b)
and earlier. Four issues identified during configuration audit.

**1. validate-config Windows portability (`.zai/validate-config`)**
- Bug: `require('/c/Users/...')` (MSYS path) not resolved by Node on Windows.
- Fix: convert via `cygpath -m` when available; Linux sandbox unaffected
  (no cygpath, original path works).
- Verified on Windows: `bash .zai/validate-config` -> RESULT: VALID.

**2. AGENT_RULES.md monorepo drift**
- §3 enforcement count: "0 enforced" -> "2 enforced" (PROC-COCHANGE-003,
  PROC-WORKLOG-005 via .husky/pre-commit).
- §4 skill catalog: "36 skills / skills/skills/INDEX.md" ->
  "14 skills / skills/INDEX.md (inline monorepo since a3d358b)".
- §9 version lock: skills@9797e69 submodule pin -> "inline monorepo";
  standards@/guard@ pins refreshed to actual SHAs (b16d154, 8eb6fe1).
- §3/§8 RULE-MONOLITH-017 wording: skills/ removed from upstream-protection
  list (now inline, not upstream).
- Header pins + Last Updated refreshed.

**3. package.json dead scripts (sandbox-verified 2026-07-04)**
- check:md:  `bash scripts/check-md.sh`           -> `bash standards/scripts/check-md.sh`
- check:graph: `ts-node scripts/check-id-graph.ts` -> `node standards/scripts/verify-id-graph.js`
- Verified: `npm run check:graph` -> PASS (13/13, 31 warnings);
  `npm run check:md` -> resolves correctly.

**4. Stale worklog-path references in SESSION_NOTES.md**
- Line 418: `cat docs/session/worklog.md` -> `cat worklog.md` (canonical root).
- Line 425: push-list entry -> `Z-ai-platform/worklog.md`.
- Line 1077: "3554-line ... docs/session/worklog.md" -> "500+ line ... worklog.md (root, canonical)".
- Remaining refs in `worklog.md` lines 309/315/421 left intact (append-only history).
- Upstream refs in `standards/` (CI-AND-TESTING.md, META-001) NOT touched — separate PR per RULE-MONOLITH-017.

---

## 2026-07-04 — zai-sandbox-rules SKILL.md audit (5 issues)

**Task:** Audit `skills/zai-sandbox-rules/SKILL.md` for structure correctness.
Sources: file itself + `Desktop/ZAI SANDBOX/ZAI ACTUAL/Z.ai-Sandbox-Guide.md`
(canonical cheat-sheet from the user).

**1. Duplicate Rule 8 (FAIL)**
- Two `## Rule 8` headers (Build Verification at line 125, Init Sandbox at 135).
- Fix: cascade renumber. Init Sandbox -> Rule 9, White Screen -> 10,
  File System -> 11, Git Submodules -> 12, Database -> 13. Final: 13 rules.
- Verified cross-refs in file: only Rules 1, 3, 4, 5, 7 — none in cascade zone.

**2. init-fullstack_*.sh placeholder (FAIL)**
- 8 occurrences of `init-fullstack_*.sh` (wildcard, not a real URL).
- Fix: replaced with concrete `init-fullstack_1775040338514.sh` per cheat-sheet
  (line 142 of Z.ai-Sandbox-Guide.md). 8 occurrences, 0 wildcards remaining.

**3. bun run build contradiction (FAIL)**
- Rule 8 (Build Verification) prescribed `bun run build` for verification.
- Rationalization Table claimed `bun run build` is "also prohibited".
- Cheat-sheet (rule 8, line 533; step 6, line 145) says build is REQUIRED
  after cloning. Internal contradiction resolved by removing the bad row.

**4. "Rules 1 through 10" (WARNING)**
- Stale count after the cascade renumber.
- Fix: updated to "Rules 1 through 13" in Red Flags section.

**5. §8 Stack Signature (OK — no change)**
- The §8 override mention is valid after commit 74539d9 (DOC-002 v2.4.4
  reversed the skill scope exclusion). No edit needed.

**Verified:**
- `bash standards/scripts/check-md.sh skills/zai-sandbox-rules/SKILL.md`
  -> static checks PASS (ESLint warning is pre-existing: skills/** is in
  eslint.config.js global ignores; lint-staged uses --no-warn-ignored).
- Frontmatter intact: name, author, version 1.5.0, trigger (singular).
- 13 rules total, no gaps, no duplicates.

---

## 2026-07-04 — H1 unification across all 14 skills

**Task:** Bring every SKILL.md H1 to canonical form per STD-SKILL-001 §3.1.

**Mistake made and corrected:** Initial pass stripped the `zai-` namespace
prefix from H1s. User pointed out the prefix is a deliberate namespace to
distinguish author skills from built-in Z.ai sandbox skills. Restored.

**Canonical form agreed with user:** `# Skill: Zai <Name> v<Version>`
where "Zai" is the Title-Case form of the `zai-` namespace.

**14 H1 unified:**
- 5 were non-canonical altogether (no `Skill:` prefix, no version):
  zai-debugging, zai-md-std, zai-sandbox-rules, zai-skill-creator,
  zai-ui-composer.
- 8 lacked the `Zai` prefix: zai-anti-monolith, zai-frontend-styling-expert,
  zai-mermaid-diagrams, zai-performance-code-generator, zai-prompt-engineering,
  zai-project-clone, zai-skill-registry (also: `Z.ai` -> `Zai`),
  zai-workflow-discipline, zai-phi-layout.

**Verified:**
- All 14 H1 match `# Skill: Zai <Name> v<Version>`.
- `node standards/scripts/verify-skills.js` -> 6/6 HARD PASS, 1 SOFT warning.
  (Previously 8/9 with 1 FAIL — the FAIL was unrelated S03 `_sts` suffix
  check, which requires upstream std fix; non-strict mode passes.)

---

## 2026-07-04 — save-work.sh: drop skills from submodule loop

**Task:** Synchronize save-work.sh with the monorepo reality. Since
commit a3d358b skills/ is an inline directory, not a git submodule.

**Problem:** The script iterated `for sub in skills standards guard`
and guarded each with `[ -d "$sub/.git" ]`. For `skills/` this check
returns false (no .git there), so the skills branch of the loop was
dead code — silently skipped every run. Behaviour was accidentally
correct (skills- changes get committed at the parent step), but the
loop and the header comment lied about 3 submodules.

**Fix:**
- Header comment: "3 submodules (skills, standards, guard)" ->
  "2 submodules (standards, guard)" + note that skills/ is inline.
- Loop body: `for sub in skills standards guard` -> `for sub in standards guard`.
- Submodule-pointer step: `git add skills standards guard` -> `git add standards guard`.

**Verified:** `bash -n save-work.sh` -> OK syntax.
Runtime check in sandbox deferred (script commits + pushes; running it
locally would sweep unrelated WT changes into a save commit).

---

## 2026-07-04 — status.sh: sync critical-skills check with reality

**Task:** Bring status.sh in line with the actual skill catalog. The
critical-skills section was looking up names that no longer exist.

**Problems found:**
- Step 3 loop iterated `skill-creator zai-skill-registry skill-id-system`.
  `skill-creator` was renamed to `zai-skill-creator`; `skill-id-system`
  never existed in this repo. Two of three checks always returned MISSING.
- Step 4 (entire block, ~12 lines) was a tone-detector for the old
  Anthropic skill-creator ("Cool?", "plumbers", etc.). It read
  `$SANDBOX_SKILLS_DIR/skill-creator/SKILL.md` which has not existed
  since the rename -- dead code.

**Fix:**
- Step 3 loop: `skill-creator zai-skill-registry skill-id-system` ->
  `zai-skill-creator zai-skill-registry`.
- Step 4: deleted the Anthropic-detector block, replaced with a short
  comment marking it as removed.

**Not touched:**
- Unicode glyphs in script output (✓ ✗ ⚠ →). Out of scope for the
  "sync with skill names" pass; separate decision needed.

**Verified:** `bash -n status.sh` -> OK syntax.

---

## 2026-07-04 — consolidate hooks under Husky (remove .githooks/)

**Task:** Two parallel hook systems were drifting apart. `.husky/`
(active via core.hooksPath=.husky/_) ran co-change + worklog + lint-staged.
`.githooks/` (dead unless install-hooks.sh run) held verify-standards,
verify-id-graph, verify-skills, Conventional Commits validation, line-count.
User needs BOTH tool groups; consolidation under one hooksPath is the fix.

**What was done:**
- `.husky/commit-msg` (new): migrated from `.githooks/commit-msg` verbatim,
  Husky v9 style (no shebang), header updated to note the migration.
- `.husky/pre-commit` (rewritten): now runs four groups in order --
  1. guard co-change + worklog (HARD)
  2. standards verify-standards + verify-id-graph + verify-skills (HARD)
     with `command -v node` and submodule-presence guards
  3. guard line-count (SOFT)
  4. lint-staged
  Dropped Phase 0 (worklog freshness on docs/session/worklog.md -- path
  was deprecated in commit 01ae72d; PROC-WORKLOG-005 already covers this).
- `.githooks/` directory: removed (pre-commit + commit-msg).
- `install-hooks.sh`: removed. Husky installs via `npm install` (prepare
  hook runs `husky`, which sets core.hooksPath). install-hooks.sh was the
  only path that could switch git to the dead .githooks/ system.
- `README.md`: three references to install-hooks.sh replaced with the
  Husky auto-install story (`npm install`).

**verify-skills.js --strict caveat:** S03 (_sts suffix) currently fails
for all 14 skills because the real skills use the `zai-` namespace
without the suffix. STD-SKILL-001 §9 needs an upstream fix (separate
PR in Z-ai-standards). The Husky pre-commit calls verify-skills.js in
non-strict mode locally; CI keeps running --strict to track the gap.

**Verified locally:**
- `bash -n .husky/pre-commit` OK syntax.
- `bash -n .husky/commit-msg` OK syntax.
- `node standards/scripts/verify-standards.js` -> 8/8 PASS.
- `node standards/scripts/verify-id-graph.js` -> 13/13 HARD PASS, 33 warnings.
- `node standards/scripts/verify-skills.js` -> 6/6 HARD PASS, 1 SOFT warning.
- `bash .husky/pre-commit` (dry-run) -> guard PROC checks execute; expected
  FAIL on worklog-check because the worklog entry for this commit was not
  staged at dry-run time.

**Pending:** sandbox test after push -- confirm `git commit` in a fresh
clone fires all four groups end-to-end.

---

## 2026-07-04 — main recovery + salvage valuable work from sandbox commits

**Task:** Three unknown commits (author `Z User <z@container>`) appeared on
origin/main overnight (3 Jul, 23:27-23:49 MSK). User confirmed no human
committed them. They were produced by a sandbox agent. Investigation:

- `4e40468` README/package/.gitignore -- duplicate of work this session did.
- `acfa86b` dead paths + Unicode + verify orchestrator -- duplicate of work
  this session did, PLUS two valuable additions: `vitest.config.ts` and an
  expanded `src/infrastructure.test.ts` (208 lines, 33 test cases).
- `58ca35f` UUID message -- GARBAGE. Pulled in code from an unrelated
  scanner project (`src/app/api/scanner/...`), tool-results dumps,
  `.bak`/`.disabled` files, and a self-referential `Z-ai-platform`
  submodule pointer that broke bootstrap.sh.

**Recovery plan (executed):**

1. Backup tag `checkpoint-pre-recovery-2026-07-04` pushed to origin.
   Pointed at 58ca35f (the pre-recovery main tip). Contains all three
   sandbox commits for full reversibility.
2. `git push --force-with-lease=main:58ca35f... 23a4460:main` -- reset
   origin/main to the common ancestor (23a4460). Three sandbox commits
   removed from main, preserved via tag.
3. `git push origin main` -- pushed the 8 clean session commits
   (01ae72d through 01e4e97) onto the reset main.

**Salvage from acfa86b (this commit):**
- `vitest.config.ts` (new) -- minimal config; documents that the parent
  sandbox's vitest.setup.ts does not apply here.
- `src/infrastructure.test.ts` -- replaced the trivial 5-test version
  with the 33-test version from acfa86b. Adapted the .githooks block to
  .husky (migrated in 01e4e97); kept all other assertions intact.
- `guard` submodule pointer bumped to 91b81b9 (upstream "fix: correct 5
  dead file paths in registry.json"). The registry.json test in the
  expanded suite caught those 5 dead paths before the bump and passes
  after it.
- `.gitignore` -- added `.zscripts/` and `*.tsbuildinfo` (from 4e40468).

**Verified:**
- `npm test` after guard bump: 33 passed, 0 failed.
- `git log --oneline origin/main..HEAD` -- empty (everything pushed).

**Rollback:** `git reset --hard checkpoint-pre-recovery-2026-07-04`.
