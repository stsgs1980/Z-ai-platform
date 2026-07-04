# CHANGELOG

## Changelog for Z-ai-platform

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/) and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.1.1] - 2026-07-04

### Fixed

- `sandbox-integration-test.sh`: trailing slash from glob pattern `*/` defeated `[ -L ]` symlink check in Test 7 and Summary, causing false "0 symlinks" even when symlinks exist
- `vitest.config.ts`: prevent parent sandbox PostCSS config bleed (add `css.postcss.plugins: []`)
- `AGENT_RULES.md` §9: update submodule pins to match actual HEADs (standards@f945f0a1, guard@91b81b97)
- `.zai/verifier-daemon.sh`: fix false [VIOLATION] logging — grep -q "FAIL" was matching summary line "FAIL: 0", changed to grep -q "\[FAIL\]"
- `.gitignore`: add `.zai/.verifier-daemon.pid` (was untracked, causing noise in git status)

### Added

- `AGENT_RULES.md`: language setting — all agent communication in Russian (Cyrillic), no emojis

---

## [1.1.0] - 2026-07-02

### Changed

- Renamed ESLint rule `no-unicode-policy` -> `unicode-policy` in `eslint.config.js`
- All rule names updated: `no-emoji` -> `emoji`, `no-unicode-graphics` -> `unicode-graphics`
- `.husky/pre-commit`: wired PROC-COCHANGE-003 (`co-change-check.sh --hard`) before lint-staged
- Updated submodule pointers:
  - standards: `f5a5bd4` (CRLF fixes + Unicode cleanup + V10 fix + snapshot update)
  - guard: `a624215` (co-change-check.sh auto-detect + Unicode cleanup)
  - skills: `59b4a89` (Unicode cleanup)

### Fixed

- `parseBlockquoteHeader` regex: `\r\n` line endings broke blockquote parsing on Windows (2 IDs extracted instead of 66)
- `parseYAMLFrontmatter` regex: `\r\n` line endings broke YAML frontmatter parsing (RULE-MONOLITH-* not detected)
- `file-scanner.js`: `path.relative()` returns backslashes on Windows, breaking glob matching for guard/skills repos
- `graph-deps.sh`: temporary `.graph-transform.js` failed in ESM context (`"type": "module"` in package.json), renamed to `.cjs`
- G03 cycle in Related graph: META-002 had bidirectional Related edges with GIT-001, DOC-002, AGENT-001 (trimmed to META-001 only)
- SUBMODULE_DIRS: platform repo scanned into standards/guard/skills submodules, causing 20+ duplicate IDs (G01)

### Added

- Workspace boundary rule in `AGENT_RULES.md` section 8
- `worklog.md` and `CHANGELOG.md`

---

## [1.0.0] - 2026-07-02

### Added

- worklog.md and CHANGELOG.md files to all Z-ai modules
- Compliance with RULE-MONOLITH-002 (maintain worklog)
- Compliance with RULE-MONOLITH-010 (documentation sync)
- Basic documentation per standards

---

## [0.9.0] - 2026-07-01

### Added

- Initial Z-ai-platform project as orchestrator
- Basic change logging structure per Z-ai standards
