# Questions — answered (2026-08-09)

All 15 questions were answered by the human. Decisions are recorded in
`DESIGN.md` ("Decisions" section) and implemented in `loop.sh`.

| # | Question | Answer |
|---|----------|--------|
| 1 | Target repo | **pi-config** (github.com/kkiyama117/pi-config) + `~/.pi` |
| 2 | Task scope | Update prompts, the loop itself, and AI-coding tools/configs (`pi`, `herdr`); fallback to the other repo if infeasible |
| 3 | Location | `~/.pi/agent-loop` now; new projects under `/data/agent_loop/` (prompts + tools like pi plugins) |
| 4 | Gate surface | Shell prompts (herdr pane) |
| 5 | Granularity | 2 gates (plan + apply) |
| 6 | Timeout | Wait forever (until reviewers/human answer) |
| 7 | Redirect | Plan gate → planner; apply gate → worker; plan-level rejection → redo from planner |
| 8 | Reviewer model | **gpt-5.6** (`cursor/gpt-5.6@1m:slow`) with `high`/`xhigh` thinking (cursor provider, not openrouter) |
| 9 | Escalation | Auto-escalate normal→thinking, max 2× |
| 10 | Verifiers | Per-repo `VERIFIERS` file |
| 11 | Iteration cap | 3 cycles; no wall-clock cap now (add if agent doesn't stop) |
| 12 | Cost guard | None in v1; add cost manager like `ccusage` if possible |
| 13 | Commit authority | May commit to `develop`/sub-branches; protect `main`; no merge/push in v1 |
| 14 | Isolation | Branch-per-loop + git worktree (one branch per loop) |
| 15 | herdr role | Visible host pane + gate notifications; agent-pane orchestration → v2 |

## Open TODOs (from the answers)

- [x] Reviewer model `cursor/gpt-5.6@1m:slow` is already enabled in `agent/settings.json` (task-001)
- [x] When the worker escalates to gpt-5.6, the reviewer must use its fallback (`cursor/claude-opus-5@1m`) — **implemented** in `stage_review()` (task-002 lesson; exercised in task-003 cycles 2–3)
- [x] Add `VERIFIERS` file to the target repo (pi-config) with real test/build/lint commands — 12 checks on `develop`
- [x] Cost *recording* — **implemented natively** via `pi_usage.py` (task-002; no ccusage needed — it tracks Claude Code, not pi)
- [ ] Cost *guard* (abort above a budget) — still deferred (Q12)
- [ ] Add wall-clock cap if the agent is observed not stopping (Q11) — timing measurement shipped (tasks 003–004); the cap itself is still deferred
- [ ] Move to `/data/agent_loop/` with sub-folders (prompts + tools) when the loop stabilizes (Q3)

## Resolved in practice (2026-08-10)

Real runs (task-001..004) confirmed and sharpened the design:

- **Review-failure escalation**: task-002 burned all 3 cycles on the same worker model while the reviewer (gpt-5.6) was right each time. `escalate_worker()` now escalates on review FAIL too (shared cap, max 2), and the reviewer switches family when the worker escalates (worker=gpt-5.6 → reviewer=claude-opus-5).
- **Redirect re-gate**: a GATE-1 redirect originally fell through to implementation without re-approval (gate bug). Fixed: revised plans are shown again at GATE-1. Exercised in production during task-004 (redirect → re-plan with Purpose section → re-approved).
- **Max-cycles guard**: a successful commit on the 3rd (== max) cycle still died with "FATAL: max cycles reached". Fixed with a `DONE` flag (`9050a6c`); regression-tested with a fake-pi stub (success path completes, genuine exhaustion still escalates).
- **Provider-aware usage**: cursor providers report cumulative usage per event, others per-turn — `pi_usage.py` sums per-turn events and takes the last event for cursor (reviewer High finding, task-002).
- **Cost accounting on abort**: the EXIT trap emits the run summary whenever calls > 0, so runs that die at a gate still get complete accounting (Q1-approved design; verified when the task-003 run died after commit).
- **Terminal-stop discipline**: `aborted`/`length`/`toolUse`/`error` stop reasons are failures that trigger the fallback; only a terminal `stop` is success.
- **Observed costs** (real runs): k3 dominates plan cost (~$0.15/call); deepseek-v4-flash is high-token/low-cost; cursor models report cost 0 (recorded as 0, never fabricated).
