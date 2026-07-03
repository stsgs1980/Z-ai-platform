# CHANGELOG

## Changelog for Z-ai-platform

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/) and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [2.7.0](https://github.com/stsgs1980/Z-ai-platform/compare/v2.6.0...v2.7.0) (2026-07-03)


### Features

* -&gt; Features, fix: -&gt; Bug Fixes, etc. ([b81d17f](https://github.com/stsgs1980/Z-ai-platform/commit/b81d17f5a2126fa72461ede2cd6c21bb000d3ee8))
* add project infrastructure - ESLint, Prettier, Husky, Vitest, TypeScript ([5c870e9](https://github.com/stsgs1980/Z-ai-platform/commit/5c870e972855b5e7cce9e41197a51da5219ad93e))
* **hooks:** wire PROC-COCHANGE-003 + PROC-LINECOUNT-004 as pre-commit Phases 4+5 ([9a114cc](https://github.com/stsgs1980/Z-ai-platform/commit/9a114ccb78f3c6fea1a7a04c4e2d3c60973e5784))
* rename unicode-policy rule, translate docs to English ([e12540f](https://github.com/stsgs1980/Z-ai-platform/commit/e12540f91e2505dfd161688fd0d298e2b8eccc6f))
* worklog enforcement (PROC-WORKLOG-005) ([b0d7a60](https://github.com/stsgs1980/Z-ai-platform/commit/b0d7a609ce26ec1efa92e68cf7700dbc8becdb36))


### Bug Fixes

* add PAT_TOKEN fallback for CI submodule auth ([80c27bb](https://github.com/stsgs1980/Z-ai-platform/commit/80c27bb222d4eacad2381113b1940718604a0add))
* align ESLint config with DOC-002/DOC-003 standards ([84daa88](https://github.com/stsgs1980/Z-ai-platform/commit/84daa88ea2c562b6d21a8bf46c7c7df01fe7a133))
* bump standards submodule (graph-deps.sh mkdir fix) ([69a667b](https://github.com/stsgs1980/Z-ai-platform/commit/69a667b2db05ce827c19438b7487615ef6cff1a3))
* CI submodule auth (SSH deploy key), README to v3.0 template, V10 renumbered, cleanup scripts ([9534f25](https://github.com/stsgs1980/Z-ai-platform/commit/9534f25202d2f6ca0b92a6206bec025f7da8f375))
* **ci:** add PAT_TOKEN to checkout + anti-monolith CI enforcement ([c81de81](https://github.com/stsgs1980/Z-ai-platform/commit/c81de811ea2af9d46b21cb536c07c4fe36a83216))
* **ci:** e2e-verifiers same submodule fix as verify-id-graph ([c356c87](https://github.com/stsgs1980/Z-ai-platform/commit/c356c876ae82c90f6915e2f01d026d535d0bf6e6))
* **ci:** remove invalid PAT_TOKEN from checkout (repos are public) ([ee3c64d](https://github.com/stsgs1980/Z-ai-platform/commit/ee3c64d5e54594e7f846b6f6636afc0e4d078848))
* **ci:** use actions/checkout submodules:recursive instead of manual git submodule update ([7649083](https://github.com/stsgs1980/Z-ai-platform/commit/7649083a9f7e1da9ce0448cf446196354e815db6))
* custom markdown processor to filter parsing errors + fix emoji in code blocks ([97b4c26](https://github.com/stsgs1980/Z-ai-platform/commit/97b4c264ca32b6c3e71f76f8631421e457ba3c49))
* graph-deps.sh .cjs extension (ESM compatibility) ([c588868](https://github.com/stsgs1980/Z-ai-platform/commit/c588868b4659f1d57ad3a4112e0788402fe56f84))
* standards compliance audit — remove bypass parser, clean eslint config, fix 3346 violations ([e266fc6](https://github.com/stsgs1980/Z-ai-platform/commit/e266fc67950fc93beb363eeb4e15688c84ba4e25))
* update standards submodule (CRLF fix + G03 cycle fix) ([26a3847](https://github.com/stsgs1980/Z-ai-platform/commit/26a38476d786df2fb3a0e978eeb4510339cd6e3b))
* update submodule pointers to latest + add standards package.json ([f97070b](https://github.com/stsgs1980/Z-ai-platform/commit/f97070b79f0e8137767c3029ed8f8a9f280b4101))
* Windows CRLF+path bugs in verifiers + wire PROC-COCHANGE-003 ([081ccb8](https://github.com/stsgs1980/Z-ai-platform/commit/081ccb868df7f3228d72ed52a341ca3bf7183e3c))

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
