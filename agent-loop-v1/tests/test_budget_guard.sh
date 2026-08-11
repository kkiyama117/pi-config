#!/usr/bin/env bash
# Regression test for the run budget guards (task-103): end-to-end stub runs
# of the real loop.sh (temp harness copy + fake pi on PATH, stdin-fed gates).
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(dirname "$TEST_DIR")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

# setup_harness <name>: temp copy of loop.sh + pi_usage.py, stub pi/herdr on
# PATH, fresh target repo on branch develop. Sets globals H (harness dir) and
# PATH. Not used in a substitution: the PATH export must reach the caller.
setup_harness() {
  H="$TMP/$1"
  mkdir -p "$H/bin"
  cp "$LOOP_DIR/loop.sh" "$LOOP_DIR/pi_usage.py" "$H/"
  cp "$TEST_DIR/fake_pi.sh" "$H/bin/pi"
  chmod +x "$H/bin/pi"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$H/bin/herdr"   # silence notify()
  chmod +x "$H/bin/herdr"
  export PATH="$H/bin:$PATH"
  local repo="$H/repo"
  git init -q "$repo"
  git -C "$repo" checkout -qb develop
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  git -C "$repo" commit -qm base --allow-empty
}

# run_loop <harness> <gate-answers-file> <extra-loop-env...>; sets RC (loop.sh
# exit code) and LOG (run's loop.log path). Not used in a substitution: RC/LOG
# are shell globals.
run_loop() {
  local h="$1" gates="$2"; shift 2
  set +e
  ( cd "$h" && "$@" "$h/loop.sh" --repo "$h/repo" --task "stub task" < "$gates" \
      > "$h/stdout" 2>&1 )
  RC=$?
  set -e
  LOG="$(ls -d "$h"/memory/runs/*/ | tail -1)loop.log"
}

log_has()   { if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1 (missing log: $3)"; fi; }
log_hasnt() { if grep -qF -- "$3" "$2"; then bad "$1 (unexpected log: $3)"; else ok "$1"; fi; }

# --- 1: cost guard — 90% warn once, then abort; EXIT trap still summarizes ---
setup_harness cost
h="$H"
printf 'a\n' > "$h/gates"    # GATE-1 approve; the run dies at implement
export MEMORY_DIR="$h/memory" FAKE_COST=0.9 FAKE_TOKENS=600000
run_loop "$h" "$h/gates" env MAX_RUN_COST_USD=1.0 BUDGET_WARN_PCT=80
if [[ $RC -eq 1 ]]; then ok "cost guard aborts the run (rc=1)"; else bad "rc=$RC"; fi
log_has "warn once at 90%" "$LOG" "budget warning: cost at 90% of 1.0"
log_has "abort names the limit" "$LOG" "run budget exceeded: cost 1.8"
log_has "EXIT trap cost summary still emitted" "$LOG" "cost summary: run="

# --- 2: token guard — cursor-cost-0 scenario (cost=0, tokens blow the cap) ---
setup_harness tokens
h="$H"
printf 'a\n' > "$h/gates"
export MEMORY_DIR="$h/memory" FAKE_COST=0 FAKE_TOKENS=600000
run_loop "$h" "$h/gates" env MAX_RUN_COST_USD=0 MAX_RUN_TOKENS=1000000
if [[ $RC -eq 1 ]]; then ok "token guard aborts the run (rc=1)"; else bad "rc=$RC"; fi
log_has "token abort names the cap" "$LOG" "run budget exceeded: tokens 1200000 > 1000000"
log_hasnt "cost guard did not fire" "$LOG" "run budget exceeded: cost"
log_has "cost-0 recorded, not fabricated" "$LOG" "cost unavailable (0)"

# --- 3: both guards disabled — full run completes, no warning, no abort ---
setup_harness free
h="$H"
printf 'a\na\n' > "$h/gates"    # GATE-1 + GATE-2 approve
export MEMORY_DIR="$h/memory" FAKE_COST=0.9 FAKE_TOKENS=600000
run_loop "$h" "$h/gates" env MAX_RUN_COST_USD=0 MAX_RUN_TOKENS=0
if [[ $RC -eq 0 ]]; then ok "guards disabled: run completes (rc=0)"; else bad "rc=$RC"; fi
log_has "iteration completed" "$LOG" "iteration complete"
log_hasnt "no budget warning" "$LOG" "budget warning"
log_hasnt "no budget abort" "$LOG" "run budget exceeded"

echo "PASS=$PASS FAIL=$FAIL"
if (( FAIL == 0 )); then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $((FAIL > 0))
