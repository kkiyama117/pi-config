# Task: enforce a structural path DENYLIST in verify_repo (agent-loop v2, task-101)

## Background

suggest_v1.md P0-1 / §3.8 "Over-Reach" failure mode: today the only thing
stopping the worker from touching credentials or unrelated paths is a soft
instruction ("no unrelated refactors") plus `git diff --check`. This task adds
a structural check: a per-repo `DENYLIST` file whose patterns are enforced by
`verify_repo()` in `agent-loop-v1/loop.sh`, turning the soft rule into a
deterministic verdict.

NOTE — the snippet in suggest_v1.md §8 (P0-1) has two known defects and must
NOT be implemented as-is (design: docs/agent_docs_v2/DESIGN.md §2.2):
(a) `git diff --name-only` misses untracked files — the worker never commits,
so newly created files are always untracked; (b) it mixes glob patterns
(`**/.env`) with `grep -E` regex matching. The completion conditions below
fix both.

Human redirect (2026-08-10, run 20260810-112247): fix the implementation with
the NORMAL worker model (ollama-cloud/deepseek-v4-flash:0731), no escalation.

## Reviewer findings to address (run 20260810-112247, cycle 3 — all must be
fixed; the reviewer FAILed on these)

1. **High — CRLF `DENYLIST` silently disables every rule (fail-open).**
   The blank/comment filter never strips `\r`, so each rule becomes `...$\r`
   and matches nothing. Fix: strip trailing `\r` in the same pipeline that
   filters blank/comment lines.
2. **High — a worker commit bypasses both the denylist and the review.**
   Changed paths come only from `git status`; the review diffs only against
   `HEAD`. A worker that commits (it is asked not to, but nothing enforces
   it) makes both gates see nothing. Fix: capture `BASE_SHA` (the branch
   point) when the worktree is created, and use it for the changed-path
   detection AND the review diff (`git diff "${BASE_SHA:-HEAD}" --`).
3. **High — inlining untracked files can make the review stage unrunnable.**
   The review prompt dumps every untracked file in full; the prompt is passed
   as one argv element, and Linux caps one argument at 131072 bytes (E2BIG).
   A large untracked text file makes `pi` fail to exec for both models.
   Fix: cap per-file output in the review prompt (e.g. emit
   `git diff --no-index --stat` instead of full content when a file exceeds
   ~64 KB).
4. **Medium — an indented rule is silently inert.** Leading whitespace is
   tolerated on blank/comment lines, so an author assumes indentation is
   insignificant, but `  ^denied/` is passed to `grep -E` intact and never
   matches. Fix: strip leading whitespace in the same `sed` as finding 1.
5. **Low — the "empty DENYLIST" log is misleading, and the file becomes
   permanently uneditable.** The immutability check runs before the
   empty-pattern check, so a comment-only `DENYLIST` hard-rejects any edit
   to itself while never printing the "present but empty — skipping" line.
   Fix: reword the message; keep fail-closed as the default.
6. **Low — a bare `exit` in the untracked-diff path kills the run without
   diagnostics** (no log, no die, no record_failure). Fix: log + skip over
   a bare exit.
7. **Low, already documented — `.gitignore` evasion.** A denied path added
   to `.gitignore` drops out of untracked coverage; impact is limited
   because GATE-2's `git add -A` also skips ignored files. No fix required;
   keep the existing comment.

## Completion condition (BFV Kernel)

1. `verify_repo()` in `agent-loop-v1/loop.sh` enforces `<repo>/DENYLIST` when
   the file exists: if any changed path matches any pattern, it logs
   `DENYLIST violation: <matching paths>` and returns 1 (same structural
   verdict as a failing VERIFIERS command).
2. Changed-path detection includes BOTH modified tracked files AND untracked
   files. Use `git status --porcelain` output (status columns stripped, rename
   `a -> b` forms reduced to the new path) — NOT `git diff --name-only` alone.
3. DENYLIST format: one POSIX ERE per line, matched against repo-relative
   paths (`grep -E`); blank lines and lines starting with `#` are ignored.
   The format is stated in a comment at the top of the DENYLIST file itself.
4. A `DENYLIST` file is added at the repo root of `~/.pi` containing at least
   (as ERE, one per line, with a format header comment):
   - `^agent/auth\.json$`
   - `(^|/)\.env(\..*)?$`
   - `(^|/)credentials[^/]*$`
   - `(^|/)secrets[^/]*$`
   - `^DENYLIST$` (the loop must not edit its own denylist)
5. When no `DENYLIST` file exists, `verify_repo()` behaves exactly as before
   (log a note at most; no failure).
6. The baseline contract check (clean tree at loop start) still passes
   trivially: with no changes, the DENYLIST check matches nothing.
7. `bash -n agent-loop-v1/loop.sh` passes; existing log line formats stay
   intact and unchanged in meaning.

## Non-negotiables

- Do not change model routing, gates, worktree isolation, or the concurrency
  lock.
- No new external dependencies (bash + git + grep only).
- Keep the change minimal: one feature, small diff (verify_repo + DENYLIST
  file + test script).
- The DENYLIST check must never auto-fix or revert files — it only rejects.

## Stop-and-ask conditions

- If matching `git status --porcelain` output requires handling a case not
  covered above (submodules, spaces-in-paths quoting), stop and ask instead
  of guessing.
- If any existing VERIFIERS line already conflicts with the new DENYLIST
  entries, stop and ask.

## Out of scope

- Allowlist semantics, per-task denylist overrides, and shared multi-loop
  denylists (Phase D).
- Wall-clock timeouts and budgets (task-102, task-103).

## Acceptance rules (harness-change gate)

- All `~/.pi` VERIFIERS checks pass.
- Reviewer verdict PASS (or every finding resolved in a later cycle).
- Run cost <= 2x the median implement-stage cost of task-001..004
  (memory/cost-log.md baseline).
- No new failure-mode category added to memory/known-failures.md by this run.
- The regression test below passes.

## Regression test

Script: `agent-loop-v1/tests/test_denylist.sh` (new; temp-repo style like the
existing fake-pi-stub tests — no model calls, no network). It must:

1. Create a temp git repo (git init, one commit) with a `DENYLIST` containing
   `^denied/` and `(^|/)\.env$`, and invoke `verify_repo` from loop.sh (via
   the same source/extract mechanism the existing fake-pi stub test uses).
2. Assert PASS (return 0): clean tree; and a modification to an allowed file.
3. Assert FAIL (return 1): (a) modifying a tracked file under `denied/`;
   (b) creating a new UNTRACKED file `denied/x.txt`; (c) creating `.env` at
   the repo root.
4. Assert PASS: same changes in a repo WITHOUT a DENYLIST file.
5. Exit 0 iff all assertions hold.
