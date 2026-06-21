#!/usr/bin/env bash
# install-hooks.sh — one-time bootstrap for git hooks
#
# Usage:  bash install-hooks.sh
#
# What it does:
#   1. Tells git to look for hooks in .githooks/ instead of .git/hooks/
#   2. Marks all hooks in .githooks/ as executable
#   3. Verifies the setup by listing the active hook path
#
# Why .githooks/ instead of .git/hooks/?
#   - .githooks/ is versioned with the repo, so hooks are shared across clones
#   - .git/hooks/ is local-only and not committed
#
# Why not Husky/lefthook?
#   - Our hooks are pure bash + node, no npm dependency needed
#   - Keeps the toolchain minimal (no package.json required to enable hooks)
#
# Active hooks (as of 2026-06-21):
#   - pre-commit  : 3-phase content/structural/worklog-freshness checks.
#                   See skills/skills/commit-work/CONTRACT.md §3-4.
#   - commit-msg  : Conventional Commits format validation on commit
#                   message (RULE-MONOLITH-004). Added in O-017 Phase B2.
#
# Contract reference:
#   skills/skills/commit-work/CONTRACT.md — full execution contract
#   skills/skills/commit-work/scripts/run-contract.sh — callable runtime

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

if [ ! -d .git ]; then
  echo "[install-hooks] Not a git repository: $REPO_ROOT"
  echo "[install-hooks] Run 'git init' first, then re-run this script."
  exit 1
fi

echo "[install-hooks] Setting core.hooksPath to .githooks"
git config core.hooksPath .githooks

echo "[install-hooks] Marking hooks executable"
chmod +x .githooks/* 2>/dev/null || true

echo "[install-hooks] Active hook path:"
git config --get core.hooksPath

echo ""
echo "[install-hooks] Done. Hooks now active:"
ls -1 .githooks/ 2>/dev/null | sed 's/^/  - /'
echo ""
echo "[install-hooks] Hook responsibilities:"
echo "  - pre-commit  : Phase 0 worklog freshness (WARN) + Phase 1 V01-V11"
echo "                  invariants (BLOCK) + Phase 2 G01-G15 ID-graph (BLOCK)"
echo "  - commit-msg  : Conventional Commits format on message (G4/G5 BLOCK,"
echo "                  G6 WARN). Per RULE-MONOLITH-004 + STD-GIT-001 §1."
echo ""
echo "[install-hooks] To bypass a hook for ONE commit (not recommended):"
echo "  git commit --no-verify"
echo ""
echo "[install-hooks] To invoke the commit-work skill explicitly (dry-run):"
echo "  bash skills/skills/commit-work/scripts/run-contract.sh --dry-run"
