import { describe, it, expect } from "vitest";
import { readFileSync } from "fs";

describe("project infrastructure", () => {
  it("package.json exists and has correct name", () => {
    const pkg = JSON.parse(readFileSync("package.json", "utf-8"));
    expect(pkg.name).toBe("z-ai-dense-graph");
    expect(pkg.devDependencies).toHaveProperty("typescript");
    expect(pkg.devDependencies).toHaveProperty("eslint");
    expect(pkg.devDependencies).toHaveProperty("prettier");
    expect(pkg.devDependencies).toHaveProperty("husky");
    expect(pkg.devDependencies).toHaveProperty("vitest");
  });

  it("tsconfig.json exists and strict mode is on", () => {
    const tsconfig = JSON.parse(readFileSync("tsconfig.json", "utf-8"));
    expect(tsconfig.compilerOptions.strict).toBe(true);
  });

  it(".gitignore excludes .env and node_modules/", () => {
    const gitignore = readFileSync(".gitignore", "utf-8");
    expect(gitignore).toContain(".env");
    expect(gitignore).toContain("node_modules/");
  });

  it(".env is not tracked by git", () => {
    const { execSync } = require("child_process");
    const tracked = execSync("git ls-files .env", { encoding: "utf-8" }).trim();
    expect(tracked).toBe("");
  });

  it("prettier config exists", () => {
    const prettierrc = JSON.parse(readFileSync(".prettierrc", "utf-8"));
    expect(prettierrc).toHaveProperty("semi");
    expect(prettierrc).toHaveProperty("printWidth");
  });
});
