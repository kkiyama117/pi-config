#!/usr/bin/env python3
"""metrics.py — run aggregation and threshold checks for agent-loop (task-105).

Subcommands (all take --memory-dir DIR; default: <this-dir>/memory):

  summary
      One line per run (parsed from cost-log.md + past-runs.md +
      known-failures.md):
        run=<id> calls=<n> tokens=<n> cost=<usd> verify_fails=<n>
        review_fails=<n> outcome=<done|aborted|unknown>
      followed by an aggregate block: total runs, done rate, review-fail rate
      (review-fail runs / total runs), escalated-run count.

  check-cost --run <id> [--factor N]
      Exit 0 when the run's total cost is <= N x the median total cost of
      PRIOR runs with outcome=done (N defaults to 2; "prior" = run ids
      strictly before <id> — ids are YYYYMMDD-HHMMSS timestamps). With fewer
      than 2 prior done runs it prints a "no baseline" note and exits 0.

  theater [--max-pct N]
      Reports verifier-theater entries from known-failures.md as
        theater=<n> reviewed_pass=<n> rate=<pct>
      and exits non-zero when the rate exceeds N% (default 30).
      reviewed_pass = runs with a done record. Theater recording starts in
      Phase D (task-204); empty input reports rate=0 and exits 0.

Tolerance policy (same as pi_usage.py): malformed/truncated memory lines are
skipped, never fatal. Read-only: metrics.py never writes to memory files.

Escalation proxy: there is no dedicated escalation record in the memory
files, so a run counts as escalated when it has verify-fail or review-fail
entries in known-failures.md (escalate_worker fires on both).

Uses only the Python 3 standard library (no pip installs).
"""

import os
import re
import sys

RUN_RE = re.compile(r"\brun=(\S+)")
COST_LOG_RE = re.compile(r"\brun=(\S+).*\btokens=(\d+)\b.*\bcost=([0-9.eE+-]+)\b")
TOTAL_COST_RE = re.compile(r"\brun=(\S+).*\btotal_cost=([0-9.eE+-]+)\b")
DONE_RE = re.compile(r"\bdone run=\S+")


class Run:
    def __init__(self, run_id):
        self.id = run_id
        self.calls = 0
        self.tokens = 0
        self.cost = 0.0
        self.verify_fails = 0
        self.review_fails = 0
        self.theater = 0
        self.done = False
        self.failed = False

    @property
    def outcome(self):
        if self.done:
            return "done"
        return "aborted" if self.failed else "unknown"


def fmt_cost(cost):
    """Trailing-zero-stripped %.6f (1.800000 -> 1.8, 0.03330936 -> 0.033309)."""
    s = f"{cost:.6f}"
    return s.rstrip("0").rstrip(".") or "0"


def pct(n, total):
    return "0.0" if total == 0 else f"{n / total * 100:.1f}"


def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.readlines()
    except OSError:
        return []


def parse_memory(memory_dir):
    """Union of run ids from cost-log.md + past-runs.md + known-failures.md."""
    runs = {}

    def get(run_id):
        r = runs.get(run_id)
        if r is None:
            r = runs[run_id] = Run(run_id)
        return r

    for line in read_lines(os.path.join(memory_dir, "cost-log.md")):
        m = COST_LOG_RE.search(line)
        if not m:
            continue  # malformed/truncated — skip, never fatal
        r = get(m.group(1))
        r.calls += 1
        r.tokens += int(m.group(2))
        r.cost += float(m.group(3))

    for line in read_lines(os.path.join(memory_dir, "past-runs.md")):
        m = RUN_RE.search(line)
        if not m:
            continue
        r = get(m.group(1))
        if DONE_RE.search(line):
            r.done = True

    for line in read_lines(os.path.join(memory_dir, "known-failures.md")):
        m = RUN_RE.search(line)
        if not m:
            continue
        r = get(m.group(1))
        r.failed = True
        if "verify-fail" in line:
            r.verify_fails += 1
        if "review-fail" in line:
            r.review_fails += 1
        if "verifier-theater" in line:
            r.theater += 1

    return runs


def cmd_summary(memory_dir):
    runs = parse_memory(memory_dir)
    lines = []
    for run_id in sorted(runs):
        r = runs[run_id]
        lines.append(
            f"run={r.id} calls={r.calls} tokens={r.tokens} cost={fmt_cost(r.cost)} "
            f"verify_fails={r.verify_fails} review_fails={r.review_fails} "
            f"outcome={r.outcome}"
        )
    total = len(runs)
    done = sum(1 for r in runs.values() if r.done)
    review_fail = sum(1 for r in runs.values() if r.review_fails > 0)
    escalated = sum(1 for r in runs.values() if r.verify_fails > 0 or r.review_fails > 0)
    lines.append(
        f"total_runs={total} done_rate={pct(done, total)}% "
        f"review_fail_rate={pct(review_fail, total)}% escalated_runs={escalated}"
    )
    return 0, "\n".join(lines) + "\n"


def cmd_check_cost(memory_dir, run_id, factor):
    runs = parse_memory(memory_dir)
    r = runs.get(run_id)
    if r is None:
        return 1, f"run={run_id} not found in memory\n"
    priors = sorted(r.cost for r in runs.values() if r.id < run_id and r.done)
    if len(priors) < 2:
        return 0, f"no baseline: fewer than 2 prior done runs ({len(priors)})\n"
    median = priors[len(priors) // 2] if len(priors) % 2 else \
        (priors[len(priors) // 2 - 1] + priors[len(priors) // 2]) / 2
    limit = factor * median
    msg = (f"run={run_id} cost={fmt_cost(r.cost)} "
           f"median_prior_done={fmt_cost(median)} limit={fmt_cost(limit)} (factor={factor})\n")
    return (0 if r.cost <= limit else 1), msg


def cmd_theater(memory_dir, max_pct):
    runs = parse_memory(memory_dir)
    theater = sum(1 for r in runs.values() if r.theater > 0)
    reviewed = sum(1 for r in runs.values() if r.done)
    if reviewed:
        rate = theater / reviewed * 100
    else:
        rate = 0.0 if theater == 0 else 100.0
    msg = f"theater={theater} reviewed_pass={reviewed} rate={rate:.1f}%\n"
    return (0 if rate <= max_pct else 1), msg


def default_memory_dir():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "memory")


def main():
    argv = sys.argv[1:]
    if not argv:
        print("usage: metrics.py summary|check-cost|theater [--memory-dir DIR] "
              "[--run ID] [--factor N] [--max-pct N]", file=sys.stderr)
        return 2
    cmd = argv[0]
    memory_dir = default_memory_dir()
    run_id = None
    factor = 2.0
    max_pct = 30.0
    i = 1
    while i < len(argv):
        opt = argv[i]
        if opt == "--memory-dir" and i + 1 < len(argv):
            memory_dir = argv[i + 1]
            i += 2
        elif opt == "--run" and i + 1 < len(argv):
            run_id = argv[i + 1]
            i += 2
        elif opt == "--factor" and i + 1 < len(argv):
            factor = float(argv[i + 1])
            i += 2
        elif opt == "--max-pct" and i + 1 < len(argv):
            max_pct = float(argv[i + 1])
            i += 2
        else:
            print(f"unknown option: {opt}", file=sys.stderr)
            return 2

    if cmd == "summary":
        rc, out = cmd_summary(memory_dir)
    elif cmd == "check-cost":
        if run_id is None:
            print("check-cost requires --run <id>", file=sys.stderr)
            return 2
        rc, out = cmd_check_cost(memory_dir, run_id, factor)
    elif cmd == "theater":
        rc, out = cmd_theater(memory_dir, max_pct)
    else:
        print(f"unknown subcommand: {cmd}", file=sys.stderr)
        return 2
    sys.stdout.write(out)
    return rc


if __name__ == "__main__":
    sys.exit(main())
