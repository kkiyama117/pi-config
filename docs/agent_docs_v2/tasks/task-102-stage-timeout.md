# Task: enable the per-stage wall-clock timeout by default (agent-loop v2, task-102)

## Background

suggest_v1.md P0-2 / §3.8 "Token Explosion": task-004's single implement call
consumed 1.16M tokens with no wall-clock cap. The plumbing already exists —
`run_pi()` wraps every pi call in `timeout "$STAGE_TIMEOUT_S"` — but the
default is 0 (disabled, per v1 decision Q11). This task turns the default on
and makes timeout failures distinguishable in the logs.

## Completion condition (BFV Kernel)

1. The default in `agent-loop-v1/loop.sh` changes from
   `STAGE_TIMEOUT_S="${STAGE_TIMEOUT_S:-0}"` to
   `STAGE_TIMEOUT_S="${STAGE_TIMEOUT_S:-900}"`. Setting the variable to 0
   still disables the timeout (coreutils `timeout 0` semantics — document
   this in the comment above the line, replacing the Q11 "no cap in v1"
   comment with a pointer to this task).
2. When an attempt is killed by the timeout (exit code 124), `run_pi()` logs
   `pi attempt model=<model> TIMEOUT after <N>s stage=<stage>` in addition to
   the existing `pi attempt model=<model> took <N>s stage=<stage>` line, and
   the normal failure path runs (usage salvage via record_usage_if_any, then
   fallback attempt — no new control flow).
3. `agent-loop-v1/README.md` "Environment knobs" line is updated:
   `STAGE_TIMEOUT_S` (default 900, 0 = no timeout).
4. `bash -n agent-loop-v1/loop.sh` passes; all existing log line formats stay
   intact and unchanged in meaning (`stage <name> took <N>s`,
   `gate <name> waited <N>s`, cost-log lines).

## Non-negotiables

- Do not change model routing, gates, worktree isolation, or the concurrency
  lock.
- No new external dependencies.
- Keep the change minimal: default value + timeout log line + doc line.
- Do not add per-model or per-stage differentiated timeouts (single knob).

## Stop-and-ask conditions

- If `timeout` turns out not to be available on the host or `run_pi`'s exit
  code handling cannot distinguish 124 without restructuring the function,
  stop and ask.

## Out of scope

- Cost/token budgets (task-103).
- Turn-count budgets passed to `pi -p` itself (future work; requires pi CLI
  support investigation).
- Gate wait timeouts (gates still wait forever — v1 decision Q6 unchanged).

## Acceptance rules (harness-change gate)

- All `~/.pi` VERIFIERS checks pass.
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median implement-stage cost of task-001..004
  (memory/cost-log.md baseline).
- No new failure-mode category added to memory/known-failures.md by this run.
- The regression test below passes.

## Regression test

Script: `agent-loop-v1/tests/test_stage_timeout.sh` (new; fake-pi-stub
pattern). It must:

1. Put a stub `pi` on PATH that sleeps 5s, and a second stub that returns a
   valid ok-stream instantly (fallback model).
2. Run the pi-call path with `STAGE_TIMEOUT_S=1`: assert the log contains
   `TIMEOUT after` for the primary attempt AND a successful fallback attempt
   line (2 `pi attempt` lines total).
3. Run with `STAGE_TIMEOUT_S=0` and the sleeping stub sleeping 1s: assert no
   TIMEOUT line and a successful attempt (0 disables).
4. Exit 0 iff all assertions hold.
