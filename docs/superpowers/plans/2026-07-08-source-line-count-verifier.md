# verify-source-line-count.js Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a source file line count verifier implementing RULE-MONOLITH-012 matrix and a Husky pre-commit hook to block commits with oversized files.

**Architecture:** Standalone Node.js script in `standards/scripts/` following the same pattern as verify-skills.js and verify-standards.js. Pre-commit hook via Husky calls the script without `--soft` for hard-fail enforcement.

**Tech Stack:** Node.js (ES modules), Husky 9.x

## Global Constraints

- Node.js >= 20.12.0 (from package.json engines)
- Husky 9.x (from package.json devDependencies)
- No external dependencies (pure Node.js, same as existing verifiers)
- Line count convention: `wc -l` equivalent (split on `\n`, subtract 1 if ends with `\n`)
- RULE-MONOLITH-012 section 4.18.1 is the canonical source for limits

---

## File Structure

| File                                            | Action | Responsibility                          |
| ----------------------------------------------- | ------ | --------------------------------------- |
| `standards/scripts/verify-source-line-count.js` | CREATE | Main verifier script (~300 lines)       |
| `.husky/pre-commit`                             | CREATE | Pre-commit hook that calls the verifier |

---

### Task 1: Create verify-source-line-count.js — scaffold and CLI parsing

**Files:**

- Create: `standards/scripts/verify-source-line-count.js`

**Interfaces:**

- Consumes: `process.argv` for CLI options
- Produces: exit code 0/1/2, JSON or human-readable output

- [ ] **Step 1: Create the script file with header, constants, and CLI parsing**

```javascript
#!/usr/bin/env node
/**
 * ============================================================================
 * verify-source-line-count.js — Anti-monolith Source File Verifier v1.0.0
 * ============================================================================
 *
 * ID: TOOL-VERIFY-SRC-001
 * Implements: RULE-MONOLITH-012 section 4.18.1 (file size by category)
 *
 * PURPOSE
 *   Enforces line-count limits per file category defined in RULE-MONOLITH-012.
 *   Scans the entire project (with exclusions) and fails if any file exceeds
 *   its category's hard limit.
 *
 * EXIT CODES
 *   0 — all files within limits (or --soft mode)
 *   1 — at least one file exceeds its limit
 *   2 — configuration error
 *
 * USAGE
 *   node standards/scripts/verify-source-line-count.js             # human-readable
 *   node standards/scripts/verify-source-line-count.js --json      # CI-friendly
 *   node standards/scripts/verify-source-line-count.js --soft      # warn-only
 *   node standards/scripts/verify-source-line-count.js --help      # show help
 *
 * ============================================================================
 */

"use strict";

const fs = require("fs");
const path = require("path");

const VERSION = "1.0.0";
const EFFECTIVE_DATE = "2026-07-08";

// ============================================================================
// CLI PARSING
// ============================================================================

function parseArgs(argv) {
  const opts = { json: false, help: false, root: null, soft: false };
  for (const arg of argv.slice(2)) {
    if (arg === "--help" || arg === "-h") opts.help = true;
    else if (arg === "--json") opts.json = true;
    else if (arg === "--soft") opts.soft = true;
    else if (arg.startsWith("--root=")) opts.root = arg.slice(7);
    else {
      console.error(`Unknown argument: ${arg}`);
      process.exit(2);
    }
  }
  return opts;
}

function showHelp() {
  console.log(`
verify-source-line-count.js v${VERSION} — Anti-monolith Source File Verifier

Usage:
  node standards/scripts/verify-source-line-count.js [options]

Options:
  --json         Output JSON (for CI)
  --soft         Warn-only mode (exit 0 even on violations)
  --root=<path>  Override project root (auto-detected otherwise)
  --help, -h     Show this help

Implements: RULE-MONOLITH-012 section 4.18.1 (file size by category)

Exit codes:
  0 — all files within limits (or soft mode)
  1 — at least one file exceeds its limit
  2 — configuration error
`);
}

// ============================================================================
// PROJECT ROOT DISCOVERY
// ============================================================================

function discoverProjectRoot() {
  if (process.env.ZAI_PLATFORM_ROOT && fs.existsSync(process.env.ZAI_PLATFORM_ROOT)) {
    return process.env.ZAI_PLATFORM_ROOT;
  }
  let dir = __dirname;
  for (let i = 0; i < 10; i++) {
    if (fs.existsSync(path.join(dir, "package.json"))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return null;
}

// ============================================================================
// MAIN
// ============================================================================

function main() {
  const opts = parseArgs(process.argv);
  if (opts.help) {
    showHelp();
    process.exit(0);
  }

  const projectRoot = opts.root || discoverProjectRoot();
  if (!projectRoot) {
    console.error("[verify-source-line-count] Could not discover project root.");
    console.error("[verify-source-line-count] Set ZAI_PLATFORM_ROOT or use --root=<path>.");
    process.exit(2);
  }

  // TODO: Implement checks in subsequent tasks
  console.log(`Project root: ${projectRoot}`);
  console.log(`Mode: ${opts.soft ? "soft" : "hard"}`);
  console.log(`JSON: ${opts.json}`);
}

main();
```

- [ ] **Step 2: Run the script to verify it executes without errors**

Run: `node standards/scripts/verify-source-line-count.js --help`
Expected: Help text displayed, exit code 0

- [ ] **Step 3: Commit**

```bash
git add standards/scripts/verify-source-line-count.js
git commit -m "feat: scaffold verify-source-line-count.js with CLI parsing"
```

---

### Task 2: Implement exclusion logic and file discovery

**Files:**

- Modify: `standards/scripts/verify-source-line-count.js`

**Interfaces:**

- Consumes: project root path from Task 1
- Produces: `shouldSkip(filePath)` function, `listFiles(root)` function

- [ ] **Step 1: Add exclusion constants and shouldSkip function**

Add after the `discoverProjectRoot` function:

```javascript
// ============================================================================
// EXCLUSIONS
// ============================================================================

const SKIP_DIRS = new Set(["node_modules", ".next", "Z-ai-governance", ".git"]);

// Also skip src/components/ui/ (shadcn)
const SKIP_DIR_PATTERNS = ["src/components/ui"];

const EXEMPT_EXTENSIONS = new Set([".json", ".yml", ".yaml", ".toml", ".ini"]);

const EXEMPT_FILE_PATTERNS = [
  /worklog\.md$/i,
  /DECISIONS.*\.md$/i,
  /SESSION.*\.md$/i,
  /MIGRATIONS.*\.md$/i,
  /^INDEX\.md$/i,
];

function shouldSkip(filePath, relativePath) {
  const parts = relativePath.split(path.sep);

  // Skip exempt directories
  for (const part of parts) {
    if (SKIP_DIRS.has(part)) return true;
  }

  // Skip src/components/ui/ pattern
  for (const pattern of SKIP_DIR_PATTERNS) {
    if (relativePath.startsWith(pattern) || relativePath.includes(path.sep + pattern + path.sep)) {
      return true;
    }
  }

  // Skip references/ directory
  if (parts.includes("references")) return true;

  // Skip exempt file patterns
  const basename = path.basename(filePath);
  for (const pattern of EXEMPT_FILE_PATTERNS) {
    if (pattern.test(basename)) return true;
  }

  // Skip exempt extensions
  const ext = path.extname(filePath).toLowerCase();
  if (EXEMPT_EXTENSIONS.has(ext)) return true;

  return false;
}

// ============================================================================
// FILE DISCOVERY
// ============================================================================

function listFiles(dir, root) {
  const results = [];
  if (!fs.existsSync(dir)) return results;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.relative(root, fullPath);

    if (entry.isDirectory()) {
      if (!shouldSkip(fullPath, relativePath)) {
        results.push(...listFiles(fullPath, root));
      }
    } else if (entry.isFile()) {
      if (!shouldSkip(fullPath, relativePath)) {
        results.push(fullPath);
      }
    }
  }

  return results;
}
```

- [ ] **Step 2: Update main() to use listFiles and log excluded counts**

Replace the TODO section in main() with:

```javascript
const allFiles = listFiles(projectRoot, projectRoot);
const skipped = { dirs: 0, exemptExt: 0, exemptPattern: 0 };

console.log(`[verify-source-line-count] Found ${allFiles.length} files to check`);
```

- [ ] **Step 3: Run to verify file discovery works**

Run: `node standards/scripts/verify-source-line-count.js --root="C:\Users\stsgr\My Projects\Z-ai-platform"`
Expected: Shows file count, exit code 0

- [ ] **Step 4: Commit**

```bash
git add standards/scripts/verify-source-line-count.js
git commit -m "feat: add exclusion logic and file discovery to verify-source-line-count"
```

---

### Task 3: Implement category detection and line counting

**Files:**

- Modify: `standards/scripts/verify-source-line-count.js`

**Interfaces:**

- Consumes: file paths from Task 2
- Produces: `categorizeFile(filePath)` function, `countLines(content)` function

- [ ] **Step 1: Add categorizeFile and countLines functions**

Add after the `listFiles` function:

```javascript
// ============================================================================
// CATEGORY DETECTION (RULE-MONOLITH-012 section 4.18.1)
// ============================================================================

const CATEGORIES = {
  SOURCE: { hard: 250, soft: 150, extensions: [".ts", ".tsx", ".js", ".jsx", ".py", ".sh"] },
  CSS: { hard: 250, soft: 150, extensions: [".css"] },
  TEST: { hard: 400, soft: 250, pattern: /\.(test|spec)\.[^.]+$/i },
  SKILL: { hard: 800, soft: 400, pattern: /^SKILL\.md$/i },
  README: { hard: 400, soft: 250, pattern: /^README\.md$/i },
  STD: { hard: 1200, soft: 800, pattern: /^(STD|META)-.+\.md$/i },
  RULE: { hard: 200, soft: 120, pattern: /^RULE-.+\.md$/i },
  PROC: { hard: 400, soft: 250, pattern: /^(PROC|TOOL)-.+\.md$/i },
  OTHER_MD: { hard: 400, soft: 250, extensions: [".md"] },
};

function categorizeFile(filePath) {
  const basename = path.basename(filePath);
  const ext = path.extname(filePath).toLowerCase();

  // Check pattern-based categories first (more specific)
  if (CATEGORIES.TEST.pattern.test(basename)) return "TEST";
  if (CATEGORIES.SKILL.pattern.test(basename)) return "SKILL";
  if (CATEGORIES.README.pattern.test(basename)) return "README";
  if (CATEGORIES.STD.pattern.test(basename)) return "STD";
  if (CATEGORIES.RULE.pattern.test(basename)) return "RULE";
  if (CATEGORIES.PROC.pattern.test(basename)) return "PROC";

  // Check extension-based categories
  if (CATEGORIES.SOURCE.extensions.includes(ext)) return "SOURCE";
  if (CATEGORIES.CSS.extensions.includes(ext)) return "CSS";
  if (CATEGORIES.OTHER_MD.extensions.includes(ext)) return "OTHER_MD";

  return null; // Not a recognized file type
}

// ============================================================================
// LINE COUNTING
// ============================================================================

function countLines(content) {
  if (content === "") return 0;
  return content.split("\n").length - (content.endsWith("\n") ? 1 : 0);
}
```

- [ ] **Step 2: Run to verify no syntax errors**

Run: `node standards/scripts/verify-source-line-count.js --help`
Expected: Help text displayed, exit code 0

- [ ] **Step 3: Commit**

```bash
git add standards/scripts/verify-source-line-count.js
git commit -m "feat: add category detection and line counting"
```

---

### Task 4: Implement checks and results collection

**Files:**

- Modify: `standards/scripts/verify-source-line-count.js`

**Interfaces:**

- Consumes: categorizeFile, countLines, listFiles from Tasks 2-3
- Produces: `runChecks(root, opts)` function, results accumulator

- [ ] **Step 1: Add results accumulator and runChecks function**

Add before the `main` function:

```javascript
// ============================================================================
// RESULTS ACCUMULATOR
// ============================================================================

const results = {
  checks: [],
  stats: {
    files_scanned: 0,
    hard_pass: 0,
    hard_fail: 0,
    soft_warnings: 0,
    exempt: 0,
  },
};

function check(id, category, hardLimit, softLimit, passed, offenders, filesChecked) {
  const status = passed ? "PASS" : "FAIL";
  results.checks.push({
    id,
    status,
    category,
    hard_limit: hardLimit,
    soft_limit: softLimit,
    files_checked: filesChecked,
    offenders,
  });
  if (passed) results.stats.hard_pass++;
  else results.stats.hard_fail++;
}

// ============================================================================
// MAIN CHECKS
// ============================================================================

function runChecks(projectRoot, opts) {
  const soft = opts.soft;
  const files = listFiles(projectRoot, projectRoot);

  // Group files by category
  const byCategory = {};
  for (const file of files) {
    const cat = categorizeFile(file);
    if (cat) {
      if (!byCategory[cat]) byCategory[cat] = [];
      byCategory[cat].push(file);
    }
  }

  results.stats.files_scanned = files.length;

  // Run checks per category
  for (const [catName, catDef] of Object.entries(CATEGORIES)) {
    const catFiles = byCategory[catName] || [];
    if (catFiles.length === 0) continue;

    const offenders = [];
    for (const file of catFiles) {
      const content = fs.readFileSync(file, "utf8");
      const lineCount = countLines(content);
      if (lineCount > catDef.hard) {
        const relativePath = path.relative(projectRoot, file);
        offenders.push({
          file: relativePath,
          lines: lineCount,
          limit: catDef.hard,
          excess: lineCount - catDef.hard,
        });
      }
    }

    check(
      catName,
      catDef.pattern ? catDef.pattern.source : catDef.extensions.join(","),
      catDef.hard,
      catDef.soft,
      offenders.length === 0,
      offenders,
      catFiles.length,
    );
  }
}
```

- [ ] **Step 2: Run to verify checks execute**

Run: `node standards/scripts/verify-source-line-count.js --root="C:\Users\stsgr\My Projects\Z-ai-platform"`
Expected: Shows check results, exit code depends on file sizes

- [ ] **Step 3: Commit**

```bash
git add standards/scripts/verify-source-line-count.js
git commit -m "feat: implement checks and results collection"
```

---

### Task 5: Implement output formatting (human-readable and JSON)

**Files:**

- Modify: `standards/scripts/verify-source-line-count.js`

**Interfaces:**

- Consumes: results from Task 4
- Produces: printHuman(), printJSON() functions

- [ ] **Step 1: Add printHuman and printJSON functions**

Add before the `main` function:

```javascript
// ============================================================================
// OUTPUT FORMATTING
// ============================================================================

function printHuman() {
  const width = Math.max(...results.checks.map((c) => c.id.length));
  console.log(`verify-source-line-count.js v${VERSION} — Anti-monolith Source File Verifier`);
  console.log(`Effective date: ${EFFECTIVE_DATE}`);
  console.log(`Files scanned: ${results.stats.files_scanned}`);
  console.log("=".repeat(72));
  console.log("");
  console.log("--- Hard Checks (by category) ---");
  for (const c of results.checks) {
    const icon = c.status === "PASS" ? "[PASS]" : "[FAIL]";
    console.log(`${icon} ${c.id.padEnd(width)}  ${c.category} <= ${c.hard_limit} lines`);
    if (c.offenders.length > 0) {
      for (const o of c.offenders) {
        console.log(
          `         ${o.file}: ${o.lines} lines (exceeds ${o.limit}-line cap, excess: ${o.excess})`,
        );
      }
    } else {
      console.log(`         all ${c.files_checked} files within limit`);
    }
  }
  console.log("");
  console.log("-".repeat(72));
  console.log(
    `HARD: ${results.stats.hard_pass}/${results.stats.hard_pass + results.stats.hard_fail} PASS, ${results.stats.hard_fail} FAIL`,
  );
  console.log("");
  if (results.stats.hard_fail > 0) {
    console.log("ACTION REQUIRED:");
    console.log("  At least one file exceeds its category limit.");
    console.log("  Split the file into smaller modules (see RULE-MONOLITH-012 section 3).");
    console.log("  Then re-run: node standards/scripts/verify-source-line-count.js");
  } else {
    console.log("All files within category limits. RULE-MONOLITH-012 satisfied.");
  }
}

function printJSON() {
  console.log(
    JSON.stringify(
      {
        script: "verify-source-line-count.js",
        version: VERSION,
        effective_date: EFFECTIVE_DATE,
        generated: new Date().toISOString(),
        summary: {
          files_scanned: results.stats.files_scanned,
          hard_pass: results.stats.hard_pass,
          hard_fail: results.stats.hard_fail,
          soft_warnings: results.stats.soft_warnings,
        },
        checks: results.checks,
      },
      null,
      2,
    ),
  );
}
```

- [ ] **Step 2: Update main() to call output functions and exit correctly**

Replace the end of main() with:

```javascript
runChecks(projectRoot, opts);

if (opts.json) {
  printJSON();
} else {
  printHuman();
}

const hardFail = results.checks.filter((c) => c.status === "FAIL").length;
process.exit(hardFail > 0 && !opts.soft ? 1 : 0);
```

- [ ] **Step 3: Run to verify output formatting**

Run: `node standards/scripts/verify-source-line-count.js --root="C:\Users\stsgr\My Projects\Z-ai-platform"`
Expected: Human-readable output with check results

Run: `node standards/scripts/verify-source-line-count.js --root="C:\Users\stsgr\My Projects\Z-ai-platform" --json`
Expected: JSON output

- [ ] **Step 4: Commit**

```bash
git add standards/scripts/verify-source-line-count.js
git commit -m "feat: add output formatting (human-readable and JSON)"
```

---

### Task 6: Create Husky pre-commit hook

**Files:**

- Create: `.husky/pre-commit`

**Interfaces:**

- Consumes: verify-source-line-count.js from Tasks 1-5
- Produces: pre-commit hook that blocks commits on violations

- [ ] **Step 1: Create .husky directory and pre-commit hook**

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "ANTI-MONOLITH: Checking source file line limits..."
node standards/scripts/verify-source-line-count.js
```

- [ ] **Step 2: Make the hook executable (Unix)**

Run: `chmod +x .husky/pre-commit`

- [ ] **Step 3: Verify Husky is installed**

Run: `npx husky install`
Expected: Husky hooks directory initialized

- [ ] **Step 4: Test the hook by attempting a commit**

Create a test file with >250 lines, stage it, and attempt to commit.
Expected: Commit blocked with error message showing the offending file.

- [ ] **Step 5: Clean up test file and commit**

```bash
git add .husky/pre-commit
git commit -m "feat: add Husky pre-commit hook for anti-monolith checks"
```

---

### Task 7: End-to-end verification

**Files:**

- None (verification only)

**Interfaces:**

- Consumes: all previous tasks
- Produces: confirmed working system

- [ ] **Step 1: Run the verifier manually**

Run: `node standards/scripts/verify-source-line-count.js`
Expected: Full scan results, exit code 0 or 1 depending on current file sizes

- [ ] **Step 2: Run with --json flag**

Run: `node standards/scripts/verify-source-line-count.js --json`
Expected: Valid JSON output with all check results

- [ ] **Step 3: Run with --soft flag**

Run: `node standards/scripts/verify-source-line-count.js --soft`
Expected: Same output but exit code 0 even if violations exist

- [ ] **Step 4: Test pre-commit hook**

1. Create a temporary file with >250 lines in a .ts extension
2. Stage it: `git add test-file.ts`
3. Attempt commit: `git commit -m "test: verify hook blocks oversized files"`
4. Expected: Commit blocked, error message shown
5. Clean up: `git reset HEAD test-file.ts && rm test-file.ts`

- [ ] **Step 5: Verify exclusions work**

1. Check that `node_modules/` files are not scanned
2. Check that `.next/` files are not scanned
3. Check that `src/components/ui/` files are not scanned
4. Check that `.json` files are not scanned

- [ ] **Step 6: Final commit (if any cleanup needed)**

```bash
git add -A
git commit -m "chore: verify anti-monolith source line count enforcement"
```
