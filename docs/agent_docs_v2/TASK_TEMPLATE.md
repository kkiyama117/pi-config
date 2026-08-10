# Task template — agent-loop v2 (mandatory structure)

Every v2 task file (`tasks/task-*.md`) MUST contain the sections below, in this
order. The file is passed verbatim to `loop.sh --task-file` and read by the
planner, worker, and reviewer models, so it must be self-contained: assume the
reader has NO context beyond this file and the target repository.

Sections marked (v1) existed in task-001..004; `Acceptance rules` and
`Regression test` are new in v2 and are REQUIRED (design: DESIGN.md §2.1).

```markdown
# Task: <one-line imperative summary> (agent-loop v2, task-NNN)

## Background

Why this change exists. Cite the source (suggest_v1.md section, reviewer
finding, known-failures entry). 3-8 lines.

## Completion condition (BFV Kernel)                                    (v1)

Numbered, testable conditions. For every proposed change ask: "can it be
omitted and completion still be proven?" — if yes, it does not belong here.
Each condition must be checkable by a command or by reading a specific file.
Always include:
- `bash -n loop.sh` passes (when loop.sh is touched)
- existing log line formats stay intact and unchanged in meaning

## Non-negotiables                                                      (v1)

Hard constraints. At minimum:
- Do not change model routing, gates, worktree isolation, or the
  concurrency lock (unless the task IS about one of them — then name it).
- No new external dependencies (no pip/npm installs, no new binaries).
- Keep the change minimal: one feature, small diff.
- Do not touch paths matched by the repo DENYLIST.

## Stop-and-ask conditions                                              (v1)

Situations where the worker must stop and ask the human instead of guessing.

## Out of scope                                                         (v1)

Explicitly deferred work, so the reviewer can reject scope creep.

## Acceptance rules (harness-change gate)                              (NEW)

Pre-declared conditions the human gate enforces at GATE-2. Default set —
tighten per task, never loosen silently:
- All repo VERIFIERS checks pass.
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median cost of comparable past tasks
  (memory/cost-log.md baseline; after task-105: `metrics.py check-cost`).
- No new failure-mode category added to memory/known-failures.md by this run.
- The Regression test below passes.

## Regression test                                                     (NEW)

A deterministic test proving the change works AND that the old behavior is
preserved. Follow the v1 fake-pi-stub pattern (task-003/004): a temp git
repo and/or a stub `pi` on PATH, no real model calls, no network. State the
exact script path (e.g. `agent-loop-v1/tests/test_<feature>.sh`), what it
asserts, and its expected exit code (0 on pass, non-zero on fail).
```

## Drafting rules

1. English, contract style (conditions, not step-by-step edits). The planner
   model produces the plan; the task file defines "done".
2. No placeholders: no "TBD", "handle errors appropriately", "similar to
   task-N". Every referenced file, flag, and log format must be spelled out.
3. One task = one feature = one loop run = one small diff. If a draft needs
   two unrelated diffs, split it.
4. File naming: `tasks/task-NNN-<kebab-slug>.md`. Numbers: 1XX = Phase A-C
   (this plan), 2XX = Phase D (drafted from BACKLOG.md).
5. After drafting a 2XX task from BACKLOG.md, list it in README.md's task
   index (status: 未着手) in the same change.
