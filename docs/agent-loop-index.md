# Agent Loop Docs Index

One-stop index of every agent-loop doc in `~/.pi`. Created 2026-08-11.
Update this file when a doc is added/moved; delete entries, don't orphan them.

## Proposal & background (Fable 5, 2026-08-10)

| File | What |
|---|---|
| `~/.pi/suggest_v1.md` | **正本.** 3-article integration (Agent SDK × Loop Engineering × Harness Optimization) + agent-loop-v1 gap review with P0/P1/P2 proposals |
| `~/.pi/merged-agent-loop-docs.md` | Raw merged notes of the same 3 articles (superseded by suggest_v1 Part 1) |
| `~/.pi/docs/agents_docs_v1/` | Original corpus (loop / contract / verification) |

## v2 execution plan (Fable 5)

| File | What |
|---|---|
| `~/.pi/docs/agent_docs_v2/README.md` | Roadmap (Phases A–F), task status table, run protocol |
| `~/.pi/docs/agent_docs_v2/DESIGN.md` | v2 design + diffs from suggest_v1 with rationale |
| `~/.pi/docs/agent_docs_v2/TASK_TEMPLATE.md` | Required task structure incl. acceptance rules |
| `~/.pi/docs/agent_docs_v2/BACKLOG.md` | Phase D briefs (task-2XX: report-only → timer → tiers → self-update) |
| `~/.pi/docs/agent_docs_v2/BACKLOG_PHASE_EF.md` | Phase E/F briefs (task-3XX skills intake, task-4XX other repos) |
| `~/.pi/docs/agent_docs_v2/tasks/task-101..106` | Contract-form tasks (Phase A–C: completed but not reviewed) |

## v1 loop (the harness itself)

| File | What |
|---|---|
| `~/.pi/agent-loop-v1/README.md` | Ops manual, telemetry spec |
| `~/.pi/agent-loop-v1/DESIGN.md` | v1 design + implementation history (task-001..004) |
| `~/.pi/agent-loop-v1/LOOP.md` | Stop-condition charter (task-104 fills this) |
| `~/.pi/agent-loop-v1/QUESTIONS.md` | Open decisions log |
| `~/.pi/agent-loop-v1/loop.sh` | The loop |
| `~/.pi/agent-loop-v1/plan.md` | Working plan |

## Memory (`~/.pi/agent-loop-v1/memory/`, gitignored)

| File | What |
|---|---|
| `decisions-log.md` | Gate decisions per run |
| `past-runs.md` | Run history |
| `known-failures.md` | Failure patterns (feeds task generation) |
| `cost-log.md` | Per-pi-call tokens/cost |
| `external-patterns.md` | **How others run agent loops** — distilled from references corpus, mapped to our status (2026-08-11) |
| `runs/<run-id>/` | Per-run artifacts |

## Reference corpus

| Path | What |
|---|---|
| `/data/references/AI/` | **New home (2026-08-14).** Searchable AI-agent reference store: TOML corpus (classified), manifest catalog, taxonomy, provenance — see its `README.md` |
| `~/.pi/docs/references/README.md` | Pointer to the new store (corpus removed from `~/.pi`; recoverable in git history) |

## Current state (2026-08-11)

- **Phase A–C (task-101..106): completed but not reviewed** — implementation done on branch `createing_agent_loop_v2`; not merged to develop; no orchestrator review yet
- **Next:** Phase D prep — metrics gate (`metrics.py summary`), merge review, then expand `BACKLOG.md` → task-201 (`--report-only`)
- Run via: `./agent-loop-v1/loop.sh --repo ~/.pi --task-file docs/agent_docs_v2/tasks/task-XXX.md`
