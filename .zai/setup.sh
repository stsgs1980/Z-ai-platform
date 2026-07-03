#!/usr/bin/env bash
# .zai/setup.sh — Z-ai-platform governance setup (integrated)
# Entry point: bash .zai/setup.sh
# Purpose: add emoji check + config.json to existing governance system
# Integrates with: existing .husky/pre-commit (co-change + worklog + lint-staged)
# Does NOT replace existing hooks — adds .zai/ layer on top

set -uo pipefail

PROJECT_ROOT="${ZAI_PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ZAI_DIR="${PROJECT_ROOT}/.zai"
GUARD_DIR="${PROJECT_ROOT}/guard"
SKILLS_DIR="${PROJECT_ROOT}/skills"
CONFIG_FILE="${ZAI_DIR}/config.json"

echo "=== Z.ai Governance Setup (integrated) ==="
echo "Project root: ${PROJECT_ROOT}"
echo ""

# --- Phase 1: Check dependencies ---
echo "[1/6] Checking dependencies..."
MISSING=0

if command -v jq &>/dev/null; then
    echo "  jq: $(jq --version)"
else
    echo "  jq: NOT FOUND — config.json defaults will be used"
    MISSING=1
fi

if command -v node &>/dev/null; then
    echo "  node: $(node --version)"
else
    echo "  node: NOT FOUND — verify-*.js checks will be skipped"
fi

if command -v perl &>/dev/null; then
    echo "  perl: $(perl -e 'print "$^V\n"' 2>/dev/null || perl --version 2>&1 | head -1)"
else
    echo "  perl: NOT FOUND — emoji check will use grep -P only (Linux)"
fi

if [[ "$MISSING" -eq 1 ]]; then
    echo "  WARN: Some dependencies missing. Governance will work with reduced functionality."
fi
echo "  OK"

# --- Phase 2: Check existing infrastructure ---
echo "[2/6] Checking existing infrastructure..."

# Check existing hook
if [[ -f "${PROJECT_ROOT}/.husky/pre-commit" ]]; then
    echo "  Existing .husky/pre-commit: FOUND"
    if grep -q "co-change-check" "${PROJECT_ROOT}/.husky/pre-commit" 2>/dev/null; then
        echo "    -> co-change-check.sh: present"
    fi
    if grep -q "worklog-check" "${PROJECT_ROOT}/.husky/pre-commit" 2>/dev/null; then
        echo "    -> worklog-check.sh: present"
    fi
    if grep -q "lint-staged" "${PROJECT_ROOT}/.husky/pre-commit" 2>/dev/null; then
        echo "    -> lint-staged: present"
    fi
else
    echo "  WARN: .husky/pre-commit not found"
fi

# Check guard scripts
if [[ -d "${GUARD_DIR}/scripts" ]]; then
    echo "  Guard scripts: $(ls ${GUARD_DIR}/scripts/*.sh 2>/dev/null | wc -l) shell scripts"
else
    echo "  WARN: guard/scripts/ not found"
fi

# Check skills
if [[ -d "${SKILLS_DIR}" ]]; then
    SKILL_COUNT=$(ls -d "${SKILLS_DIR}"/*/ 2>/dev/null | wc -l)
    echo "  Skills: ${SKILL_COUNT} available"
else
    echo "  WARN: ${SKILLS_DIR}/ not found"
fi

echo "  OK"

# --- Phase 3: Create config.json if missing ---
echo "[3/6] Checking config..."
if [[ ! -f "${CONFIG_FILE}" ]]; then
    cat > "${CONFIG_FILE}" << 'CONF'
{
  "version": "1.0.0",
  "line_count": {
    "limit": 500,
    "extensions": [".md", ".ts", ".js", ".py", ".sh"]
  },
  "worklog": {
    "paths": ["worklog.md"],
    "min_lines": 1
  },
  "emoji": {
    "enabled": true,
    "extensions": [".md"]
  },
  "exclude_dirs": [".git", "node_modules", ".next", "skills", "guard", "standards"]
}
CONF
    echo "  Created: .zai/config.json"
else
    echo "  config.json exists"
fi

# --- Phase 4: Validate config ---
echo "[4/6] Validating config..."
if [[ -f "${ZAI_DIR}/validate-config" ]]; then
    bash "${ZAI_DIR}/validate-config" --config "${CONFIG_FILE}" 2>&1 | sed 's/^/  /'
else
    echo "  SKIP: validate-config not found"
fi

# --- Phase 5: Install emoji check in existing hook ---
echo "[5/6] Adding emoji check to .husky/pre-commit..."
HOOK="${PROJECT_ROOT}/.husky/pre-commit"
ZAI_DIR_REL=".zai"

if [[ -f "$HOOK" ]]; then
    # Check if emoji check already added
    if grep -q "check-emoji.sh" "$HOOK" 2>/dev/null; then
        echo "  Emoji check already in .husky/pre-commit"
    else
        # Append emoji check to existing hook
        cat >> "$HOOK" << 'EMOJI_CHECK'

# .zai/emoji-check: STD-DOC-003 emoji detection
if [[ -f ".zai/lib/check-emoji.sh" ]]; then
    bash .zai/lib/check-emoji.sh --staged || exit 1
fi
EMOJI_CHECK
        echo "  Added: emoji check to .husky/pre-commit"
    fi
else
    echo "  WARN: .husky/pre-commit not found — creating new hook"
    mkdir -p "${PROJECT_ROOT}/.husky"
    cat > "$HOOK" << 'NEW_HOOK'
#!/usr/bin/env bash
# Z.ai pre-commit hook — governance enforcement
set -uo pipefail

echo "[zai] Running governance checks..."

# Emoji check (STD-DOC-003)
if [[ -f ".zai/lib/check-emoji.sh" ]]; then
    bash .zai/lib/check-emoji.sh --staged || exit 1
fi

echo "[zai] All checks passed."
NEW_HOOK
    chmod +x "$HOOK"
    echo "  Created: .husky/pre-commit with emoji check"
fi

# --- Phase 6: Summary ---
echo "[6/6] Setup complete."
echo ""
echo "Governance layers active:"
echo "  Existing:"
echo "    - co-change-check.sh (guard/scripts/)"
echo "    - worklog-check.sh (guard/scripts/)"
echo "    - lint-staged (npx)"
echo "  Added by .zai/:"
echo "    - emoji check (.zai/lib/check-emoji.sh)"
echo "    - config.json (.zai/config.json)"
echo "    - verify orchestrator (.zai/verify)"
echo ""
echo "Commands:"
echo "  bash .zai/verify                  (run all checks)"
echo "  bash .zai/verify --staged         (staged files only)"
echo "  bash .zai/verify --check emoji    (specific check)"
echo "  bash .zai/validate-config         (validate config.json)"
echo ""
echo "Config: edit .zai/config.json to change limits"
