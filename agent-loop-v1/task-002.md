# Task: add cost tracking to agent-loop v1 (loop.sh)

## Completion condition (BFV Kernel)

`agent-loop-v1/loop.sh` must record token/cost usage for every pi call:

1. `pi_call` runs `pi -p --mode json` (instead of plain text mode) and extracts
   the `usage` object from the final `message_end` event:
   `input`, `output`, `cacheRead`, `cacheWrite`, `totalTokens`, and
   `cost.total` (all may be 0 — record them anyway).
2. Each pi call appends one line to `memory/cost-log.md`:
   `- <ISO timestamp> run=<run_id> stage=<stage> model=<model> tokens=<totalTokens> cost=<cost.total>`
3. At the end of a run, a cost summary line is printed and appended to
   `memory/past-runs.md`:
   `- <ISO timestamp> run=<run_id> total_tokens=<sum> total_cost=<sum> calls=<n>`
4. `--dry-run` mode still works (no pi call, no usage recorded, EXIT 0).
5. `bash -n loop.sh` passes.

## Non-negotiables

- Do not change model routing, gates, worktree isolation, VERIFIERS, or the
  concurrency lock.
- Do not add external dependencies (no pip/npm installs). ccusage tracks
  Claude Code, not pi — out of scope.
- The human-facing gate prompts and log output must stay readable (json mode
  output must not leak into the terminal).
- Keep the change minimal: one feature, small diff.

## Stop-and-ask conditions

- If pi's `--mode json` output format differs from the expected NDJSON events
  (no `message_end` with `usage`), stop and ask instead of guessing.
- If cost data is unavailable (cost.total = 0), record tokens only and note
  it in the log — do not invent costs.

## Out of scope

- Installing or wiring ccusage (Claude Code tool; the loop uses pi).
- Cost-based abort/guardrails (a later step — this task only records).
- Changing model routing or any other loop behavior.
