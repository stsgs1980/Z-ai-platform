# Design: verify-source-line-count.js + Pre-commit Hook

**Date:** 2026-07-08
**Status:** Approved
**Implements:** RULE-MONOLITH-012 (anti-monolith enforcement)

## Problem

RULE-MONOLITH-012 defines line limits per file category (source 250, tests 400, SKILL.md 800, etc.) but no automated enforcement exists for source files. The rule states:

> Today (v1.3): soft warnings via `scripts/audit_md_files.py`. Run manually or wire as a non-blocking pre-commit hook. No CI hard-fail.
> Future (PROC-LINECOUNT-004, deferred): bash pre-commit hook (~80 lines) that reads the section 4.18.1 matrix and enforces it.

This design implements the deferred PROC-LINECOUNT-004 as a Node.js script (not bash) for cross-platform consistency with existing verifiers.

## Design Decisions

| Decision      | Choice                           | Rationale                                                    |
| ------------- | -------------------------------- | ------------------------------------------------------------ |
| Approach      | Standalone script + Husky hook   | Consistent with verify-skills.js/verify-standards.js pattern |
| Language      | Node.js                          | Cross-platform, same as existing verifiers                   |
| Location      | `standards/scripts/`             | Same directory as other verifiers                            |
| Default mode  | Hard-fail                        | User requirement: block commits on violation                 |
| Matrix source | RULE-MONOLITH-012 section 4.18.1 | Canonical source of truth                                    |

## Matrix (from RULE-MONOLITH-012 section 4.18.1)

| Category              | Hard   | Soft | Extensions/Pattern                                             |
| --------------------- | ------ | ---- | -------------------------------------------------------------- |
| Source code           | 250    | 150  | `.ts`, `.tsx`, `.js`, `.jsx`, `.py`, `.sh`                     |
| CSS                   | 250    | 150  | `.css`                                                         |
| Tests                 | 400    | 250  | `.test.*`, `.spec.*`                                           |
| Config                | exempt | -    | `.json`, `.yml`, `.yaml`, `.toml`, `.ini`                      |
| SKILL.md              | 800    | 400  | `SKILL.md`                                                     |
| README.md             | 400    | 250  | `README.md`                                                    |
| INDEX.md              | exempt | -    | `INDEX.md`                                                     |
| STD-_.md / META-_.md  | 1200   | 800  | `STD-*.md`, `META-*.md`                                        |
| RULE-*.md             | 200    | 120  | `RULE-*.md`                                                    |
| PROC-_.md / TOOL-_.md | 400    | 250  | `PROC-*.md`, `TOOL-*.md`                                       |
| references/**.md      | exempt | -    | `references/**`                                                |
| Append-only logs      | exempt | -    | `worklog.md`, `DECISIONS*.md`, `SESSION*.md`, `MIGRATIONS*.md` |
| Other .md             | 400    | 250  | Default for unrecognized .md                                   |

## Exclusions

### Directories (recursive skip)

- `node_modules/`
- `.next/`
- `Z-ai-governance/`
- `src/components/ui/` (shadcn components)
- `.git/`

### Files (exempt by pattern)

- Config files: `.json`, `.yml`, `.yaml`, `.toml`, `.ini`
- Append-only logs: `worklog.md`, `DECISIONS*.md`, `SESSION*.md`, `MIGRATIONS*.md`
- Router files: `INDEX.md`
- Externalized references: `references/**`

## CLI Interface

```
node standards/scripts/verify-source-line-count.js [options]

Options:
  --json         JSON output (for CI)
  --soft         Warn-only mode (exit 0 even on violations)
  --root=<path>  Override project root (auto-detected otherwise)
  --help, -h     Show help

Exit codes:
  0 - all files within limits (or soft mode)
  1 - at least one file exceeds its limit
  2 - configuration error
```

## Pre-commit Hook

File: `.husky/pre-commit`

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "ANTI-MONOLITH: Checking source file line limits..."
node standards/scripts/verify-source-line-count.js
```

The hook runs WITHOUT `--soft`, meaning hard-fail. If any file exceeds its category limit, the commit is blocked.

## Output Format

### Human-readable (default)

```
verify-source-line-count.js v1.0.0 -- Anti-monolith Source File Verifier
Effective date: 2026-07-08
Files scanned: 142
========================================================================

--- Hard Checks (by category) ---

[PASS] SRC    Source code (.ts/.tsx/.js/.jsx/.py/.sh) <= 250 lines
         all 89 files within limit
[PASS] CSS    CSS (.css) <= 250 lines
         all 12 files within limit
[FAIL] TEST   Tests (.test.*/.spec.*) <= 400 lines
         1 file(s) over cap: src/utils/helpers.test.ts: 423 lines (exceeds 400-line cap)

--- Exempt ---
  Config files: 23 skipped (exempt per RULE-MONOLITH-012)
  Append-only logs: 3 skipped (exempt)
  references/**: 12 skipped (exempt)

========================================================================
HARD: 1/2 FAIL, 1 FAIL

ACTION REQUIRED:
  At least one file exceeds its category limit.
  Split the file into smaller modules (see RULE-MONOLITH-012 section 3).
  Then re-run: node standards/scripts/verify-source-line-count.js
```

### JSON (--json)

```json
{
  "script": "verify-source-line-count.js",
  "version": "1.0.0",
  "effective_date": "2026-07-08",
  "generated": "2026-07-08T12:00:00.000Z",
  "summary": {
    "files_scanned": 142,
    "hard_pass": 1,
    "hard_fail": 1,
    "soft_warnings": 0,
    "exempt": 38
  },
  "checks": [
    {
      "id": "SRC",
      "status": "PASS",
      "category": "Source code",
      "extensions": [".ts", ".tsx", ".js", ".jsx", ".py", ".sh"],
      "hard_limit": 250,
      "soft_limit": 150,
      "files_checked": 89,
      "offenders": []
    },
    {
      "id": "TEST",
      "status": "FAIL",
      "category": "Tests",
      "extensions": [".test.*", ".spec.*"],
      "hard_limit": 400,
      "soft_limit": 250,
      "files_checked": 15,
      "offenders": [
        {
          "file": "src/utils/helpers.test.ts",
          "lines": 423,
          "limit": 400,
          "excess": 23
        }
      ]
    }
  ]
}
```

## Architecture

```
standards/scripts/verify-source-line-count.js
  |
  +-- discoverProjectRoot()    -- find project root (walk up from __dirname)
  |
  +-- shouldSkip(filePath)     -- check exclusions (dirs + file patterns)
  |
  +-- categorizeFile(filePath) -- determine category from extension/pattern
  |
  +-- countLines(content)      -- wc -l equivalent (consistent with other verifiers)
  |
  +-- runChecks(root, opts)    -- scan files, apply limits, collect results
  |
  +-- printHuman() / printJSON() -- output formatting
```

## Category Detection Logic

```
1. If file matches append-only log pattern -> EXEMPT
2. If file is INDEX.md -> EXEMPT
3. If file is in references/ -> EXEMPT
4. If extension is .json/.yml/.yaml/.toml/.ini -> EXEMPT (Config)
5. If filename matches *.test.* or *.spec.* -> TEST (400/250)
6. If filename is SKILL.md -> SKILL (800/400)
7. If filename is README.md -> README (400/250)
8. If filename matches STD-*.md or META-*.md -> STD (1200/800)
9. If filename matches RULE-*.md -> RULE (200/120)
10. If filename matches PROC-*.md or TOOL-*.md -> PROC (400/250)
11. If extension is .css -> CSS (250/150)
12. If extension is .ts/.tsx/.js/.jsx/.py/.sh -> SOURCE (250/150)
13. If extension is .md -> OTHER_MD (400/250)
14. Otherwise -> skip (not a recognized file type)
```

## Integration with Existing Verifiers

| Verifier                        | Scope                           | What it checks                                    |
| ------------------------------- | ------------------------------- | ------------------------------------------------- |
| verify-skills.js                | skills/                         | SKILL.md format, frontmatter, line caps           |
| verify-standards.js             | standards/ + docs/ + templates/ | Content invariants (emoji, fences, language)      |
| verify-id-graph.js              | Cross-repo                      | ID graph, Related edges, structural               |
| **verify-source-line-count.js** | **Entire project**              | **Source file line limits per RULE-MONOLITH-012** |

The new verifier complements the existing ones by covering the source-code corpus that they do not touch.

## Testing

1. Run manually: `node standards/scripts/verify-source-line-count.js`
2. Verify JSON output: `node standards/scripts/verify-source-line-count.js --json`
3. Verify soft mode: `node standards/scripts/verify-source-line-count.js --soft`
4. Test pre-commit hook: create a file >250 lines, attempt to commit
5. Verify exclusions: confirm node_modules, .next, etc. are skipped

## Files to Create/Modify

| File                                            | Action | Description                                          |
| ----------------------------------------------- | ------ | ---------------------------------------------------- |
| `standards/scripts/verify-source-line-count.js` | CREATE | Main verifier script                                 |
| `.husky/pre-commit`                             | CREATE | Pre-commit hook (requires `npx husky install` first) |
| `package.json`                                  | VERIFY | Ensure `"prepare": "husky"` exists (already present) |
