// eslint.config.js
// Enforces: STD-DOC-002 (Markdown Standard), STD-DOC-003 (No-Unicode Policy)
//
// Architecture:
// 1. Custom markdown-snippets processor extracts code blocks from .md
//    (wraps eslint-plugin-markdown's processor, filters parsing errors)
// 2. TS parser handles JS/TS/TSX code blocks (they parse as real code)
// 3. Non-JS code blocks (bash, yaml, css, etc.) are skipped — ESLint is a JS linter
// 4. Custom rules run on .md raw text AND on JS/TS code blocks
// 5. Parsing errors (ruleId === null) from incomplete snippets are filtered
//    in postprocess — this is NOT a bypass; code snippets in docs are
//    never complete programs, same as eslint-plugin-markdown already
//    filters eol-last and unicode-bom as UNSATISFIABLE_RULES.

import markdown from "eslint-plugin-markdown";
import tsParser from "@typescript-eslint/parser";
import noUnicodePolicy from "./eslint-rules/no-unicode-policy.js";
import codeBlockLanguage from "./eslint-rules/code-block-language.js";
import markdownSnippetsProcessor from "./eslint-processors/markdown-snippets.js";

const codeBlockLanguagePlugin = {
  meta: { name: "code-block-language", version: "1.0.0" },
  rules: { "require-language": codeBlockLanguage },
};

export default [
  // --- Global ignores ---
  {
    ignores: [
      "node_modules/**",
      ".next/**",
      "dist/**",
      "build/**",
      "coverage/**",
    ],
  },

  // --- Markdown: code extraction ---
  // Use markdown.configs.recommended for rule overrides (no-undef etc. off for .md/**),
  // but OVERRIDE the processor with our custom one that filters parsing errors.
  ...markdown.configs.recommended,

  // Override the markdown processor with our snippet-aware one
  {
    files: ["**/*.md"],
    processor: markdownSnippetsProcessor,
  },

  // --- Code blocks INSIDE .md files (virtual .md/** files) ---
  // TS parser so JS/TS/TSX code blocks parse correctly.
  // Only custom STD-DOC-003 rules run here (emoji/unicode checks).
  // Standard rule overrides come from markdown.configs.recommended above.
  // Unused eslint-disable directives in doc code snippets are expected
  // (examples showing how to disable rules — the disable is "unused" because
  // the snippet doesn't actually violate the rule in isolation).
  {
    files: ["**/*.md/**"],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        ecmaFeatures: { jsx: true },
      },
    },
    linterOptions: {
      reportUnusedDisableDirectives: false,
    },
    plugins: {
      "no-unicode-policy": noUnicodePolicy,
    },
    rules: {
      // STD-DOC-003: No emoji/unicode in code examples
      "no-unicode-policy/no-emoji": "error",
      "no-unicode-policy/no-unicode-graphics": "error",
    },
  },

  // --- .md files themselves (raw text, not code blocks) ---
  // Custom rules scan raw text for emoji, unicode graphics, and missing code block languages.
  {
    files: ["**/*.md"],
    plugins: {
      "no-unicode-policy": noUnicodePolicy,
      "code-block-language": codeBlockLanguagePlugin,
    },
    rules: {
      // STD-DOC-003 [C] Critical: No emoji in Markdown documentation
      "no-unicode-policy/no-emoji-in-md": "error",

      // STD-DOC-003 [C] Critical: No Unicode icons in Markdown documentation
      "no-unicode-policy/no-unicode-graphics-in-md": "error",

      // STD-DOC-002 section 5.4: Code blocks must specify a language
      "code-block-language/require-language": "error",
    },
  },

  // --- Source code files (.ts, .tsx, .js, .jsx) ---
  {
    files: ["**/*.{ts,tsx,js,jsx}"],
    languageOptions: {
      parser: tsParser,
      parserOptions: {
        ecmaVersion: "latest",
        sourceType: "module",
        ecmaFeatures: { jsx: true },
      },
    },
    plugins: {
      "no-unicode-policy": noUnicodePolicy,
    },
    rules: {
      // STD-DOC-003 [C] Critical: No emoji in production code / UI strings
      "no-unicode-policy/no-emoji": "error",

      // STD-DOC-003 [C] Critical: No Unicode graphics in production code
      "no-unicode-policy/no-unicode-graphics": "error",

      // STD-DOC-002: no irregular whitespace (NBSP, ZWSP, etc.)
      "no-irregular-whitespace": "error",
    },
  },
];
