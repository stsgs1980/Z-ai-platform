#!/usr/bin/env bash
#
# governance-ab-test.sh — A/B test: governance ON vs OFF
# Tests whether governance hooks actually block violations.
#
# Usage:
#   bash tests/governance-ab-test.sh setup    # Create two test projects
#   bash tests/governance-ab-test.sh task     # Simulate agent work (write violating files)
#   bash tests/governance-ab-test.sh commit   # Try to commit in both projects
#   bash tests/governance-ab-test.sh compare  # Compare results
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$SCRIPT_DIR/lib/ab-test-helpers.sh"

TEST_DIR="/tmp/governance-ab-test"
PROJECT_OFF="$TEST_DIR/project-off"
PROJECT_ON="$TEST_DIR/project-on"
RESULTS_DIR="$TEST_DIR/results"
GUARD_DIR="$SCRIPT_DIR/../guard"

cmd_setup() {
    step "Setting up A/B test projects..."
    create_test_projects

    for project in "$PROJECT_OFF" "$PROJECT_ON"; do
        mkdir -p "$project/src/app"
        mkdir -p "$project/src/components"
        mkdir -p "$project/src/lib"

        cd "$project"

        cat > "$project/package.json" << 'PKGEOP'
{
  "name": "governance-ab-test",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "lint": "next lint",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "next": "^16.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/react": "^19.0.0",
    "typescript": "^5.7.0"
  }
}
PKGEOP

        cat > "$project/tsconfig.json" << 'TSEOP'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "strict": true,
    "noEmit": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "preserve",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
TSEOP

        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        echo "# Governance A/B Test" > README.md
        git add README.md
        git commit -q -m "Initial commit"
    done

    log "A/B test projects created"
    log "  OFF: $PROJECT_OFF"
    log "  ON:  $PROJECT_ON"
}

cmd_task() {
    step "Simulating agent work (writing violating files)..."

    for project in "$PROJECT_OFF" "$PROJECT_ON"; do
        cd "$project"

        cat > "src/app/monolith-page.tsx" << 'TSEOP'
export default function MonolithPage() {
    return (
        <div>
            <h1>Monolith Page</h1>
            <p>This file exceeds 250 lines to test anti-monolith enforcement.</p>
            {/* Many more lines to exceed limit */}
            {[...Array(200)].map((_, i) => (
                <div key={i}>Line {i}</div>
            ))}
        </div>
    )
}
TSEOP

        git add "src/app/monolith-page.tsx"
    done

    log "Violating files written to both projects"
}

cmd_commit() {
    step "Attempting commits..."

    cd "$PROJECT_OFF"
    log "Testing project OFF (no governance)..."
    if git commit -q -m "Add monolith page" 2>/dev/null; then
        log "OFF: Commit succeeded (expected)"
    else
        fail "OFF: Commit failed (unexpected)"
    fi

    cd "$PROJECT_ON"
    log "Testing project ON (with governance)..."
    if git commit -q -m "Add monolith page" 2>/dev/null; then
        fail "ON: Commit succeeded (governance should block)"
    else
        log "ON: Commit blocked (expected)"
    fi
}

cmd_compare() {
    step "Comparing results..."

    cd "$PROJECT_OFF"
    local off_commits=$(git log --oneline | wc -l)

    cd "$PROJECT_ON"
    local on_commits=$(git log --oneline | wc -l)

    echo ""
    echo "Commit count:"
    echo "  OFF: $off_commits"
    echo "  ON:  $on_commits"

    if [ $off_commits -eq 2 ] && [ $on_commits -eq 1 ]; then
        log "A/B test PASSED: governance blocks violations"
    else
        fail "A/B test FAILED: unexpected commit counts"
    fi
}

main() {
    local command="${1:-help}"

    case "$command" in
        setup)   cmd_setup ;;
        task)    cmd_task ;;
        commit)  cmd_commit ;;
        compare) cmd_compare ;;
        *)       echo "Usage: $0 {setup|task|commit|compare}" && exit 1 ;;
    esac
}

main "$@"