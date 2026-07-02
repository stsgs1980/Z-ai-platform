// eslint.config.js
// Derived from: DOC-002-eslint-integration.md section 10.3
// Enforces: STD-DOC-002 (Markdown Standard), STD-DOC-003 (No-Unicode Policy)

import markdown from "eslint-plugin-markdown";
import noUnicodePolicy from "./eslint-rules/no-unicode-policy.js";

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

  // --- Markdown files (.md) ---
  // eslint-plugin-markdown extracts code blocks from .md files
  // and presents them as virtual JS/TS files for linting.
  ...markdown.configs.recommended,

  {
    files: ["**/*.md/**"],          // virtual files inside .md code blocks
    rules: {
      // STD-DOC-002: Code blocks must specify a language
      "markdown/code-block-language": "warn",

      // STD-DOC-003: No emoji/Unicode graphics in code blocks
      "no-unicode-policy/no-emoji": "error",
      "no-unicode-policy/no-unicode-graphics": "error",

      // General quality rules for code inside .md blocks
      "no-undef": "off",            // code snippets in docs may be incomplete
      "no-unused-vars": "off",      // examples don't need every variable used
      "no-console": "off",          // examples often show console usage
    },
  },

  {
    files: ["**/*.md"],             // the .md files themselves (not code blocks)
    plugins: {
      "no-unicode-policy": noUnicodePolicy,
    },
    rules: {
      // STD-DOC-003 section 4: No emoji in Markdown documentation
      // Severity: error ([C] Critical)
      "no-unicode-policy/no-emoji-in-md": "error",

      // STD-DOC-003 section 4: No Unicode icons in Markdown documentation
      "no-unicode-policy/no-unicode-graphics-in-md": "error",
    },
  },

  // --- Source code files (.ts, .tsx, .js, .jsx) ---
  {
    files: ["**/*.{ts,tsx,js,jsx}"],
    plugins: {
      "no-unicode-policy": noUnicodePolicy,
    },
    rules: {
      // STD-DOC-003 [C] Critical: No emoji in production code / UI strings
      "no-unicode-policy/no-emoji": "error",

      // STD-DOC-003 [C] Critical: No Unicode graphics in production code
      "no-unicode-policy/no-unicode-graphics": "error",

      // STD-DOC-002 indirectly: no irregular whitespace (NBSP, ZWSP, etc.)
      "no-irregular-whitespace": "error",
    },
  },
];
