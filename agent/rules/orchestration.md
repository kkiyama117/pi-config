# Domain: Execution and orchestration

Read when choosing between direct work, delegation, or independent review.
Apply `../AGENTS.md`; these are local workflow defaults, not additional authority.

## 1. Choose the execution shape

- Use one agent for small tasks, tightly coupled reasoning, ordered dependencies,
  or work that would make agents contend over the same files. The main agent may
  implement complex work directly; a stronger model is not restricted to advice.
- Delegate concrete, independent work when parallel execution, focused context,
  or independent findings are likely to improve time or quality after accounting
  for coordination, usage, and integration. Examples: separate codebase areas,
  competing failure hypotheses, independent components, or a focused review.
- Use only the roles the task needs. Do not force planner/worker/reviewer chains,
  DAGs, per-phase human gates, or recursive agent trees for every task.
- Select models by task fit and measured end-to-end results. No model is always
  a worker, reviewer, or orchestrator. Cheaper tokens do not guarantee cheaper
  completed work; include retries, reviews, fixes, and integration in comparisons.

## 2. Execute within the existing authorization

- Infer routine details from context and complete the intended outcome. Do not
  stop at "shall I continue?" when the requested work is already authorized.
- Ask when the answer could materially change correctness, scope, or permission.
  Complete independent, authorized preparation before requesting approval for
  deployment, publication, merging, or other actions whose authority is missing.
- Do not invent approval flows for hypothetical risks. Do not treat autonomy as
  authorization for destructive or irreversible actions.
- Within local guidance, explicit user requests override skill defaults. If an
  instruction blocks progress, cite its file and exact text instead of silently
  imposing a workflow. System/developer rules and tool permissions still apply.

## 3. When delegation is useful

- Use `pi-subagents` for governed delegation. Read its applicable skill/reference,
  discover executable agents, and check the actual runtime tools before relying
  on them. A capability listing alone is not proof that a child can do the work.
- Give each child a bounded task, relevant context, write scope, completion
  criteria, expected evidence, and stop conditions. The parent retains final
  acceptance and reconciles conflicting findings.
- Keep one writer per shared scope; isolate concurrent writers. Child fan-out is
  allowed only when explicitly authorized and supported by the runtime.
- Use fresh-context, read-only review where independent scrutiny is worthwhile.
  Advisors answer unresolved questions; reviewers inspect evidence. Neither is a
  compulsory stage or automatic implementation approval.
- Use the runtime's asynchronous lifecycle and native completion notifications.
  Do not sleep/poll for completion or launch ungoverned background agent processes.
- On a child launch, extension, or tool-setup failure, stop the affected workflow,
  report the exact failure and run/cwd/ref, and capture clean state or partial
  changes. Do not repeat a known-broken route or silently switch execution modes;
  obtain owner approval for a different mode, including direct parent fallback.
- Use Herdr only when explicitly requested. Load its skill then, rather than
  hard-coding pane IDs or a machine-specific socket. Herdr is not a prerequisite
  for native `pi-subagents` runs.

## 4. Verification and completion

Run required checks and meaningful tests appropriate to the change. After they
pass, repeat or broaden verification only for new changes, failures, or unresolved
concerns. Independent review supplements deterministic checks; it does not replace
those checks or authorize publication. Report actual outcomes and remaining gaps.

## Sources and local choices

Based on OpenAI's [GPT-6 Astra guide](https://developers.openai.com/api/docs/guides/latest-model?model=gpt-6-astra)
(initiative, instruction following, delegation, verification) and
[Multi-agent guide](https://developers.openai.com/api/docs/guides/responses-multi-agent)
(independent work versus sequential/shared-state work and token overhead).
Runtime choice, one-writer boundaries, restricted recursive delegation, Herdr
opt-in, and failure recovery are local policies, not OpenAI requirements.
