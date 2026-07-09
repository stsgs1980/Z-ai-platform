# Split Scripts into lib/ Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split 8 oversized scripts in standards/scripts/ into lib/ modules so all files stay under 250 lines.

**Architecture:** Extract reusable functions from each script into lib/ modules. Each script becomes a thin orchestrator that imports from lib/. Follow existing patterns (verify-id-graph.js already has lib/ constants, graph-algorithms, parsers, snapshot, health-warnings, declarations, output, file-scanner).

**Tech Stack:** Node.js (CommonJS), Bash

## Global Constraints

- Node.js >= 20.12.0
- No external dependencies (pure Node.js)
- Line count convention: `wc -l` equivalent
- Each file must stay under 250 lines (SOURCE category)
- lib/ files must also stay under 250 lines
- Follow existing patterns in the codebase

---

## File Structure

| File                                  | Action | Responsibility                                 |
| ------------------------------------- | ------ | ---------------------------------------------- |
| `scripts/lib/cli-utils.js`            | CREATE | Shared CLI parsing, help, output formatting    |
| `scripts/lib/file-utils.js`           | CREATE | File discovery, exclusion logic, line counting |
| `scripts/lib/category-utils.js`       | CREATE | Category detection from RULE-MONOLITH-012      |
| `scripts/lib/check-utils.js`          | CREATE | Check execution, results accumulation          |
| `scripts/check-md.sh`                 | MODIFY | Split into main + sourced functions            |
| `scripts/graph-deps.sh`               | MODIFY | Split into main + sourced functions            |
| `scripts/lib/declarations.js`         | MODIFY | Trim 3 lines (already in lib/)                 |
| `scripts/lib/health-warnings.js`      | MODIFY | Split into smaller modules                     |
| `scripts/verify-id-graph.js`          | MODIFY | Extract more functions to lib/                 |
| `scripts/verify-skills.js`            | MODIFY | Extract more functions to lib/                 |
| `scripts/verify-source-line-count.js` | MODIFY | Extract to use shared lib/ modules             |
| `scripts/verify-standards.js`         | MODIFY | Extract more functions to lib/                 |

---

### Task 1: Create shared lib/ modules (cli-utils, file-utils, category-utils, check-utils)

**Files:**

- Create: `scripts/lib/cli-utils.js`
- Create: `scripts/lib/file-utils.js`
- Create: `scripts/lib/category-utils.js`
- Create: `scripts/lib/check-utils.js`

**Interfaces:**

- Consumes: none (foundation modules)
- Produces: shared functions for all scripts

- [ ] **Step 1: Create cli-utils.js with shared CLI functions**

```javascript
// scripts/lib/cli-utils.js
"use strict";

const VERSION = "1.0.0";

function parseArgs(argv, validFlags) {
  const opts = {};
  for (const arg of argv.slice(2)) {
    if (arg === "--help" || arg === "-h") {
      opts.help = true;
      continue;
    }
    if (arg === "--json") {
      opts.json = true;
      continue;
    }
    if (arg === "--soft") {
      opts.soft = true;
      continue;
    }
    if (arg === "--strict") {
      opts.strict = true;
      continue;
    }
    if (arg.startsWith("--root=")) {
      opts.root = arg.slice(7);
      continue;
    }
    if (arg.startsWith("--snapshot=")) {
      opts.snapshot = arg.slice(11);
      continue;
    }
    if (arg.startsWith("--compare=")) {
      opts.compare = arg.slice(10);
      continue;
    }
    if (arg.startsWith("--update-snapshot")) {
      opts.updateSnapshot = true;
      continue;
    }
    console.error(`Unknown argument: ${arg}`);
    process.exit(2);
  }
  return opts;
}

function printJSON(data) {
  console.log(JSON.stringify(data, null, 2));
}

module.exports = { VERSION, parseArgs, printJSON };
```

- [ ] **Step 2: Create file-utils.js with shared file functions**

```javascript
// scripts/lib/file-utils.js
"use strict";

const fs = require("fs");
const path = require("path");

const SKIP_DIRS = new Set(["node_modules", ".next", "Z-ai-governance", ".git"]);
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
  for (const part of parts) {
    if (SKIP_DIRS.has(part)) return true;
  }
  for (const pattern of SKIP_DIR_PATTERNS) {
    if (relativePath.startsWith(pattern) || relativePath.includes(path.sep + pattern + path.sep))
      return true;
  }
  if (parts.includes("references")) return true;
  const basename = path.basename(filePath);
  for (const pattern of EXEMPT_FILE_PATTERNS) {
    if (pattern.test(basename)) return true;
  }
  const ext = path.extname(filePath).toLowerCase();
  if (EXEMPT_EXTENSIONS.has(ext)) return true;
  return false;
}

function listFiles(dir, root) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    const relativePath = path.relative(root, fullPath);
    if (entry.isDirectory()) {
      if (!shouldSkip(fullPath, relativePath)) results.push(...listFiles(fullPath, root));
    } else if (entry.isFile()) {
      if (!shouldSkip(fullPath, relativePath)) results.push(fullPath);
    }
  }
  return results;
}

function countLines(content) {
  if (content === "") return 0;
  return content.split("\n").length - (content.endsWith("\n") ? 1 : 0);
}

function discoverProjectRoot(startDir) {
  if (process.env.ZAI_PLATFORM_ROOT && fs.existsSync(process.env.ZAI_PLATFORM_ROOT)) {
    return process.env.ZAI_PLATFORM_ROOT;
  }
  let dir = startDir;
  for (let i = 0; i < 10; i++) {
    if (fs.existsSync(path.join(dir, "package.json"))) return dir;
    dir = path.dirname(dir);
  }
  return null;
}

module.exports = { listFiles, countLines, discoverProjectRoot, shouldSkip };
```

- [ ] **Step 3: Create category-utils.js**

```javascript
// scripts/lib/category-utils.js
"use strict";

const path = require("path");

const CATEGORIES = {
  SOURCE: { hard: 250, soft: 150, extensions: [".ts", ".tsx", ".js", ".jsx", ".py", ".sh"] },
  CSS: { hard: 250, soft: 150, extensions: [".css"] },
  TEST: { hard: 400, soft: 250, pattern: /\.(test|spec)\.[^.]+$/i },
  SKILL: { hard: 800, soft: 400, pattern: /^SKILL\.md$/i },
  README: { hard: 400, soft: 250, pattern: /^README\.md$/i },
  STD: {
    hard: 1200,
    soft: 800,
    pattern: /^(A11Y|AGENT|ARCH|DESIGN|DOC|ERR|FE|GIT|META|SEC|SKILL|STD)-.+\.md$/i,
  },
  RULE: { hard: 200, soft: 120, pattern: /^RULE-.+\.md$/i },
  PROC: { hard: 400, soft: 250, pattern: /^(PROC|TOOL)-.+\.md$/i },
  OTHER_MD: { hard: 400, soft: 250, extensions: [".md"] },
};

function categorizeFile(filePath) {
  const basename = path.basename(filePath);
  const ext = path.extname(filePath).toLowerCase();
  if (CATEGORIES.TEST.pattern.test(basename)) return "TEST";
  if (CATEGORIES.SKILL.pattern.test(basename)) return "SKILL";
  if (CATEGORIES.README.pattern.test(basename)) return "README";
  if (CATEGORIES.STD.pattern.test(basename)) return "STD";
  if (CATEGORIES.RULE.pattern.test(basename)) return "RULE";
  if (CATEGORIES.PROC.pattern.test(basename)) return "PROC";
  if (CATEGORIES.SOURCE.extensions.includes(ext)) return "SOURCE";
  if (CATEGORIES.CSS.extensions.includes(ext)) return "CSS";
  if (CATEGORIES.OTHER_MD.extensions.includes(ext)) return "OTHER_MD";
  return null;
}

module.exports = { CATEGORIES, categorizeFile };
```

- [ ] **Step 4: Create check-utils.js**

```javascript
// scripts/lib/check-utils.js
"use strict";

function createResults() {
  return {
    checks: [],
    stats: { files_scanned: 0, hard_pass: 0, hard_fail: 0, soft_warnings: 0 },
  };
}

function addCheck(results, id, status, description, detail, isSoft) {
  results.checks.push({ id, status, description, detail, isSoft: !!isSoft });
  if (status === "PASS") results.stats.hard_pass++;
  else if (isSoft) results.stats.soft_warnings++;
  else results.stats.hard_fail++;
}

module.exports = { createResults, addCheck };
```

- [ ] **Step 5: Commit**

```bash
git add scripts/lib/cli-utils.js scripts/lib/file-utils.js scripts/lib/category-utils.js scripts/lib/check-utils.js
git commit -m "feat: add shared lib/ modules for CLI, file, category, check utils"
```

---

### Task 2: Refactor verify-source-line-count.js to use shared lib/

**Files:**

- Modify: `scripts/verify-source-line-count.js`

**Interfaces:**

- Consumes: cli-utils, file-utils, category-utils, check-utils from Task 1
- Produces: refactored script under 250 lines

- [ ] **Step 1: Rewrite verify-source-line-count.js using shared modules**

Replace the entire file with:

```javascript
#!/usr/bin/env node
"use strict";

const path = require("path");
const { VERSION, parseArgs, printJSON } = require("./lib/cli-utils");
const { listFiles, countLines, discoverProjectRoot } = require("./lib/file-utils");
const { CATEGORIES, categorizeFile } = require("./lib/category-utils");
const { createResults, addCheck } = require("./lib/check-utils");

function showHelp() {
  console.log(`
verify-source-line-count.js v${VERSION} — Anti-monolith Source File Verifier

Usage: node standards/scripts/verify-source-line-count.js [options]

Options:
  --json         Output JSON (for CI)
  --soft         Warn-only mode (exit 0 even on violations)
  --root=<path>  Override project root
  --help, -h     Show this help

Implements: RULE-MONOLITH-012 section 4.18.1

Exit codes: 0 = all OK, 1 = violations found, 2 = config error
`);
}

function printHuman(results) {
  const w = Math.max(...results.checks.map((c) => c.id.length));
  console.log(`verify-source-line-count.js v${VERSION}`);
  console.log("=".repeat(72));
  for (const c of results.checks) {
    const icon = c.status === "PASS" ? "[PASS]" : "[FAIL]";
    console.log(`${icon} ${c.id.padEnd(w)}  ${c.description}`);
    if (c.detail) console.log(`         ${c.detail}`);
  }
  console.log("-".repeat(72));
  console.log(
    `HARD: ${results.stats.hard_pass}/${results.stats.hard_pass + results.stats.hard_fail} PASS, ${results.stats.hard_fail} FAIL`,
  );
}

function runChecks(projectRoot) {
  const results = createResults();
  const files = listFiles(projectRoot, projectRoot);
  results.stats.files_scanned = files.length;

  const byCategory = {};
  for (const file of files) {
    const cat = categorizeFile(file);
    if (cat) {
      if (!byCategory[cat]) byCategory[cat] = [];
      byCategory[cat].push(file);
    }
  }

  for (const [catName, catDef] of Object.entries(CATEGORIES)) {
    const catFiles = byCategory[catName] || [];
    if (catFiles.length === 0) continue;
    const offenders = [];
    for (const file of catFiles) {
      const content = require("fs").readFileSync(file, "utf8");
      const lineCount = countLines(content);
      if (lineCount > catDef.hard) {
        offenders.push({
          file: path.relative(projectRoot, file),
          lines: lineCount,
          limit: catDef.hard,
          excess: lineCount - catDef.hard,
        });
      }
    }
    const desc = catDef.pattern ? catDef.pattern.source : catDef.extensions.join(",");
    const detail =
      offenders.length === 0
        ? `all ${catFiles.length} files within limit`
        : offenders.map((o) => `${o.file}: ${o.lines} lines (exceeds ${o.limit})`).join("; ");
    addCheck(
      results,
      catName,
      offenders.length === 0 ? "PASS" : "FAIL",
      `${catDesc} <= ${catDef.hard} lines`,
      detail,
    );
  }
  return results;
}

function main() {
  const opts = parseArgs(process.argv);
  if (opts.help) {
    showHelp();
    process.exit(0);
  }
  const root = opts.root || discoverProjectRoot(__dirname);
  if (!root) {
    console.error("Could not discover project root.");
    process.exit(2);
  }
  const results = runChecks(root);
  if (opts.json) printJSON({ script: "verify-source-line-count.js", version: VERSION, ...results });
  else printHuman(results);
  const fail = results.checks.filter((c) => c.status === "FAIL").length;
  process.exit(fail > 0 && !opts.soft ? 1 : 0);
}

main();
```

- [ ] **Step 2: Verify it runs**

Run: `node standards/scripts/verify-source-line-count.js --help`
Expected: Help text, exit 0

- [ ] **Step 3: Commit**

```bash
git add scripts/verify-source-line-count.js
git commit -m "refactor: verify-source-line-count.js uses shared lib/ modules"
```

---

### Task 3: Refactor verify-skills.js to use shared lib/

**Files:**

- Modify: `scripts/verify-skills.js`

**Interfaces:**

- Consumes: cli-utils, file-utils from Task 1
- Produces: refactored script under 250 lines

- [ ] **Step 1: Extract functions to lib/skills-utils.js**

Create `scripts/lib/skills-utils.js` with:

- parseFrontmatter(content)
- parseBlockquote(content)
- listSkillDirs(skillsRoot)

- [ ] **Step 2: Rewrite verify-skills.js main logic**

Keep only the main orchestration and check definitions. Move all helper functions to lib/.

- [ ] **Step 3: Verify it runs**

Run: `node standards/scripts/verify-skills.js --help`
Expected: Help text, exit 0

- [ ] **Step 4: Commit**

```bash
git add scripts/verify-skills.js scripts/lib/skills-utils.js
git commit -m "refactor: verify-skills.js uses shared lib/ modules"
```

---

### Task 4: Refactor verify-standards.js to use shared lib/

**Files:**

- Modify: `scripts/verify-standards.js`

**Interfaces:**

- Consumes: cli-utils, file-utils from Task 1
- Produces: refactored script under 250 lines

- [ ] **Step 1: Extract functions to lib/standards-utils.js**

Create `scripts/lib/standards-utils.js` with:

- readSafe(filePath)
- extractSection(content, sectionNumber)

- [ ] **Step 2: Rewrite verify-standards.js main logic**

Keep only V04-V18 check definitions. Move helpers to lib/.

- [ ] **Step 3: Verify it runs**

Run: `node standards/scripts/verify-standards.js --help`
Expected: Help text, exit 0

- [ ] **Step 4: Commit**

```bash
git add scripts/verify-standards.js scripts/lib/standards-utils.js
git commit -m "refactor: verify-standards.js uses shared lib/ modules"
```

---

### Task 5: Refactor verify-id-graph.js to use shared lib/

**Files:**

- Modify: `scripts/verify-id-graph.js`

**Interfaces:**

- Consumes: cli-utils, file-utils from Task 1
- Produces: refactored script under 250 lines

- [ ] **Step 1: Extract more functions to lib/ modules**

verify-id-graph.js already has lib/ modules. Extract remaining shared functions.

- [ ] **Step 2: Rewrite verify-id-graph.js main logic**

Keep only the main orchestration. Move helpers to lib/.

- [ ] **Step 3: Verify it runs**

Run: `node standards/scripts/verify-id-graph.js --help`
Expected: Help text, exit 0

- [ ] **Step 4: Commit**

```bash
git add scripts/verify-id-graph.js
git commit -m "refactor: verify-id-graph.js uses shared lib/ modules"
```

---

### Task 6: Split shell scripts (check-md.sh, graph-deps.sh)

**Files:**

- Modify: `scripts/check-md.sh`
- Modify: `scripts/graph-deps.sh`

**Interfaces:**

- Consumes: none (shell functions)
- Produces: split scripts under 250 lines

- [ ] **Step 1: Create scripts/lib/shell-functions.sh**

Extract shared shell functions:

- log_info, log_warn, log_error
- check_file, process_directory

- [ ] **Step 2: Rewrite check-md.sh to source shared functions**

- [ ] **Step 3: Rewrite graph-deps.sh to source shared functions**

- [ ] **Step 4: Verify both scripts run**

- [ ] **Step 5: Commit**

```bash
git add scripts/check-md.sh scripts/graph-deps.sh scripts/lib/shell-functions.sh
git commit -m "refactor: split shell scripts into main + lib/ functions"
```

---

### Task 7: Fix remaining lib/ files (declarations.js, health-warnings.js)

**Files:**

- Modify: `scripts/lib/declarations.js`
- Modify: `scripts/lib/health-warnings.js`

**Interfaces:**

- Consumes: none
- Produces: files under 250 lines

- [ ] **Step 1: Trim declarations.js (253 → 250)**

Remove 3 lines of verbose comments or consolidate functions.

- [ ] **Step 2: Split health-warnings.js (425 → 250)**

Extract warning generators to lib/warnings/ subdirectory.

- [ ] **Step 3: Verify no syntax errors**

- [ ] **Step 4: Commit**

```bash
git add scripts/lib/declarations.js scripts/lib/health-warnings.js
git commit -m "refactor: split lib/declarations.js and lib/health-warnings.js"
```

---

### Task 8: Final verification

**Files:**

- None (verification only)

**Interfaces:**

- Consumes: all previous tasks
- Produces: all files under 250 lines

- [ ] **Step 1: Run verifier**

Run: `node standards/scripts/verify-source-line-count.js`
Expected: SOURCE category PASS

- [ ] **Step 2: Verify all scripts work**

Run each script with --help to confirm no breakage.

- [ ] **Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: verify all scripts under 250 lines"
```
