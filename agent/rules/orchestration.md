# Domain: Orchestration (multi-agent / model-driven work)

Read when: launching or steering any long-lived / model-driven agent work,
calling a wiser model (Claude Fable/Opus), or coordinating multi-agent phases.

These rules exist because they were violated. Do not violate them again.
(Moved verbatim from the former top-level AGENTS.md, 2026-08-10.)

## 1. USE HERDR — always, for agent work
Any long-lived or model-driven agent work runs inside a herdr pane:
- `herdr pane split <pane> --direction down` — create a pane
- `herdr pane run <pane_id> '<command>'` — run a command there (text + Enter)
- `herdr pane send-keys <pane_id> <key>` — steer it
- `herdr pane read <pane_id>` — inspect output
- Socket: `HERDR_SOCKET_PATH=/home/kiyama/.config/herdr/sessions/agent_loop/herdr.sock`

NEVER launch agent work as `nohup`/detached background processes — invisible,
unsteerable, was the repeated failure (violated 3+ times).

## 2. The rule when you call a wiser model (Claude Fable/Opus)
- **I write the prompt.** Never launch it with a bare "implement this".
- The prompt must tell it: **do NOT implement the full task yourself — use YOUR OWN
  subagents to do the implementation.** It plans/coordinates; its subagents do the
  work; it reviews the result. Do as the agent-loop does: planner/oracle at the top,
  workers below, HITL gates between.
- Wiser model role = **planner / orchestrator / oracle (reviewer)** — never a lone
  worker grinding the implementation.
- Run it **interactively in a herdr pane** (no `-p`, no headless).

## 3. I orchestrate the phases
Decompose → write the prompt → wise model plans → HITL gate → wise model delegates
implementation to its subagents → I verify deterministically (tests, `bash -n`,
`git diff --check`) → wise model reviews the result as oracle → iterate.

## 4. Full doctrine
Read `/home/kiyama/.agents/skills/orchestrate-agents/SKILL.md` before orchestrating
multi-agent work (or force-load with `/skill:orchestrate-agents`).
