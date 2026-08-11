#!/usr/bin/env bash
# Fake pi for agent-loop end-to-end stub tests (tasks 102/103/106): reads the
# prompt from stdin, writes a valid ok NDJSON stream (pi_usage.py-compatible)
# to stdout. Env knobs:
#   FAKE_COST / FAKE_TOKENS       usage reported per call (default 0.001 / 20)
#   FAKE_SLOW_MODEL / FAKE_SLEEP  sleep Ns when the --model matches (task-102)
# Stage detection is prompt-based: PLANNER/WORKER/REVIEWER. The WORKER stub
# creates <repo>/implemented.txt so a full run has something to commit.
set -euo pipefail
model=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) model="$2"; shift 2 ;;
    --thinking) shift 2 ;;
    *) shift ;;
  esac
done
prompt="$(cat)"
if [[ -n "${FAKE_SLOW_MODEL:-}" && "$model" == "$FAKE_SLOW_MODEL" ]]; then
  sleep "${FAKE_SLEEP:-1}"
fi
text="ok"
case "$prompt" in
  *"You are the PLANNER"*)
    text="plan: minimal diff; per-phase verification" ;;
  *"You are the WORKER"*)
    repo="$(printf '%s\n' "$prompt" | sed -n 's/.*Implement the approved plan in \(.*\)\.$/\1/p' | head -1)"
    if [[ -n "$repo" && -d "$repo" ]]; then
      printf 'stub artifact\n' > "$repo/implemented.txt"
    fi
    text="implemented" ;;
  *"You are the REVIEWER"*)
    text="PASS" ;;
esac
cost="${FAKE_COST:-0.001}"
tokens="${FAKE_TOKENS:-20}"
half=$((tokens / 2))
printf '{"type":"message_end","message":{"role":"assistant","provider":"stub","stopReason":"stop","content":[{"type":"text","text":"%s"}],"usage":{"input":%d,"output":%d,"cacheRead":0,"cacheWrite":0,"totalTokens":%d,"cost":{"total":%s}}}}\n' \
  "$text" "$half" "$half" "$tokens" "$cost"
