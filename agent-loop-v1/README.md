# Agent Loop v1 — Operations

A bounded, HITL-first AI-agent loop that drives `pi` headless via a shell
script. Design rationale: `DESIGN.md`; Q&A: `QUESTIONS.md`.

## Files

| File | Purpose |
|------|---------|
| `loop.sh` | The loop driver (bash; requires `pi`, `git`, `python3`) |
| `pi_usage.py` | Python3-stdlib NDJSON parser for `pi --mode json` (status/usage/text; provider-aware, no jq) |
| `task-00X.md` | Task files — one per loop task, with completion condition (BFV Kernel) + non-negotiables |
| `DESIGN.md` | Design decisions (all 15 Q&A folded in) + implemented-features log |
| `QUESTIONS.md` | Original Q&A + resolved-in-practice lessons |
| `memory/` | Filesystem memory (gitignored): `decisions-log.md`, `past-runs.md`, `cost-log.md`, `known-failures.md`, `runs/<run-id>/` artifacts |
| `locks/` | flock-based per-repo concurrency locks (gitignored) |
| `worktrees/` | Branch-per-loop git worktrees (gitignored) |

## Operational doctrine (applies to ALL agent orchestration)

1. **USE HERDR** — every long-lived/model-driven agent runs in a herdr pane (visible,
   steerable, gates reachable). Never `nohup`/detached background for agent work.
2. **When calling a wiser model, I write the prompt and it delegates** — the wise model
   plans/orchestrates/reviews; its OWN subagents do the implementation. It is never a
   lone worker implementing the full task, never a headless implementer.
3. **I orchestrate** — decompose → prompt (wise model) → gate → wise model delegates
   to its subagents → deterministic verify → wise model reviews as oracle.

Global rules live in `~/.pi/agent/AGENTS.md` (loaded every pi session); full
doctrine: `~/.agents/skills/orchestrate-agents/SKILL.md`.

## Run a task

```bash
# in a herdr pane (visible gates) — target repo must be on develop/sub-branch
./agent-loop-v1/loop.sh --repo /home/kiyama/.pi --task-file agent-loop-v1/task-005.md
# dry run (no model calls, no commits):
./agent-loop-v1/loop.sh --repo /home/kiyama/.pi --task-file agent-loop-v1/task-005.md --dry-run
```

Environment knobs: `MAX_CYCLES` (default 3), `MAX_ESCALATIONS` (2),
`STAGE_TIMEOUT_S` (0 = no timeout).

## Flow

```
contract → plan (k3) → [GATE-1: a/r/d] → implement (deepseek) → verify (VERIFIERS)
→ review (gpt-5.6, adversarial) → [GATE-2: a/r/d] → commit → merge to develop (manual)
```

- Gates read stdin in the pane: `a` approve, `r` reject, `d` redirect with
  feedback. GATE-1 redirect re-plans **and re-gates**; GATE-2 redirect sends
  feedback to the worker.
- Verify is deterministic only (`VERIFIERS` in the target repo; always
  `git diff --check`). Review is a fresh-context adversarial model that must
  differ in family from the worker.
- Worker escalates on verify **or** review failure (max 2×, shared cap);
  when escalated, the reviewer switches to `cursor/claude-opus-5@1m`.
- Main is protected: the loop refuses to start on `main`, commits only to
  `loop/<run-id>` branches in worktrees, and never merges/pushes.
  Merge `loop/<run-id>` → develop manually after a successful run.

## Telemetry (tasks 002–004)

Every pi call records, to `memory/cost-log.md`:
`run=<id> stage=<s> model=<m> tokens=<n> cost=<c>` — plus these log lines:

```
stage plan took 42s                      # total per stage (incl. fallback)
pi attempt model=deepseek-v4-flash took 3s stage=implement   # per attempt
gate 'GATE-1 plan approval' waited 12s   # human response time
cost summary: run=<id> total_tokens=.. total_cost=.. calls=..  # EXIT trap (aborts included)
```

Usage parsing is provider-aware: cursor reports cumulative totals (last
event wins); other providers report per-turn (summed). Costs of 0 are
recorded as 0 — never fabricated.

## Lessons baked into v1 (see QUESTIONS.md for detail)

1. Review failures must escalate the worker (task-002 burned 3 cycles otherwise).
2. A revised plan must be re-approved at GATE-1 (redirect fell through once).
3. The max-cycles guard must not fire after a successful commit (DONE flag).
4. Truncated JSONL on failure paths must still record usage (tolerant parsing).
5. Only a terminal `stopReason == "stop"` is success.
