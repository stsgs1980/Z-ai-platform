#!/usr/bin/env bash
#
# bootstrap.sh — restore your custom skills in a fresh Z.ai sandbox session
#
# Usage:
#   bash /home/z/my-project/Z-ai-platform/bootstrap.sh
#
# What it does:
#   1. Clones (or updates) stsgs1980/Z-ai-platform into /home/z/my-project/Z-ai-platform/
#      with all submodules (skills, standards, guard).
#   2. Normalizes git mode-bit handling (core.fileMode=false on platform + all
#      submodules). Sandbox fs mount sets +x on all files, which git's default
#      core.fileMode=true flags as 'modified' (17-file noise). See
#      SESSION_NOTES.md §12 LESSON-002.
#   3. Symlinks every skill from Z-ai-platform/skills/skills/* into
#      /home/z/my-project/skills/ so the sandbox can find them.
#   4. Prints a list of available custom skills at the end.
#
# Run this once at the start of any new sandbox session where you want your
# custom skills back.

set -euo pipefail

PLATFORM_DIR="/home/z/my-project/Z-ai-platform"
SANDBOX_SKILLS_DIR="/home/z/my-project/skills"
GITHUB_URL="https://github.com/stsgs1980/Z-ai-platform.git"

echo "=== Step 1: Ensure Z-ai-platform is cloned ==="

if [ ! -d "$PLATFORM_DIR/.git" ]; then
    echo "Cloning Z-ai-platform into $PLATFORM_DIR ..."
    git clone --recurse-submodules "$GITHUB_URL" "$PLATFORM_DIR"
else
    echo "Z-ai-platform already exists. Pulling latest ..."
    cd "$PLATFORM_DIR"
    git pull --recurse-submodules --ff-only
fi

echo ""
echo "=== Step 2: Normalize git mode-bit handling ==="
# Sandbox fs mount sets +x on all files (so .sh scripts run). Git's default
# core.fileMode=true flags the index/working-tree mismatch as 'modified'.
# Setting false makes git ignore mode bit changes. Existing index modes are
# preserved: .sh files stay 100755, docs stay 100644. New .sh files need
# explicit 'git update-index --chmod=+x'.
# See SESSION_NOTES.md §12 LESSON-002 for full rationale.
cd "$PLATFORM_DIR"
git config core.fileMode false
git submodule foreach --recursive 'git config core.fileMode false' 2>/dev/null || true
echo "  core.fileMode=false applied to platform + submodules"

echo ""
echo "=== Step 3: Symlink custom skills into sandbox skills dir ==="

mkdir -p "$SANDBOX_SKILLS_DIR"

TOOLKIT_SKILLS_DIR="$PLATFORM_DIR/skills/skills"
LINKED_COUNT=0
SKIPPED_COUNT=0

for skill_dir in "$TOOLKIT_SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    target_link="$SANDBOX_SKILLS_DIR/$skill_name"

    if [ -e "$target_link" ] || [ -L "$target_link" ]; then
        if [ -L "$target_link" ]; then
            # Already a symlink we created — refresh it
            rm "$target_link"
            ln -s "$skill_dir" "$target_link"
            LINKED_COUNT=$((LINKED_COUNT + 1))
        else
            # Real directory exists with this name. For our toolkit skills
            # (the ones in Z-ai-platform), we want OUR version to win.
            # Backup the sandbox version and replace with symlink.
            backup_dir="${target_link}.sandbox-backup"
            if [ -d "$backup_dir" ]; then
                # Already backed up previously — just remove the sandbox copy
                rm -rf "$target_link"
            else
                mv "$target_link" "$backup_dir"
            fi
            ln -s "$skill_dir" "$target_link"
            echo "  REPLACE  $skill_name  (sandbox version backed up to ${skill_name}.sandbox-backup)"
            LINKED_COUNT=$((LINKED_COUNT + 1))
        fi
    else
        ln -s "$skill_dir" "$target_link"
        echo "  LINK     $skill_name"
        LINKED_COUNT=$((LINKED_COUNT + 1))
    fi
done

echo ""
echo "=== Step 4: Available custom skills ==="
echo "Linked: $LINKED_COUNT"
echo "Skipped (already exist as real dirs): $SKIPPED_COUNT"
echo ""
echo "Custom skills now available via Skill(command=\"...\"):"
for skill_dir in "$TOOLKIT_SKILLS_DIR"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
        # Extract description first line
        desc=$(awk '/^description:/{sub(/^description: /,""); print; exit}' "$skill_dir/SKILL.md" | cut -c1-80)
        printf "  %-40s %s\n" "$skill_name" "$desc"
    fi
done

echo ""
echo "Done. To verify: Skill(command=\"skill-creator\") should now load your refactored version."
