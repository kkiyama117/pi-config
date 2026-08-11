#!/usr/bin/env bash
# Regression test for auto worktree cleanup on the GATE-2 approve path
# (task-106): full stubbed runs of the real loop.sh — one approve (worktree
# removed, branch kept), one reject (rollback unchanged).
set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOOP_DIR="$(dirname "$TEST_DIR")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1"; }

setup_harness() { # $1=name; sets globals H (harness dir) and PATH — see
  # test_budget_guard.sh for the no-substitution rationale
  H="$TMP/$1"
  mkdir -p "$H/bin"
  cp "$LOOP_DIR/loop.sh" "$LOOP_DIR/pi_usage.py" "$H/"
  cp "$TEST_DIR/fake_pi.sh" "$H/bin/pi"
  chmod +x "$H/bin/pi"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$H/bin/herdr"
  chmod +x "$H/bin/herdr"
  export PATH="$H/bin:$PATH"
  local repo="$H/repo"
  git init -q "$repo"
  git -C "$repo" checkout -qb develop
  git -C "$repo" config user.email t@t
  git -C "$repo" config user.name t
  git -C "$repo" commit -qm base --allow-empty
}

run_loop() { # $1=harness $2=gate-answers-file; sets RC and LOG (globals)
  local h="$1" gates="$2"
  set +e
  ( cd "$h" && "$h/loop.sh" --repo "$h/repo" --task "stub task" < "$gates" \
      > "$h/stdout" 2>&1 )
  RC=$?
  set -e
  LOG="$(ls -d "$h"/memory/runs/*/ | tail -1)loop.log"
}

log_has()   { if grep -qF -- "$3" "$2"; then ok "$1"; else bad "$1 (missing log: $3)"; fi; }
log_hasnt() { if grep -qF -- "$3" "$2"; then bad "$1 (unexpected log: $3)"; else ok "$1"; fi; }

# --- 1: GATE-2 approve -> worktree removed, branch kept with the commit ---
setup_harness approve
h="$H"
printf 'a\na\n' > "$h/gates"    # GATE-1 approve, GATE-2 approve
export MEMORY_DIR="$h/memory"
run_loop "$h" "$h/gates"
if [[ $RC -eq 0 ]]; then ok "approve run completes (rc=0)"; else bad "rc=$RC"; fi
log_has "committed on loop branch" "$LOG" "committed on loop/"
log_has "cleanup log line" "$LOG" "worktree removed; branch"
log_hasnt "no leftover-worktree message" "$LOG" "worktree left at"
if [[ -z "$(ls -A "$h/worktrees" 2>/dev/null)" ]]; then
  ok "worktree directory removed"
else
  bad "worktree directory still exists: $(ls -A "$h/worktrees")"
fi
branches="$(git -C "$h/repo" branch --list 'loop/*' | tr -d '[:space:]')"
if [[ -n "$branches" ]]; then
  ok "loop branch kept ($branches)"
else
  bad "loop branch missing"
fi
if git -C "$h/repo" log --oneline "$branches" 2>/dev/null | grep -q 'agent-loop('; then
  ok "branch contains the loop commit"
else
  bad "branch has no loop commit"
fi

# --- 2: GATE-2 reject -> rollback unchanged (worktree removed, branch dropped) ---
setup_harness reject
h="$H"
printf 'a\nr\na\n' > "$h/gates"    # GATE-1 approve, GATE-2 reject, abort
export MEMORY_DIR="$h/memory"
run_loop "$h" "$h/gates"
if [[ $RC -eq 1 ]]; then ok "reject run aborts (rc=1)"; else bad "rc=$RC"; fi
log_has "rollback logged" "$LOG" "work rejected at GATE-2"
if [[ -z "$(ls -A "$h/worktrees" 2>/dev/null)" ]]; then
  ok "reject path removed the worktree"
else
  bad "reject path left a worktree"
fi
if [[ -z "$(git -C "$h/repo" branch --list 'loop/*')" ]]; then
  ok "reject path dropped the branch"
else
  bad "reject path kept the branch"
fi

echo "PASS=$PASS FAIL=$FAIL"
if (( FAIL == 0 )); then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
exit $((FAIL > 0))
