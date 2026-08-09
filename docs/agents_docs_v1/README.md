# AI Agent Coding Loop — Reference Docs (v1)

Full-text reference extracts of the AI-agent-coding articles from the
`miyake-ken/prompts` reference corpus, organized by stage of the agent coding
loop. Primary focus: **AI loop engineering** and **generating AI coding
environments**.

```
┌──────────────────────┐
│ ① ENVIRONMENT         │   harness & infrastructure (managed VMs, internal/
│  (01-environment.md)  │   external harness, env-as-code)
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ ② CONTRACT            │   AGENTS.md/CLAUDE.md, PLANS.md/DOCS.md, north-star
│  (02-contract.md)     │   metric, instruction-doc handoffs
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ ③ LOOP                │   loop types & triggers, graph shapes (chain/
│  (03-loop.md)         │   diamond/router/cycle), verifiers, budget, memory,
│                       │   skills; LoopX, DeepCode v2
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ ④ ORCHESTRATION       │   plan-agent → execute-agent → verify-agent, agent
│  (04-orchestration.md)│   teams (CodexLoom), herdr 4-thread coordination
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ ⑤ VERIFICATION        │   eval engineering: LLM-judge calibration, test
│  (05-verification.md) │   generation (Locksmith Loop)
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ ⑥ LEARNING (optional) │   train agents in their own harness (TRL+OpenEnv),
│  (06-learning.md)     │   self-improvement theory, auto-research
└──────────────────────┘

⚠ REALITY CHECK (07-reality-check.md): agents pass tests but codebases can
  degrade — keep humans at key nodes, expect 2–3× not 10–100×, value before
  methodology.
```

## Stage files

| File | Stage | Articles |
|------|-------|----------|
| 00-references.md | Source memo (every article, URL, and corpus path used) | — |
| 01-environment.md | Environment (harness & infrastructure) | 5 |
| 02-contract.md | Contract (agent configuration) | 7 |
| 03-loop.md | Loop (loop & graph engineering, memory, skills) | 10 |
| 04-orchestration.md | Orchestration (multi-agent) | 4 |
| 05-verification.md | Verification (eval engineering) | 2 |
| 06-learning.md | Learning (self-improving agents) | 4 |
| 07-reality-check.md | Reality check (software factories & business value) | 3 |
| **Total** | | **35** |

## Source

Full texts extracted verbatim from
`docs/references/classified_v1/miyake-ken-prompts` — tweets and non-X links
collected from the `#hermes_home` Slack channel (github.com/miyake-ken/prompts,
converted 2026-08-08). Original texts kept as-is (Japanese / English / Chinese);
no translation or summarization.
