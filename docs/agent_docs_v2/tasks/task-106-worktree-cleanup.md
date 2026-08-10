# Task: auto-remove the worktree after a successful commit (agent-loop v2, task-106)

## Background

suggest_v1.md P2-3 / §3.3 Worktree.lifecycle: after a successful run the
worktree stays behind and the final log line only suggests manual removal.
The REJECT path already removes the worktree; the success path should too
(branch kept for the manual merge to develop).

## Completion condition (BFV Kernel)

1. On the GATE-2 approve path in `agent-loop-v1/loop.sh`, after a successful
   `git commit` on the loop branch, the worktree is removed:
   `( cd "$MAIN_REPO" && git worktree remove --force "$WT_DIR" ) || true`
   and a log line reports it:
   `worktree removed; branch <branch> kept — merge with: git merge <branch>`.
2. The loop branch is NOT deleted (manual merge to develop is unchanged).
3. `--dry-run` behavior is unchanged (no commit happens, so no removal; the
   existing "worktree left at ..." message may remain for dry runs and
   non-approve exits).
4. The GATE-2 reject/rollback path and its existing removal are unchanged.
5. The final "worktree left at ..." log line is only emitted when the
   worktree actually still exists.
6. `bash -n agent-loop-v1/loop.sh` passes; existing log line formats stay
   intact and unchanged in meaning.

## Non-negotiables

- Do not change model routing, gates, worktree isolation semantics
  (branch-per-loop stays), or the concurrency lock.
- No new external dependencies.
- Keep the change minimal: one feature, small diff.

## Stop-and-ask conditions

- If `git worktree remove --force` can fail in a way that would lose the
  committed work (it should not — the commit lives on the branch), stop and
  ask rather than adding recovery logic.

## Out of scope

- Auto-merging the loop branch into develop (still manual, v1 decision Q13).
- Pruning old worktrees from previous runs (one-off manual cleanup).

## Acceptance rules (harness-change gate)

- All `~/.pi` VERIFIERS checks pass.
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median implement-stage cost of task-001..004
  (memory/cost-log.md baseline; or `metrics.py check-cost` if task-105 is
  merged).
- No new failure-mode category added to memory/known-failures.md by this run.
- The regression test below passes.

## Regression test

Extend the existing fake-pi-stub success-path test (the one added for the
DONE-flag fix, commit 9050a6c) or add
`agent-loop-v1/tests/test_worktree_cleanup.sh`:

1. Drive a full stubbed run to a GATE-2 approve + commit (stdin-fed gate
   answers, fake pi on PATH).
2. Assert: the worktree directory no longer exists; the loop branch still
   exists and contains the commit; the log contains
   `worktree removed; branch`.
3. Drive a GATE-2 reject run: assert the existing rollback behavior is
   unchanged (worktree removed, branch deleted).
4. Exit 0 iff all assertions hold.
