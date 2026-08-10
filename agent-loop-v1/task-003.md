# Task: add per-stage elapsed timing to agent-loop v1 (loop.sh)

## Completion condition (BFV Kernel)

`agent-loop-v1/loop.sh` must log how long each stage took, in a grep-able
format:

1. Every `pi_call` stage (plan / implement / review) logs its wall-clock
   duration at completion:
   `stage <name> took <N>s` (example: `stage plan took 150s`).
2. The gate wait is measured too: when a gate is approved/rejected, log
   `gate <GATE-1|GATE-2> waited <N>s`.
3. Timing is measured with bash builtins or coreutils only (`SECONDS`,
   `date +%s`) — no new external dependencies.
4. `--dry-run` mode shows the same timing lines (with ~0s durations) and
   exits 0.
5. `bash -n loop.sh` passes.
6. The existing cost tracking, gates, model routing, worktree isolation,
   VERIFIERS, and the concurrency lock are untouched.

## Non-negotiables

- Do not change model routing, gates, worktree isolation, VERIFIERS, or the
  concurrency lock.
- Do not add external dependencies (no pip/npm installs, no new binaries).
- Human-facing gate prompts and log output must stay readable.
- Keep the change minimal: one feature, small diff.

## Stop-and-ask conditions

- If a stage's duration cannot be measured without touching the stage's
  logic (e.g. the stage function returns before the timing line is logged),
  stop and ask instead of restructuring the loop.

## Out of scope

- Wall-clock stage timeouts or caps (deferred by design — this task only
  measures and reports).
- Cost-based abort/guardrails.
- Changing model routing or any other loop behavior.
