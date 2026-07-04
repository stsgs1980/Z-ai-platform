# Session Handoff — 2026-07-04

## Context

Z-ai-platform: governance system with 3-layer enforcement (daemon → pre-commit hooks → CI).
All code passes. Sandbox tests fully pass (45/45). Multiple agents tested (GLM-5.2, GLM-5.1, GLM-5-Turbo).

## Completed

- `.gitattributes` — LF enforced for `*.sh`
- All .sh files converted CRLF → LF
- `edge-case-tests.sh` bugfix: `echo "" > file` → `: > file`
- All verifiers pass: verify-standards (14/14), verify-id-graph (13/13), verify-skills (7/7)
- 33/33 vitest tests pass
- Worklog updated
- **Test 7 bugfix**: trailing slash from glob pattern defeated `[ -L ]` symlink check
- **Russian language setting**: AGENT_RULES.md §1.1 — all agent communication in Russian
- **Sandbox tests: 45/45 PASS** (real sandbox at chat.z.ai)
- **Verifier daemon: PASS** (polling + file watch verified)
- **Bootstrap.sh: PASS** (full flow in sandbox)

## Sandbox test results (real sandbox, 2026-07-04)

| Suite                       | Result    | Notes                   |
| --------------------------- | --------- | ----------------------- |
| sandbox-integration-test.sh | 20/20     | All PASS                |
| sandbox-behavior-test.sh    | 10/10     | All PASS                |
| edge-case-tests.sh          | 15/15     | All PASS                |
| verifier-daemon.sh          | PASS      | Polling + file watch OK |
| **Total**                   | **45/45** | **All PASS**            |

## Sandbox agent behavior

| Agent       | `curl ... \| bash`          | `git clone` | Language                 |
| ----------- | --------------------------- | ----------- | ------------------------ |
| GLM-5.2     | Refuses                     | Executes    | English                  |
| GLM-5.1     | Executes (after inspection) | Executes    | Russian (after reminder) |
| GLM-5-Turbo | Refuses                     | Executes    | English                  |

**Note**: All agents execute `git clone` (safe — downloads only). All agents refuse `curl ... | bash` initially but may execute after inspection. Russian language setting works after reminder in chat.

## Remaining tasks

1. **Issue #2** — rename AGENT_RULES.md → AGENT-RULES.md (143 refs, 34 files) — defer

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

```bash
# In new session, run in sandbox:
git clone --recurse-submodules https://github.com/stsgs1980/Z-ai-platform.git /home/z/my-project/Z-ai-platform
curl https://z-cdn.chatglm.cn/fullstack/init-fullstack_1775040338514.sh | bash
bash /home/z/my-project/Z-ai-platform/bootstrap.sh
cd /home/z/my-project/Z-ai-platform
bash tests/sandbox-integration-test.sh
bash tests/sandbox-behavior-test.sh
bash tests/edge-case-tests.sh
bash .zai/verifier-daemon.sh start
# Wait 10s, touch a file, check logs
bash .zai/verifier-daemon.sh status
bash .zai/verifier-daemon.sh stop
```
