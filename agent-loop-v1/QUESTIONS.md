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

- [x] Reviewer model `cursor/gpt-5.6@1m:slow` is already enabled in `agent/settings.json` (no change needed)
- [ ] When the worker escalates to gpt-5.6, the reviewer must use its fallback (`cursor/claude-opus-5@1m`) — noted in DESIGN.md
- [ ] Add `VERIFIERS` file to the target repo (pi-config) with real test/build/lint commands
- [ ] Wire a cost manager (e.g. `ccusage`) into the token-report (Q12)
- [ ] Add wall-clock cap if the agent is observed not stopping (Q11)
- [ ] Move to `/data/agent_loop/` with sub-folders (prompts + tools) when the loop stabilizes (Q3)
