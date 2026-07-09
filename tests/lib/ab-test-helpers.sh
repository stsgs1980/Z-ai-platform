#!/usr/bin/env bash
#
# ab-test-helpers.sh — A/B test specific utilities
# Source this after test-helpers.sh: source tests/lib/test-helpers.sh && source tests/lib/ab-test-helpers.sh
#

set -euo pipefail

# A/B test project setup
create_test_projects() {
    local TEST_DIR="/tmp/governance-ab-test"
    local PROJECT_OFF="$TEST_DIR/project-off"
    local PROJECT_ON="$TEST_DIR/project-on"

    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/results"

    for project in "$PROJECT_OFF" "$PROJECT_ON"; do
        mkdir -p "$project/src/app"
        mkdir -p "$project/src/components"
        mkdir -p "$project/src/lib"

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

        cd "$project"
        git init -q
        git config user.email "test@example.com"
        git config user.name "Test User"
        echo "# Governance A/B Test" > README.md
        git add README.md
        git commit -q -m "Initial commit"
    done
}