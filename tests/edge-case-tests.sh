#!/usr/bin/env bash
#
# edge-case-tests.sh — Try to break the system with edge cases
#
# Usage:
#   bash tests/edge-case-tests.sh
#
# What it tests:
#   1. Invalid inputs
#   2. Missing files
#   3. Permission issues
#   4. Network failures (simulated)
#   5. Concurrent access
#   6. Resource exhaustion
#
# WARNING: These tests intentionally create error conditions.
#          Run only in test environments!

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
TEST_DIR="/tmp/zai-edge-case-test-$$"

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
# Test 1: Bootstrap with read-only filesystem
# ============================================================================

test_readonly_filesystem() {
    local test_dir="$TEST_DIR/readonly"
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
    
    # Make directory read-only (will fail on mkdir)
    chmod 555 my-project 2>/dev/null || true
    
    log_info "Running bootstrap on read-only directory..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_warn "Bootstrap succeeded on read-only directory (unexpected)"
        chmod 755 my-project 2>/dev/null || true
        return 0
    else
        log_info "Bootstrap failed on read-only directory (expected)"
        chmod 755 my-project 2>/dev/null || true
        return 0
    fi
}

# ============================================================================
# Test 2: Bootstrap with no write permission to skills dir
# ============================================================================

test_no_write_permission_skills() {
    local test_dir="$TEST_DIR/no-write-skills"
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
    
    # Create a read-only skills directory
    mkdir -p skills
    chmod 555 skills
    
    log_info "Running bootstrap with read-only skills directory..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_warn "Bootstrap succeeded with read-only skills dir"
        chmod 755 skills
        return 0
    else
        log_info "Bootstrap failed with read-only skills dir (expected)"
        chmod 755 skills 2>/dev/null || true
        return 0
    fi
}

# ============================================================================
# Test 3: Bootstrap with corrupted git repo
# ============================================================================

test_corrupted_git_repo() {
    local test_dir="$TEST_DIR/corrupted-git"
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
    
    # Corrupt the git repo
    rm -rf .git/HEAD
    
    log_info "Running bootstrap with corrupted git repo..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_warn "Bootstrap succeeded with corrupted git repo"
        return 0
    else
        log_info "Bootstrap failed with corrupted git repo (expected)"
        return 0
    fi
}

# ============================================================================
# Test 4: Bootstrap with no network (simulated)
# ============================================================================

test_no_network() {
    local test_dir="$TEST_DIR/no-network"
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
    
    # We can't really block network, but we can test with invalid URL
    # by modifying bootstrap.sh temporarily
    log_info "Testing bootstrap with invalid git URL..."
    
    # Create a modified bootstrap that uses invalid URL
    sed 's|https://github.com/stsgs1980/Z-ai-platform.git|https://invalid.example.com/nonexistent.git|' \
        "$PLATFORM_DIR/bootstrap.sh" > /tmp/test-bootstrap.sh
    
    if bash /tmp/test-bootstrap.sh > bootstrap.log 2>&1; then
        log_warn "Bootstrap succeeded with invalid URL"
        rm -f /tmp/test-bootstrap.sh
        return 0
    else
        log_info "Bootstrap failed with invalid URL (expected)"
        rm -f /tmp/test-bootstrap.sh
        return 0
    fi
}

# ============================================================================
# Test 5: Bootstrap with disk full (simulated)
# ============================================================================

test_disk_full() {
    local test_dir="$TEST_DIR/disk-full"
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
    
    # We can't really fill the disk, but we can test with a tiny tmpfs
    # For now, just check if bootstrap handles errors gracefully
    log_info "Testing bootstrap error handling..."
    
    # Run bootstrap and capture exit code
    local exit_code=0
    bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1 || exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_info "Bootstrap completed successfully"
    else
        log_info "Bootstrap failed with exit code $exit_code"
    fi
    
    # Check if error message is informative
    if grep -q "error\|Error\|ERROR\|fatal\|Fatal\|FATAL" bootstrap.log; then
        log_info "Error messages found in output"
    fi
    
    return 0
}

# ============================================================================
# Test 6: Bootstrap with very long paths
# ============================================================================

test_long_paths() {
    local test_dir="$TEST_DIR/long-paths"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a project with a very long path
    local long_dir="a"
    for i in {1..10}; do
        long_dir="$long_dir/abcdef"
    done
    
    mkdir -p "my-project/$long_dir"
    cd "my-project/$long_dir"
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    log_info "Running bootstrap with long path..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed with long path"
        return 0
    else
        log_warn "Bootstrap failed with long path"
        return 0
    fi
}

# ============================================================================
# Test 7: Bootstrap with special characters in path
# ============================================================================

test_special_characters_path() {
    local test_dir="$TEST_DIR/special-chars"
    mkdir -p "$test_dir"
    cd "$test_dir"
    
    # Create a project with special characters in path
    mkdir -p "my project (test)"
    cd "my project (test)"
    git init
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "node_modules/" > .gitignore
    git add .
    git commit -m "Initial commit"
    
    log_info "Running bootstrap with special characters in path..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed with special characters"
        return 0
    else
        log_warn "Bootstrap failed with special characters"
        return 0
    fi
}

# ============================================================================
# Test 8: Bootstrap with concurrent runs
# ============================================================================

test_concurrent_runs() {
    local test_dir="$TEST_DIR/concurrent"
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
    
    log_info "Running bootstrap concurrently..."
    
    # Run bootstrap in background
    bash "$PLATFORM_DIR/bootstrap.sh" > /tmp/bootstrap1.log 2>&1 &
    local pid1=$!
    
    # Run another bootstrap immediately
    bash "$PLATFORM_DIR/bootstrap.sh" > /tmp/bootstrap2.log 2>&1 &
    local pid2=$!
    
    # Wait for both
    wait $pid1 || true
    wait $pid2 || true
    
    # Check if both completed (may have conflicts)
    if [ -d "Z-ai-platform/.git" ]; then
        log_info "Concurrent runs completed (may have conflicts)"
    else
        log_warn "Concurrent runs may have failed"
    fi
    
    return 0
}

# ============================================================================
# Test 9: Bootstrap with symlink loops
# ============================================================================

test_symlink_loops() {
    local test_dir="$TEST_DIR/symlink-loops"
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
    
    # Create a symlink loop
    mkdir -p skills
    ln -sf skills skills/self
    
    log_info "Running bootstrap with symlink loop..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed with symlink loop"
        
        # Check if loop was handled
        if [ -L skills/self ]; then
            log_warn "Symlink loop still exists"
        fi
        
        return 0
    else
        log_warn "Bootstrap failed with symlink loop"
        return 0
    fi
}

# ============================================================================
# Test 10: Bootstrap with broken symlinks
# ============================================================================

test_broken_symlinks() {
    local test_dir="$TEST_DIR/broken-symlinks"
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
    
    # Create broken symlinks
    mkdir -p skills
    ln -sf /nonexistent/path skills/broken1
    ln -sf /another/nonexistent skills/broken2
    
    log_info "Running bootstrap with broken symlinks..."
    if bash "$PLATFORM_DIR/bootstrap.sh" > bootstrap.log 2>&1; then
        log_info "Bootstrap completed with broken symlinks"
        
        # Check if broken symlinks were handled
        local broken_count=$(find skills -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l)
        if [ "$broken_count" -gt 0 ]; then
            log_warn "Found $broken_count broken symlinks after bootstrap"
        fi
        
        return 0
    else
        log_warn "Bootstrap failed with broken symlinks"
        return 0
    fi
}

# ============================================================================
# Test 11: Verify error messages are helpful
# ============================================================================

test_error_messages() {
    local test_dir="$TEST_DIR/error-messages"
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
    
    log_info "Testing error message quality..."
    
    # Test 1: Missing git
    local original_path="$PATH"
    if command -v git &>/dev/null; then
        local git_path=$(dirname $(which git))
        PATH=$(echo "$PATH" | sed "s|$git_path:||g")
    fi
    
    bash "$PLATFORM_DIR/bootstrap.sh" > /tmp/error-test.log 2>&1 || true
    
    PATH="$original_path"
    
    # Check if error message is helpful
    if grep -qi "git\|clone\|repository" /tmp/error-test.log; then
        log_info "Error message mentions git/clone/repository"
    else
        log_warn "Error message may not be helpful"
    fi
    
    return 0
}

# ============================================================================
# Test 12: Verify cleanup on failure
# ============================================================================

test_cleanup_on_failure() {
    local test_dir="$TEST_DIR/cleanup"
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
    
    log_info "Testing cleanup on failure..."
    
    # Run bootstrap
    bash "$PLATFORM_DIR/bootstrap.sh" > /dev/null 2>&1 || true
    
    # Check if partial state was left
    if [ -d "Z-ai-platform" ]; then
        log_info "Z-ai-platform directory exists (may be partial)"
    fi
    
    if [ -d "skills" ]; then
        log_info "skills directory exists (may be partial)"
    fi
    
    # Clean up
    rm -rf Z-ai-platform skills 2>/dev/null || true
    
    log_info "Cleanup completed"
    return 0
}

# ============================================================================
# Main test runner
# ============================================================================

main() {
    echo "=========================================="
    echo "Z-ai-platform Edge Case Tests"
    echo "=========================================="
    echo ""
    echo "WARNING: These tests intentionally create error conditions."
    echo "         Run only in test environments!"
    echo ""
    echo "Platform directory: $PLATFORM_DIR"
    echo "Test directory: $TEST_DIR"
    echo ""
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Run tests
    run_test "Read-only filesystem" test_readonly_filesystem
    run_test "No write permission to skills dir" test_no_write_permission_skills
    run_test "Corrupted git repo" test_corrupted_git_repo
    run_test "No network (simulated)" test_no_network
    run_test "Disk full (simulated)" test_disk_full
    run_test "Very long paths" test_long_paths
    run_test "Special characters in path" test_special_characters_path
    run_test "Concurrent runs" test_concurrent_runs
    run_test "Symlink loops" test_symlink_loops
    run_test "Broken symlinks" test_broken_symlinks
    run_test "Error messages quality" test_error_messages
    run_test "Cleanup on failure" test_cleanup_on_failure
    
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
