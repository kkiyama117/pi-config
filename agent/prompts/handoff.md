---
description: Compact the session — produce a dense handoff summary (state, decisions, artifacts, next steps)
argument-hint: "[output-file]"
---
Compress this entire conversation into a compact handoff summary that a fresh
session can continue from. Be dense: exact paths, exact command lines, no
fluff.

## Step 1 — capture live state (run these)

- `git branch --show-current` and `git status --short` (in the current repo)
- `git worktree list` if any worktrees exist
- `git log --oneline -5` for recent history
- `ps aux | grep -E "loop.sh|pi -p" | grep -v grep` — any running agent-loop or pi processes
- `ls -t ~/.pi/agent-loop-v1/memory/runs/ 2>/dev/null | head -3` — latest loop runs
- `tail -3 ~/.pi/agent-loop-v1/memory/decisions-log.md 2>/dev/null` — recent gate decisions

## Step 2 — write the summary with these sections

1. **Goal & progress** — what this session set out to do, what is done, what is not.
2. **Key decisions** — every decision with its date and the reasoning in one line.
3. **Files & repos touched** — exact paths; mark new files vs modified; note branch/commit ids.
4. **Current state** — branch, worktree, running processes, artifacts (run dirs, logs, memory files).
5. **Commands to know** — the exact commands that matter (loop invocation, verification, merge steps).
6. **Open items & next steps** — the immediate next action and who owns it.
7. **Risks / gotchas** — anything a fresh session would trip on (dirty trees, protocol mismatches, model routing, known bugs).

Keep the whole summary under ~150 lines. Use code blocks for commands and paths.

## Step 3 — save

- If an argument was given: write the summary to that exact path.
- Otherwise: write it to `~/.pi/compacts/compact-$(date +%Y%m%d-%H%M%S).md`
  (create the directory if needed) and also print it.

Do not modify any project files other than the summary file.
