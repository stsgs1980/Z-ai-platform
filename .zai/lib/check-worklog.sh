#!/usr/bin/env bash
# check-worklog.sh — verify worklog exists and is non-empty (v4)
# Usage: bash check-worklog.sh [--paths PATH1,PATH2] [--min-lines N] [--config PATH]
#   --paths      comma-separated worklog paths (overrides config.json)
#   --min-lines  minimum lines required (overrides config.json)
#   --config P   path to config.json (default: .zai/config.json)
# Exit: 0 = pass, 1 = worklog missing or too short
# Reads defaults from .zai/config.json if not specified via CLI

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.json"

# Defaults (overridden by config.json, then by CLI args)
WORKLOG_PATHS="worklog.md,docs/session/worklog.md"
MIN_LINES=1

# Read from config.json if available
if [[ -f "$CONFIG_FILE" ]] && command -v node &>/dev/null; then
    CONFIG_PATHS=$(node -e "try{console.log((require('${CONFIG_FILE}').worklog.paths||[]).join(','))}catch(e){console.log('')}" 2>/dev/null || echo "")
    CONFIG_MIN=$(node -e "try{console.log(require('${CONFIG_FILE}').worklog.min_lines||1)}catch(e){console.log(1)}" 2>/dev/null || echo 1)
    [[ -n "$CONFIG_PATHS" ]] && WORKLOG_PATHS="$CONFIG_PATHS"
    MIN_LINES="$CONFIG_MIN"
fi

# Parse CLI args (overrides config)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --paths)     WORKLOG_PATHS="$2"; shift 2 ;;
        --min-lines) MIN_LINES="$2"; shift 2 ;;
        --config)    CONFIG_FILE="$2"; shift 2 ;;
        *)           echo "Unknown option: $1"; exit 2 ;;
    esac
done

FOUND=0
while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    if [[ -s "$path" ]]; then
        LINES=$(awk 'END{print NR}' "$path")
        if [[ "$LINES" -ge "$MIN_LINES" ]]; then
            echo "[check-worklog] PASS: $path ($LINES lines)"
            FOUND=1
            break
        else
            echo "[check-worklog] WARN: $path exists but only $LINES lines (need $MIN_LINES)"
        fi
    fi
done < <(echo "$WORKLOG_PATHS" | tr ',' '\n')

if [[ "$FOUND" -eq 0 ]]; then
    echo "[check-worklog] FAIL: no worklog found or all too short"
    echo "  Checked: $WORKLOG_PATHS"
    echo "  Minimum: $MIN_LINES lines"
    exit 1
fi

exit 0
