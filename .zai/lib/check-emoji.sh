#!/usr/bin/env bash
# check-emoji.sh — detect emoji in .md files (v4, STD-DOC-003)
# Usage: bash check-emoji.sh [--staged] [--file FILE] [--config PATH]
#   --staged    check only git staged .md files (default: all .md in cwd)
#   --file F    check a specific file
#   --config P  path to config.json (default: .zai/config.json)
# Exit: 0 = pass, 1 = emoji found
# macOS compat: grep -P (GNU) primary, perl -C (BSD) fallback

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.json"

MODE="all"
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged) MODE="staged"; shift ;;
        --file)   TARGET_FILE="$2"; shift 2 ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        *)        echo "Unknown option: $1"; exit 2 ;;
    esac
done

# Emoji regex — covers common Unicode emoji ranges
EMOJI_REGEX='[\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F900}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{FE00}-\x{FE0F}\x{1F1E0}-\x{1F1FF}]'

check_file() {
    local f="$1"
    [[ -z "$f" ]] && return
    [[ ! -f "$f" ]] && return

    # Try grep -P first (GNU/Linux), fall back to perl -C (macOS/BSD)
    if grep -Pq "$EMOJI_REGEX" "$f" 2>/dev/null; then
        echo "[check-emoji] FAIL: $f contains emoji (STD-DOC-003)"
        return 1
    elif perl -C -ne "exit 1 if /$EMOJI_REGEX/" "$f" 2>/dev/null; then
        # perl exited 0 = no emoji
        return 0
    else
        # perl exited 1 = emoji found
        echo "[check-emoji] FAIL: $f contains emoji (STD-DOC-003)"
        return 1
    fi
    return 0
}

FAIL=0

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
