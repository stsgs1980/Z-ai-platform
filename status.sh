#!/usr/bin/env bash
#
# status.sh — check if your custom skills are loaded in the current session
#
# Usage:
#   bash /home/z/my-project/Z-ai-platform/status.sh
#
# Run this if you suspect the session restarted or skills are missing.
# It tells you:
#   - Whether Z-ai-platform is cloned
#   - Whether symlinks are in place
#   - Which custom skills are currently active
#   - Whether you need to run bootstrap.sh

set -euo pipefail

PLATFORM_DIR="/home/z/my-project/Z-ai-platform"
SANDBOX_SKILLS_DIR="/home/z/my-project/skills"

echo "============================================"
echo "  Z.ai Sandbox Session Status"
echo "  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "============================================"
echo ""

# 1. Is Z-ai-platform cloned?
if [ -d "$PLATFORM_DIR/.git" ]; then
    cd "$PLATFORM_DIR"
    last_commit=$(git log -1 --oneline 2>&1)
    branch=$(git rev-parse --abbrev-ref HEAD 2>&1)
    dirty=$(git status --porcelain 2>&1 | wc -l)
    echo "✓ Z-ai-platform: CLONED"
    echo "  Branch: $branch"
    echo "  Last commit: $last_commit"
    echo "  Uncommitted changes: $dirty files"
else
    echo "✗ Z-ai-platform: NOT CLONED"
    echo ""
    echo "  → Run bootstrap.sh to restore your skills:"
    echo "    bash <(curl -fsSL https://raw.githubusercontent.com/stsgs1980/Z-ai-platform/main/bootstrap.sh)"
    exit 0
fi

echo ""

# 2. Are skills symlinked?
echo "=== Custom skills in /home/z/my-project/skills/ ==="
symlink_count=$(ls -l "$SANDBOX_SKILLS_DIR" 2>/dev/null | grep -c "^l" || echo 0)
real_count=$(ls -l "$SANDBOX_SKILLS_DIR" 2>/dev/null | grep "^d" | wc -l)

if [ "$symlink_count" -eq 0 ]; then
    echo "✗ No symlinks found — bootstrap.sh has not been run in this session."
    echo ""
    echo "  → Run:"
    echo "    bash $PLATFORM_DIR/bootstrap.sh"
else
    echo "✓ $symlink_count custom skills linked from Z-ai-platform"
    echo "  ($real_count real directories are sandbox-installed)"
fi

echo ""

# 3. Critical skills check
echo "=== Critical skills check ==="
for skill in skill-creator zai-skill-registry skill-id-system; do
    target="$SANDBOX_SKILLS_DIR/$skill"
    if [ -L "$target" ]; then
        real_path=$(readlink -f "$target")
        if [ -f "$target/SKILL.md" ]; then
            echo "✓ $skill → $(basename $(dirname $real_path))/$(basename $real_path)"
        else
            echo "✗ $skill → BROKEN SYMLINK (target missing)"
        fi
    elif [ -d "$target" ]; then
        echo "⚠ $skill → real directory (sandbox-installed, not your version)"
    else
        echo "✗ $skill → MISSING"
    fi
done

echo ""

# 4. Refactored skill-creator check
echo "=== skill-creator version check ==="
if [ -f "$SANDBOX_SKILLS_DIR/skill-creator/SKILL.md" ]; then
    cool_count=$(grep -cE "Cool\?|how could you|plumbers|Good luck!" "$SANDBOX_SKILLS_DIR/skill-creator/SKILL.md" 2>/dev/null || true)
    cool_count=${cool_count:-0}
    line_count=$(wc -l < "$SANDBOX_SKILLS_DIR/skill-creator/SKILL.md")
    if [ "${cool_count:-0}" -eq 0 ]; then
        echo "✓ Refactored version active ($line_count lines, no conversational tone)"
    else
        echo "⚠ Original Anthropic version active ($cool_count conversational phrases found, $line_count lines)"
        echo "  → Run bootstrap.sh to switch to refactored version"
    fi
fi

echo ""
echo "============================================"
if [ "$symlink_count" -gt 0 ]; then
    echo "  Status: HEALTHY — your custom skills are loaded."
else
    echo "  Status: NEEDS BOOTSTRAP — run bootstrap.sh to restore skills."
fi
echo "============================================"
