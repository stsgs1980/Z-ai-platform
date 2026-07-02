// eslint-rules/code-block-language.js
// Enforces STD-DOC-002 section 5.4: every fenced code block must specify a language
// Derived from: DOC-002-eslint-integration.md section 10.5.1

export default {
  meta: {
    type: "suggestion",
    docs: {
      description:
        "Require language specification in fenced code blocks (STD-DOC-002 section 5.4)",
    },
    messages: {
      missingLanguage:
        "Code block must specify a language. Use 'text' or 'bash' if unknown (STD-DOC-002 section 5.4).",
    },
  },
  create(context) {
    const sourceCode = context.sourceCode || context.getSourceCode();
    const text = sourceCode.getText();
    const lines = text.split("\n");

    const fenceRegex = /^```(\s*)$/;

    return {
      Program() {
        lines.forEach((line, index) => {
          if (fenceRegex.test(line)) {
            context.report({
              loc: { line: index + 1, column: 0 },
              messageId: "missingLanguage",
            });
          }
        });
      },
    };
  },
};
