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

## Reviewer findings — round 1 (run 20260810-112247): RESOLVED

Fixed and verified by the reviewer in run 20260810-122118 (CRLF/indent
normalization, malformed-ERE fail-closed, DENYLIST immutability incl.
committed-edit and empty-base cases, rename source+destination, committed
denied files via base-ref diff, review diff surfacing untracked files).
Keep the fixes; the round-2 findings below are the remaining holes.

## Reviewer findings — round 2 (run 20260810-122118): RESOLVED

Fixed and verified by the reviewer in run 20260810-133054 (stdin transport
confirmed live, `--ignored=traditional` + `--untracked-files=all` expands
nested ignored dirs individually, worker suite 29/29). Keep the fixes; the
round-3 findings below are the remaining holes.

## Reviewer findings — round 2 (run 20260810-122118, cycle 3 — all must be
fixed; the reviewer FAILed on these)

1. **High — `--ignored=matching` collapses ignored directories, defeating
   the evasion it was added to stop.** Git reports a directory matching an
   ignore pattern as a single entry with a trailing slash (`!! cache/`), so
   files under it are never handed to the matcher: `cache/credentials.json`
   and a worker-written `.gitignore` with `stuff/` + `stuff/secrets.tar`
   both pass. The test matrix misses this because every ignore test uses a
   FILE pattern (`agent/auth.json`, `secrets.txt`), which `matching` does
   report individually. Fix: use `--ignored=traditional` (reports individual
   files) for the in-worktree pass.
2. **High — a committed DENYLIST makes the baseline contract check fail on
   a pristine tree.** `git status --ignored` lists every ignored file
   PRESENT, not every ignored file changed, so pre-existing ignored files
   are treated as worker-changed paths. On `~/.pi`: `agent/auth.json` is
   ignored (`.gitignore:3`) and DENYLIST:7 is `^agent/auth\.json$` —
   reproduced: clean tree → `DENYLIST violation: agent/auth.json`, rc=1.
   The moment DENYLIST is committed, every future run dies at the contract
   check. Fix: restrict the ignored scan to the in-worktree pass (only when
   `BASE_SHA` is set); a fresh worktree has no ignored files, so nothing is
   lost. (Reviewer-verified fix: `local ignored_opt=(); [[ -n
   "${BASE_SHA:-}" ]] && ignored_opt=(--ignored=traditional)` — 30/30
   tests still pass, both High cases fail closed.)
3. **Medium — a review-diff failure yields an empty diff block, and the
   reviewer PASSes a review of nothing.** Every degradation path (failed
   mktemp, unresolvable BASE_SHA, untracked-listing failure, per-file
   skips) reports only through `log` (stderr/loop.log); nothing reaches
   `review.prompt.md`, so the reviewer sees an empty fenced block and
   answers PASS. Fix: print a marker on stdout so it lands in the prompt,
   e.g. `printf '### REVIEW-DIFF INCOMPLETE: tracked diff unavailable
   (rc=%s)\n' "$rc"` alongside each `log` call in the review-diff
   functions.
4. **Medium — full contents of gitignored files are now sent to the
   reviewer model.** `git ls-files --ignored` enumerates individual files
   and `emit_untracked_for_review` dumps each under 64 KiB verbatim — on
   this repo the ignored set is the local-secret set (auth.json, trust.json,
   sessions/, transcripts/, run-history.jsonl) and the prompt goes to
   gpt-5.6/claude-opus-5. Fix: keep ignored paths in the listing but route
   them through the stat-only branch (pass a flag to
   `emit_untracked_for_review` for the second `ls-files` stream).
5. **Low — the unresolvable-base branch logs "skipping" but does not
   skip.** Control falls through; correct today only because the following
   conditions happen to leave `denylist_present=0`. Fix: add `return 0`
   after that log so the stated behavior is the actual behavior.

## Reviewer findings — round 3 (run 20260810-133054, cycle 3 — all must be
fixed; the reviewer FAILed on these)

1. **High — reviewer prompt injection via untracked filename.** The path
   header lines print the filename unquoted (`printf '### untracked: %s\n'
   "$f"` at 4 sites). `git ls-files -z` preserves newlines in filenames, so
   a worker-created file whose name contains a newline breaks out of the
   fence in `review.prompt.md` and can inject instructions that suppress
   the `^FAIL` line the loop gates on (structural verdict parse). The
   ignored path-only branch has the same hole. Fix: use bash `%q` on all
   four emission sites (`printf '### untracked: %q\n' "$f"`) — ordinary
   paths stay byte-identical, newline-bearing names render as a single
   `$'...'` token.
2. **Medium — non-ignored untracked emission is unbounded.** The
   `ignored_count`/`ignored_limit` cap is only consulted inside the
   `ignored_path_only == 1` branch; the content branch has a 64 KiB
   per-file cap but no count cap (measured: 3000 files → 504 KB prompt).
   Load-bearing because the stdin transport removed the argv ceiling that
   used to fail loudly. Fix: hoist the counter check above the
   `if (( ignored_path_only == 1 ))` test so both branches share the cap,
   emitting the existing `### REVIEW-DIFF TRUNCATED` marker.
3. **Low — DENYLIST matching is skipped, not failed, when the base ref
   will not resolve.** The `denied` computation lives entirely inside the
   `git rev-parse --verify "$base_sha"` success branch, so an unresolvable
   base means a present, valid DENYLIST enforces nothing (fail-open in a
   fail-closed control). Fix: move the `denied` block out of the `if`;
   keep only the `base_diff` union inside it.
4. **Low — `getline src` is unguarded** in the rename/copy record
   handling; prints stale/empty `src` on a truncated record. Fix:
   `if ((getline src) > 0) print src`.
5. **Low — `stat -c%s` does not dereference symlinks** (untracked symlink
   reports link-target length, always takes the inline branch). Benign
   (git diffs the link text); no fix required, note only.

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
