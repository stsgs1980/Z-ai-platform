# Z-ai-platform Test Report

**Date:** 2026-07-04
**Tester:** Automated test suite
**Environment:** Windows 11, WSL2, Bash

## Executive Summary

Tests revealed a **critical bug** in `bootstrap.sh` that prevents it from working in bash environments with CRLF line endings. This explains why the sandbox session broke.

## Critical Issues

### CRITICAL-001: bootstrap.sh has CRLF line endings

**Severity:** CRITICAL
**Component:** `bootstrap.sh`
**Impact:** Bootstrap script fails to execute in bash

**Evidence:**

```
/mnt/c/Users/stsgr/My Projects/Z-ai-platform/bootstrap.sh: line 21: $'\r': command not found
/mnt/c/Users/stsgr/My Projects/Z-ai-platform/bootstrap.sh: line 22: set: pipefail: invalid option name
```

**Root Cause:**

- `bootstrap.sh` has Windows-style CRLF (`\r\n`) line endings
- Bash expects Unix-style LF (`\n`) line endings
- The `\r` character is interpreted as part of the command, causing syntax errors

**Impact:**

- Bootstrap fails immediately at `set -euo pipefail` (line 22)
- No skills are symlinked
- No AGENT_RULES.md is printed
- No verifiers are run
- Agent cannot access custom skills

**Reproduction:**

```bash
# Any attempt to run bootstrap.sh will fail
bash bootstrap.sh
```

**Fix:**

```bash
# Convert CRLF to LF
sed -i 's/\r$//' bootstrap.sh

# Or using dos2unix
dos2unix bootstrap.sh
```

**Verification:**

```bash
# After fix
file bootstrap.sh  # Should show "ASCII text" or "UTF-8 text"
bash -n bootstrap.sh  # Should pass syntax check
```

## Test Results

### Integration Tests

| Test                       | Result | Notes             |
| -------------------------- | ------ | ----------------- |
| bootstrap.sh — clean run   | FAIL   | CRLF issue        |
| bootstrap.sh — idempotent  | FAIL   | CRLF issue        |
| Skills symlink validation  | FAIL   | Bootstrap failed  |
| Governance system (.zai/)  | FAIL   | Bootstrap failed  |
| Verifiers                  | FAIL   | Bootstrap failed  |
| Missing dependencies       | FAIL   | Bootstrap failed  |
| No git                     | PASS   | Expected behavior |
| Existing Z-ai-platform     | FAIL   | CRLF issue        |
| Skills directory conflicts | FAIL   | CRLF issue        |
| Bootstrap output format    | FAIL   | Bootstrap failed  |
| Git config changes         | FAIL   | Bootstrap failed  |
| Symlink targets            | FAIL   | Bootstrap failed  |

**Summary:** 1/12 tests passed (8%)

### Edge Case Tests

_Not run due to bootstrap failure in integration tests._

### Behavior Tests

_Not run due to bootstrap failure in integration tests._

## Additional Findings

### FINDING-001: Multiple shell scripts have CRLF

**Affected files:**

- `bootstrap.sh` - CRLF
- `save-work.sh` - CRLF
- `status.sh` - CRLF
- `.husky/pre-commit` - CRLF
- `.husky/pre-push` - CRLF

**Not affected:**

- `.husky/commit-msg` - LF (correct)

**Impact:** All these scripts will fail in bash environments that expect LF line endings.

### FINDING-002: No line ending enforcement

The project lacks `.gitattributes` or similar configuration to enforce consistent line endings. This allows CRLF to creep in on Windows.

### FINDING-003: No syntax validation in CI

The CI pipeline doesn't check shell script syntax. A simple `bash -n bootstrap.sh` would catch this issue before merge.

### FINDING-004: Inconsistent line endings across hooks

- `.husky/pre-commit` has CRLF
- `.husky/commit-msg` has LF
- `.husky/pre-push` has CRLF

This suggests different tools or processes created these files with different line endings.

## Recommendations

### Immediate (P0)

1. **Fix all CRLF files**

   ```bash
   # Fix bootstrap.sh
   sed -i 's/\r$//' bootstrap.sh

   # Fix save-work.sh
   sed -i 's/\r$//' save-work.sh

   # Fix status.sh
   sed -i 's/\r$//' status.sh

   # Fix husky hooks
   sed -i 's/\r$//' .husky/pre-commit
   sed -i 's/\r$//' .husky/pre-push

   # Commit all fixes
   git add bootstrap.sh save-work.sh status.sh .husky/pre-commit .husky/pre-push
   git commit -m "fix: convert shell scripts from CRLF to LF"
   ```

2. **Verify all .sh files have LF**
   ```bash
   # Find all .sh files with CRLF
   find . -name "*.sh" -type f -exec sh -c 'if cat -A "$1" | grep -q $'\r''; then echo "CRLF: $1"; fi' _ {} \;

   # Fix them all
   find . -name "*.sh" -type f -exec sed -i 's/\r$//' {} \;
   ```

### Short-term (P1)

3. **Add .gitattributes** (CRITICAL - prevents future CRLF issues)

   ```
   # Enforce LF for shell scripts
   *.sh text eol=lf
   *.bash text eol=lf

   # Enforce LF for husky hooks
   .husky/* text eol=lf

   # Enforce LF for JavaScript/TypeScript
   *.js text eol=lf
   *.ts text eol=lf
   *.jsx text eol=lf
   *.tsx text eol=lf

   # Enforce LF for JSON
   *.json text eol=lf

   # Enforce LF for YAML
   *.yml text eol=lf
   *.yaml text eol=lf

   # Enforce LF for Markdown
   *.md text eol=lf

   # Enforce LF for CSS
   *.css text eol=lf

   # Enforce LF for HTML
   *.html text eol=lf
   ```

4. **Add syntax check to CI**
   ```yaml
   - name: Check shell syntax
     run: |
       bash -n bootstrap.sh
       bash -n save-work.sh
       bash -n status.sh
       bash -n .husky/pre-commit
       bash -n .husky/pre-push
       bash -n .husky/commit-msg
   ```

### Medium-term (P2)

5. **Add pre-commit hook for line endings**

   ```bash
   # In .husky/pre-commit
   if git diff --cached --name-only | xargs grep -l $'\r' 2>/dev/null; then
     echo "ERROR: CRLF detected in staged files"
     echo "Fix with: sed -i 's/\r$//' <file>"
     exit 1
   fi
   ```

6. **Document line ending policy**
   - Add to CONTRIBUTING.md
   - Add to AGENT_RULES.md

7. **Add .editorconfig** (optional but helpful)
   ```
   root = true

   [*]
   end_of_line = lf
   insert_final_newline = true
   trim_trailing_whitespace = true

   [*.md]
   trim_trailing_whitespace = false
   ```

## Test Artifacts

- `tests/sandbox-integration-test.sh` - Integration test suite
- `tests/edge-case-tests.sh` - Edge case test suite
- `tests/sandbox-behavior-test.sh` - Behavior test suite
- `tests/README.md` - Test documentation

## Next Steps

1. Fix CRITICAL-001 (bootstrap.sh CRLF)
2. Re-run all tests
3. Implement P1 recommendations
4. Verify fix in actual Z.ai sandbox
