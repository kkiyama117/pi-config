You are the PLANNER for a bounded agent task. Produce plan.md only — no code.
Repository: /data/pi-config
Task: # Task: add agent-loop v1 models to pi-config enabledModels

## Completion condition (BFV Kernel)

`agent/settings.json` `enabledModels` must contain BOTH:

- `kimi-coding/k3` (planner model for agent-loop v1)
- `cursor/gpt-5.6@1m:slow` (reviewer/escalation model for agent-loop v1)

All existing 15 entries must be preserved (no removals, no reordering
required). The change is additive only.

## Non-negotiables

- Do not touch any other file in the repo.
- Do not change `defaultProvider`, `defaultThinkingLevel`, or any other
  settings key.
- JSON must stay valid; all VERIFIERS checks must pass.

## Stop-and-ask conditions

- If the exact model IDs cannot be confirmed as valid pi model patterns,
  stop and ask instead of guessing.
- If adding the entries would break the settings shape, stop and ask.

## Out of scope

- Syncing the rest of the runtime `~/.pi` settings drift.
- Enabling any other models.
- Changing provider configs.

Rules (from the loop contract):
- Completion condition is fixed: # Task: add agent-loop v1 models to pi-config enabledModels

## Completion condition (BFV Kernel)

`agent/settings.json` `enabledModels` must contain BOTH:

- `kimi-coding/k3` (planner model for agent-loop v1)
- `cursor/gpt-5.6@1m:slow` (reviewer/escalation model for agent-loop v1)

All existing 15 entries must be preserved (no removals, no reordering
required). The change is additive only.

## Non-negotiables

- Do not touch any other file in the repo.
- Do not change `defaultProvider`, `defaultThinkingLevel`, or any other
  settings key.
- JSON must stay valid; all VERIFIERS checks must pass.

## Stop-and-ask conditions

- If the exact model IDs cannot be confirmed as valid pi model patterns,
  stop and ask instead of guessing.
- If adding the entries would break the settings shape, stop and ask.

## Out of scope

- Syncing the rest of the runtime `~/.pi` settings drift.
- Enabling any other models.
- Changing provider configs.
- For every proposed change ask: can it be omitted and completion still proven? (BFV Kernel)
- Phases: small, safe, ordered; each phase names its verification step.
- Include: Behaviors To Preserve, Non-Negotiables, Stop-And-Ask Conditions,
  Baseline Commands, Out-of-scope items.
- If anything is ambiguous, list it under "Questions for the human" instead of guessing.
