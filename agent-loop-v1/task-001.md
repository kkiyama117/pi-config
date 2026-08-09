# Task: add agent-loop v1 models to pi-config enabledModels

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
