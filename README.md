# Z-ai-platform

Orchestrator for the Z-ai ecosystem — pins three submodules (standards, guard, skills) and enforces cross-repo ID-graph integrity in CI.

[![Status: LIVE](https://img.shields.io/badge/Status-LIVE-brightgreen.svg?style=flat-square)]()
[![License: Private](https://img.shields.io/badge/License-Private-red.svg?style=flat-square)]()
[![CI: Verify ID Graph](https://img.shields.io/github/actions/workflow/status/stsgs1980/Z-ai-platform/verify-id-graph.yml?style=flat-square&label=CI)](https://github.com/stsgs1980/Z-ai-platform/actions)

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Scripts](#scripts)
- [CI Behavior](#ci-behavior)
- [Agent Rules](#agent-rules)
- [License](#license)

## Features

- **4-repo architecture** — platform (L0), standards (L1), guard (L2), skills (L3) evolve independently
- **Cross-repo ID graph** — 65 IDs with 125 Related: edges and 2 Aligned_with: edges, verified by 13/13 HARD checks
- **Nightly + push CI** — `verify-standards.js`, `verify-id-graph.js`, `verify-skills.js`, and snapshot compare run automatically
- **Pre-commit hooks** — local verification on `.md` and `verify-*.js` changes via `install-hooks.sh`
- **Bootstrap script** — one command restores all 35+ custom skills into any fresh Z.ai sandbox session

## Tech Stack

- **Language** - JavaScript (Node.js 20, ESLint 9 flat config)
- **CI** - GitHub Actions (verify-id-graph.yml, e2e-verifiers.yml)
- **Submodules** - git submodules for standards, guard, skills
- **Verification** - Custom Node.js scripts (verify-standards.js, verify-id-graph.js, verify-skills.js)

## Getting Started

### Prerequisites

- Node.js 20+
- Git with submodule support
- (For CI) SSH deploy key with read access to all three submodule repos

### Installation

```bash
git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git
cd Z-ai-platform
```

### Run

```bash
# Verify the ID graph locally
node standards/scripts/verify-standards.js
node standards/scripts/verify-id-graph.js

# Install pre-commit hooks (optional)
./install-hooks.sh

# Bootstrap skills into a Z.ai sandbox
bash <(curl -fsSL https://raw.githubusercontent.com/stsgs1980/Z-ai-platform/main/bootstrap.sh)
```

## Architecture

The platform uses a 4-layer repository architecture where each layer can evolve independently. Standards can be amended without forcing rule or skill updates; guard rules ship on their own cadence; skills are consumed standalone by the sandbox runtime. The ID graph (G01-G15) enforces that changes in one layer do not silently break references in another. See `standards/standards/META-001-id-registry.md` for the full ID catalogue and layer matrix.

## Project Structure

- `standards/` - Z-ai-standards submodule (L1): STD-* files, verifier scripts, snapshots
- `guard/` - Z-ai-guard submodule (L2): RULE-MONOLITH-* rules, procedures, tools
- `skills/` - Z-ai-skills submodule (L3): 35 skill directories with ZAI-* IDs
- `.github/workflows/` - CI workflows (verify-id-graph.yml, e2e-verifiers.yml)
- `eslint-rules/` - Custom ESLint rules for STD-DOC-003 compliance
- `eslint-processors/` - Custom markdown processor for code-snippet linting
- `docs/` - Generated ID-graph diagrams and session documentation

## Scripts

| Script | Description |
|--------|-------------|
| `node standards/scripts/verify-standards.js` | Content-level invariants (V04-V11) |
| `node standards/scripts/verify-id-graph.js` | Cross-repo ID-graph invariants (G01-G15) |
| `node standards/scripts/verify-skills.js --strict` | Skills-side format verifier (S01-S09) |
| `bash standards/scripts/graph-deps.sh` | Render ID dependency graph (dot/svg/png) |
| `./install-hooks.sh` | Bootstrap pre-commit hooks for local verification |
| `./bootstrap.sh` | One-command skill restore for fresh sandbox sessions |

## CI Behavior

The `verify-id-graph.yml` workflow triggers on push to `main`, pull requests, nightly at 03:00 UTC, and manual dispatch. It runs four verification steps in sequence: `verify-standards.js`, `verify-id-graph.js`, snapshot compare against the committed baseline, and `verify-skills.js --strict`. All must pass for the workflow to succeed. On failure, verifier output is uploaded as an artifact (7-day retention) and a comment is posted on the PR. The ID graph (dot/svg/png) is always uploaded as a 30-day artifact for review.

## Agent Rules

Any AI agent working on this project MUST read and follow `AGENT_RULES.md` before performing any operations.

## License

Private. See individual submodules for any additional terms.
