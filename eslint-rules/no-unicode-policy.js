// eslint-rules/no-unicode-policy.js
// Enforces STD-DOC-003: No emoji / Unicode graphics in source code and documentation
// Derived from: DOC-002-eslint-integration.md section 10.5

const emojiPattern =
  /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{27BF}\u{FE00}-\u{FEFF}\u{1F900}-\u{1F9FF}\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{2702}-\u{27B0}]/u;

const unicodeGraphicsPattern = /[\u2500-\u257F\u2580-\u259F\u25A0-\u25FF\u2800-\u28FF]/;

const noEmoji = {
  meta: {
    type: "problem",
    docs: {
      description: "No emoji in source code (STD-DOC-003)",
    },
    messages: {
      noEmoji:
        "Emoji are prohibited in source code. Use text tags like [OK], [FAIL] instead (STD-DOC-003).",
    },
  },
  create(context) {
    const sourceCode = context.sourceCode || context.getSourceCode();
    const text = sourceCode.getText();
    const lines = text.split("\n");
    return {
      Program() {
        lines.forEach((line, index) => {
          if (emojiPattern.test(line)) {
            context.report({ loc: { line: index + 1, column: 0 }, messageId: "noEmoji" });
          }
        });
      },
    };
  },
};

const noUnicodeGraphics = {
  meta: {
    type: "problem",
    docs: {
      description: "No Unicode box/line drawing in source code (STD-DOC-003)",
    },
    messages: {
      noUnicodeGraphics:
        "Unicode box/line drawing characters are prohibited. Use ASCII or text alternatives (STD-DOC-003).",
    },
  },
  create(context) {
    const sourceCode = context.sourceCode || context.getSourceCode();
    const text = sourceCode.getText();
    const lines = text.split("\n");
    return {
      Program() {
        lines.forEach((line, index) => {
          if (unicodeGraphicsPattern.test(line)) {
            context.report({ loc: { line: index + 1, column: 0 }, messageId: "noUnicodeGraphics" });
          }
        });
      },
    };
  },
};

const noEmojiInMd = {
  meta: {
    type: "problem",
    docs: {
      description: "No emoji in Markdown documentation (STD-DOC-002 section 4.4, STD-DOC-003)",
    },
    messages: {
      noEmojiInMd:
        "Emoji are prohibited in Markdown documentation. Use text tags like [OK], [FAIL] instead (STD-DOC-002 section 4.4, STD-DOC-003).",
    },
  },
  create(context) {
    const sourceCode = context.sourceCode || context.getSourceCode();
    const text = sourceCode.getText().replace(/```[\s\S]*?```/g, "");
    const lines = text.split("\n");
    return {
      Program() {
        lines.forEach((line, index) => {
          if (emojiPattern.test(line)) {
            context.report({ loc: { line: index + 1, column: 0 }, messageId: "noEmojiInMd" });
          }
        });
      },
    };
  },
};

const noUnicodeGraphicsInMd = {
  meta: {
    type: "problem",
    docs: {
      description: "No Unicode box/line drawing in Markdown documentation (STD-DOC-003)",
    },
    messages: {
      noUnicodeGraphicsInMd:
        "Unicode box/line drawing characters are prohibited in Markdown. Use ASCII or code blocks (STD-DOC-003).",
    },
  },
  create(context) {
    const sourceCode = context.sourceCode || context.getSourceCode();
    const text = sourceCode.getText().replace(/```[\s\S]*?```/g, "");
    const lines = text.split("\n");
    return {
      Program() {
        lines.forEach((line, index) => {
          if (unicodeGraphicsPattern.test(line)) {
            context.report({ loc: { line: index + 1, column: 0 }, messageId: "noUnicodeGraphicsInMd" });
          }
        });
      },
    };
  },
};

export default {
  meta: {
    name: "no-unicode-policy",
    version: "1.0.0",
  },
  rules: {
    "no-emoji": noEmoji,
    "no-unicode-graphics": noUnicodeGraphics,
    "no-emoji-in-md": noEmojiInMd,
    "no-unicode-graphics-in-md": noUnicodeGraphicsInMd,
  },
};
