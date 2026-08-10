# Task: add run-level cost and token budget guards (agent-loop v2, task-103)

## Background

suggest_v1.md P1-1 / §3.7 token budget management: v1 records cost per pi call
(`memory/cost-log.md`, EXIT-trap summary) but never aborts. suggest_v1
proposes a cost-only guard; that is insufficient here because cursor-family
models report cost 0 (QUESTIONS.md "Observed costs"), so an escalated run
(worker=gpt-5.6 via cursor) would sail past any USD budget. This task adds
BOTH a cost guard and a token guard, with a warn-then-abort shape matching
the guide's Slow Down / Kill stages (design: DESIGN.md §2.3).

## Completion condition (BFV Kernel)

1. New knobs in `agent-loop-v1/loop.sh` with these defaults:
   - `MAX_RUN_COST_USD="${MAX_RUN_COST_USD:-2.0}"` (0 = guard disabled)
   - `MAX_RUN_TOKENS="${MAX_RUN_TOKENS:-3000000}"` (0 = guard disabled)
   - `BUDGET_WARN_PCT="${BUDGET_WARN_PCT:-80}"`
2. After `record_usage_line()` updates `RUN_TOTAL_COST` / `RUN_TOTAL_TOKENS`,
   the guard checks (float compare via awk, integer compare for tokens):
   - total >= 100% of a non-zero budget →
     `die "run budget exceeded: <cost|tokens> <actual> > <limit> — stop and ask"`
     (the EXIT trap still emits the cost summary; verify this).
   - total >= BUDGET_WARN_PCT% of a non-zero budget → log
     `budget warning: <cost|tokens> at <pct>% of <limit>` and call `notify`,
     at most ONCE per run per budget type.
3. `--dry-run` runs never trigger the guard (no usage is recorded).
4. `agent-loop-v1/README.md` "Environment knobs" line documents the three new
   knobs and the cursor-cost-0 limitation (why the token guard exists).
5. `bash -n agent-loop-v1/loop.sh` passes; existing log/cost-log line formats
   stay intact and unchanged in meaning.

## Non-negotiables

- Do not change model routing, gates, worktree isolation, or the concurrency
  lock.
- No new external dependencies (bash + awk only).
- Keep the change minimal: guard function + calls + doc lines.
- Never fabricate costs: the guard only compares recorded totals.

## Stop-and-ask conditions

- If the guard has to fire inside `record_usage_if_any` (failure-path
  salvage) and aborting there would mask the original failure reason, stop
  and ask about ordering instead of guessing.

## Out of scope

- Daily/aggregate budgets across runs (Phase D; needs metrics.py, task-105).
- Cost-inversion detection (LOOP.md documents the criterion, task-104).
- Pause/resume semantics — v2 only warns and kills; no mid-run pause.

## Acceptance rules (harness-change gate)

- All `~/.pi` VERIFIERS checks pass.
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median implement-stage cost of task-001..004
  (memory/cost-log.md baseline).
- No new failure-mode category added to memory/known-failures.md by this run.
- The regression test below passes.

## Regression test

Script: `agent-loop-v1/tests/test_budget_guard.sh` (new; fake-pi-stub
pattern). Using a stub `pi` that emits a valid ok-stream with a fixed usage
(e.g. tokens=600000 cost=0.9 per call):

1. With `MAX_RUN_COST_USD=1.0`: first call passes with a `budget warning`
   line (90%), second call dies with `run budget exceeded`; the cost summary
   line is still emitted (EXIT trap).
2. With `MAX_RUN_COST_USD=0 MAX_RUN_TOKENS=1000000`: second call dies on the
   token guard (1.2M > 1M) even though cost stays under any USD limit
   (cursor-cost-0 scenario: also run once with cost=0 in the stub stream).
3. With both knobs 0: many calls, no warning, no abort.
4. Exit 0 iff all assertions hold.
