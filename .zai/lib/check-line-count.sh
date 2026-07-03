#!/usr/bin/env bash
# check-line-count.sh — check .md files for line count violations (v4)
# Usage: bash check-line-count.sh [--staged] [--limit N] [--file FILE] [--config PATH]
#   --staged    check only git staged .md files (default: all .md in cwd)
#   --limit N   max lines per file (overrides config.json)
#   --file F    check a specific file
#   --config P  path to config.json (default: .zai/config.json)
# Exit: 0 = pass, 1 = violations found
# Reads default limit from .zai/config.json if --limit not specified

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.json"

# Defaults (overridden by config.json, then by CLI args)
LIMIT=500
MODE="all"
TARGET_FILE=""

# Read from config.json if available
if [[ -f "$CONFIG_FILE" ]] && command -v node &>/dev/null; then
    CONFIG_LIMIT=$(node -e "try{console.log(require('${CONFIG_FILE}').line_count.limit||500)}catch(e){console.log(500)}" 2>/dev/null || echo 500)
    LIMIT="$CONFIG_LIMIT"
fi

# Parse CLI args (overrides config)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged) MODE="staged"; shift ;;
        --limit)  LIMIT="$2"; shift 2 ;;
        --file)   TARGET_FILE="$2"; shift 2 ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        *)        echo "Unknown option: $1"; exit 2 ;;
    esac
done

FAIL=0

check_file() {
    local f="$1"
    [[ -z "$f" ]] && return
    [[ ! -f "$f" ]] && return

    local lines
    lines=$(awk 'END{print NR}' "$f")
    if [[ "$lines" -gt "$LIMIT" ]]; then
        echo "[check-line-count] FAIL: $f has $lines lines (limit: $LIMIT)"
        return 1
    fi
    return 0
}

if [[ -n "$TARGET_FILE" ]]; then
    check_file "$TARGET_FILE" || FAIL=1
elif [[ "$MODE" == "staged" ]]; then
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        check_file "$f" || FAIL=1
    done < <(git diff --cached --name-only --diff-filter=ACM | grep '\.md$' || true)
else
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        check_file "$f" || FAIL=1
    done < <(find . -name '*.md' \
        -not -path './.git/*' \
        -not -path './node_modules/*' \
        -not -path './.next/*' \
        -not -path './skills/*' \
        2>/dev/null || true)
fi

exit $FAIL
