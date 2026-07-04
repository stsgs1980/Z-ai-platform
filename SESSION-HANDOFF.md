# Session Handoff — 2026-07-04

## Context

Z-ai-platform: governance system with 3-layer enforcement (daemon → pre-commit hooks → CI).
All code passes. Sandbox tests partially run (WSL). Remaining: test in real Linux sandbox.

## Completed

- `.gitattributes` — LF enforced for `*.sh`
- All .sh files converted CRLF → LF
- `edge-case-tests.sh` bugfix: `echo "" > file` → `: > file`
- All verifiers pass: verify-standards (14/14), verify-id-graph (13/13), verify-skills (7/7)
- 33/33 vitest tests pass
- Worklog updated

## Sandbox test results (WSL)

| Suite                       | Result | Notes                                      |
| --------------------------- | ------ | ------------------------------------------ |
| sandbox-integration-test.sh | 18/20  | 2 FAIL — skills not at /home/z/my-project/ |
| sandbox-behavior-test.sh    | 7/10   | 3 FAIL — same reason                       |
| edge-case-tests.sh          | 15/15  | All PASS                                   |

## Remaining tasks

1. **Run in real sandbox** — all 3 test suites need Linux `/home/z/my-project/`
2. **Test verifier-daemon.sh** — needs inotifywait (Linux)
3. **Test bootstrap.sh** — full flow in sandbox
4. **Issue #2** — rename AGENT_RULES.md → AGENT-RULES.md (143 refs, 34 files) — defer

## Key files

- `tests/sandbox-integration-test.sh` — 20 integration tests
- `tests/sandbox-behavior-test.sh` — 10 behavior tests
- `tests/edge-case-tests.sh` — 15 edge case tests
- `.zai/verifier-daemon.sh` — background file watcher (inotifywait + polling)
- `bootstrap.sh` — sandbox setup script
- `standards/scripts/verify-standards.js` — V01-V17 checks
- `standards/scripts/verify-id-graph.js` — G01-G15 checks
- `standards/scripts/verify-skills.js` — skills checks

## How to continue

```
# In new session, run in sandbox:
cd /home/z/my-project/Z-ai-platform
bash tests/sandbox-integration-test.sh
bash tests/sandbox-behavior-test.sh
bash tests/edge-case-tests.sh
bash .zai/verifier-daemon.sh start
# Wait 10s, touch a file, check logs
bash .zai/verifier-daemon.sh status
bash .zai/verifier-daemon.sh stop
```
