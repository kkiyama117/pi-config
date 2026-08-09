#!/usr/bin/env bash
# agent-loop v1 — HITL-first agent loop (see DESIGN.md)
#
# One iteration:
#   intake -> contract check -> plan -> [GATE 1] -> implement -> verify
#          -> review -> [GATE 2] -> commit|rollback -> record
#
# This is a SKELETON: it runs, prompts the human at both gates, and calls
# models through `pi -p`. TODO markers show where real implementations plug in.
# It never commits, merges, or mutates the target repo without GATE 2 approval.
#
# Usage:
#   ./loop.sh --repo /path/to/target --task "describe the task"
#   ./loop.sh --repo /path/to/target --task-file task.md
#   ./loop.sh --dry-run            # walk the stages without model calls
#
# Requires: pi (headless CLI), git. Optional: herdr (host pane + notifications).

set -euo pipefail

# ---------------------------------------------------------------------------
# Config (model routing — user rule 2; see DESIGN.md "Model routing")
# ---------------------------------------------------------------------------
MODEL_NORMAL="${MODEL_NORMAL:-ollama-cloud/deepseek-v4-flash:0731}"
MODEL_NORMAL_FALLBACK="${MODEL_NORMAL_FALLBACK:-cursor/composer-2-5:fast}"
MODEL_PLAN="${MODEL_PLAN:-kimi-coding/k3}"
MODEL_PLAN_FALLBACK="${MODEL_PLAN_FALLBACK:-ollama-cloud/glm-5.2}"
# Reviewer MUST differ from the worker model family (eval-engineering rule).
# Decided (Q8): gpt-5.6 via cursor (not openrouter), high/xhigh thinking.
MODEL_REVIEW="${MODEL_REVIEW:-cursor/gpt-5.6@1m:slow}"
MODEL_REVIEW_FALLBACK="${MODEL_REVIEW_FALLBACK:-cursor/claude-opus-5@1m}"
THINKING_REVIEW="${THINKING_REVIEW:-high}"   # high | xhigh (Q8)
MODEL_ESCALATE="${MODEL_ESCALATE:-cursor/gpt-5.6@1m:slow}"

MAX_CYCLES="${MAX_CYCLES:-3}"          # bounded retry cycle (graph Shape 4 hard limit)
MAX_ESCALATIONS="${MAX_ESCALATIONS:-2}" # normal -> thinking escalations per iteration
# Q11: no wall-clock cap in v1 (0 = disabled). Set STAGE_TIMEOUT_S if the agent
# is observed not stopping.
STAGE_TIMEOUT_S="${STAGE_TIMEOUT_S:-0}"

LOOP_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DIR="${MEMORY_DIR:-$LOOP_HOME/memory}"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$MEMORY_DIR/runs/$RUN_ID"

REPO=""
TASK=""
TASK_FILE=""
DRY_RUN=0

# ---------------------------------------------------------------------------
# Logging / memory (filesystem memory — inspectable, cheap; DESIGN.md)
# ---------------------------------------------------------------------------
log()  { printf '[loop %s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "$RUN_DIR/loop.log" >&2; }
die()  { log "FATAL: $*"; record_failure "$*"; exit 1; }

record() { # append a line to a memory file
  local file="$1"; shift
  printf -- '- %s %s\n' "$(date -Iseconds)" "$*" >> "$MEMORY_DIR/$file"
}
record_decision() { record "decisions-log.md" "$*"; }
record_run()      { record "past-runs.md" "$*"; }
record_failure()  { record "known-failures.md" "run=$RUN_ID $*"; }

notify() { # herdr notification when a gate is waiting (optional integration)
  if command -v herdr >/dev/null 2>&1; then
    # TODO(herdr): choose the right notification subcommand for your setup.
    herdr notification send "agent-loop: $*" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# pi headless call: pi_call <model> <fallback> <prompt-file> <out-file>
# Normal tasks route cheap-first; thinking tasks route to k3/opus/gpt-5.6.
# ---------------------------------------------------------------------------
pi_call() {
  local model="$1" fallback="$2" prompt_file="$3" out_file="$4"
  local thinking="${5:-}"
  local args=()
  [[ -n "$thinking" ]] && args+=(--thinking "$thinking")
  if [[ "$DRY_RUN" == "1" ]]; then
    log "DRY-RUN: would call pi -p --model $model ${args[*]} < $prompt_file"
    echo "[dry-run output for $model]" > "$out_file"
    return 0
  fi
  log "pi call: model=$model (fallback=$fallback) thinking=${thinking:-default} timeout=${STAGE_TIMEOUT_S}s"
  # TODO: add --mode json and parse usage for the token-report (Budget: token-report).
  # TODO(Q12): wire a cost manager like ccusage into the token-report.
  if ! timeout "$STAGE_TIMEOUT_S" pi -p --model "$model" "${args[@]}" \
        "$(cat "$prompt_file")" > "$out_file" 2>>"$RUN_DIR/pi.stderr"; then
    log "primary model failed/timeout, retrying with fallback=$fallback"
    timeout "$STAGE_TIMEOUT_S" pi -p --model "$fallback" "${args[@]}" \
      "$(cat "$prompt_file")" > "$out_file" 2>>"$RUN_DIR/pi.stderr" \
      || die "both models failed for stage (see $RUN_DIR/pi.stderr)"
  fi
  record_run "stage pi_call model=$model ok out=$out_file"
}

# ---------------------------------------------------------------------------
# HITL gate: gate <name> <artifact-to-show>
# Surfaces: shell prompt in the herdr pane (v1 default).
# Returns via global GATE_ACTION: approve | reject | redirect
# ---------------------------------------------------------------------------
GATE_ACTION=""
GATE_FEEDBACK=""
gate() {
  local name="$1" artifact="${2:-}"
  notify "GATE $name waiting for human decision (run $RUN_ID)"
  echo
  echo "==================== HITL GATE: $name ===================="
  [[ -n "$artifact" && -f "$artifact" ]] && { echo "--- artifact: $artifact ---"; cat "$artifact"; echo "---"; }
  echo "Decision required: [a]pprove  [r]eject  [d]irect (redirect with feedback)"
  local ans
  while true; do
    read -r -p "gate($name)> " ans
    case "$ans" in
      a|approve)  GATE_ACTION="approve";  break ;;
      r|reject)   GATE_ACTION="reject";   break ;;
      d|redirect) GATE_ACTION="redirect"; read -r -p "feedback> " GATE_FEEDBACK; break ;;
      *) echo "please answer a / r / d" ;;
    esac
  done
  record_decision "gate=$name action=$GATE_ACTION feedback=${GATE_FEEDBACK:-none}"
  # Alt surface (in-Pi): pi-subagents checkpoint —
  #   subagent({action:"append-step", id, step:{checkpoint:"gate1", message:"..."}})
  #   subagent({action:"approve-checkpoint"|"reject-checkpoint", id})
  #   redirect -> subagent({action:"steer", id, message: feedback})
  # TODO: add a --surface=checkpoint mode when the loop is driven from a Pi session.
}

# ---------------------------------------------------------------------------
# Verifier: deterministic commands only; structural verdict (exit != 0 => reject)
# Q10: per-repo VERIFIERS file — one command per line, run in the repo root.
# ---------------------------------------------------------------------------
verify_repo() {
  local repo="$1"
  log "verify: running deterministic checks in $repo"
  ( cd "$repo" && git diff --check ) || return 1          # diff-sanity (always)
  if [[ -f "$repo/VERIFIERS" ]]; then
    while IFS= read -r cmd; do
      [[ -z "$cmd" || "$cmd" == \#* ]] && continue
      log "verify: $cmd"
      ( cd "$repo" && eval "$cmd" ) || { log "verify FAILED: $cmd"; return 1; }
    done < "$repo/VERIFIERS"
  else
    log "verify: no VERIFIERS file in $repo — only git diff --check runs"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Stages
# ---------------------------------------------------------------------------
stage_contract_check() {
  log "stage: contract check (clean tree + baseline)"
  if ( cd "$REPO" && git status --porcelain ) | grep -q .; then
    die "target repo is dirty; refusing to start (refactor-instructions rule)"
  fi
  verify_repo "$REPO" || die "baseline verification fails; refusing to build on a red tree"
  [[ -n "$TASK" ]] || die "missing completion condition / task (BFV Kernel: define done first)"
  # Q13: main is protected — never create a loop branch from main.
  local cur_branch
  cur_branch="$(cd "$REPO" && git branch --show-current)"
  if [[ "$cur_branch" == "main" || "$cur_branch" == "master" ]]; then
    die "current branch is $cur_branch (protected); checkout develop or a sub-branch first"
  fi
}

stage_plan() {
  local feedback="${1:-}"
  log "stage: plan (thinking model)"
  cat > "$RUN_DIR/plan.prompt.md" <<EOF
You are the PLANNER for a bounded agent task. Produce plan.md only — no code.
Repository: $REPO
Task: $TASK

Rules (from the loop contract):
- Completion condition is fixed: $TASK
- For every proposed change ask: can it be omitted and completion still proven? (BFV Kernel)
- Phases: small, safe, ordered; each phase names its verification step.
- Include: Behaviors To Preserve, Non-Negotiables, Stop-And-Ask Conditions,
  Baseline Commands, Out-of-scope items.
- If anything is ambiguous, list it under "Questions for the human" instead of guessing.
EOF
  if [[ -n "$feedback" ]]; then
    echo "Human redirect feedback (must be incorporated):" >> "$RUN_DIR/plan.prompt.md"
    echo "$feedback" >> "$RUN_DIR/plan.prompt.md"
  fi
  pi_call "$MODEL_PLAN" "$MODEL_PLAN_FALLBACK" "$RUN_DIR/plan.prompt.md" "$RUN_DIR/plan.md"
}

stage_implement() {
  local feedback="${1:-}"
  log "stage: implement (normal model, worker) cycle=$CYCLE escalation=$ESCALATIONS"
  local model="$MODEL_NORMAL" fb="$MODEL_NORMAL_FALLBACK"
  if (( ESCALATIONS > 0 )); then model="$MODEL_ESCALATE"; fb="$MODEL_PLAN"; fi
  {
    echo "You are the WORKER. Implement the approved plan in $REPO."
    echo "Plan:"; cat "$RUN_DIR/plan.md"
    echo "Rules: small revertable changes; no unrelated refactors; stop and ask on ambiguity;"
    echo "run the verification commands yourself and report results; do NOT git commit."
    [[ -n "$feedback" ]] && { echo "Human redirect feedback:"; echo "$feedback"; }
    [[ -f "$RUN_DIR/review.md" ]] && { echo "Reviewer findings to address:"; cat "$RUN_DIR/review.md"; }
  } > "$RUN_DIR/implement.prompt.md"
  pi_call "$model" "$fb" "$RUN_DIR/implement.prompt.md" "$RUN_DIR/implement.out.md"
}

stage_review() {
  log "stage: review (thinking model, adversarial, different family from worker)"
  {
    echo "You are the REVIEWER. Fresh, adversarial review of the worker's diff in $REPO."
    echo "Diff:"; echo '```'; ( cd "$REPO" && git diff ); echo '```'
    echo "Report only concrete findings with file/line refs and smallest safe fixes."
    echo "Do not edit files. Verdict line: PASS or FAIL: <reason>."
  } > "$RUN_DIR/review.prompt.md"
  pi_call "$MODEL_REVIEW" "$MODEL_REVIEW_FALLBACK" "$RUN_DIR/review.prompt.md" "$RUN_DIR/review.md" "$THINKING_REVIEW"
}

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
usage() { sed -n '2,14p' "$0"; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)      REPO="$2"; shift 2 ;;
    --task)      TASK="$2"; shift 2 ;;
    --task-file) TASK_FILE="$2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    *) usage ;;
  esac
done
[[ -n "$REPO" ]] || usage
[[ -d "$REPO/.git" ]] || die "not a git repo: $REPO"
[[ -n "$TASK_FILE" ]] && TASK="$(cat "$TASK_FILE")"

mkdir -p "$RUN_DIR" "$MEMORY_DIR"
touch "$MEMORY_DIR/decisions-log.md" "$MEMORY_DIR/past-runs.md" "$MEMORY_DIR/known-failures.md"

# ---------------------------------------------------------------------------
# Concurrency guard: one loop per repo (flock-based; auto-released on exit,
# even on kill — no stale-lock cleanup needed).
# ---------------------------------------------------------------------------
LOCK_DIR="${LOCK_DIR:-$LOOP_HOME/locks}"
mkdir -p "$LOCK_DIR"
LOCK_FILE="$LOCK_DIR/$(printf '%s' "$REPO" | md5sum | cut -d' ' -f1).lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  die "another agent-loop is already running for $REPO (lock: $LOCK_FILE)"
fi
printf '%s\n' "pid=$$ started=$(date -Iseconds) repo=$REPO" >&9
log "acquired repo lock: $LOCK_FILE"

log "run $RUN_ID repo=$REPO dry_run=$DRY_RUN"
record_run "start run=$RUN_ID repo=$REPO task=${TASK:0:120}"

stage_contract_check
stage_plan

gate "GATE-1 plan approval" "$RUN_DIR/plan.md"
case "$GATE_ACTION" in
  reject)   die "plan rejected at GATE-1" ;;
  # Q7: plan-gate redirect -> feedback goes to the PLANNER.
  redirect) stage_plan "$GATE_FEEDBACK" ;;
esac

BRANCH="loop/$RUN_ID"
log "isolation: branch-per-loop + git worktree -> $BRANCH (Q14)"
MAIN_REPO="$REPO"   # keep the main checkout for worktree management
WT_DIR="$LOOP_HOME/worktrees/$RUN_ID"
mkdir -p "$LOOP_HOME/worktrees"
( cd "$MAIN_REPO" && git worktree add -b "$BRANCH" "$WT_DIR" ) \
  || die "cannot create loop worktree/branch"
REPO="$WT_DIR"   # all subsequent stages run inside the worktree

CYCLE=0; ESCALATIONS=0
while (( CYCLE < MAX_CYCLES )); do
  CYCLE=$((CYCLE + 1))
  stage_implement "${GATE_FEEDBACK:-}"

  if ! verify_repo "$REPO"; then
    log "verify FAILED (cycle $CYCLE)"
    record_failure "verify-fail run=$RUN_ID cycle=$CYCLE"
    if (( ESCALATIONS < MAX_ESCALATIONS )); then
      ESCALATIONS=$((ESCALATIONS + 1))
      log "escalating worker model ($ESCALATIONS/$MAX_ESCALATIONS)"
      continue
    fi
    gate "ESCALATION verify keeps failing" "$RUN_DIR/implement.out.md"
    [[ "$GATE_ACTION" == "reject" ]] && die "aborted by human after verify failures"
    continue
  fi

  stage_review
  if grep -q '^FAIL' "$RUN_DIR/review.md"; then
    log "review FAIL (cycle $CYCLE) — looping with findings"
    continue
  fi

  gate "GATE-2 apply approval" "$RUN_DIR/review.md"
  case "$GATE_ACTION" in
    approve)
      # Q13: loop may commit to develop/sub-branches; main is protected;
      # no merge/push in v1.
      ( cd "$REPO" && git add -A )
      if [[ "$DRY_RUN" == "1" ]]; then
        log "DRY-RUN: would commit on $BRANCH (worktree $WT_DIR)"
      else
        ( cd "$REPO" && git commit -m "agent-loop($RUN_ID): $TASK" ) \
          || die "commit failed on $BRANCH"
        log "committed on $BRANCH (worktree $WT_DIR)"
      fi
      record_decision "gate=GATE-2 approved run=$RUN_ID branch=$BRANCH committed"
      break
      ;;
    reject)
      # Q7: if the rejection is plan-level (huge bugs, scope drift), redo from
      # the planner; otherwise abort. Ask the human which one.
      echo "Reject at GATE-2: [p]lan-level problem (redo from planner)  [a]bort"
      read -r -p "gate(GATE-2 reject)> " ans
      if [[ "$ans" == "p" ]]; then
        log "GATE-2 rejected as plan-level — redoing from planner"
        ( cd "$REPO" && git checkout -q -- . ) || true
        stage_plan "GATE-2 rejection: $GATE_FEEDBACK"
        continue
      fi
      log "GATE-2 rejected — rollback"
      ( cd "$REPO" && git checkout -q -- . ) || true
      ( cd "$MAIN_REPO" && git worktree remove --force "$WT_DIR" ) || true
      ( cd "$MAIN_REPO" && git branch -D "$BRANCH" ) || true
      die "work rejected at GATE-2; branch $BRANCH dropped"
      ;;
    redirect)
      # Q7: apply-gate redirect -> feedback goes to the WORKER.
      GATE_FEEDBACK="$GATE_FEEDBACK"
      continue ;;
  esac
done
(( CYCLE >= MAX_CYCLES )) && die "max cycles ($MAX_CYCLES) reached — forced human escalation"

record_run "done run=$RUN_ID branch=$BRANCH cycles=$CYCLE"
log "iteration complete. Review $RUN_DIR for artifacts; memory in $MEMORY_DIR"
log "worktree left at $WT_DIR — remove with: git worktree remove --force $WT_DIR"
