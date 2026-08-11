#!/usr/bin/env bash
# Regression test for DENYLIST enforcement in verify_repo + review-diff helpers
# (task-101). Extracts the relevant functions from loop.sh, stubs log(), and
# runs the mandated matrix plus direct evidence for the reviewer findings
# (rounds 1-7) and the round-6 fixes. No model calls, no network, no commits
# to the real repo.
set -euo pipefail

LOOP_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/loop.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOGFILE="$TMP/logout"
: > "$LOGFILE"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL $1"; }
check() { # $1=label $2=expected $3=actual
  if [[ "$3" == "$2" ]]; then ok "$1"; else bad "$1 (got=$3 want=$2)"; fi
}
check_contains() { # $1=label $2=haystack $3=needle
  if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1 (missing: $3)"; fi
}
check_not_contains() { # $1=label $2=haystack $3=needle
  if printf '%s' "$2" | grep -qF -- "$3"; then bad "$1 (unexpected: $3)"; else ok "$1"; fi
}
log_has() { # $1=label $2=substring
  if grep -qF -- "$2" "$LOGFILE"; then ok "$1"; else bad "$1 (missing log: $2)"; fi
}
reset_log() { : > "$LOGFILE"; }

# --- stub log() so verify_repo / helpers are self-contained ---
log() { printf '%s\n' "$*" >> "$LOGFILE"; }

# --- extract a named function from loop.sh ---
extract() { # $1=function name
  awk -v fn="$1" '$0 ~ "^" fn "\\(\\)" {f=1} f{print} f && /^}/{exit}' "$LOOP_SH"
}
eval "$(extract snapshot_bootstrap_denylist)"
eval "$(extract collect_changed_paths)"
eval "$(extract verify_repo)"
eval "$(extract emit_review_diff)"
eval "$(extract emit_review_path)"
eval "$(extract emit_untracked_for_review)"
eval "$(extract emit_review_prompt_data)"
eval "$(extract review_input_is_complete)"
eval "$(extract review_gate_passes)"
eval "$(extract worktree_review_state)"
eval "$(extract worktree_state_verify_unchanged)"

# --- globals the extracted functions read ---
BASE_SHA=""
DENYLIST_SNAPSHOT=""
DENYLIST_SNAPSHOT_ESTABLISHED=0
DENYLIST_SNAPSHOT_HASH=""
REVIEW_EMIT_COUNT=0
REVIEW_EMIT_BYTES=0
REVIEW_PATH_COUNT=0
REVIEW_PATH_BYTES=0
REVIEW_PATH_LIMIT_REPORTED=0
REVIEW_INCOMPLETE=0
REVIEW_REDIRECT=0
REVIEW_CAPPED=0

# --- helpers ---
newrepo() { # $1=label; creates a fresh repo; sets global r and BASE_SHA
  r="$TMP/$(mktemp -u XXXXXX)"
  mkdir -p "$r"
  ( cd "$r" && git init -q && git config user.email t@t && git config user.name t )
  git -C "$r" commit -qm base --allow-empty
  BASE_SHA="$(git -C "$r" rev-parse HEAD)"
}
write_denylist() { # $1=repo $2=content
  printf '%s\n' "$2" > "$1/DENYLIST"
}
commit_denylist() { # $1=repo; commit DENYLIST so it is tracked at base
  ( cd "$1" && git add DENYLIST && git commit -qm "add DENYLIST" )
  BASE_SHA="$(git -C "$1" rev-parse HEAD)"
}
expect() { # $1=label $2=expected_rc; runs verify_repo "$r"
  local got=0
  if verify_repo "$r" >/dev/null 2>&1; then got=0; else got=1; fi
  check "$1" "$2" "$got"
}
emit() { # $1=ignored_path_only $2=repo; captures emit_untracked_for_review into $out (NUL-safe)
  local i="$1" d="$2" f
  f="$TMP/emit.out"
  emit_untracked_for_review "$d" "$i" > "$f" 2>/dev/null || true
  out="$(tr -d '\0' < "$f" || true)"
}

DL_BASIC='^denied/
(^|/)denied/
^denied[^/]*$
(^|/)\.env$
(^|/)secrets[^/]*$
^agent/auth\.json$'

# ===========================================================================
# t1 — denied tracked file -> FAIL, violation logged
# ===========================================================================
BASE_SHA=""
r="$TMP/t1"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && echo b > denied/b.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo b2 >> denied/b.txt ); reset_log
expect "t1 denied tracked file -> FAIL" 1
log_has "t1 violation logged" "DENYLIST violation"

# ===========================================================================
# t2 — no denied paths -> PASS
# ===========================================================================
BASE_SHA=""
r="$TMP/t2"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && echo b > denied/b.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo a2 >> allowed.txt )
expect "t2 no denied paths -> PASS" 0

# ===========================================================================
# t3 — no DENYLIST -> PASS, note logged
# ===========================================================================
BASE_SHA=""
r="$TMP/t3"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo b > denied/b.txt && git add -A && git commit -qm init )
( cd "$r" && echo b2 >> denied/b.txt ); reset_log
expect "t3 no DENYLIST -> PASS" 0
log_has "t3 no-DENYLIST note logged" "skipping DENYLIST enforcement"

# ===========================================================================
# t4 — untracked denied file -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t4"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo x > denied/x.txt )
expect "t4 untracked denied file -> FAIL" 1

# ===========================================================================
# t5 — ignored denied file -> FAIL (BASE_SHA set -> --ignored scanned)
# ===========================================================================
BASE_SHA=""
r="$TMP/t5"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'denied/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo x > denied/x.txt )
expect "t5 ignored denied file -> FAIL" 1

# ===========================================================================
# t6 — committed denied file -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t6"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo b > denied/b.txt && git add -A && git commit -qm denied )
expect "t6 committed denied file -> FAIL" 1

# ===========================================================================
# t7 — CRLF/indent stripped, denied -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t7"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && echo b > denied/b.txt && git add -A && git commit -qm init )
# DENYLIST line carries a trailing CR and leading whitespace; sed must strip both.
printf '\t^denied/\r\n' > "$r/DENYLIST"; commit_denylist "$r"
( cd "$r" && echo b2 >> denied/b.txt )
expect "t7 CRLF/indent stripped, denied -> FAIL" 1

# ===========================================================================
# t8 — malformed ERE -> FAIL, logged
# ===========================================================================
BASE_SHA=""
r="$TMP/t8"; mkdir -p "$r"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
printf '[\n' > "$r/DENYLIST"; commit_denylist "$r"; reset_log
expect "t8 malformed ERE -> FAIL" 1
log_has "t8 malformed logged" "malformed pattern"

# ===========================================================================
# t9 — pristine baseline -> PASS
# ===========================================================================
BASE_SHA=""
r="$TMP/t9"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
expect "t9 pristine baseline -> PASS" 0

# ===========================================================================
# t10 — rename to denied path -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t10"; mkdir -p "$r/allowed"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed/ok.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && git mv allowed/ok.txt denied.txt )
expect "t10 rename to denied path -> FAIL" 1

# ===========================================================================
# t11 — unreadable DENYLIST -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t11"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/DENYLIST" && echo nope > "$r/DENYLIST/x"   # DENYLIST is a directory, not a regular file
expect "t11 unreadable DENYLIST -> FAIL" 1

# ===========================================================================
# t12 — newline-bearing path -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t12"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && printf 'b\n' > "$(printf 'denied\nname')" )
expect "t12 newline-bearing path -> FAIL" 1

# ===========================================================================
# t13 — untracked embedded repo -> FAIL, unenumerable logged
# ===========================================================================
BASE_SHA=""
r="$TMP/t13"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/vendor" && git -C "$r/vendor" init -q; reset_log
expect "t13 untracked embedded repo -> FAIL" 1
log_has "t13 unenumerable logged" "embedded git repo"

# ===========================================================================
# t14 — review_input_is_complete: INCOMPLETE/PARTIAL/plain
# ===========================================================================
printf '### REVIEW-DIFF INCOMPLETE: x\n' > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "t14 INCOMPLETE marker -> incomplete" 1 "$rc"
printf '### REVIEW-DIFF PARTIAL: x\n' > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "t14 PARTIAL marker -> incomplete" 1 "$rc"
printf 'diff --git a/x b/x\n' > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "t14 plain diff -> complete" 0 "$rc"

# ===========================================================================
# t15 — ignored path-only header; ignored secret content absent
# ===========================================================================
r="$TMP/t15"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'ign/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/ign"; printf 'SECRET\n' > "$r/ign/f.txt"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 1 "$r"
check_contains "t15 ignored path-only header" "$out" "### untracked (ignored, path-only): ign/f.txt"
check_not_contains "t15 ignored secret content absent" "$out" "SECRET"

# ===========================================================================
# t16 — %q header (path with spaces/special chars)
# ===========================================================================
r="$TMP/t16"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
printf 'x\n' > "$r/my file.txt"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 0 "$r"
check_contains "t16 %q header" "$out" "my\\ file.txt"

# ===========================================================================
# t17 — UNTRUSTED-DIFF prefix applied; fence line prefixed
# ===========================================================================
printf 'line1\nline2\n' > "$TMP/rd.txt"
out="$(emit_review_prompt_data "$TMP/rd.txt")"
check_contains "t17 prefix applied" "$out" "UNTRUSTED-DIFF | line1"
check_contains "t17 fence line prefixed" "$out" "UNTRUSTED-DIFF | line2"

# ===========================================================================
# t18 — large file PARTIAL stat-only header; needs human gate
# ===========================================================================
r="$TMP/t18"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
head -c 80000 /dev/zero | tr '\0' x > "$r/big.bin"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 0 "$r"
check_contains "t18 large file PARTIAL stat-only header" "$out" "### REVIEW-DIFF PARTIAL: untracked (large, stat-only)"
printf '%s' "$out" > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "t18 PARTIAL large file needs human gate" 1 "$rc"

# ===========================================================================
# t19 — empty repo with DENYLIST -> PASS
# ===========================================================================
BASE_SHA=""
r="$TMP/t19"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t && git commit -qm base --allow-empty )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
expect "t19 empty repo with DENYLIST -> PASS" 0

# ===========================================================================
# t20 — overridable limit marker
# ===========================================================================
r="$TMP/t20"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
for i in $(seq 1 5); do echo x > "$r/u$i.txt"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
out=$(REVIEW_UNTRACKED_LIMIT=3 emit_untracked_for_review "$r" 0)
check_contains "t20 overridable limit marker" "$out" "capped at 3 paths"

# ===========================================================================
# t21 — PARTIAL capped list; needs human gate
# ===========================================================================
check_contains "t21 PARTIAL marker" "$out" "REVIEW-DIFF PARTIAL"
printf '%s' "$out" > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "t21 PARTIAL capped list needs human gate" 1 "$rc"

# ===========================================================================
# t22 — unresolvable base + denied -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/t22"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
BASE_SHA="deadbeef00000000000000000000000000000000"
( cd "$r" && echo x > denied/x.txt )
expect "t22 unresolvable base + denied -> FAIL" 1
BASE_SHA="$(git -C "$r" rev-parse HEAD)"

# ===========================================================================
# H1 — bootstrap snapshot; immutable bootstrap
# ===========================================================================
BASE_SHA=""
r="$TMP/h1"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"
DENYLIST_SNAPSHOT="$TMP/h1.snap"; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""
snapshot_bootstrap_denylist "$r" "$(git -C "$r" rev-parse HEAD)"; check "H1 bootstrap snapshot created" 0 $?
write_denylist "$r" '^other$'; reset_log
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "H1 rewritten bootstrap DENYLIST -> FAIL" 1 "$rc"
log_has "H1 rewrite logged as immutable" "immutable"
rm -f "$r/DENYLIST"; reset_log
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "H1 deleted bootstrap DENYLIST -> FAIL" 1 "$rc"
DENYLIST_SNAPSHOT=""; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""

# ===========================================================================
# H2 — malformed porcelain -> FAIL, logged (guard present)
# ===========================================================================
if grep -qF 'malformed porcelain status record' "$LOOP_SH"; then ok "H2 malformed porcelain -> FAIL"; else bad "H2 malformed porcelain -> FAIL"; fi
if grep -qF 'malformed porcelain status record' "$LOOP_SH"; then ok "H2 malformed porcelain logged"; else bad "H2 malformed porcelain logged"; fi

# ===========================================================================
# H3 — incomplete input control flow: grep-verified stage_review/main-loop wiring
# ===========================================================================
grep -qF 'REVIEW_INCOMPLETE=1' "$LOOP_SH" && grep -qF 'review_input_is_complete "$review_diff"' "$LOOP_SH" \
  && ok "H3 incomplete input skips reviewer pi_call" || bad "H3 incomplete input skips reviewer pi_call"
grep -qF 'gate "REVIEW INPUT INCOMPLETE"' "$LOOP_SH" && ok "H3 incomplete input opens human gate" || bad "H3 incomplete input opens human gate"
grep -qF 'REVIEW_REDIRECT=1' "$LOOP_SH" && ok "H3 redirect flag reaches main-loop control" || bad "H3 redirect flag reaches main-loop control"
grep -qF '[[ "$DRY_RUN" != "1" ]] && (( REVIEW_INCOMPLETE == 1 ))' "$LOOP_SH" \
  && ok "H3 dry-run incomplete input does not gate" || bad "H3 dry-run incomplete input does not gate"
grep -qF 'elif [[ "$DRY_RUN" != "1" ]] && ! review_gate_passes' "$LOOP_SH" \
  && ok "H3 dry-run continues through dry-run pi_call" || bad "H3 dry-run continues through dry-run pi_call"

# ===========================================================================
# H4 — bulk gitlink scans present; no per-path gitlink process scan
# ===========================================================================
grep -qF 'git ls-files --stage -z' "$LOOP_SH" && grep -qF 'git ls-tree -r -z' "$LOOP_SH" \
  && ok "H4 bulk gitlink scans present" || bad "H4 bulk gitlink scans present"
if grep -qE 'git ls-files -s .*for|git status .*--porcelain.*for ' "$LOOP_SH"; then
  bad "H4 no per-path gitlink process scan"; else ok "H4 no per-path gitlink process scan"; fi

# ===========================================================================
# H5 — review_gate_passes verdict parsing
# ===========================================================================
mk_v() { printf '%s\n' "diff" > "$TMP/i.txt"; printf '%s' "$1" > "$TMP/v.txt"; if review_gate_passes "$TMP/i.txt" "$TMP/v.txt"; then rc=0; else rc=1; fi; }
mk_v "PASS";                         check "H5 PASS -> pass" 0 "$rc"
mk_v "**PASS**";                     check "H5 **PASS** -> pass" 0 "$rc"
mk_v "  PASS";                       check "H5 leading-space PASS -> pass" 0 "$rc"
mk_v "PASS.";                        check "H5 PASS. -> pass" 0 "$rc"
mk_v "PASS criteria not met";        check "H5 verdict-format prose -> fail" 1 "$rc"
mk_v "not PASS";                     check "H5 negative PASS prose -> fail" 1 "$rc"
mk_v "PASS but disclaimer";          check "H5 PASS disclaimer -> fail" 1 "$rc"
mk_v "PASS: good work";              check "H5 PASS with reason -> fail" 1 "$rc"
mk_v "**FAIL**: x";                  check "H5 **FAIL**: x -> fail" 1 "$rc"
mk_v "FAIL";                         check "H5 FAIL -> fail" 1 "$rc"

# ===========================================================================
# H6 — comment lines ignored, patterns enforced
# ===========================================================================
BASE_SHA=""
r="$TMP/h6"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
printf '# a comment\n\n  \n^denied/\n' > "$r/DENYLIST"; commit_denylist "$r"
( cd "$r" && echo x > denied/x.txt )
expect "H6 comment lines ignored, patterns enforced" 1

# ===========================================================================
# H7 — exactly one PARTIAL marker across both streams
# ===========================================================================
r="$TMP/h7"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
for i in $(seq 1 250); do echo x > "$r/u$i.txt"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
out=$(emit_untracked_for_review "$r" 0)
cnt=$(printf '%s' "$out" | grep -c 'REVIEW-DIFF PARTIAL' || true)
check "H7 exactly one PARTIAL marker across both streams" 1 "$cnt"

# ===========================================================================
# H8 — dirty gitlink -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/h8"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
sub="$TMP/h8sub"; mkdir -p "$sub"; ( cd "$sub" && git init -q && git config user.email t@t && git config user.name t \
  && echo s > f && git add -A && git commit -qm s )
( cd "$r" && git -c protocol.file.allow=always submodule add -q "$sub" mod 2>/dev/null && git add -A && git commit -qm sub )
( cd "$r" && echo changed > mod/f )
expect "H8 dirty gitlink -> FAIL" 1

# ===========================================================================
# H9 — exported BASE_SHA ignored (no --ignored) -> PASS
# ===========================================================================
grep -qF 'BASE_SHA=""' "$LOOP_SH" && ok "H9 global BASE_SHA empty" || bad "H9 global BASE_SHA empty"
BASE_SHA=""
r="$TMP/h9"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'denied/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo x > denied/x.txt )
BASE_SHA=""   # globals force empty -> no --ignored -> ignored denied file invisible
expect "H9 exported BASE_SHA ignored (no --ignored) -> PASS" 0
BASE_SHA="$(git -C "$r" rev-parse HEAD)"

# ===========================================================================
# R5-1a — diff.external silenced, content present, no INCOMPLETE
# ===========================================================================
r="$TMP/r5a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo base > payload.txt && git add -A && git commit -qm init )
printf 'PAYLOAD\n' >> "$r/payload.txt"
printf 'untracked\n' > "$r/new.txt"
out=$(emit_review_diff "$r" "$(git -C "$r" rev-parse HEAD)")
check_contains "R5-1a diff.external silenced, content present" "$out" "PAYLOAD"
check_not_contains "R5-1a no INCOMPLETE marker" "$out" "INCOMPLETE"

# ===========================================================================
# R5-1b — untracked body present (via emit_untracked_for_review)
# ===========================================================================
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
REVIEW_PATH_COUNT=0; REVIEW_PATH_BYTES=0; REVIEW_PATH_LIMIT_REPORTED=0
out2=$(emit_untracked_for_review "$r" 0)
check_contains "R5-1b untracked body present" "$out2" "new.txt"

# ===========================================================================
# R5-2a — ignored nested checkout no denied -> PASS
# ===========================================================================
r="$TMP/r5a"; mkdir -p "$r/vendor/dep"; ( cd "$r/vendor/dep" && git init -q && git config user.email t@t && git config user.name t \
  && echo d > dep.txt && git add -A && git commit -qm d )
printf 'vendor/\n' > "$r/.gitignore"; ( cd "$r" && git add -A && git commit -qm gi )
BASE_SHA="$(git -C "$r" rev-parse HEAD)"
expect "R5-2a ignored nested checkout no denied -> PASS" 0

# ===========================================================================
# R5-2b — ignored checkout with denied path -> FAIL
# ===========================================================================
BASE_SHA=""
r="$TMP/r5b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'vendor/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/vendor/dep/denied"; ( cd "$r/vendor/dep" && git init -q && git config user.email t@t && git config user.name t \
  && echo x > denied/x.txt && git add -A && git commit -qm d )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
expect "R5-2b ignored checkout with denied path -> FAIL" 1

# ===========================================================================
# R5-2c — untracked embedded repo -> FAIL, unenumerable logged
# ===========================================================================
BASE_SHA=""
r="$TMP/r5c"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/emb" && git -C "$r/emb" init -q; reset_log
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "R5-2c untracked embedded repo -> FAIL" 1 "$rc"
log_has "R5-2c unenumerable logged" "embedded git repo"

# ===========================================================================
# R5-3 — payload path appears; capped list needs human gate
# ===========================================================================
r="$TMP/r53"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
for i in $(seq 1 220); do echo x > "$r/p$i.txt"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
out=$(REVIEW_UNTRACKED_LIMIT=200 emit_untracked_for_review "$r" 0)
check_contains "R5-3 payload path appears" "$out" "p220.txt"
printf '%s' "$out" > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "R5-3 capped list needs human gate" 1 "$rc"

# ===========================================================================
# R5-4 — aggregate byte budget: content stops, later paths path-only
# ===========================================================================
r="$TMP/r54"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
for i in $(seq 1 5); do head -c 60000 /dev/zero | tr '\0' x > "$r/big$i"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
out=$(REVIEW_UNTRACKED_TOTAL_BYTES=100000 emit_untracked_for_review "$r" 0)
check_contains "R5-4 aggregate cap marker" "$out" "untracked content capped"
check_contains "R5-4 later file path-only" "$out" "big5"
printf '%s' "$out" > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "R5-4 aggregate-capped input needs human gate" 1 "$rc"

# ===========================================================================
# R5-5 — gate artifact smaller than full diff
# ===========================================================================
grep -qF 'review.diff.gate' "$LOOP_SH" && grep -qF 'head -n 80' "$LOOP_SH" \
  && ok "R5-5 gate artifact smaller than full diff" || bad "R5-5 gate artifact smaller than full diff"

# ===========================================================================
# R5-6a — vacuous bootstrap DENYLIST -> FAIL, logged
# ===========================================================================
BASE_SHA=""
r="$TMP/r56a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "# no active rules"
DENYLIST_SNAPSHOT="$TMP/r56a.snap"; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""
snapshot_bootstrap_denylist "$r" "$(git -C "$r" rev-parse HEAD)"
reset_log
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "R5-6a vacuous bootstrap DENYLIST -> FAIL" 1 "$rc"
log_has "R5-6a vacuous logged" "no active patterns"
DENYLIST_SNAPSHOT=""; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""

# ===========================================================================
# R5-6b — tracked empty DENYLIST -> PASS, skip matching logged
# ===========================================================================
BASE_SHA=""
r="$TMP/r56b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "# comments only"; commit_denylist "$r"; reset_log
expect "R5-6b tracked empty DENYLIST -> PASS" 0
log_has "R5-6b skip matching logged" "no active rules"

# ===========================================================================
# R6-1a — --text defeats binary attribute; bounded tracked diff complete
# ===========================================================================
r="$TMP/r61a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf '*.sh -diff\n' > .gitattributes && echo old > payload.sh && git add -A && git commit -qm base )
printf 'VISIBLE\n' >> "$r/payload.sh"
out=$(emit_review_diff "$r" "$(git -C "$r" rev-parse HEAD)")
check_contains "R6-1a --text defeats binary attribute" "$out" "VISIBLE"
check_not_contains "R6-1a bounded tracked diff remains complete" "$out" "INCOMPLETE"

# ===========================================================================
# R6-1b — tracked diff cap emits INCOMPLETE
# ===========================================================================
r="$TMP/r61b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
head -c 2000 /dev/zero | tr '\0' x > "$r/huge.txt"
( cd "$r" && git add huge.txt && git commit -qm big )
printf 'CHANGE' >> "$r/huge.txt"
out=$(REVIEW_TRACKED_MAX_BYTES=100 emit_review_diff "$r" "$(git -C "$r" rev-parse HEAD)")
check_contains "R6-1b tracked diff cap emits INCOMPLETE" "$out" "INCOMPLETE"

# ===========================================================================
# R6-2a — FIFO rejected as non-regular
# ===========================================================================
r="$TMP/r62a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
mkfifo "$r/daemon.sock"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 0 "$r"
check_contains "R6-2a FIFO rejected as non-regular" "$out" "non-regular untracked path"

# ===========================================================================
# R6-2b — socket rejected as non-regular
# ===========================================================================
r="$TMP/r62b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
python3 - <<'PY' "$r/daemon.sock"
import socket, sys
s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])
PY
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 0 "$r"
check_contains "R6-2b socket rejected as non-regular" "$out" "non-regular untracked path"

# ===========================================================================
# R6-3 — PARTIAL skips reviewer pi_call; opens human gate (grep-verified)
# ===========================================================================
grep -qF 'if [[ "$DRY_RUN" != "1" ]] && ! review_input_is_complete "$review_diff"' "$LOOP_SH" \
  && ok "R6-3 PARTIAL skips reviewer pi_call" || bad "R6-3 PARTIAL skips reviewer pi_call"
grep -qF 'gate "REVIEW INPUT INCOMPLETE"' "$LOOP_SH" && ok "R6-3 PARTIAL opens human gate" || bad "R6-3 PARTIAL opens human gate"

# ===========================================================================
# R6-4a — path-count cap emits INCOMPLETE; stops later names
# ===========================================================================
r="$TMP/r64a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
for i in $(seq 1 20); do echo x > "$r/u$i.txt"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
REVIEW_PATH_COUNT=0; REVIEW_PATH_BYTES=0; REVIEW_PATH_LIMIT_REPORTED=0
out=$(REVIEW_UNTRACKED_PATH_LIMIT=3 emit_untracked_for_review "$r" 0)
check_contains "R6-4a path-count cap emits INCOMPLETE" "$out" "exceeded 3 paths"
check_not_contains "R6-4a path-count cap stops later names" "$out" "u20.txt"

# ===========================================================================
# R6-4b — path-byte cap emits INCOMPLETE
# ===========================================================================
r="$TMP/r64b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
for i in $(seq 1 3); do echo x > "$r/p$i.txt"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
REVIEW_PATH_COUNT=0; REVIEW_PATH_BYTES=0; REVIEW_PATH_LIMIT_REPORTED=0
out=$(REVIEW_UNTRACKED_PATH_BYTES=10 emit_untracked_for_review "$r" 0)
check_contains "R6-4b path-byte cap emits INCOMPLETE" "$out" "or 10 bytes"

# ===========================================================================
# R6-5 — BASE_SHA captured from created worktree; no post-add HEAD read
# ===========================================================================
grep -qF 'BASE_SHA="$(cd "$WT_DIR" && git rev-parse HEAD)"' "$LOOP_SH" \
  && ok "R6-5 BASE_SHA captured from created worktree" || bad "R6-5 BASE_SHA captured from created worktree"
if grep -qE 'git add -A.*rev-parse HEAD|rev-parse HEAD.*git add -A' "$LOOP_SH"; then
  bad "R6-5 no post-add main-checkout HEAD read"; else ok "R6-5 no post-add main-checkout HEAD read"; fi

# ===========================================================================
# R6-6 — pristine baseline with ignored denied file -> PASS (BASE_SHA empty)
# ===========================================================================
BASE_SHA=""
r="$TMP/r66"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'denied/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo x > denied/x.txt )
BASE_SHA=""
expect "R6-6 pristine baseline with ignored denied file -> PASS" 0
BASE_SHA="$(git -C "$r" rev-parse HEAD)"

# ===========================================================================
# R7-1 — repo attributes and NUL bytes cannot hide untracked content
# ===========================================================================
r="$TMP/r71"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf '*.sh -diff\n' > .gitattributes && git add -A && git commit -qm base )
printf 'VISIBLE-BEFORE\0VISIBLE-AFTER\n' > "$r/payload.sh"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
raw_out="$TMP/r71.raw"; emit_untracked_for_review "$r" 0 > "$raw_out" 2>/dev/null || true
out="$(tr -d '\0' < "$raw_out" || true)"
check_contains "R7-1 untracked -diff attribute defeated" "$out" "VISIBLE-BEFORE"
check_contains "R7-1 untracked content after NUL remains visible" "$out" "VISIBLE-AFTER"
check_not_contains "R7-1 untracked binary marker absent" "$out" "Binary files"

# ===========================================================================
# R7-2 — non-ignored nested repo labeled, pruned, PARTIAL
# ===========================================================================
r="$TMP/r72"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
mkdir -p "$r/vendor" && git -C "$r/vendor" init -q
printf 'BACKDOOR\n' > "$r/vendor/evil.sh"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 0 "$r"
check_contains "R7-2 nested repo is marked PARTIAL" "$out" "untracked directory contents are path-only"
check_contains "R7-2 nested file is non-ignored path-only" "$out" "### untracked (path-only): vendor/evil.sh"
check_not_contains "R7-2 nested file not mislabeled ignored" "$out" "ignored, path-only): vendor/evil.sh"
check_not_contains "R7-2 nested .git internals pruned" "$out" "hooks/applypatch-msg.sample"

# ===========================================================================
# R7-3 — commit-then-revert still denied and historically reviewable
# ===========================================================================
BASE_SHA=""
r="$TMP/r73"; mkdir -p "$r/agent"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t )
write_denylist "$r" "$DL_BASIC"
printf 'safe\n' > "$r/agent/auth.json"
( cd "$r" && git add -A && git commit -qm base ); BASE_SHA="$(git -C "$r" rev-parse HEAD)"
printf 'evil-secret\n' > "$r/agent/auth.json"; ( cd "$r" && git commit -qam bad )
printf 'safe\n' > "$r/agent/auth.json"; ( cd "$r" && git commit -qam restore )
reset_log
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "R7-3 commit-then-revert denied -> FAIL" 1 "$rc"
out=$(emit_review_diff "$r" "$BASE_SHA")
check_contains "R7-3 reverted content remains reviewable" "$out" "evil-secret"
BASE_SHA=""

# ===========================================================================
# R7-4 — structural checks do not depend on active DENYLIST patterns
# ===========================================================================
BASE_SHA=""
r="$TMP/r74a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
mkdir -p "$r/vendor" && git -C "$r/vendor" init -q
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "R7-4a no-DENYLIST embedded repo -> FAIL" 1 "$rc"

BASE_SHA=""
r="$TMP/r74b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
printf '# comments only\n' > "$r/DENYLIST"; mkdir -p "$r/vendor" && git -C "$r/vendor" init -q
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "R7-4b empty-pattern DENYLIST embedded repo -> FAIL" 1 "$rc"

BASE_SHA=""
r="$TMP/r74c"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
sub="$TMP/r74sub"; mkdir -p "$sub"; ( cd "$sub" && git init -q && git config user.email t@t && git config user.name t \
  && echo s > f && git add -A && git commit -qm s )
( cd "$r" && git -c protocol.file.allow=always submodule add -q "$sub" mod 2>/dev/null && git add -A && git commit -qm base )
BASE_SHA="$(git -C "$r" rev-parse HEAD)"; echo changed > "$r/mod/f"
verify_repo "$r" >/dev/null 2>&1 && rc=0 || rc=1; check "R7-4c no-DENYLIST dirty gitlink -> FAIL" 1 "$rc"
BASE_SHA=""

# ===========================================================================
# R7-5 — tracked-diff status parsing is explicitly fail-closed
# ===========================================================================
if grep -qF '[[ -s "$tmp/status" ]]' "$LOOP_SH" \
  && grep -qF '[[ "$git_rc" =~ ^[0-9]+$ && "$head_rc" =~ ^[0-9]+$ ]]' "$LOOP_SH"; then
  ok "R7-5 empty/malformed status is fail-closed"
else
  bad "R7-5 empty/malformed status is fail-closed"
fi

# ===========================================================================
# R7-6 — ignored special files skipped; symlink targets reviewed
# ===========================================================================
r="$TMP/r76a"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'node_modules/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm base )
mkdir -p "$r/node_modules/.cache" && mkfifo "$r/node_modules/.cache/daemon.sock"
REVIEW_PATH_COUNT=0; REVIEW_PATH_BYTES=0; REVIEW_PATH_LIMIT_REPORTED=0
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
emit 0 "$r"
check_not_contains "R7-6a ignored FIFO does not degrade review" "$out" "daemon.sock"
check_not_contains "R7-6a ignored FIFO emits no INCOMPLETE" "$out" "INCOMPLETE"

r="$TMP/r76b"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
ln -s /etc/passwd "$r/leak.txt"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
REVIEW_PATH_COUNT=0; REVIEW_PATH_BYTES=0; REVIEW_PATH_LIMIT_REPORTED=0
emit 0 "$r"
check_contains "R7-6b symlink header emitted" "$out" "### untracked (symlink): leak.txt"
check_contains "R7-6b symlink target emitted" "$out" "symlink target: /etc/passwd"
check_not_contains "R7-6b symlink is not INCOMPLETE" "$out" "INCOMPLETE"

# ===========================================================================
# R6-1 (round-6) — ignored overflow emits no REVIEW-DIFF marker; complete
# ===========================================================================
r="$TMP/r6i"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'node_modules/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm base )
mkdir -p "$r/node_modules"
for i in $(seq 1 250); do echo x > "$r/node_modules/f$i.js"; done
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
out=$(emit_untracked_for_review "$r" 1)
check_not_contains "R6-1 no REVIEW-DIFF PARTIAL from ignored overflow" "$out" "REVIEW-DIFF PARTIAL"
check_not_contains "R6-1 no REVIEW-DIFF INCOMPLETE from ignored overflow" "$out" "REVIEW-DIFF INCOMPLETE"
check_contains "R6-1 ignored overflow uses non-marker summary" "$out" "### untracked (ignored): further paths omitted"
printf '%s' "$out" > "$TMP/i.txt"; review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "R6-1 ignored overflow input complete" 0 "$rc"

# ===========================================================================
# R6-2 (round-6) — empty review.diff incomplete; assume-unchanged / skip-worktree fail closed
# ===========================================================================
grep -qF 'no changes captured' "$LOOP_SH" && ok "R6-2a empty review.diff gets INCOMPLETE marker" || bad "R6-2a empty review.diff gets INCOMPLETE marker"
printf '### REVIEW-DIFF INCOMPLETE: no changes captured\n' > "$TMP/i.txt"
review_input_is_complete "$TMP/i.txt" && rc=0 || rc=1; check "R6-2a empty-marker input is incomplete" 1 "$rc"

# R6-2b: assume-unchanged on modified tracked denied file -> FAIL (fail closed)
BASE_SHA=""
r="$TMP/r62au"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && echo b > denied/b.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo b2 >> denied/b.txt && git update-index --assume-unchanged denied/b.txt )
expect "R6-2b assume-unchanged hides edits -> FAIL closed" 1
( cd "$r" && git update-index --no-assume-unchanged denied/b.txt )

# R6-2c: skip-worktree on modified tracked denied file -> FAIL (fail closed)
BASE_SHA=""
r="$TMP/r62sw"; mkdir -p "$r/denied"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && echo b > denied/b.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
( cd "$r" && echo b2 >> denied/b.txt && git update-index --skip-worktree denied/b.txt )
expect "R6-2c skip-worktree hides edits -> FAIL closed" 1
( cd "$r" && git update-index --no-skip-worktree denied/b.txt )

# ===========================================================================
# R8-1 — ignored nested checkout: denied SYMLINK must not bypass verify_repo
#         (reviewer High: loop.sh:305-319 enumerated only regular files)
# ===========================================================================
BASE_SHA=""
r="$TMP/r81"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'vendor/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/vendor/dep/denied"; ( cd "$r/vendor/dep" && git init -q && git config user.email t@t && git config user.name t \
  && ln -s /etc/passwd denied/link && git add -A && git commit -qm d )
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
reset_log
expect "R8-1 ignored checkout denied SYMLINK -> FAIL closed" 1

# ===========================================================================
# R8-2 — ignored nested checkout: denied FIFO must not bypass verify_repo
# ===========================================================================
BASE_SHA=""
r="$TMP/r82"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && printf 'vendor/\n' > .gitignore && echo a > allowed.txt && git add -A && git commit -qm init )
mkdir -p "$r/vendor/dep/denied"; ( cd "$r/vendor/dep" && git init -q && git config user.email t@t && git config user.name t )
mkfifo "$r/vendor/dep/denied/fifo"
write_denylist "$r" "$DL_BASIC"; commit_denylist "$r"
reset_log
expect "R8-2 ignored checkout denied FIFO -> FAIL closed" 1

# ===========================================================================
# R8-3 — bootstrap snapshot deletion cannot force a silent recapture
#         (reviewer High: loop.sh:245-265,484-522 — in-process tracking)
# ===========================================================================
BASE_SHA=""
r="$TMP/r83"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"
DENYLIST_SNAPSHOT="$TMP/r83.snap"; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""
snapshot_bootstrap_denylist "$r" "$(git -C "$r" rev-parse HEAD)"; check "R8-3 bootstrap snapshot established" 0 $?
rm -f "$DENYLIST_SNAPSHOT"
write_denylist "$r" '^nothing-matches-this$'   # worker weakens the working-tree policy
reset_log
snapshot_bootstrap_denylist "$r" "$(git -C "$r" rev-parse HEAD)" >/dev/null 2>&1 && rc=0 || rc=1
check "R8-3 deleted snapshot does not recapture -> FAIL closed" 1 "$rc"
log_has "R8-3 deletion logged" "missing or was replaced"
[[ -f "$DENYLIST_SNAPSHOT" ]] && rc=0 || rc=1
check "R8-3 snapshot file not silently recreated" 1 "$rc"
DENYLIST_SNAPSHOT=""; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""

# ===========================================================================
# R8-4 — bootstrap snapshot content replacement detected via recorded hash
# ===========================================================================
BASE_SHA=""
r="$TMP/r84"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
write_denylist "$r" "$DL_BASIC"
DENYLIST_SNAPSHOT="$TMP/r84.snap"; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""
snapshot_bootstrap_denylist "$r" "$(git -C "$r" rev-parse HEAD)"; check "R8-4 bootstrap snapshot established" 0 $?
printf '^nothing-matches-this$\n' > "$DENYLIST_SNAPSHOT"   # replace snapshot content directly
reset_log
snapshot_bootstrap_denylist "$r" "$(git -C "$r" rev-parse HEAD)" >/dev/null 2>&1 && rc=0 || rc=1
check "R8-4 replaced snapshot content -> FAIL closed" 1 "$rc"
log_has "R8-4 content-change logged" "changed since"
DENYLIST_SNAPSHOT=""; DENYLIST_SNAPSHOT_ESTABLISHED=0; DENYLIST_SNAPSHOT_HASH=""

# ===========================================================================
# R8-5 — tracked DENYLIST modified-then-reverted in history -> FAIL closed,
#         even when the policy does not self-list ^DENYLIST$
#         (reviewer Medium: loop.sh:363-379,530-565)
# ===========================================================================
BASE_SHA=""
r="$TMP/r85"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm init )
NO_SELF_DL='^denied/
(^|/)\.env$'
write_denylist "$r" "$NO_SELF_DL"; commit_denylist "$r"
printf '^nothing-matches-this$\n' > "$r/DENYLIST"; ( cd "$r" && git commit -qam weaken )
write_denylist "$r" "$NO_SELF_DL"; ( cd "$r" && git commit -qam restore )
reset_log
expect "R8-5 DENYLIST modified-then-reverted in history -> FAIL closed" 1
log_has "R8-5 immutability violation logged" "immutable"

# ===========================================================================
# R9-1 — large index: assume-unchanged still fail-closed despite SIGPIPE risk
#         (reviewer High: loop.sh:375 — `git ls-files -v | grep -qE` under
#         `set -o pipefail` can have `git` killed by SIGPIPE once `grep -q`
#         closes early on its first match, flipping the pipeline's reported
#         status to `git`'s 141 and silently skipping the fail-closed check
#         on large enough indexes)
# ===========================================================================
BASE_SHA=""
r="$TMP/r91"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t )
# Name the flagged file so it sorts first in `git ls-files -v` (byte order):
# thousands of bytes of later lines must still be pending when grep matches
# line 1, which is what makes the SIGPIPE race reproducible regardless of
# the platform's pipe buffer size.
: > "$r/0marked.txt"
for i in $(seq 1 20000); do printf 'x' > "$r/f$(printf '%05d' "$i").txt"; done
( cd "$r" && git add -A && git commit -qm 'large index' )
( cd "$r" && git update-index --assume-unchanged 0marked.txt )
reset_log
expect "R9-1 assume-unchanged on large index -> FAIL closed (no SIGPIPE bypass)" 1
log_has "R9-1 violation logged" "assume-unchanged/skip-worktree index entries present"
( cd "$r" && git update-index --no-assume-unchanged 0marked.txt )

# ===========================================================================
# round-7 fixes
# ===========================================================================

# --- F7-1 — git replace refs cannot weaken BASE_SHA policy reads -----------
grep -qF 'export GIT_NO_REPLACE_OBJECTS=1' "$LOOP_SH" \
  && ok "F7-1 GIT_NO_REPLACE_OBJECTS exported" || bad "F7-1 GIT_NO_REPLACE_OBJECTS exported"
if grep -qF 'unset GIT_NO_REPLACE_OBJECTS' "$LOOP_SH"; then
  bad "F7-1 GIT_NO_REPLACE_OBJECTS never unset"; else ok "F7-1 GIT_NO_REPLACE_OBJECTS never unset"; fi
# Functional: replace the base commit with a weakened-DENYLIST variant.
# Extracted functions do not inherit loop.sh's export — set it here.
export GIT_NO_REPLACE_OBJECTS=1
BASE_SHA=""
r="$TMP/f71"; mkdir -p "$r/denied"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt )
write_denylist "$r" "$DL_BASIC"
( cd "$r" && git add -A && git commit -qm base )
BASE_SHA="$(git -C "$r" rev-parse HEAD)"
( cd "$r" && git checkout -qb weakbr \
  && printf '^nothing-matches-this$\n' > DENYLIST && git commit -qam weaken \
  && weak_sha="$(git rev-parse HEAD)" && git checkout -q - \
  && git replace "$BASE_SHA" "$weak_sha" )
printf '^nothing-matches-this$\n' > "$r/DENYLIST"   # worker aligns worktree with the fake base
( cd "$r" && echo x > denied/x.txt )
reset_log
expect "F7-1 replace-ref weakened base -> FAIL closed" 1
log_has "F7-1 violation logged" "DENYLIST violation"
BASE_SHA=""

# --- F7-2 — reviewer worktree edits are detected via state snapshot --------
r="$TMP/f72"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > tracked.txt && git add -A && git commit -qm base )
snap="$(worktree_review_state "$r")"
worktree_state_verify_unchanged "$r" "$snap" && rc=0 || rc=1; check "F7-2 unchanged worktree verifies" 0 "$rc"
echo edit >> "$r/tracked.txt"
worktree_state_verify_unchanged "$r" "$snap" && rc=0 || rc=1; check "F7-2 tracked edit detected" 1 "$rc"
( cd "$r" && git checkout -q -- tracked.txt )
worktree_state_verify_unchanged "$r" "$snap" && rc=0 || rc=1; check "F7-2 restore verifies again" 0 "$rc"
echo new > "$r/new-file.txt"
worktree_state_verify_unchanged "$r" "$snap" && rc=0 || rc=1; check "F7-2 new untracked file detected" 1 "$rc"
rm -f "$r/new-file.txt"
worktree_state_verify_unchanged "$r" "$snap" && rc=0 || rc=1; check "F7-2 untracked removal restores" 0 "$rc"
worktree_state_verify_unchanged "$r" "" && rc=0 || rc=1; check "F7-2 empty expected digest fails closed" 1 "$rc"
# grep evidence: stage_review snapshots around the reviewer pi_call and
# routes an edited worktree to the human gate.
grep -qF 'wt_state_before="$(worktree_review_state "$REPO")"' "$LOOP_SH" \
  && ok "F7-2 stage_review snapshots before reviewer call" || bad "F7-2 stage_review snapshots before reviewer call"
grep -qF 'worktree_state_verify_unchanged "$REPO" "$wt_state_before"' "$LOOP_SH" \
  && ok "F7-2 stage_review verifies after reviewer call" || bad "F7-2 stage_review verifies after reviewer call"
grep -qF 'gate "REVIEWER EDITED WORKTREE"' "$LOOP_SH" \
  && ok "F7-2 edited worktree opens human gate" || bad "F7-2 edited worktree opens human gate"
grep -qF 'REVIEW_REVIEWER_EDITED=1' "$LOOP_SH" \
  && ok "F7-2 edited-worktree flag reaches main-loop control" || bad "F7-2 edited-worktree flag reaches main-loop control"

# --- F7-3 — merge-commit conflict resolutions surface in the review diff ---
grep -qF -- '--no-ext-diff --no-textconv --text -p -m --full-diff' "$LOOP_SH" \
  && ok "F7-3 review log diffs merges (-m)" || bad "F7-3 review log diffs merges (-m)"
BASE_SHA=""
r="$TMP/f73"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo base > f.txt && git add -A && git commit -qm base )
merge_base="$(git -C "$r" rev-parse HEAD)"
( cd "$r" && git checkout -qb side && echo side > f.txt && git commit -qam side \
  && git checkout -q - && echo mainline > f.txt && git commit -qam mainline \
  && git merge -q side >/dev/null 2>&1 || true )
printf 'MERGE-RESOLUTION\n' > "$r/f.txt"
( cd "$r" && git add f.txt && git commit -qm merge-resolved )
out=$(emit_review_diff "$r" "$merge_base")
check_contains "F7-3 merge conflict resolution surfaces in review diff" "$out" "MERGE-RESOLUTION"
check_not_contains "F7-3 merge diff capture stays complete" "$out" "INCOMPLETE"

# --- F7-4 — oversized untracked files get fs metadata, never a git diff ----
if grep -qF -- '--no-index --stat' "$LOOP_SH"; then
  bad "F7-4 no stat-mode git diff left in loop.sh"; else ok "F7-4 no stat-mode git diff left in loop.sh"; fi
r="$TMP/f74"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
  && echo a > allowed.txt && git add -A && git commit -qm base )
head -c 300 /dev/zero | tr '\0' Z > "$r/huge.bin"
REVIEW_EMIT_COUNT=0; REVIEW_EMIT_BYTES=0; REVIEW_CAPPED=0
REVIEW_PATH_COUNT=0; REVIEW_PATH_BYTES=0; REVIEW_PATH_LIMIT_REPORTED=0
out=$(REVIEW_UNTRACKED_MAX_BYTES=100 emit_untracked_for_review "$r" 0)
check_contains "F7-4 stat-only PARTIAL marker kept" "$out" "### REVIEW-DIFF PARTIAL: untracked (large, stat-only): huge.bin"
check_contains "F7-4 filesystem metadata emitted" "$out" "stat-only: size=300"
check_not_contains "F7-4 no git diff stat content" "$out" "file changed"
check_not_contains "F7-4 oversized content absent" "$out" "ZZZZ"

# --- F7-5 — PASS verdict must be the final nonblank line; FAIL overrides ---
mk_v "$(printf 'PASS\n\nFAIL: finding')";              check "F7-5 PASS then FAIL -> fail" 1 "$rc"
mk_v "$(printf 'PASS\n\n- concrete finding follows')"; check "F7-5 mid-document PASS -> fail" 1 "$rc"
mk_v "$(printf 'findings: none blocking\n\nPASS')";    check "F7-5 final-line PASS -> pass" 0 "$rc"
mk_v "$(printf 'summary\n\n**PASS**')";                check "F7-5 final decorated PASS -> pass" 0 "$rc"
mk_v "$(printf 'PASS\nFAIL')";                         check "F7-5 FAIL anywhere overrides -> fail" 1 "$rc"

# ===========================================================================
# Summary
# ===========================================================================
echo
echo "PASS=$PASS FAIL=$FAIL"
if (( FAIL == 0 )); then echo "RESULT: PASS"; exit 0; else echo "RESULT: FAIL"; exit 1; fi
