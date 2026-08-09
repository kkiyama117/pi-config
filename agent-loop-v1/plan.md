# Plan: add agent-loop v1 models to pi-config enabledModels

## Completion Condition (BFV Kernel)

`/data/pi-config/agent/settings.json` `enabledModels` contains BOTH:

- `kimi-coding/k3` (planner model for agent-loop v1)
- `cursor/gpt-5.6@1m:slow` (reviewer/escalation model for agent-loop v1)

All 15 existing entries preserved (no removals; reordering not required).
Change is additive only. JSON stays valid; all VERIFIERS checks pass.

Proof command (run from `/data/pi-config`):

```sh
jq -e '
  (.enabledModels | length == 17) and
  (.enabledModels | index("kimi-coding/k3") != null) and
  (.enabledModels | index("cursor/gpt-5.6@1m:slow") != null)
' agent/settings.json
```

## Baseline (verified by planner, 2026-08-09)

- Repo: `/data/pi-config`, git working tree clean, HEAD `3bb0252`.
- `agent/settings.json` `enabledModels` currently has exactly **15** entries
  (5 `cursor/`, 5 `ollama-cloud/`, 1 `kimi-coding/`, 4 `openrouter/`).
- **Model ID validity confirmed** (stop-and-ask condition resolved):
  - `kimi-coding/k3` — `k3` is a registered model id under the `kimi-coding`
    provider in `agent/models-store.json`
    (`kimi-coding: k3, k3-256k, kimi-for-coding, kimi-for-coding-highspeed`).
  - `cursor/gpt-5.6@1m:slow` — matches the existing enabled pattern
    `cursor/gpt-5.5@1m:slow` (same `@1m` context suffix and `:slow`
    thinking-level suffix), and `cursor/gpt-5.6@1m` is already referenced
    by the `reviewer` subagent override in the same file.
- VERIFIERS file exists at repo root; the loop runs it plus `git diff --check`.

Baseline commands (record before editing):

```sh
cd /data/pi-config
git status --short                                   # expect: clean
jq -r '.enabledModels[]' agent/settings.json | sort | md5sum   # 15-entry fingerprint
jq empty agent/settings.json                          # JSON valid
```

## Behaviors To Preserve

- All 15 existing `enabledModels` entries, exactly as spelled.
- Every other settings key untouched, in particular `defaultProvider`
  (`ollama-cloud`), `defaultThinkingLevel` (`high`), `defaultModel`,
  `subagents`, `packages`.
- No other file in the repo modified (git status shows exactly one changed
  file: `agent/settings.json`).
- File remains 2-space-indented valid JSON (matching current style).

## Non-Negotiables

- Do not touch any other file in the repo.
- Do not change `defaultProvider`, `defaultThinkingLevel`, or any other
  settings key.
- JSON must stay valid; all VERIFIERS checks must pass.

## Stop-And-Ask Conditions

- Model ID validity: **already confirmed** (see Baseline). If a pre-edit
  check contradicts this (e.g. `k3` no longer in models-store), stop and ask.
- If the edit would change the settings shape (enabledModels not a flat
  array of `"provider/id"` strings, or file fails `jq empty` after edit),
  revert and ask.
- If the working tree is dirty before editing, stop and ask — do not
  entangle this change with unrelated edits.

## Out Of Scope

- Syncing runtime `~/.pi` settings drift into the repo.
- Enabling any other models.
- Changing provider configs (`models.json`, `models-store.json`,
  `providers/kimi-coding/config.json`).
- Git commit/push (loop contract handles verification; committing is not
  part of the completion condition).

## Phases

### Phase 1 — Pre-flight checks (read-only)

```sh
cd /data/pi-config
git status --short
jq '.enabledModels | length' agent/settings.json          # expect 15
jq -r 'to_entries[] | select(.key=="kimi-coding") | .value.models[].id' agent/models-store.json | grep -x k3
jq -r '.enabledModels[]' agent/settings.json | grep -x 'cursor/gpt-5.5@1m:slow'
```

Verification: tree clean; length == 15; `k3` present in kimi-coding models;
`gpt-5.5@1m:slow` pattern present. Any failure → Stop-And-Ask.

### Phase 2 — Append the two entries (single-file, additive edit)

Edit **only** `/data/pi-config/agent/settings.json`. Append two elements to
the end of the `enabledModels` array, after
`"openrouter/deepseek/deepseek-v4-flash"`:

```json
    "openrouter/deepseek/deepseek-v4-flash",
    "kimi-coding/k3",
    "cursor/gpt-5.6@1m:slow"
  ],
```

(Appending at the end guarantees zero reordering of existing entries.
BFV check: everything beyond this one edit is omittable — no other change
is needed to prove completion.)

Verification: `jq empty agent/settings.json` succeeds.

### Phase 3 — Prove completion + run verifiers

```sh
cd /data/pi-config
# Completion condition
jq -e '(.enabledModels | length == 17)
       and (.enabledModels | index("kimi-coding/k3") != null)
       and (.enabledModels | index("cursor/gpt-5.6@1m:slow") != null)' agent/settings.json
# Preservation: the 15 baseline entries are all still present
jq -r '.enabledModels[]' agent/settings.json | sort | head -15 > /tmp/after.txt
# (compare against baseline fingerprint; first 15 sorted lines must match baseline sorted list)
# Only one file changed
git status --short                                       # expect: M agent/settings.json only
# No other key changed
git diff agent/settings.json | grep -E '^[+-]' | grep -v '^[+-][+-]'
# expect exactly: one context-ish '+' pair for the two new lines (and the
# comma added to the previous last line)
# Full VERIFIERS suite (loop also runs git diff --check)
sh -c 'grep -v "^#" VERIFIERS | grep -v "^$" | while read -r line; do eval "$line" || exit 1; done'
git diff --check
```

Verification: all commands above exit 0.

## Questions for the human

None. Both stop-and-ask triggers were resolved during planning:
model IDs confirmed against `models-store.json` and existing in-file
patterns, and the settings shape is unaffected by a two-element append.
