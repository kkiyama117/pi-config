#!/usr/bin/env bash
# Regression test for the per-stage wall-clock timeout (task-102): extracts
# run_pi from loop.sh, stubs log(), runs the pi-call path with a fake pi on
# PATH (sleeping primary + instant fallback).
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(dirname "$TEST_DIR")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOGFILE="$TMP/logout"
: > "$LOGFILE"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1"; }
log_has()   { if grep -qF -- "$2" "$LOGFILE"; then ok "$1"; else bad "$1 (missing log: $2)"; fi; }
log_hasnt() { if grep -qF -- "$2" "$LOGFILE"; then bad "$1 (unexpected log: $2)"; else ok "$1"; fi; }

# --- stub log() so run_pi is self-contained ---
log() { printf '%s\n' "$*" >> "$LOGFILE"; }
extract() { awk -v fn="$1" '$0 ~ "^" fn "\\(\\)" {f=1} f{print} f && /^}/{exit}' "$LOOP_DIR/loop.sh"; }
eval "$(extract stream_status)"
eval "$(extract run_pi)"
PARSER="$LOOP_DIR/pi_usage.py"
RUN_DIR="$TMP/rundir"
mkdir -p "$RUN_DIR"
: > "$RUN_DIR/pi.stderr"
printf 'prompt\n' > "$TMP/prompt"

# fake pi on PATH
mkdir -p "$TMP/bin"
cp "$TEST_DIR/fake_pi.sh" "$TMP/bin/pi"
chmod +x "$TMP/bin/pi"
export PATH="$TMP/bin:$PATH"

# --- 1: STAGE_TIMEOUT_S=1, primary sleeps 5 -> TIMEOUT + fallback succeeds ---
STAGE_TIMEOUT_S=1
export FAKE_SLOW_MODEL="primary-model" FAKE_SLEEP=5
rc1=0; run_pi "primary-model" "$TMP/prompt" "$TMP/out1.jsonl" "implement" || rc1=$?
rc2=0; run_pi "fallback-model" "$TMP/prompt" "$TMP/out2.jsonl" "implement" || rc2=$?
if [[ $rc1 -ne 0 ]]; then ok "primary killed by timeout (rc=$rc1)"; else bad "primary rc=$rc1"; fi
if [[ $rc2 -eq 0 ]]; then ok "fallback attempt succeeds"; else bad "fallback rc=$rc2"; fi
log_has "TIMEOUT line logged" "TIMEOUT after"
log_has "primary took line kept" "pi attempt model=primary-model took"
log_has "fallback attempt line" "pi attempt model=fallback-model took"
# Primary produces TWO pi-attempt lines (took + TIMEOUT, task-102 completion
# #2); fallback produces one. 3 lines total = 2 attempts.
n_attempts="$(grep -c 'pi attempt' "$LOGFILE")"
if [[ "$n_attempts" -eq 3 ]]; then ok "3 pi attempt lines (primary took + TIMEOUT + fallback)"; else bad "attempt lines=$n_attempts"; fi

# --- 2: STAGE_TIMEOUT_S=0 disables the timeout (1s sleep succeeds) ---
STAGE_TIMEOUT_S=0
: > "$LOGFILE"
export FAKE_SLOW_MODEL="slow-model" FAKE_SLEEP=1
rc3=0; run_pi "slow-model" "$TMP/prompt" "$TMP/out3.jsonl" "implement" || rc3=$?
if [[ $rc3 -eq 0 ]]; then ok "timeout 0 disables (attempt succeeds)"; else bad "rc=$rc3"; fi
log_hasnt "no TIMEOUT line with timeout disabled" "TIMEOUT after"

echo "PASS=$PASS FAIL=$FAIL"
if (( FAIL == 0 )); then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $((FAIL > 0))
