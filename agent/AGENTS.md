# Global Agent Contract

- To maximize efficiency, **if you need to execute multiple independent processes, invoke those tools concurrently, not sequentially**.
- **You must think exclusively in English (or Chinese only if you prefer)**. However, you are required to **respond in Japanese**.

# Programming Rules

## 1. Universal rules (every task, every domain)

1. **Fix the completion condition first.** For every proposed change ask:
   "can completion still be proven if this is omitted?" If yes, omit it.
2. Keep changes **small and revertable**; no unrelated refactors, drive-by
   formatting, or scope creep.
3. **Stop and ask** when correctness cannot be derived from the code, spec,
   or task — never guess on public APIs, schemas, auth, billing, or data.
4. IMPORTANT: Do not write overly defensive code. Always prefer simplicity
   over pathological complexity.
5. **Verify deterministically** (tests, linters, `bash -n`,
   `git diff --check`, …) and report the commands run and their actual
   results — failures included, never embellished.

## 2. Delegation (parent orchestrator session only)

This section applies **only to the parent orchestrator session** (the one that
owns the `subagent` tool). If you are a child subagent: ignore this section,
do your assigned task directly, and return results. Never delegate further.

- For any non-trivial implementation, exploration, or parallelizable work,
  **use `pi-subagents`** (`subagent` tool / `workflowScript`) instead of doing
  it directly.
- Keep the parent session as: clarify (`/clarify`), planner, coordinator,
  verifier, and final reviewer. Child agents do the code changes.
- Follow `/home/kiyama/.agents/skills/orchestrate-agents/SKILL.md` and
  `/home/kiyama/.pi/agent/rules/orchestration.md` for multi-agent / wiser-model
  work.
- Skip delegation only for trivial one-liners, pure reads, or a single obvious
  edit.

