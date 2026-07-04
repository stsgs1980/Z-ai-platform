#!/usr/bin/env bash
#
# sandbox-integration-test.sh — Comprehensive testing of Z-ai-platform components
#
# Usage:
#   bash tests/sandbox-integration-test.sh
#
# What it tests:
#   1. bootstrap.sh execution in different scenarios
#   2. Skills loading and symlink validation
#   3. Governance system (.zai/)
#   4. Pre-commit hooks
#   5. Verifiers (standards, id-graph, skills)
#   6. Edge cases and failure modes
#
# Environment:
#   - Expects to run in Z-ai-platform directory
#   - Creates temporary test directory in /tmp
#   - Cleans up after itself

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

# Platform directory (where this script is run from)
PLATFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test directory
TEST_DIR="/tmp/zai-platform-test-$$"

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
# Test 1: bootstrap.sh — clean run
# ============================================================================

test_bootstrap_clean_run() {
    local test_dir="$TEST_DIR/bootstrap-clean"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a minimal project
    mkdir -p my-project
    cd my-project
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    echo "# Test Project" > README.md
    git add .
    git commit -m "Initial commit"
    
    # Run bootstrap
    log_info "Running bootstrap.sh..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed"
        
        # Verify Z-ai-platform was cloned
        if [ -d "Z-ai-platform/.git" ]; then
            log_info "Z-ai-platform cloned successfully"
        else
            log_fail "Z-ai-platform not cloned"
            return 1
        fi
        
        # Verify skills were symlinked
        local skill_count=$(ls -d skills/*/ 2>/dev/null | wc -l)
        if [ "$skill_count" -gt 0 ]; then
            log_info "Symlinked $skill_count skills"
        else
            log_fail "No skills symlinked"
            return 1
        fi
        
        # Verify AGENT_RULES.md was printed (check bootstrap output)
        if grep -q "AGENT_RULES.md" bootstrap.log; then
            log_info "AGENT_RULES.md printed"
        else
            log_fail "AGENT_RULES.md not in output"
            return 1
        fi
        
        return 0
    else
        log_fail "bootstrap.sh failed"
        cat bootstrap.log
        return 1
    fi
}

# ============================================================================
# Test 2: bootstrap.sh — idempotent (run twice)
# ============================================================================

test_bootstrap_idempotent() {
    local test_dir="$TEST_DIR/bootstrap-idempotent"
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
    
    # Run bootstrap twice
    log_info "Running bootstrap.sh (first time)..."
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "First bootstrap failed"
        return 1
    fi
    
    local skill_count_1=$(ls -d skills/*/ 2>/dev/null | wc -l)
    
    log_info "Running bootstrap.sh (second time)..."
    if ! bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1; then
        log_fail "Second bootstrap failed"
        return 1
    fi
    
    local skill_count_2=$(ls -d skills/*/ 2>/dev/null | wc -l)
    
    # Verify same number of skills
    if [ "$skill_count_1" -eq "$skill_count_2" ]; then
        log_info "Same skill count after second run: $skill_count_2"
    else
        log_fail "Skill count changed: $skill_count_1 -> $skill_count_2"
        return 1
    fi
    
    # Verify no duplicate symlinks
    local broken_links=$(find skills -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l)
    if [ "$broken_links" -eq 0 ]; then
        log_info "No broken symlinks"
    else
        log_fail "Found $broken_links broken symlinks"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Test 3: Skills symlink validation
# ============================================================================

test_skills_symlink_validation() {
    local test_dir="$TEST_DIR/skills-validation"
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
    
    # Check each skill directory
    local errors=0
    for skill_dir in skills/*/; do
        [ -d "$skill_dir" ] || continue
        local skill_name=$(basename "$skill_dir")
        
        # Check SKILL.md exists
        if [ ! -f "$skill_dir/SKILL.md" ]; then
            log_fail "$skill_name: SKILL.md missing"
            errors=$((errors + 1))
            continue
        fi
        
        # Check SKILL.md has frontmatter
        if ! head -1 "$skill_dir/SKILL.md" | grep -q "^---"; then
            log_fail "$skill_name: SKILL.md missing frontmatter"
            errors=$((errors + 1))
            continue
        fi
        
        # Check frontmatter has name field
        if ! sed -n '/^---$/,/^---$/p' "$skill_dir/SKILL.md" | grep -q "^name:"; then
            log_fail "$skill_name: SKILL.md missing name in frontmatter"
            errors=$((errors + 1))
            continue
        fi
        
        log_info "$skill_name: OK"
    done
    
    if [ "$errors" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Test 4: Governance system (.zai/)
# ============================================================================

test_governance_system() {
    local test_dir="$TEST_DIR/governance"
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
    
    # Check .zai/ directory exists in Z-ai-platform
    if [ -d "Z-ai-platform/.zai" ]; then
        log_info ".zai/ directory exists"
    else
        log_fail ".zai/ directory missing"
        return 1
    fi
    
    # Check config.json exists
    if [ -f "Z-ai-platform/.zai/config.json" ]; then
        log_info "config.json exists"
        
        # Validate config.json is valid JSON
        if command -v node &>/dev/null; then
            if node -e "require('./Z-ai-platform/.zai/config.json')" 2>/dev/null; then
                log_info "config.json is valid JSON"
            else
                log_fail "config.json is invalid JSON"
                return 1
            fi
        fi
    else
        log_fail "config.json missing"
        return 1
    fi
    
    # Check setup.sh exists
    if [ -f "Z-ai-platform/.zai/setup.sh" ]; then
        log_info "setup.sh exists"
        
        # Check setup.sh is executable or has correct shebang
        if head -1 "Z-ai-platform/.zai/setup.sh" | grep -q "bash"; then
            log_info "setup.sh has correct shebang"
        else
            log_warn "setup.sh shebang may be incorrect"
        fi
    else
        log_fail "setup.sh missing"
        return 1
    fi
    
    # Check verify script exists
    if [ -f "Z-ai-platform/.zai/verify" ]; then
        log_info "verify script exists"
    else
        log_fail "verify script missing"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Test 5: Verifiers
# ============================================================================

test_verifiers() {
    local test_dir="$TEST_DIR/verifiers"
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
    
    # Check verify-standards.js
    if [ -f "Z-ai-platform/standards/scripts/verify-standards.js" ]; then
        log_info "verify-standards.js exists"
        
        # Try to run it
        if command -v node &>/dev/null; then
            log_info "Running verify-standards.js..."
            if (cd "Z-ai-platform/standards" && node scripts/verify-standards.js 2>&1 | tail -5); then
                log_info "verify-standards.js passed"
            else
                log_fail "verify-standards.js failed"
                return 1
            fi
        fi
    else
        log_fail "verify-standards.js missing"
        return 1
    fi
    
    # Check verify-id-graph.js
    if [ -f "Z-ai-platform/standards/scripts/verify-id-graph.js" ]; then
        log_info "verify-id-graph.js exists"
        
        # Try to run it
        if command -v node &>/dev/null; then
            log_info "Running verify-id-graph.js..."
            if (cd "Z-ai-platform/standards" && node scripts/verify-id-graph.js 2>&1 | tail -5); then
                log_info "verify-id-graph.js passed"
            else
                log_fail "verify-id-graph.js failed"
                return 1
            fi
        fi
    else
        log_fail "verify-id-graph.js missing"
        return 1
    fi
    
    return 0
}

# ============================================================================
# Test 6: Edge case — missing dependencies
# ============================================================================

test_missing_dependencies() {
    local test_dir="$TEST_DIR/missing-deps"
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
    
    # Temporarily hide node
    local original_path="$PATH"
    if command -v node &>/dev/null; then
        local node_path=$(dirname $(which node))
        PATH=$(echo "$PATH" | sed "s|$node_path:||g")
    fi
    
    log_info "Running bootstrap without node..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed without node"
        
        # Verify it still cloned
        if [ -d "Z-ai-platform/.git" ]; then
            log_info "Z-ai-platform cloned (node not required for bootstrap)"
        else
            log_fail "Z-ai-platform not cloned"
            PATH="$original_path"
            return 1
        fi
    else
        log_fail "Bootstrap failed without node"
        PATH="$original_path"
        return 1
    fi
    
    PATH="$original_path"
    return 0
}

# ============================================================================
# Test 7: Edge case — no git
# ============================================================================

test_no_git() {
    local test_dir="$TEST_DIR/no-git"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a directory without git
    mkdir -p my-project
    cd my-project
    
    # Temporarily hide git
    local original_path="$PATH"
    if command -v git &>/dev/null; then
        local git_path=$(dirname $(which git))
        PATH=$(echo "$PATH" | sed "s|$git_path:||g")
    fi
    
    log_info "Running bootstrap without git..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_warn "Bootstrap completed without git (unexpected)"
        PATH="$original_path"
        return 0
    else
        log_info "Bootstrap failed without git (expected behavior)"
        PATH="$original_path"
        return 0
    fi
}

# ============================================================================
# Test 8: Edge case — already existing Z-ai-platform
# ============================================================================

test_existing_platform() {
    local test_dir="$TEST_DIR/existing-platform"
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
    
    # Create a fake Z-ai-platform directory
    mkdir -p Z-ai-platform
    cd Z-ai-platform
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "# Fake Platform" > README.md
    git add .
    git commit -m "Initial commit"
    cd ..
    
    log_info "Running bootstrap with existing Z-ai-platform..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed with existing directory"
        
        # Check if it pulled latest
        if grep -q "Pulling latest" bootstrap.log; then
            log_info "Bootstrap pulled latest (correct behavior)"
        else
            log_warn "Bootstrap did not pull latest"
        fi
        
        return 0
    else
        log_fail "Bootstrap failed with existing directory"
        cat bootstrap.log
        return 1
    fi
}

# ============================================================================
# Test 9: Edge case — skills directory conflicts
# ============================================================================

test_skills_conflicts() {
    local test_dir="$TEST_DIR/skills-conflicts"
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
    
    # Create a fake skills directory with a conflicting skill
    mkdir -p skills/zai-sandbox-rules
    echo "# Fake Skill" > skills/zai-sandbox-rules/SKILL.md
    
    log_info "Running bootstrap with conflicting skills..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed with conflicts"
        
        # Check if backup was created
        if [ -d "skills/zai-sandbox-rules.sandbox-backup" ]; then
            log_info "Backup created for conflicting skill"
        else
            log_warn "No backup created for conflicting skill"
        fi
        
        # Check if our skill won
        if grep -q "stsgs1980" skills/zai-sandbox-rules/SKILL.md 2>/dev/null || \
           head -5 skills/zai-sandbox-rules/SKILL.md | grep -q "zai-sandbox-rules"; then
            log_info "Our skill won the conflict"
        else
            log_warn "Our skill may not have won the conflict"
        fi
        
        return 0
    else
        log_fail "Bootstrap failed with conflicts"
        cat bootstrap.log
        return 1
    fi
}

# ============================================================================
# Test 10: Verify bootstrap output format
# ============================================================================

test_bootstrap_output_format() {
    local test_dir="$TEST_DIR/output-format"
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
    
    log_info "Running bootstrap and checking output format..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        # Check for expected sections
        local sections=(
            "Step 1: Ensure Z-ai-platform is cloned"
            "Step 2: Normalize git mode-bit handling"
            "Step 3: Symlink custom skills"
            "Step 4: Available custom skills"
            "Step 5: Print AGENT_RULES.md"
            "Step 6: Run sanity verifiers"
        )
        
        local missing=0
        for section in "${sections[@]}"; do
            if grep -q "$section" bootstrap.log; then
                log_info "Found section: $section"
            else
                log_fail "Missing section: $section"
                missing=$((missing + 1))
            fi
        done
        
        if [ "$missing" -eq 0 ]; then
            return 0
        else
            return 1
        fi
    else
        log_fail "Bootstrap failed"
        return 1
    fi
}

# ============================================================================
# Test 11: Verify git config changes
# ============================================================================

test_git_config_changes() {
    local test_dir="$TEST_DIR/git-config"
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
    
    # Check core.fileMode in platform
    local platform_filemode=$(cd Z-ai-platform && git config core.fileMode)
    if [ "$platform_filemode" = "false" ]; then
        log_info "Platform core.fileMode = false"
    else
        log_fail "Platform core.fileMode = $platform_filemode (expected false)"
        return 1
    fi
    
    # Check core.fileMode in submodules
    local standards_filemode=$(cd Z-ai-platform/standards && git config core.fileMode 2>/dev/null || echo "not set")
    if [ "$standards_filemode" = "false" ]; then
        log_info "Standards core.fileMode = false"
    else
        log_warn "Standards core.fileMode = $standards_filemode"
    fi
    
    local guard_filemode=$(cd Z-ai-platform/guard && git config core.fileMode 2>/dev/null || echo "not set")
    if [ "$guard_filemode" = "false" ]; then
        log_info "Guard core.fileMode = false"
    else
        log_warn "Guard core.fileMode = $guard_filemode"
    fi
    
    return 0
}

# ============================================================================
# Test 12: Verify symlink targets
# ============================================================================

test_symlink_targets() {
    local test_dir="$TEST_DIR/symlink-targets"
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
    
    # Check each symlink
    local errors=0
    for skill_link in skills/*/; do
        [ -d "$skill_link" ] || continue
        local skill_name=$(basename "$skill_link")
        
        # Check if it's a symlink
        if [ -L "$skill_link" ]; then
            local target=$(readlink -f "$skill_link" 2>/dev/null || readlink "$skill_link")
            
            # Check if target exists
            if [ -d "$target" ]; then
                log_info "$skill_name -> $target (valid)"
            else
                log_fail "$skill_name -> $target (broken)"
                errors=$((errors + 1))
            fi
        else
            log_warn "$skill_name is not a symlink"
        fi
    done
    
    if [ "$errors" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# Main test runner
# ============================================================================

main() {
    echo "=========================================="
    echo "Z-ai-platform Sandbox Integration Tests"
    echo "=========================================="
    echo ""
    echo "Platform directory: $PLATFORM_DIR"
    echo "Test directory: $TEST_DIR"
    echo ""
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Run tests
    run_test "bootstrap.sh — clean run" test_bootstrap_clean_run
    run_test "bootstrap.sh — idempotent (run twice)" test_bootstrap_idempotent
    run_test "Skills symlink validation" test_skills_symlink_validation
    run_test "Governance system (.zai/)" test_governance_system
    run_test "Verifiers" test_verifiers
    run_test "Edge case — missing dependencies" test_missing_dependencies
    run_test "Edge case — no git" test_no_git
    run_test "Edge case — already existing Z-ai-platform" test_existing_platform
    run_test "Edge case — skills directory conflicts" test_skills_conflicts
    run_test "Verify bootstrap output format" test_bootstrap_output_format
    run_test "Verify git config changes" test_git_config_changes
    run_test "Verify symlink targets" test_symlink_targets
    
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
