# Z-ai-platform

> Layer: Meta — Orchestrator
> Last Updated: 2026-06-17
> Status: **SKELETON — pending full setup**

This repository is the **orchestrator** for the Z-ai ecosystem. It contains
the cross-repo integration scripts, install hooks, doctor diagnostics, and
the canonical `.gitmodules` file that wires the other three repos together
as submodules.

## Repository Layout (planned)

```
Z-ai-platform/
├── .gitmodules               # Pins Z-ai-standards, Z-ai-guard, Z-ai-skills
├── install.sh                # PROC-PLATFORM-INSTALL-005 — bootstrap all 4 repos
├── update.sh                 # PROC-PLATFORM-UPDATE-006 — update all submodules
├── doctor.sh                 # PROC-PLATFORM-DOCTOR-007 — diagnostic suite
├── install-hooks.sh          # Bootstrap pre-commit hooks
├── scripts/
│   ├── cross-validator-test.js    # Cross-repo verifier integration test
│   └── run-pre-commit.sh          # Hook runner
├── templates/                # Templates for new projects
├── docs/                     # Cross-repo documentation
└── README.md                 # This file
```

## Procedures (PROC-PLATFORM-*)

| ID | File | Version | Level | Status |
|---|---|---|---|---|
| PROC-PLATFORM-INSTALL-005 | install.sh | 1.0 | [C] | ACTIVE (planned) |
| PROC-PLATFORM-UPDATE-006 | update.sh | 1.0 | [C] | ACTIVE (planned) |
| PROC-PLATFORM-DOCTOR-007 | doctor.sh | 1.0 | [C] | ACTIVE (planned) |

## Cross-Repo CI

The `.github/workflows/cross-repo.yml` (planned) runs nightly:
1. Checkout all 4 repos at pinned versions
2. Run `node standards/scripts/verify-id-graph.js --json > result.json`
3. Upload `result.json` as artifact
4. Open GitHub issue if any HARD check fails

## Pre-Commit Hook

`install-hooks.sh` configures `core.hooksPath = .githooks` so that
pre-commit runs `verify-standards.js` automatically on any commit
touching `.md` or `verify-*.js` files.

## Status

This repo is a skeleton. Currently contains only:
- `install-hooks.sh` — pre-commit hook bootstrap (copied from project root)
- `scripts/cross-validator-test.js` — integration test runner
