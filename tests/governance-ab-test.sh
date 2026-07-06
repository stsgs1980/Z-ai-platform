#!/usr/bin/env bash
# ============================================================================
# governance-ab-test.sh — A/B test: governance ON vs OFF
# ============================================================================
# Usage:
#   bash tests/governance-ab-test.sh setup    # Create test project
#   bash tests/governance-ab-test.sh run-on   # Run with governance
#   bash tests/governance-ab-test.sh run-off  # Run without governance
#   bash tests/governance-ab-test.sh compare  # Compare results
# ============================================================================

set -euo pipefail

TEST_DIR="/tmp/governance-ab-test"
PROJECT_DIR="$TEST_DIR/project"
RESULTS_DIR="$TEST_DIR/results"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[AB-TEST]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }

# ============================================================================
# SETUP — Create clean test project
# ============================================================================
cmd_setup() {
    log "Setting up test project..."
    
    # Clean slate
    rm -rf "$TEST_DIR"
    mkdir -p "$RESULTS_DIR"
    
    # Create minimal Next.js project structure
    mkdir -p "$PROJECT_DIR/src/app"
    mkdir -p "$PROJECT_DIR/src/components"
    mkdir -p "$PROJECT_DIR/prisma"
    
    # package.json
    cat > "$PROJECT_DIR/package.json" << 'EOF'
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
EOF
    
    # tsconfig.json
    cat > "$PROJECT_DIR/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF
    
    # Initial page.tsx (empty)
    cat > "$PROJECT_DIR/src/app/page.tsx" << 'EOF'
export default function Home() {
  return <div>Hello World</div>;
}
EOF
    
    log "Test project created at $PROJECT_DIR"
}

# ============================================================================
# COLLECT METRICS — Run after test task
# ============================================================================
collect_metrics() {
    local mode=$1  # "on" or "off"
    local output_file="$RESULTS_DIR/metrics-${mode}.json"
    
    log "Collecting metrics for mode: $mode"
    
    cd "$PROJECT_DIR"
    
    # Initialize metrics
    local lint_errors=0
    local type_errors=0
    local max_file_lines=0
    local files_over_250=0
    local total_lines=0
    local file_count=0
    local upward_imports=0
    local worklog_entries=0
    local todo_count=0
    local aria_count=0
    local component_count=0
    
    # 1. Lint errors
    if command -v bun &> /dev/null; then
        lint_errors=$(bun run lint 2>&1 | grep -c "error" || true)
    elif command -v npm &> /dev/null; then
        lint_errors=$(npm run lint 2>&1 | grep -c "error" || true)
    fi
    
    # 2. Type errors
    if command -v bun &> /dev/null; then
        type_errors=$(bun run typecheck 2>&1 | grep -c "error TS" || true)
    elif command -v npx &> /dev/null; then
        type_errors=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
    fi
    
    # 3. File sizes
    while IFS= read -r file; do
        lines=$(wc -l < "$file" 2>/dev/null || echo 0)
        total_lines=$((total_lines + lines))
        file_count=$((file_count + 1))
        
        if [ "$lines" -gt "$max_file_lines" ]; then
            max_file_lines=$lines
        fi
        
        if [ "$lines" -gt 250 ]; then
            files_over_250=$((files_over_250 + 1))
            warn "Monolith detected: $file ($lines lines)"
        fi
    done < <(find src -name "*.tsx" -o -name "*.ts" 2>/dev/null)
    
    # 4. Upward imports (FSD violation)
    upward_imports=$(grep -r "from '\.\./\.\." src/ 2>/dev/null | wc -l || true)
    
    # 5. Worklog entries
    if [ -f worklog.md ]; then
        worklog_entries=$(grep -c "^##" worklog.md || true)
    fi
    
    # 6. TODO/FIXME count
    todo_count=$(grep -rn "TODO\|FIXME" src/ 2>/dev/null | wc -l || true)
    
    # 7. ARIA / semantic HTML
    aria_count=$(grep -rc "aria-\|<main\|<nav\|<section" src/ 2>/dev/null | awk -F: '{s+=$2} END {print s}' || true)
    
    # 8. Component count
    component_count=$(find src -name "*.tsx" 2>/dev/null | wc -l || true)
    
    # 9. Average file size
    local avg_lines=0
    if [ "$file_count" -gt 0 ]; then
        avg_lines=$((total_lines / file_count))
    fi
    
    # Write JSON
    cat > "$output_file" << EOF
{
  "mode": "$mode",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "metrics": {
    "lint_errors": $lint_errors,
    "type_errors": $type_errors,
    "max_file_lines": $max_file_lines,
    "files_over_250": $files_over_250,
    "total_lines": $total_lines,
    "file_count": $file_count,
    "avg_lines_per_file": $avg_lines,
    "upward_imports": $upward_imports,
    "worklog_entries": $worklog_entries,
    "todo_count": $todo_count,
    "aria_count": $aria_count,
    "component_count": $component_count
  }
}
EOF
    
    log "Metrics saved to $output_file"
    cat "$output_file"
}

# ============================================================================
# COMPARE — Show diff between ON and OFF
# ============================================================================
cmd_compare() {
    local on_file="$RESULTS_DIR/metrics-on.json"
    local off_file="$RESULTS_DIR/metrics-off.json"
    
    if [ ! -f "$on_file" ] || [ ! -f "$off_file" ]; then
        fail "Both metrics-on.json and metrics-off.json required. Run tests first."
    fi
    
    log "=== GOVERNANCE A/B TEST RESULTS ==="
    echo ""
    
    # Parse JSON and create comparison table
    echo "| Метрика | GOV=OFF | GOV=ON | Delta |"
    echo "|---------|---------|--------|-------|"
    
    for metric in lint_errors type_errors max_file_lines files_over_250 avg_lines_per_file upward_imports worklog_entries todo_count aria_count component_count; do
        local off_val=$(jq -r ".metrics.$metric" "$off_file" 2>/dev/null || echo "0")
        local on_val=$(jq -r ".metrics.$metric" "$on_file" 2>/dev/null || echo "0")
        
        local delta=0
        if [ "$off_val" != "0" ]; then
            delta=$((on_val - off_val))
        fi
        
        local delta_str=""
        if [ "$delta" -lt 0 ]; then
            delta_str="${GREEN}${delta}${NC}"
        elif [ "$delta" -gt 0 ]; then
            delta_str="${RED}+${delta}${NC}"
        else
            delta_str="${GREEN}0${NC}"
        fi
        
        echo "| $metric | $off_val | $on_val | $delta_str |"
    done
    
    echo ""
    log "=== ANALYSIS ==="
    
    # Key insights
    local off_lint=$(jq -r ".metrics.lint_errors" "$off_file")
    local on_lint=$(jq -r ".metrics.lint_errors" "$on_file")
    local off_mono=$(jq -r ".metrics.files_over_250" "$off_file")
    local on_mono=$(jq -r ".metrics.files_over_250" "$on_file")
    
    if [ "$off_lint" -gt 0 ] && [ "$on_lint" -eq 0 ]; then
        log "Governance eliminated $off_lint lint errors"
    fi
    
    if [ "$off_mono" -gt 0 ] && [ "$on_mono" -eq 0 ]; then
        log "Governance prevented $off_mono monolithic files"
    fi
}

# ============================================================================
# MAIN
# ============================================================================
case "${1:-help}" in
    setup)   cmd_setup ;;
    run-on)  collect_metrics "on" ;;
    run-off) collect_metrics "off" ;;
    compare) cmd_compare ;;
    *)
        echo "Usage: $0 {setup|run-on|run-off|compare}"
        exit 1
        ;;
esac
