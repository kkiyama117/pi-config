# Task: add metrics.py — run aggregation and threshold checks (agent-loop v2, task-105)

## Background

suggest_v1.md §7 meta-loop gaps: the five fixed points lack 評価指標 (metrics)
and the 4-axis monitoring lacks success-rate / false-positive aggregation.
Raw data already exists in `agent-loop-v1/memory/` (cost-log.md,
past-runs.md, known-failures.md) but nothing aggregates it, so acceptance
rules like "cost <= 2x median" and the 30% verifier-theater threshold cannot
be checked mechanically (design: DESIGN.md §2.5 — the aggregator comes
BEFORE the recording hook, task-204).

## Completion condition (BFV Kernel)

1. `agent-loop-v1/metrics.py` exists: python3 stdlib only, no third-party
   imports, same style as `pi_usage.py` (argparse or sys.argv subcommands).
2. `python3 metrics.py summary [--memory-dir DIR]` prints one line per run
   (parsed from cost-log.md + past-runs.md + known-failures.md):
   `run=<id> calls=<n> tokens=<n> cost=<usd> verify_fails=<n>
   review_fails=<n> outcome=<done|aborted|unknown>`
   followed by an aggregate block: total runs, done rate, review-fail rate
   (review-fail runs / total runs), escalated-run count.
3. `python3 metrics.py check-cost --run <id> [--memory-dir DIR]` exits 0 if
   the run's total cost is <= 2x the median total cost of prior runs with
   `outcome=done`, non-zero otherwise (prints both numbers). With fewer than
   2 prior done runs it exits 0 with a "no baseline" note. A `--factor N`
   flag overrides the 2x default.
4. `python3 metrics.py theater [--memory-dir DIR]` reports
   `verifier-theater` entries from known-failures.md as
   `theater=<n> reviewed_pass=<n> rate=<pct>` and exits non-zero when rate
   exceeds 30% (threshold flag `--max-pct`, default 30). With no entries it
   reports rate=0 and exits 0 (recording starts in Phase D, task-204).
5. Malformed/truncated memory lines are skipped, never fatal (same tolerance
   policy as pi_usage.py).
6. Unit test passes (see Regression test). loop.sh is NOT modified.

## Non-negotiables

- python3 stdlib only; no new binaries, no pip installs.
- Read-only: metrics.py never writes to memory/ files.
- Do not change existing memory line formats; parse what is there.

## Stop-and-ask conditions

- If cost-log.md lines exist whose format does not match
  `run=<id> stage=<s> model=<m> tokens=<n> cost=<c>`, stop and ask before
  inventing a second parser.

## Out of scope

- Recording verifier-theater events (task-204, Phase D).
- Weekly digest generation (task-205).
- Any loop.sh integration (acceptance rules cite metrics.py manually until
  Phase D wires it in).

## Acceptance rules (harness-change gate)

- All `~/.pi` VERIFIERS checks pass.
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median implement-stage cost of task-001..004
  (memory/cost-log.md baseline — this task's own tool, checked manually).
- No new failure-mode category added to memory/known-failures.md by this run.
- The regression test below passes.

## Regression test

Script: `agent-loop-v1/tests/test_metrics.py` (new; python3 stdlib unittest,
runnable as `python3 tests/test_metrics.py`). Using a fixture memory dir
written by the test (synthetic values only):

1. Three synthetic runs (two done, one aborted; one with a review-fail entry)
   → `summary` output contains the correct per-run lines and a done rate of
   2/3.
2. `check-cost` passes for a run at 1.5x median and fails for a run at 3x.
3. `theater` exits 0 with rate=0 on no entries; exits non-zero when 2 of 4
   reviewed-pass runs have theater entries (50% > 30%).
4. A malformed line mixed into cost-log.md does not raise.
