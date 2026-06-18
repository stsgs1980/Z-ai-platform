# Z-ai-platform

> Layer: L0 — Orchestrator
> Last Updated: 2026-06-17
> Status: **LIVE — 4-repo architecture deployed on GitHub**

This repository is the **orchestrator** for the Z-ai ecosystem. It pins
the other three repositories (Z-ai-standards, Z-ai-guard, Z-ai-skills)
as git submodules and runs the cross-repo ID-graph verifier in CI.

## Repository layout

```
Z-ai-platform/                  (this repo, L0)
├── .gitmodules                 # Pins 3 submodules (clean HTTPS URLs, no PATs)
├── README.md                   # This file
├── CONTRIBUTING.md             # How to make changes without breaking the ID graph
├── install-hooks.sh            # Bootstrap pre-commit hooks
├── .github/
│   └── workflows/
│       └── verify-id-graph.yml # CI: nightly + push + PR verification
├── standards/                  # → Z-ai-standards (submodule, L1)
│   ├── standards/              #   6 STD-* files (4 stubs + 2 v1.0+)
│   ├── docs/
│   ├── scripts/
│   │   ├── verify-standards.js #   Per-repo invariants (V01-V10)
│   │   └── verify-id-graph.js  #   Cross-repo ID graph (13/13 HARD PASS)
│   └── MIGRATIONS.md           #   M001 (ZAI-META-001 SUPERSEDED), M002 (RULE-MONOLITH)
├── guard/                      # → Z-ai-guard (submodule, L2)
│   ├── rules/
│   │   ├── RULE-MONOLITH-001.md  .. RULE-MONOLITH-017.md   (17 rules)
│   │   └── INDEX.md            #   Rule catalog
│   ├── instructions/
│   ├── scripts/
│   └── tools/
└── skills/                     # → Z-ai-skills (submodule, L3)
    ├── skills/                 #   35 skill dirs (24 with ZAI-* IDs, 11 without)
    │   ├── INDEX.md            #   Skill catalog by domain
    │   ├── skill-id-system/    #   ZAI-META-001
    │   ├── skill-creator/      #   ZAI-META-002
    │   └── ...                 #   32 more skills
    └── README.md
```

## ID graph state (2026-06-17)

```
IDs extracted:    47  (6 STD + 17 RULE + 24 ZAI)
Related edges:    30
Aligned_with:     2   (STD-SKILL-001 ↔ ZAI-META-001, ↔ ZAI-META-002)
Hard checks:      13/13 PASS
Soft warnings:    23  (W03 stub dead standard + W04 rogue-skill-with-ID x22, non-blocking)
```

The 13/13 HARD PASS is enforced by:
- **Locally**: `node standards/scripts/verify-id-graph.js`
- **On CI**: `.github/workflows/verify-id-graph.yml` runs on every push, PR, and nightly at 03:00 UTC.

## Quick start

### In a fresh Z.ai sandbox session (your daily workflow)

When you start a new sandbox session and want your custom skills back, run **one command**:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/stsgs1980/Z-ai-platform/main/bootstrap.sh)
```

This will:
1. Clone `Z-ai-platform` (with all submodules) into `/home/z/my-project/Z-ai-platform/` if not already there.
2. `git pull --recurse-submodules` if it is already there (gets latest skills).
3. Symlink every skill from `Z-ai-platform/skills/skills/*` into `/home/z/my-project/skills/` so the sandbox can find them.
4. Back up any sandbox-installed skill with the same name to `<name>.sandbox-backup/` (so your toolkit version always wins).
5. Print a list of available custom skills at the end.

After that, `Skill(command="skill-creator")` (and all 35+ of your toolkit skills) will load from your GitHub repo.

> **If `curl` is unavailable in the sandbox**, run it manually in two steps:
> ```bash
> git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git /home/z/my-project/Z-ai-platform
> bash /home/z/my-project/Z-ai-platform/bootstrap.sh
> ```

### First-time clone (for development / inspection)

```bash
# Clone with submodules (one command)
git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git
cd Z-ai-platform

# Verify the ID graph
node standards/scripts/verify-id-graph.js

# Install pre-commit hooks (optional, runs verifier on .md/.js changes)
./install-hooks.sh
```

## Updating a submodule

```bash
# Pull latest changes inside the submodule
cd standards
git checkout main
git pull
cd ..

# Bump the pointer in Z-ai-platform
git add standards
git commit -m "Bump standards: <reason>"
git push
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

## Architecture: 4 repositories

| Repo | Layer | Purpose | Contents |
|------|-------|---------|----------|
| **Z-ai-platform** | L0 | Orchestrator | `.gitmodules`, CI, hooks |
| **Z-ai-standards** | L1 | Standards | 6 STD-* files (4 stubs + 2 v1.0+), verifier scripts |
| **Z-ai-guard** | L2 | Rules | 17 RULE-MONOLITH-* rules + INDEX |
| **Z-ai-skills** | L3 | Skills | 35 skill dirs (24 with ZAI-* IDs) |

The 4-repo split exists so each layer can evolve independently:
- Standards can be amended without forcing rule/skill updates.
- Guard can ship rule changes on its own cadence.
- Skills can be consumed standalone by the sandbox runtime.

## Cross-repo ID graph

The ID graph (G01-G15) enforces that changes in one layer do not silently
break references in another. See `standards/standards/STD-META-001-v2.0.md`
§10.2 for the full G-check catalogue.

| Prefix | Layer | Lives in | Example |
|--------|-------|----------|---------|
| STD | L1 | standards/ | STD-META-001 |
| RULE | L2 | guard/ | RULE-MONOLITH-002 |
| PROC | L2 | guard/ | PROC-MONOLITH-SETUP |
| TOOL | L2 | guard/ | TOOL-MONOLITH-VERIFY |
| ZAI | L3 | skills/ | ZAI-META-001 |

**Related:** directed edges, must respect the layer matrix. Cross-layer STD→RULE is FORBIDDEN (use the reverse direction).

**Aligned_with:** undirected edges, can cross layers (e.g. STD ↔ ZAI). Must be reciprocated.

## CI behavior

`.github/workflows/verify-id-graph.yml` triggers on:
- Push to `main` in Z-ai-platform (covers submodule pointer bumps)
- Pull request to `main`
- Nightly at 03:00 UTC (= 06:00 Europe/Moscow)
- Manual dispatch via GitHub Actions UI

The workflow:
1. Checks out Z-ai-platform with `--recurse-submodules`
2. Sets up Node.js 20
3. Runs `node standards/scripts/verify-id-graph.js`
4. On failure: uploads the verifier output as an artifact (7-day retention), posts a comment on the PR (if PR).

## Pre-commit hook

`install-hooks.sh` configures `core.hooksPath = .githooks` so that pre-commit runs `verify-standards.js` automatically on any commit touching `.md` or `verify-*.js` files.

## License

Private. See individual submodules for any additional terms.
