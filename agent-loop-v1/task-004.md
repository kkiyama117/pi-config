# Task: per-attempt duration attribution for agent-loop v1 (loop.sh)

## Background (reviewer follow-up, task-003 cycle 3)

Task-003 added `stage <name> took <N>s` (total wall-clock per stage) and
`gate <name> waited <N>s`. The task-003 reviewer flagged a gap:

> Duration conflates the primary and fallback attempts. When the primary
> model fails and the fallback succeeds, `stage plan took 300s` covers both
> attempts, while `cost-log.md` attributes the call only to the successful
> model. That makes the timing unusable for per-model attribution.

## Completion condition (BFV Kernel)

`agent-loop-v1/loop.sh` must attribute durations per model attempt:

1. Every actual `pi` invocation logs its own duration with the model name:
   `pi attempt model=<model> took <N>s` (primary attempt and fallback
   attempt each get their own line when the fallback runs).
2. The existing lines stay intact and unchanged in meaning:
   `stage <name> took <N>s` (total for the stage, including fallback time)
   and `gate <name> waited <N>s`.
3. Attempt timing uses the same mechanism as task-003 (bash builtin
   `SECONDS` or coreutils) — no new external dependencies.
4. `--dry-run` mode logs `pi attempt model=<model> took 0s` for each
   would-be attempt and exits 0.
5. `bash -n loop.sh` passes.
6. After the change, per-model attribution is possible: for every
   `cost-log.md` line there is a matching `pi attempt` line with the same
   model and stage.

## Non-negotiables

- Do not change model routing, gates, worktree isolation, VERIFIERS, or the
  concurrency lock.
- Do not change the task-003 output lines' meaning or format.
- Do not add external dependencies (no pip/npm installs, no new binaries).
- Keep the change minimal: one feature, small diff.

## Stop-and-ask conditions

- If logging the per-attempt duration requires restructuring `run_pi`'s
  failure handling (it currently returns the process status; timing must be
  logged inside the attempt, not after), stop and ask instead of guessing.

## Out of scope

- Wall-clock stage timeouts or caps (still deferred by design).
- Cost-based abort/guardrails.
- Changing model routing or any other loop behavior.
