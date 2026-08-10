# Agent Loop v1 — Design (HITL first)

A minimal, honest AI-agent loop for this machine. v1 optimizes for **human
approval at every key node**, not autonomy. Every claim here traces to either
the corpus (`docs/agents_docs_v1/`) or the pi-subagents runtime primitives.

## Principles (from the corpus)

1. **Humans at key nodes** — agents pass tests fast but codebases degrade;
   architecture/boundary judgment stays human. Realistic gain is 2–3×, not
   10–100×. (`07-reality-check.md`, tweet 2082028299275149685)
2. **Contract before work** — define completion conditions up front (BFV
   Kernel: "can this change be omitted and completion still be proven?"), plus
   Stop-And-Ask conditions and baseline verification commands.
   (`02-contract.md`, tweets 2085860526052315310, 2065068565720649775)
3. **Deterministic verification first, judges second** — plain code answers
   objective questions (did tests pass, does the file exist, did the build
   succeed). LLM judges are noisy (13.6% self-disagreement, 72% first-slot
   bias) — use them only for what needs reading, never let a model grade its
   own family, and make the verdict *structural* (reject the handoff, don't
   log it). (`05-verification.md`, tweet 2082193490956476521)
4. **Loop shape = chain + bounded cycle** — v1 is a chain (plan → implement →
   verify → review → gate). The only cycle is a bounded retry loop with a hard
   iteration cap; an uncapped cycle "runs until your budget is gone."
   (`03-loop.md`, graph shapes, tweet 2081076728126968237)
5. **HITL now, HOTL later** — start with human-in-the-loop; grow toward
   human-on-the-loop only after the gates prove reliable.
   (`03-loop.md`, tweet 2085759371355525610)
6. **Memory on the filesystem** — markdown decisions-log / past-runs /
   known-failures, inspectable by humans, cheap to retrieve.
   (`03-loop.md`, tweets 2085787859680637092, 2080678034093252935;
   PLANS/DOCS indexing, 2084097212850839893)

## Decisions (human answers, 2026-08-09)

| # | Question | Decision |
|---|----------|----------|
| 1 | Target repo | **pi-config** (github.com/kkiyama117/pi-config) + `~/.pi` |
| 2 | Task scope | Update prompts, the loop itself, and AI-coding tools/configs (`pi`, `herdr`); if not feasible, fall back to the other repo |
| 3 | Location | `~/.pi/agent-loop` now; new projects under `/data/agent_loop/` with sub-folders (prompts + tools like pi plugins) |
| 4 | Gate surface | Shell prompts (herdr pane) |
| 5 | Granularity | 2 gates (plan + apply) |
| 6 | Timeout | Wait forever (until reviewers/human answer) |
| 7 | Redirect | Plan gate → feedback to **planner**; apply gate → feedback to **worker**; plan-level rejection (e.g. huge bugs found by worker) → redo from **planner** |
| 8 | Reviewer model | **gpt-5.6** (`cursor/gpt-5.6@1m:slow`) with `high`/`xhigh` thinking |
| 9 | Escalation | Auto-escalate normal→thinking, max 2× |
| 10 | Verifiers | Per-repo `VERIFIERS` file read by the loop |
| 11 | Iteration cap | 3 cycles; no wall-clock cap now — add if the agent doesn't stop |
| 12 | Cost guard | None in v1 (providers have own rate limits); add a cost manager like `ccusage` if possible |
| 13 | Commit authority | Loop **may commit** to `develop` and sub-branches; **protect `main`**; never merge/push in v1 |
| 14 | Isolation | Branch-per-loop **+ git worktree** (one branch per loop, but use the worktree feature) |
| 15 | herdr role | Visible host pane + gate notifications; agent-pane orchestration → v2 |

## Architecture

```
                 ┌────────────────────────────────────────────────────┐
                 │                 herdr pane (visible)                │
                 │              loop.sh drives everything              │
                 └────────────────────────────────────────────────────┘

  TASK INTAKE ──► CONTRACT ──► PLAN ──► [GATE 1] ──► IMPLEMENT ──► VERIFY ──► REVIEW ──► [GATE 2] ──► COMMIT
   (human)       (check repo   (thinking  human:      (normal      (deterministic  (thinking   human:      (or ROLLBACK
                 state +       model)     approve/    model,       commands:       model,      approve/    + record to
                 baseline)               reject/      worker)      test/build/     adversarial, redirect/   memory/
                                     redirect)                      lint/diff)      fresh ctx)   reject)
                                            ▲                                                    │
                                            └────────── bounded retry cycle (max N) ◄────────────┘
```

### Stages

| # | Stage | Actor | Model route | Notes |
|---|-------|-------|-------------|-------|
| 0 | Intake | human | — | Free-form task; loop writes a `task.md` with completion condition + stop-ask conditions (BFV Kernel). |
| 1 | Contract check | script | — | `git status` clean? baseline verification commands pass? Refuse to start on a dirty or red tree (refactor-instructions pattern). |
| 2 | Plan | pi headless | thinking (k3) | Produce `plan.md`: phases small and ordered, per-phase verification, explicit out-of-scope. No code yet. |
| — | **GATE 1** | human | — | approve / reject / redirect. Before *any* implementation. Redirect → feedback goes to the **planner**. |
| 3 | Implement | pi headless | normal (deepseek-v4-flash) | worker executes plan.md in the target repo on a loop branch (worktree). |
| 4 | Verify | script | — | deterministic commands only: tests, build, lint, diff-sanity (per-repo `VERIFIERS`). Structural verdict. |
| 5 | Review | pi headless | thinking (gpt-5.6-luna, high/xhigh) | fresh-context adversarial review of the diff; findings with file/line. |
| — | **GATE 2** | human | — | approve / reject / redirect. Before *any* commit. Redirect → feedback to the **worker**; plan-level rejection → redo from **planner**. |
| 6 | Commit or rollback | script (+human) | — | v1: loop commits to `develop`/sub-branches after GATE-2; `main` is protected; no merge/push. Rollback = drop branch. |
| 7 | Record | script | — | append to `memory/decisions-log.md`, `past-runs.md`, `cost-log.md` (one line per pi call: run/stage/model/tokens/cost); failures to `known-failures.md`. Cost summary is emitted by an **EXIT trap** so aborted runs still get complete accounting (Q1-approved). |

## HITL gates

Two mandatory gates per iteration (both required by the user's brief):

- **Gate 1 — before implementation.** Cheap to reject here; a bad plan costs
  one thinking-model call, a bad implementation costs the diff.
- **Gate 2 — before merge/apply.** The merge decision is never delegated;
  receipts/verifier results are *evidence, not authority* (pi-subagents
  always-on constraint).

Gate surface options (decision for the human — see QUESTIONS):

| Surface | How | Status |
|---------|-----|--------|
| Shell prompt in herdr pane | `read` in loop.sh; pane is visible; `herdr notification` pings on gate wait | **v1 (decided)** |
| pi-subagents checkpoint | When the loop is driven from inside a Pi session: `append-step { checkpoint, message }` → `approve-checkpoint` / `reject-checkpoint`; `steer` for redirect | v1 alt path |
| herdr cross-pane | `herdr agent prompt` to a supervisor pane, `herdr agent wait` for state | v2 |

Redirect policy (decided):

- **GATE-1 redirect** → feedback is fed into the **planner** prompt; plan is regenerated **and shown again at GATE-1** (revised plans are never auto-approved — the re-gate was added after a redirect fell through to implementation without re-approval; fixed before task-002 and exercised in production during task-004).
- **GATE-2 redirect** → feedback is fed into the **worker** prompt; next cycle re-implements.
- **GATE-2 reject with plan-level problems** (e.g. worker found huge bugs, scope drift) → redo from the **planner**, not the worker.

## Model routing (user rule 2)

Exact IDs from `agent/settings.json` enabledModels:

| Role | Route | Fallback | Thinking | Why |
|------|-------|----------|----------|-----|
| Intake/contract formatting | `ollama-cloud/deepseek-v4-flash:0731` | `deepseek/deepseek-v4-flash` | — | normal task, cheap-first |
| Worker (implement) | `ollama-cloud/deepseek-v4-flash:0731` | `cursor/composer-2-5:fast` | `medium` (`THINKING_IMPLEMENT`) | normal task |
| Plan | `kimi-coding/k3` | `cursor/grok-4.5` | `high` (`THINKING_PLAN`) | thinking task |
| Review (adversarial) | `cursor/gpt-5.6@1m:slow` | `cursor/claude-opus-5@1m` | `high` (`THINKING_REVIEW`) | thinking + **must differ from worker model family** (eval-engineering rule); decided by human (Q8) — cursor provider, not openrouter |
| Escalation (worker stuck) | `cursor/gpt-5.6@1m:slow` | `kimi-coding/k3` | `high` (`THINKING_ESCALATE`) | thinking, max 2 escalations/iteration |

> Thinking levels are pinned per stage (v2): no stage relies on pi's
> `defaultThinkingLevel` (settings.json), which can drift. All four knobs are
> env-overridable: `THINKING_PLAN` / `THINKING_IMPLEMENT` / `THINKING_REVIEW` /
> `THINKING_ESCALATE`.

> Note: when the worker escalates to `cursor/gpt-5.6@1m:slow`, the reviewer
> must use its fallback (`cursor/claude-opus-5@1m`) so the reviewer never
> grades its own model family (eval-engineering rule).
> **Implemented** in `stage_review()` (task-002 lesson; exercised in task-003
> cycles 2–3: worker on gpt-5.6, reviewer on claude-opus-5).

Cheap-model-first with explicit escalation; every stage logs model + token
usage (`memory/cost-log.md`, one line per pi call) and wall-clock durations
(`stage <name> took <N>s`, `pi attempt model=<model> took <N>s stage=<stage>`,
`gate <name> waited <N>s` — tasks 002–004).

## herdr + pi-subagents integration (user rule 1)

- **herdr** = the visible host. loop.sh runs inside a named herdr session/pane
  so the human watches gates, diffs, and verifier output live
  (`herdr --session agent-loop`). `herdr notification` fires when a gate is
  waiting. Cross-CLI agents (Codex/Cursor panes) are a v2 extension via
  `herdr agent prompt` / `herdr agent wait` / `herdr agent read`.
- **pi-subagents** = the in-Pi orchestration path. The same stage graph maps
  to a `workflowScript`: `runs.run("plan", { model: "kimi-coding/k3", ... })`,
  checkpoint steps for Gate 1/Gate 2, `gate: "<verifier command>"` for
  host-run deterministic verification (memoized per workspace state),
  `steer` for redirect, `resume` after human approval. v1 ships the shell
  driver; the workflowScript mapping is documented as the alt path.
- **Missions**: when run from a Pi session, the default mission record gives
  durable objective/run/decision history; `memory/*.md` mirrors the same in
  human-readable files.

## Failure & stop conditions (no silent failures)

- **Concurrency guard**: one loop per repo. A `flock`-based lock file
  (`locks/<repo-md5>.lock`) is acquired at startup; a second loop for the
  same repo is refused immediately. The lock auto-releases on process exit
  (even on kill) — no stale-lock cleanup needed. Known edge case: deleting
  the lock file while a loop holds it bypasses the guard (manual cleanup
  only).
- Any stage failure aborts the loop with a logged reason; nothing is retried
  silently.
- Bounded retry cycle: max **3** implement→verify→review cycles per iteration
  (graph Shape 4 hard limit); then forced human escalation.
- The max-cycles guard only fires on **genuine exhaustion** (`DONE` flag set
  on the GATE-2 approve path). Without the flag, a successful commit on the
  3rd cycle still died with "FATAL: max cycles reached" — found by the
  task-003 validation run, reproduced by a regression test (fake-pi stub),
  fixed in `9050a6c`.
- Max **2** model escalations (normal → thinking) per iteration. Escalation
  triggers on **verify failure OR review failure** (review-fail escalation
  added after task-002: 3 review FAILs burned all cycles on the same worker
  model while the reviewer's findings were valid). Escalation cap reached →
  forced human gate.
- Refuse to start: dirty git tree, failing baseline verifier, missing
  completion condition.
- Any unapproved product/scope/architecture decision that surfaces mid-loop →
  stop and ask (escalate upward; never let the agent decide silently).
- Wall-clock: **no per-stage timeout in v1** (decided Q11) — add one if the
  agent is observed not stopping. The `STAGE_TIMEOUT_S` variable exists but
  defaults to 0 (disabled).
- Cost: no hard budget in v1 (decided Q12); providers enforce their own rate
  limits. **Cost recording is implemented** (task-002): `pi_usage.py` parses
  `pi --mode json` NDJSON — provider-aware (cursor reports cumulative totals →
  last event; other providers report per-turn → summed), tolerant of
  truncated/malformed lines, no jq. A cost *guard* (abort above a budget)
  remains a later step.

## Isolation

- v1: **branch-per-loop + git worktree** in the target repo
  (`loop/<date>-<slug>`); one branch per loop, but the loop runs in a
  worktree so the main checkout stays clean. Rollback = drop the branch and
  remove the worktree. Blast radius = one branch.
- The loop commits to `develop` and sub-branches only after GATE-2 approval;
  `main` is protected (refuse to create a loop branch from `main`).
  No merge/push in v1 (decided Q13/Q14).

## Implemented & operational history (2026-08-10)

| Task | What shipped | Outcome / lesson |
|------|--------------|------------------|
| task-001 | Add `kimi-coding/k3` + `cursor/gpt-5.6@1m:slow` to `agent/settings.json` | First real loop run; review PASS, committed on loop branch, merged to develop |
| task-002 | Cost tracking: `pi_usage.py` (stdlib, no jq), `cost-log.md`, EXIT-trap summary, provider-aware usage aggregation | Reviewer FAIL x3 → forced human escalation → escalation gap found: worker never escalated on *review* failures. Fixed: `escalate_worker()` shared by verify+review paths |
| task-003 | Per-stage timing: `stage <name> took <N>s`, `gate <name> waited <N>s` | Validation run found the max-cycles-after-commit bug (DONE flag, `9050a6c`); regression-tested with a fake-pi stub |
| task-004 | Per-attempt attribution: `pi attempt model=<model> took <N>s stage=<stage>` | Real GATE-1 redirect exercised the re-gate fix in production; fallback path proven by stub test (primary fail + fallback success → 2 attempt lines + 2 cost-log lines) |

## What v1 deliberately excludes

Parallel workers (diamond shape), schedules/triggers, auto-merge/push,
cross-repo work, HOTL, vector memory, herdr agent-pane orchestration. Each is
a later, separately approved step (`03-loop.md` Ops: pilot-before-scale).

## Target & location (decided Q1–Q3)

- **Target repo:** `pi-config` (github.com/kkiyama117/pi-config) and `~/.pi`.
  v1 tasks: update prompts, the loop itself, and the AI-coding tools/configs
  (`pi`, `herdr`). If that proves infeasible, fall back to the other repo.
- **Location:** the loop lives at `~/.pi/agent-loop` for now; new projects go
  under `/data/agent_loop/` with sub-folders — not only prompts but also
  tools (e.g. pi plugins) when they need to be created.

## References

- `docs/agents_docs_v1/03-loop.md` — loop taxonomy (contract, verifiers,
  isolation, budget, memory, hooks), graph shapes, HITL→HOTL, filesystem memory
- `docs/agents_docs_v1/02-contract.md` — BFV Kernel, refactor-instructions
  (stop-and-ask, baseline commands, small phases), PLANS/DOCS indexing
- `docs/agents_docs_v1/05-verification.md` — eval engineering (deterministic
  first, judge calibration, structural verdicts)
- `docs/agents_docs_v1/07-reality-check.md` — software-factory limits, 2–3×,
  humans at key nodes, vertical slices
- `docs/agents_docs_v1/01-environment.md` — harness/infrastructure reality
- pi-subagents skill: `~/.pi/agent/npm/node_modules/pi-subagents/skills/pi-subagents/`
  (workflowScript, checkpoints, gate, steer/resume, missions, constraints)
