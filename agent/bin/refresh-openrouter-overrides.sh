#!/usr/bin/env bash
# Regenerate the OpenRouter anthropic-model overrides in models.json from the
# current models-store.json catalog snapshot. Run after a catalog refresh
# (pi update / 4-hourly re-fetch) so the overrides never go stale.
# Background: pi.dev marks 15 anthropic/* models as api "anthropic-messages" +
# baseUrl ".../api", but pi's openrouter provider only streams openai-completions
# -> 404. The override rewrites those 15 to the working openai-completions route
# while copying ALL catalog fields (reasoning, thinkingLevelMap, cost, context,
# input) verbatim — modelFromJson inherits only api/baseUrl from defaults.
# ponytail: abort if the catalog count changes; extend this script only after
# re-reviewing new entries.
set -euo pipefail
agent_dir="${PI_AGENT_DIR:-$HOME/.pi/agent}"
store="$agent_dir/models-store.json"
models="$agent_dir/models.json"
backup=$(mktemp)
cp "$models" "$backup"

jq --slurpfile store "$store" '
  .providers.openrouter = { models: (
    $store[0].openrouter.models
    | map(select(.api == "anthropic-messages")
      | . + { api: "openai-completions", baseUrl: "https://openrouter.ai/api/v1",
              compat: ((.compat // {}) + {thinkingFormat: "openrouter"}) })
  ) }' "$models" >"$models.new"

n=$(jq '.providers.openrouter.models | length' "$models.new")
[ "$n" -eq 15 ] || {
  echo "expected 15 override entries, got $n; catalog changed — review before applying (backup: $backup)"
  exit 1
}
jq -e '.providers.openrouter.models[] | select(.id=="anthropic/claude-fable-5.1") | .reasoning==true and .thinkingLevelMap!=null' "$models.new" >/dev/null

mv "$models.new" "$models"
echo "OK: $n overrides regenerated (backup: $backup)"
