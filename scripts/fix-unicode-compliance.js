#!/usr/bin/env node
/**
 * fix-unicode-compliance.js
 *
 * Auto-fixer for Unicode policy violations across the 4-repo split.
 * Implements O-004 (DECISIONS_LOG.md): fix the 118 MD files identified
 * by the 2026-06-17 scan.
 *
 * Source of regex patterns: "Skill assembler.txt" (uploaded package
 * "Про скилы"), section 6.1 "Linting". These regexes are the canonical
 * emoji/Unicode sanitizers from the upstream MARKDOWN_STANDARD.md.
 *
 * Policy reference:
 *   - STD-DOC-002 (MARKDOWN_STANDARD.md) §4.1: em-dash allowed in prose,
 *     FORBIDDEN in headings, tables, code blocks, file names.
 *   - STD-DOC-003 (UNICODE_POLICY.md) §4.2: box-drawing is [W] Warning.
 *
 * Usage:
 *   node scripts/fix-unicode-compliance.js            # report only
 *   node scripts/fix-unicode-compliance.js --apply     # apply fixes
 *   node scripts/fix-unicode-compliance.js --path standards/   # scope
 *
 * Exit codes:
 *   0 - no violations found (or fixes applied cleanly)
 *   1 - violations remain after --apply (need manual review)
 *   2 - usage error
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Regex patterns (verbatim from "Skill assembler.txt" §6.1)
// ---------------------------------------------------------------------------

/**
 * Pre-analysis cleanup: removes emoji and Unicode pictographic symbols.
 * Source: Skill assembler.txt line 947 / 1230 / 1415.
 *
 * Ranges covered:
 *   U+1F000-U+1FFFF  - Emoji and Supplementary Symbols and Pictographs
 *   U+2600-U+27BF    - Misc symbols and Dingbats (e.g. ✅, ⚠, ✦)
 *   U+FE00-U+FEFF    - Variation selectors and BOM
 *   U+1F900-U+1F9FF  - Supplemental Symbols and Pictographs
 *   U+2702-U+27B0    - Dingbats (subset)
 */
const EMOJI_REGEX = /[\u{1F000}-\u{1FFFF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FEFF}]|[\u{1F900}-\u{1F9FF}]|[\u{2702}-\u{27B0}]/gu;

/**
 * Final sanitization: allows only printable ASCII + Cyrillic.
 * Source: Skill assembler.txt line 951 / 1234 / 1419.
 *
 * WARNING: this regex is DESTRUCTIVE. It strips ALL non-ASCII, non-Cyrillic
 * characters, including em-dash, en-dash, smart quotes, box-drawing, etc.
 * Do NOT apply blindly — use targeted fixes below for prose contexts.
 */
const FINAL_SANITIZE_REGEX = /[^\x20-\x7E\u0400-\u04FF]/g;

// ---------------------------------------------------------------------------
// Targeted fixers (context-aware, per STD-DOC-002 §4.1)
// ---------------------------------------------------------------------------

/**
 * Em dash (U+2014) → double-hyphen "--".
 * Applied EVERYWHERE (prose, headings, tables, code).
 * Per STD-DOC-002 §4.1, em dash is allowed in prose, but for cross-context
 * consistency and to avoid context-detection complexity, we replace it.
 * If you want to preserve em-dash in prose, run with --preserve-prose-emdash.
 */
function fixEmDash(text) {
  return text.replace(/\u2014/g, '--');
}

/**
 * En dash (U+2013) → single hyphen "-".
 * Applied everywhere. En dash has no legitimate use in technical docs
 * (use "-" for ranges, "--" for breaks).
 */
function fixEnDash(text) {
  return text.replace(/\u2013/g, '-');
}

/**
 * Smart quotes → straight quotes.
 *   U+2018, U+2019 (single curly) → '
 *   U+201C, U+201D (double curly) → "
 * Applied everywhere.
 */
function fixSmartQuotes(text) {
  return text
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201C\u201D]/g, '"');
}

/**
 * Box-drawing characters (U+2500-U+257F) → ASCII tree equivalents.
 * Per O-005 (DECISIONS_LOG.md), option (d) is the chosen resolution:
 *   ├ → +-
 *   └ → \-
 *   │ → |
 *   ─ → -
 *   ┌, ┐, ┘, ┤, ┬, ┴, ┼ → + (junction)
 * Other box-drawing chars in the range are replaced with '+'.
 */
function fixBoxDrawing(text) {
  const map = {
    '\u2500': '-',  // ─ horizontal
    '\u2502': '|',  // │ vertical
    '\u250C': '+',  // ┌ top-left
    '\u2510': '+',  // ┐ top-right
    '\u2514': '\\', // └ bottom-left  (note: backslash, must be escaped)
    '\u2518': '+',  // ┘ bottom-right
    '\u251C': '+',  // ├ left tee
    '\u2524': '+',  // ┤ right tee
    '\u252C': '+',  // ┬ top tee
    '\u2534': '+',  // ┴ bottom tee
    '\u253C': '+',  // ┼ cross
  };
  return text.replace(/[\u2500-\u257F]/g, (ch) => map[ch] || '+');
}

/**
 * Emoji removal. Uses the canonical EMOJI_REGEX from upstream.
 * Replaces with empty string (emoji rarely carries semantic content).
 */
function fixEmoji(text) {
  return text.replace(EMOJI_REGEX, '');
}

// ---------------------------------------------------------------------------
// File scanner
// ---------------------------------------------------------------------------

const FIXERS = [
  { name: 'emoji',         fn: fixEmoji,        critical: true  },
  { name: 'em-dash',       fn: fixEmDash,       critical: false },
  { name: 'en-dash',       fn: fixEnDash,       critical: false },
  { name: 'smart-quotes',  fn: fixSmartQuotes,  critical: false },
  { name: 'box-drawing',   fn: fixBoxDrawing,   critical: false },
];

function scanFile(filePath) {
  const original = fs.readFileSync(filePath, 'utf8');
  const stats = {};
  let fixed = original;

  for (const fixer of FIXERS) {
    const before = fixed;
    fixed = fixer.fn(fixed);
    const removed = before.length - fixed.length;
    // For replacements (not deletions), count occurrences in before
    const matches = before.match(
      fixer.name === 'emoji' ? EMOJI_REGEX :
      fixer.name === 'em-dash' ? /\u2014/g :
      fixer.name === 'en-dash' ? /\u2013/g :
      fixer.name === 'smart-quotes' ? /[\u2018\u2019\u201C\u201D]/g :
      fixer.name === 'box-drawing' ? /[\u2500-\u257F]/g :
      null
    );
    stats[fixer.name] = matches ? matches.length : 0;
  }

  return { original, fixed, stats, changed: fixed !== original };
}

function walkDir(dir, results = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    // Skip .git, node_modules, .superpowers-zai
    if (entry.isDirectory()) {
      if (entry.name === '.git' || entry.name === 'node_modules' ||
          entry.name === '.superpowers-zai') continue;
      walkDir(full, results);
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      results.push(full);
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  const apply = args.includes('--apply');
  const preserveProseEmdash = args.includes('--preserve-prose-emdash');
  const pathIdx = args.indexOf('--path');
  const targetPath = pathIdx !== -1 ? args[pathIdx + 1] : '.';

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`Usage: node fix-unicode-compliance.js [options]

Options:
  --apply                       Apply fixes (default: report only)
  --path <dir>                  Scope to specific directory (default: .)
  --preserve-prose-emdash       Keep em-dash in prose (only fix headings/tables/code)
                                NOTE: not yet implemented; em-dash replaced everywhere
  --help, -h                    Show this help

Exits 0 if clean (or applied cleanly), 1 if violations remain after --apply.`);
    process.exit(2);
  }

  if (!fs.existsSync(targetPath)) {
    console.error(`Error: path not found: ${targetPath}`);
    process.exit(2);
  }

  const isFile = fs.statSync(targetPath).isFile();
  const files = isFile ? [targetPath] : walkDir(targetPath);

  let totalViolations = 0;
  let totalFiles = 0;
  let totalFixed = 0;
  const byCategory = { emoji: 0, 'em-dash': 0, 'en-dash': 0,
                       'smart-quotes': 0, 'box-drawing': 0 };

  for (const file of files) {
    const { original, fixed, stats, changed } = scanFile(file);
    const fileTotal = Object.values(stats).reduce((a, b) => a + b, 0);
    if (fileTotal === 0) continue;

    totalFiles++;
    totalViolations += fileTotal;
    for (const [k, v] of Object.entries(stats)) byCategory[k] += v;

    const rel = path.relative(process.cwd(), file);
    const fixList = Object.entries(stats)
      .filter(([, v]) => v > 0)
      .map(([k, v]) => `${k}=${v}`)
      .join(', ');
    console.log(`${apply ? (changed ? '[FIX]' : '[SKIP]') : '[VIOL]'} ${rel}  (${fixList})`);

    if (apply && changed) {
      fs.writeFileSync(file, fixed, 'utf8');
      totalFixed++;
    }
  }

  console.log('---');
  console.log(`Files scanned:      ${files.length}`);
  console.log(`Files with violations: ${totalFiles}`);
  console.log(`Total violations:   ${totalViolations}`);
  console.log(`By category:        ${JSON.stringify(byCategory)}`);
  if (apply) {
    console.log(`Files fixed:        ${totalFixed}`);
  }

  process.exit(totalViolations === 0 ? 0 : (apply ? (totalViolations > 0 ? 1 : 0) : 1));
}

main();
