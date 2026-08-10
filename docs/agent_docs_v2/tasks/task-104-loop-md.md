# Task: create LOOP.md, the stop-conditions charter, with a sync check (agent-loop v2, task-104)

## Background

suggest_v1.md P1-2 / §3.6 "停止基準は LOOP.md に明記" / "停止条件を
First-Class に": v1's stop conditions (cycle cap, escalation cap, refusal
conditions) are scattered across DESIGN.md, QUESTIONS.md, and loop.sh
defaults. This task creates `agent-loop-v1/LOOP.md` as the single canonical
document, WITHOUT making loop.sh parse it (design: DESIGN.md §2.4 — values
live in loop.sh env defaults; LOOP.md documents them; a deterministic check
keeps the two in sync).

Prerequisite: task-102 and task-103 are merged (their knobs/defaults are part
of the documented values).

## Completion condition (BFV Kernel)

1. `agent-loop-v1/LOOP.md` exists and contains, with the ACTUAL defaults
   from loop.sh at the time of writing:
   - Budget block: `max_run_cost_usd: 2.0`, `max_run_tokens: 3000000`,
     `budget_warn_pct: 80`, `stage_timeout_s: 900`.
   - Cycle block: `max_cycles: 3`, `max_escalations: 2`.
   - Kill criteria (human-executed, documented not automated):
     `kill_on_review_fail_streak: 3` (abort the task file, redesign it) and
     `kill_on_cost_inversion_runs: 3` (3 consecutive runs whose cost exceeds
     the value of the change — human judgment, logged in decisions-log.md).
   - Refusal-to-start conditions (dirty tree, red baseline, missing
     completion condition, protected branch) — copied from current behavior.
   - Escalation channel: herdr pane + `herdr notification` (gate waits).
   - A header note: "values mirror loop.sh env defaults; the sync check
     below fails if they drift".
2. Sync check script `agent-loop-v1/tests/test_loop_md_sync.sh` (new)
   extracts each `NAME="${NAME:-default}"` default for MAX_CYCLES,
   MAX_ESCALATIONS, STAGE_TIMEOUT_S, MAX_RUN_COST_USD, MAX_RUN_TOKENS,
   BUDGET_WARN_PCT from loop.sh and the corresponding `key: value` line from
   LOOP.md, and exits non-zero on any mismatch (with a message naming the
   drifted key).
3. A line invoking `agent-loop-v1/tests/test_loop_md_sync.sh` is appended to
   the `~/.pi` `VERIFIERS` file, so drift is caught by every future run's
   verify stage.
4. loop.sh itself is NOT modified by this task.

## Non-negotiables

- No parser: loop.sh must not read LOOP.md at runtime.
- No new external dependencies (bash + grep/sed/awk only).
- Keep the change minimal: LOOP.md + sync script + one VERIFIERS line.

## Stop-and-ask conditions

- If task-102/103 defaults differ from the values listed above at execution
  time, use the actual loop.sh values and note the discrepancy — but if a
  knob is missing entirely (task not merged), stop and ask.

## Out of scope

- Automating the kill criteria (streak detection belongs to metrics.py
  consumers, Phase D).
- Autonomy-tier fields in LOOP.md (task-203 adds them).

## Acceptance rules (harness-change gate)

- All `~/.pi` VERIFIERS checks pass (including the newly added sync line).
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median implement-stage cost of task-001..004
  (memory/cost-log.md baseline).
- No new failure-mode category added to memory/known-failures.md by this run.
- The regression test below passes.

## Regression test

The sync check itself is the regression test. Verify both directions:

1. `agent-loop-v1/tests/test_loop_md_sync.sh` exits 0 against the committed
   loop.sh + LOOP.md pair.
2. In a temp copy, change `MAX_CYCLES` default to 4 in loop.sh only: the
   script exits non-zero and names `max_cycles`.
3. In a temp copy, change `max_run_cost_usd` in LOOP.md only: the script
   exits non-zero and names `max_run_cost_usd`.
