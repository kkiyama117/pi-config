#!/usr/bin/env bash
# LOOP.md <-> loop.sh env-default sync check (task-104).
# Used both as the VERIFIERS gate and as its own regression test: after the
# real-pair check it re-runs the extraction against mutated temp copies (both
# drift directions) and fails if a drift goes undetected.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."   # agent-loop-v1/

# key_synced <key> <VARNAME> <loop.sh> <LOOP.md>; 0 = in sync, 1 = drifted
key_synced() {
  local key="$1" var="$2" sh="$3" md="$4"
  local sh_val md_val
  # loop.sh line: VAR="${VAR:-default}" [trailing comment] -> extract "default"
  sh_val="$(sed -n "s/^${var}=\"\${${var}:-//p" "$sh" | head -1 | sed -n 's/}".*//p')"
  # LOOP.md line: "key: value" -> extract "value"
  md_val="$(sed -n "s/^${key}: *//p" "$md" | head -1)"
  if [[ -z "$sh_val" || -z "$md_val" || "$sh_val" != "$md_val" ]]; then
    echo "SYNC FAIL: $key (loop.sh=$sh_val LOOP.md=$md_val)" >&2
    return 1
  fi
  return 0
}

fail=0
for spec in "max_cycles:MAX_CYCLES" "max_escalations:MAX_ESCALATIONS" \
            "stage_timeout_s:STAGE_TIMEOUT_S" "max_run_cost_usd:MAX_RUN_COST_USD" \
            "max_run_tokens:MAX_RUN_TOKENS" "budget_warn_pct:BUDGET_WARN_PCT"; do
  key_synced "${spec%%:*}" "${spec##*:}" loop.sh LOOP.md || fail=1
done

# --- self-test: both drift directions must be detected ---
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp loop.sh LOOP.md "$tmp/"
sed -i 's/^MAX_CYCLES="${MAX_CYCLES:-3}"/MAX_CYCLES="${MAX_CYCLES:-4}"/' "$tmp/loop.sh"
if key_synced max_cycles MAX_CYCLES "$tmp/loop.sh" "$tmp/LOOP.md"; then
  echo "SELF-TEST FAIL: loop.sh-only drift of max_cycles not detected" >&2
  fail=1
else
  echo "self-test: loop.sh-only drift of max_cycles detected"
fi
sed -i 's/^max_run_cost_usd: 2.0/max_run_cost_usd: 9.9/' "$tmp/LOOP.md"
if key_synced max_run_cost_usd MAX_RUN_COST_USD "$tmp/loop.sh" "$tmp/LOOP.md"; then
  echo "SELF-TEST FAIL: LOOP.md-only drift of max_run_cost_usd not detected" >&2
  fail=1
else
  echo "self-test: LOOP.md-only drift of max_run_cost_usd detected"
fi
if (( fail == 0 )); then
  echo "LOOP.md sync OK (6 keys)"
fi
exit "$fail"
