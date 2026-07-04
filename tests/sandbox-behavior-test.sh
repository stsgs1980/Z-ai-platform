#!/usr/bin/env bash
#
# sandbox-behavior-test.sh — Test actual sandbox behavior
#
# Usage:
#   bash tests/sandbox-behavior-test.sh
#
# What it tests:
#   1. What the agent actually sees and can do
#   2. Skills loading behavior
#   3. Governance system behavior
#   4. Pre-commit hook behavior
#   5. Verifier behavior
#
# This test simulates what an agent would experience in the sandbox.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Platform directory
PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test directory
TEST_DIR="/tmp/zai-sandbox-behavior-test-$$"

# ============================================================================
# Helper functions
# ============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

run_test() {
    local test_name="$1"
    local test_func="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    echo "=== Test: $test_name ==="
    
    if $test_func; then
        log_success "$test_name"
    else
        log_fail "$test_name"
    fi
}

# ============================================================================
# Test 1: Agent can read AGENT_RULES.md
# ============================================================================

test_agent_can_read_agent_rules() {
    local test_dir="$TEST_DIR/agent-rules"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if AGENT_RULES.md is readable
    if [ -f "Z-ai-platform/AGENT_RULES.md" ]; then
        log_info "AGENT_RULES.md exists"
        
        # Check if agent can read it
        if cat "Z-ai-platform/AGENT_RULES.md" > /dev/null 2>&1; then
            log_info "AGENT_RULES.md is readable"
        else
            log_fail "AGENT_RULES.md is not readable"
            return 1
        fi
        
        # Check if it contains expected content
        if grep -q "Single Entry Point" "Z-ai-platform/AGENT_RULES.md"; then
            log_info "AGENT_RULES.md contains expected content"
        else
            log_fail "AGENT_RULES.md missing expected content"
            return 1
        fi
        
        return 0
    else
        log_fail "AGENT_RULES.md not found"
        return 1
    fi
}

# ============================================================================
# Test 2: Agent can load skills
# ============================================================================

test_agent_can_load_skills() {
    local test_dir="$TEST_DIR/load-skills"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if skills are accessible
    if [ -d "skills" ]; then
        log_info "skills directory exists"
        
        # Check each skill
        local errors=0
        for skill_dir in skills/*/; do
            [ -d "$skill_dir" ] || continue
            local skill_name=$(basename "$skill_dir")
            
            # Check if SKILL.md is readable
            if [ -f "$skill_dir/SKILL.md" ]; then
                if cat "$skill_dir/SKILL.md" > /dev/null 2>&1; then
                    log_info "$skill_name: SKILL.md readable"
                else
                    log_fail "$skill_name: SKILL.md not readable"
                    errors=$((errors + 1))
                fi
            else
                log_fail "$skill_name: SKILL.md missing"
                errors=$((errors + 1))
            fi
        done
        
        if [ "$errors" -eq 0 ]; then
            return 0
        else
            return 1
        fi
    else
        log_fail "skills directory not found"
        return 1
    fi
}

# ============================================================================
# Test 3: Agent can find zai-sandbox-rules
# ============================================================================

test_agent_can_find_sandbox_rules() {
    local test_dir="$TEST_DIR/sandbox-rules"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if zai-sandbox-rules exists
    if [ -f "skills/zai-sandbox-rules/SKILL.md" ]; then
        log_info "zai-sandbox-rules/SKILL.md exists"
        
        # Check if it contains the rules
        if grep -q "Rule 1:" "skills/zai-sandbox-rules/SKILL.md"; then
            log_info "zai-sandbox-rules contains Rule 1"
        else
            log_fail "zai-sandbox-rules missing Rule 1"
            return 1
        fi
        
        if grep -q "NEVER Run Dev Servers" "skills/zai-sandbox-rules/SKILL.md"; then
            log_info "zai-sandbox-rules contains 'NEVER Run Dev Servers'"
        else
            log_fail "zai-sandbox-rules missing 'NEVER Run Dev Servers'"
            return 1
        fi
        
        return 0
    else
        log_fail "zai-sandbox-rules/SKILL.md not found"
        return 1
    fi
}

# ============================================================================
# Test 4: Agent can run verifiers
# ============================================================================

test_agent_can_run_verifiers() {
    local test_dir="$TEST_DIR/run-verifiers"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if verifiers are executable
    if [ -f "Z-ai-platform/standards/scripts/verify-standards.js" ]; then
        log_info "verify-standards.js exists"
        
        # Try to run it
        if command -v node &>/dev/null; then
            log_info "Running verify-standards.js..."
            if (cd "Z-ai-platform/standards" && node scripts/verify-standards.js 2>&1 | tail -3); then
                log_info "verify-standards.js executed"
            else
                log_fail "verify-standards.js failed to execute"
                return 1
            fi
        else
            log_skip "node not available"
        fi
    else
        log_fail "verify-standards.js not found"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Test 5: Agent can check git status
# ============================================================================

test_agent_can_check_git_status() {
    local test_dir="$TEST_DIR/git-status"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if agent can run git status
    if git status > /dev/null 2>&1; then
        log_info "git status works"
        
        # Check if Z-ai-platform is tracked
        if git status Z-ai-platform > /dev/null 2>&1; then
            log_info "Z-ai-platform is tracked by git"
        else
            log_warn "Z-ai-platform may not be tracked by git"
        fi
        
        return 0
    else
        log_fail "git status failed"
        return 1
    fi
}

# ============================================================================
# Test 6: Agent can read config
# ============================================================================

test_agent_can_read_config() {
    local test_dir="$TEST_DIR/read-config"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if config is readable
    if [ -f "Z-ai-platform/.zai/config.json" ]; then
        log_info "config.json exists"
        
        # Check if agent can read it
        if cat "Z-ai-platform/.zai/config.json" > /dev/null 2>&1; then
            log_info "config.json is readable"
        else
            log_fail "config.json is not readable"
            return 1
        fi
        
        # Check if it's valid JSON
        if command -v node &>/dev/null; then
            if node -e "require('./Z-ai-platform/.zai/config.json')" 2>/dev/null; then
                log_info "config.json is valid JSON"
            else
                log_fail "config.json is invalid JSON"
                return 1
            fi
        fi
        
        return 0
    else
        log_fail "config.json not found"
        return 1
    fi
}

# ============================================================================
# Test 7: Agent can understand skill structure
# ============================================================================

test_agent_can_understand_skill_structure() {
    local test_dir="$TEST_DIR/skill-structure"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if agent can understand skill structure
    if [ -f "skills/INDEX.md" ]; then
        log_info "INDEX.md exists"
        
        # Check if it lists skills
        if grep -q "zai-sandbox-rules" "skills/INDEX.md"; then
            log_info "INDEX.md lists zai-sandbox-rules"
        else
            log_fail "INDEX.md missing zai-sandbox-rules"
            return 1
        fi
        
        return 0
    else
        log_fail "INDEX.md not found"
        return 1
    fi
}

# ============================================================================
# Test 8: Agent can follow onboarding protocol
# ============================================================================

test_agent_can_follow_onboarding() {
    local test_dir="$TEST_DIR/onboarding"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if agent can follow onboarding protocol
    # Step 1: Read AGENT_RULES.md
    if [ -f "Z-ai-platform/AGENT_RULES.md" ]; then
        log_info "Step 1: AGENT_RULES.md exists"
    else
        log_fail "Step 1: AGENT_RULES.md not found"
        return 1
    fi
    
    # Step 2: Check standards
    if [ -d "Z-ai-platform/standards" ]; then
        log_info "Step 2: standards directory exists"
    else
        log_fail "Step 2: standards directory not found"
        return 1
    fi
    
    # Step 3: Check skills
    if [ -f "skills/INDEX.md" ]; then
        log_info "Step 3: skills INDEX.md exists"
    else
        log_fail "Step 3: skills INDEX.md not found"
        return 1
    fi
    
    # Step 4: Check guard
    if [ -d "Z-ai-platform/guard" ]; then
        log_info "Step 4: guard directory exists"
    else
        log_fail "Step 4: guard directory not found"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Test 9: Agent can detect sandbox rules
# ============================================================================

test_agent_can_detect_sandbox_rules() {
    local test_dir="$TEST_DIR/detect-rules"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if agent can detect sandbox rules
    if [ -f "skills/zai-sandbox-rules/SKILL.md" ]; then
        log_info "zai-sandbox-rules detected"
        
        # Check if it has trigger keywords
        if grep -q "bun run dev" "skills/zai-sandbox-rules/SKILL.md"; then
            log_info "Trigger keyword 'bun run dev' found"
        else
            log_fail "Trigger keyword 'bun run dev' not found"
            return 1
        fi
        
        if grep -q "EADDRINUSE" "skills/zai-sandbox-rules/SKILL.md"; then
            log_info "Trigger keyword 'EADDRINUSE' found"
        else
            log_fail "Trigger keyword 'EADDRINUSE' not found"
            return 1
        fi
        
        return 0
    else
        log_fail "zai-sandbox-rules not detected"
        return 1
    fi
}

# ============================================================================
# Test 10: Agent can understand priority order
# ============================================================================

test_agent_can_understand_priority() {
    local test_dir="$TEST_DIR/priority"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Bootstrap failed"
        return 1
    fi
    
    # Check if agent can understand priority order
    if [ -f "Z-ai-platform/AGENT_RULES.md" ]; then
        log_info "AGENT_RULES.md exists"
        
        # Check if it mentions priority
        if grep -q "Priority" "Z-ai-platform/AGENT_RULES.md"; then
            log_info "Priority order mentioned in AGENT_RULES.md"
        else
            log_fail "Priority order not mentioned in AGENT_RULES.md"
            return 1
        fi
        
        return 0
    else
        log_fail "AGENT_RULES.md not found"
        return 1
    fi
}

# ============================================================================
# Main test runner
# ============================================================================

main() {
    echo "=========================================="
    echo "Z-ai-platform Sandbox Behavior Tests"
    echo "=========================================="
    echo ""
    echo "These tests simulate what an agent would experience in the sandbox."
    echo ""
    echo "Platform directory: $PLATFORM_DIR"
    echo "Test directory: $TEST_DIR"
    echo ""
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Run tests
    run_test "Agent can read AGENT_RULES.md" test_agent_can_read_agent_rules
    run_test "Agent can load skills" test_agent_can_load_skills
    run_test "Agent can find zai-sandbox-rules" test_agent_can_find_sandbox_rules
    run_test "Agent can run verifiers" test_agent_can_run_verifiers
    run_test "Agent can check git status" test_agent_can_check_git_status
    run_test "Agent can read config" test_agent_can_read_config
    run_test "Agent can understand skill structure" test_agent_can_understand_skill_structure
    run_test "Agent can follow onboarding protocol" test_agent_can_follow_onboarding
    run_test "Agent can detect sandbox rules" test_agent_can_detect_sandbox_rules
    run_test "Agent can understand priority order" test_agent_can_understand_priority
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo ""
    echo "Tests run:    $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo "Tests skipped: $TESTS_SKIPPED"
    echo ""
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Run main function
main "$@"
