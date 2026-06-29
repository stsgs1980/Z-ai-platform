# Z-ai-platform

Orchestrator for the Z-ai ecosystem, pinning Z-ai-standards, Z-ai-guard, and Z-ai-skills as git submodules and running the cross-repo ID-graph verifier in CI.

[![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat-square)](https://nodejs.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)

## Features

- 4-repo git submodule architecture (standards L1, guard L2, skills L3, platform L0)
- Cross-repo ID-graph verifier enforcing G01-G15 invariants (13/13 HARD PASS)
- CI pipeline with push, PR, nightly (03:00 UTC), and manual dispatch triggers
- Pre-commit hook running verify-standards.js on .md and .js changes
- One-command bootstrap script for Z.ai sandbox session setup with skill symlinks
- Graphviz-powered ID graph rendering with SVG/PNG/DOT artifact uploads
- CONTRIBUTING.md guide for safe cross-repo changes without breaking the ID graph

## Tech Stack

- **Runtime** - Node.js
- **Verification** - Shell (pre-commit hooks)
- **CI** - GitHub Actions

## Getting Started

### Prerequisites

- Git
- Node.js 20+
- curl (optional, for bootstrap script)

### Installation

For a fresh Z.ai sandbox session, run one command:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/stsgs1980/Z-ai-platform/main/bootstrap.sh)
```

This clones Z-ai-platform with all submodules, symlinks skills into the sandbox, and prints available skills. If curl is unavailable:

```bash
git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git
cd Z-ai-platform
bash bootstrap.sh
```

### Run

```bash
# Verify the cross-repo ID graph
node standards/scripts/verify-id-graph.js

# Install pre-commit hooks (optional)
./install-hooks.sh
```

## Architecture

| Repo | Layer | Purpose | Contents |
|------|-------|---------|----------|
| Z-ai-platform | L0 | Orchestrator | .gitmodules, CI, hooks |
| Z-ai-standards | L1 | Standards | 6 STD-* files (4 stubs + 2 v1.0+), verifier scripts |
| Z-ai-guard | L2 | Rules | 17 RULE-MONOLITH-* rules + INDEX |
| Z-ai-skills | L3 | Skills | 35 skill dirs (24 with ZAI-* IDs) |

The 4-repo split allows each layer to evolve independently: standards can be amended without forcing rule/skill updates, guard can ship rule changes on its own cadence, and skills can be consumed standalone by the sandbox runtime.

## Project Structure

- `.gitmodules` - Pins 3 submodules (standards, guard, skills)
- `.github/workflows/verify-id-graph.yml` - CI verification workflow
- `CONTRIBUTING.md` - Cross-repo change guide
- `install-hooks.sh` - Pre-commit hook bootstrap
- `bootstrap.sh` - One-command sandbox setup
- `standards/` - Z-ai-standards submodule (L1): 6 STD-* files, scripts/, docs/
- `guard/` - Z-ai-guard submodule (L2): 17 rules, instructions/, scripts/, tools/
- `skills/` - Z-ai-skills submodule (L3): 35 skill directories with INDEX.md

## Cross-repo ID Graph

The ID graph (G01-G15) enforces that changes in one layer do not silently break references in another. See `standards/standards/STD-META-001-v2.0.md` s10.2 for the full G-check catalogue.

| Prefix | Layer | Lives in | Example |
|--------|-------|----------|---------|
| STD | L1 | standards/ | STD-META-001 |
| RULE | L2 | guard/ | RULE-MONOLITH-002 |
| PROC | L2 | guard/ | PROC-SETUP-001 |
| TOOL | L2 | guard/ | TOOL-VERIFY-001 |
| ZAI | L3 | skills/ | ZAI-META-001 |

Related: directed edges, must respect the layer matrix. Cross-layer STD to RULE is FORBIDDEN (use the reverse direction).

Aligned_with: undirected edges, can cross layers (e.g. STD to ZAI). Must be reciprocated.

Current state (2026-06-17): 47 IDs extracted (6 STD + 17 RULE + 24 ZAI), 30 Related edges, 2 Aligned_with edges, 13/13 HARD PASS, 23 soft warnings (non-blocking).

## CI Behavior

`.github/workflows/verify-id-graph.yml` triggers on push to main, PRs, nightly at 03:00 UTC, and manual dispatch.

The workflow:
1. Checks out Z-ai-platform with `--recurse-submodules`
2. Sets up Node.js 20
3. Runs `verify-standards.js` (per-repo invariants)
4. Runs `verify-id-graph.js` (cross-repo graph)
5. Installs graphviz and renders the ID graph
6. Uploads id-graph.svg, id-graph.png, id-graph.dot as 30-day artifacts (even on green builds)
7. On failure: uploads verifier output as artifact, posts PR comment

`install-hooks.sh` configures `core.hooksPath = .githooks` so that pre-commit runs `verify-standards.js` automatically on any commit touching `.md` or `verify-*.js` files.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide on making changes without breaking the ID graph. When updating a submodule:

```bash
cd standards
git checkout main
git pull
cd ..
git add standards
git commit -m "Bump standards: <reason>"
git push
```

## License

Private. See individual submodules for any additional terms.
