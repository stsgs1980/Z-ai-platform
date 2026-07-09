#!/usr/bin/env bash
#
# sandbox-integration-test.sh — Test Z-ai-platform in sandbox environment
#
# Usage:
#   bash tests/sandbox-integration-test.sh
#
# What it tests:
#   1. Bootstrap has already run (skills symlinked)
#   2. Skills are valid and accessible
#   3. Governance system (.zai/) exists and works
#   4. Verifiers pass
#   5. Agent can read AGENT_RULES.md
#   6. Git config is correct
#
# Environment:
#   - Expects to run AFTER bootstrap.sh has been executed
#   - Working directory: /home/z/my-project/Z-ai-platform
#   - Does NOT clone from GitHub (uses existing installation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"

# Platform directory
PLATFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sandbox skills directory
SANDBOX_SKILLS_DIR="/home/z/my-project/skills"

test_platform_directory_exists() {
    if [ -d "$PLATFORM_DIR" ]; then
        log_info "Platform directory exists: $PLATFORM_DIR"
        return 0
    else
        log_fail "Platform directory not found: $PLATFORM_DIR"
        return 1
    fi
}

test_git_repository_is_valid() {
    if [ ! -d "$PLATFORM_DIR/.git" ]; then
        log_fail "Not a git repository: $PLATFORM_DIR"
        return 1
    fi

    cd "$PLATFORM_DIR"
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_fail "Git repository corrupted"
        return 1
    fi

    log_info "Git repository is valid"
    return 0
}

test_git_config_correct() {
    cd "$PLATFORM_DIR"
    local email=$(git config user.email)
    local name=$(git config user.name)

    if [ -z "$email" ] || [ -z "$name" ]; then
        log_fail "Git config incomplete: email='$email', name='$name'"
        return 1
    fi

    log_info "Git config: $name <$email>"
    return 0
}

test_governance_system_exists() {
    local zai_dir="$PLATFORM_DIR/.zai"

    if [ ! -d "$zai_dir" ]; then
        log_fail "Governance system not found: $zai_dir"
        return 1
    fi

    log_info "Governance system exists: $zai_dir"
    return 0
}

test_agent_rules_readable() {
    local agent_rules="$PLATFORM_DIR/AGENT_RULES.md"

    if [ ! -f "$agent_rules" ]; then
        log_fail "AGENT_RULES.md not found: $agent_rules"
        return 1
    fi

    if [ ! -r "$agent_rules" ]; then
        log_fail "AGENT_RULES.md not readable: $agent_rules"
        return 1
    fi

    log_info "AGENT_RULES.md is readable"
    return 0
}

test_skills_symlinked() {
    if [ ! -L "$SANDBOX_SKILLS_DIR" ]; then
        log_fail "Skills symlink not found: $SANDBOX_SKILLS_DIR"
        return 1
    fi

    if [ ! -d "$SANDBOX_SKILLS_DIR" ]; then
        log_fail "Skills symlink target not accessible"
        return 1
    fi

    log_info "Skills symlinked: $SANDBOX_SKILLS_DIR -> $(readlink -f "$SANDBOX_SKILLS_DIR")"
    return 0
}

test_verifiers_pass() {
    cd "$PLATFORM_DIR/standards"

    log_info "Running verify-standards.js..."
    if ! node scripts/verify-standards.js; then
        log_fail "verify-standards.js failed"
        return 1
    fi

    log_info "Running verify-id-graph.js..."
    if ! node scripts/verify-id-graph.js; then
        log_fail "verify-id-graph.js failed"
        return 1
    fi

    log_info "All verifiers passed"
    return 0
}

run_all_tests() {
    run_test "Platform directory exists" test_platform_directory_exists
    run_test "Git repository is valid" test_git_repository_is_valid
    run_test "Git config correct" test_git_config_correct
    run_test "Governance system exists" test_governance_system_exists
    run_test "AGENT_RULES.md readable" test_agent_rules_readable
    run_test "Skills symlinked" test_skills_symlinked
    run_test "Verifiers pass" test_verifiers_pass

    print_test_summary
}

main() {
    log_info "Starting sandbox integration tests..."
    log_info "Platform directory: $PLATFORM_DIR"
    log_info "Sandbox skills: $SANDBOX_SKILLS_DIR"

    run_all_tests

    log_info "All tests passed!"
}

main "$@"