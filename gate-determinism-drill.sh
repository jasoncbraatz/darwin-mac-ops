#!/bin/bash
# =============================================================================
# gate-determinism-drill.sh — a gate that cannot reproduce its own verdict has no
# business blocking a handoff. State Machine 1217341652482828, step 4.
#
# WHY THIS EXISTS. The card is "gate-selfcheck.sh FLAPS: PASS/FAIL/PASS on
# identical clean state". Steps 2 and 3 (tri-state remote probes, proven by
# gate-probe-tristate-drill.sh) fixed the mechanism the card NAMED. This is the
# step that notices the NEXT one: a detector that compares two runs of the gate
# against byte-identical state and says, out loud, when they disagree.
#
# IT COMPARES THE ISSUE SET, NOT THE EXIT CODE. This is the whole design and it
# is not a refinement — a gate that swaps G-V out for G-AE on identical state is
# flapping even though it exited 1 both times, and THAT is the more expensive
# flap: an exit-code comparator calls it stable and sends the next session
# chasing a finding that was never reproducible. Every control below that says
# "both exit 1" exists to pin that, by name, against a future tightening.
#
# THREE VERDICTS, because "I could not read the transcript" is not "they agreed":
#   rc 0  SAME          — identical issue sets
#   rc 1  FLAP          — the sets differ; the symmetric difference is printed
#   rc 2  CANNOT VERIFY — a transcript has no readable verdict block
#
# MODES
#   bash gate-determinism-drill.sh                  hermetic self-test of the
#                                                   comparator (fixtures only,
#                                                   no gate run, ~instant)
#   bash gate-determinism-drill.sh --compare A B..  compare captured transcripts
#   bash gate-determinism-drill.sh --live [N]       run the REAL gate N times
#                                                   (default 2) and compare.
#                                                   ~182 s PER RUN — background it.
#
# The default is hermetic on purpose: per the house rule, a control that shells
# out to the whole gate is a control nobody iterates on. --live is the deliberate
# act; the self-test is what proves --live's comparator still works.
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
GATE="${GATE_SELFCHECK:-$HERE/gate-selfcheck.sh}"

# --- the comparator ----------------------------------------------------------
# _issue_keys <file> -> one stable KEY per issue, sorted; rc 2 if the transcript
# has no verdict block at all.
#
# The KEY is the gate letter+tag (G-T#43b), not the issue's prose. Prose carries
# volatile fields — a short sha, a count, a host — and keying on prose would
# report a FLAP every time a sha moved, which is the false positive that gets a
# flap detector switched off in a week. Two runs that both say G-T#43b about
# different shas are the SAME finding. An issue with no gate letter falls back to
# its first 60 characters, squeezed, so a prose-only FAIL is still comparable.
_issue_keys() {
  local _f="$1" _v
  [ -r "$_f" ] || return 2
  _v="$(command grep -cE '^GATE SELF-CHECK: (PASS|FAIL)|GATE SELF-CHECK: (PASS|FAIL)' "$_f" 2>/dev/null)"
  # The bold() wrapper wraps the verdict in escape codes, so match loosely.
  if [ "${_v:-0}" -eq 0 ]; then
    command grep -qE 'GATE SELF-CHECK' "$_f" 2>/dev/null || return 2
  fi
  # Issues are the summary block's '  - ' lines; NEVER-RAN checks are '  ! '.
  # A skipped check is part of the run's identity: a run that skipped G-AL and a
  # run that executed it did not do the same work, even if both exited 1.
  command grep -hE '^[[:space:]]*[-!][[:space:]]' "$_f" 2>/dev/null \
  | sed -E 's/^[[:space:]]*([-!])[[:space:]]+/\1 /' \
  | sed -E 's/\x1b\[[0-9;]*m//g' \
  | awk '{
      line=$0; mark=substr(line,1,1); rest=substr(line,3);
      if (match(rest, /G-[A-Z]+(#[A-Za-z0-9]+)?/))
        print mark " " substr(rest, RSTART, RLENGTH);
      else { s=substr(rest,1,60); gsub(/[[:space:]]+/," ",s); print mark " " s }
    }' \
  | sort -u
  return 0
}

# _compare <fileA> <fileB> -> prints a verdict line; rc 0 SAME / 1 FLAP / 2 CANNOT VERIFY
_compare() {
  local _a="$1" _b="$2" _ka _kb _rc _only_a _only_b
  _ka="$(_issue_keys "$_a")" || { printf 'CANNOT VERIFY: %s has no readable gate verdict block\n' "$_a"; return 2; }
  _kb="$(_issue_keys "$_b")" || { printf 'CANNOT VERIFY: %s has no readable gate verdict block\n' "$_b"; return 2; }
  if [ "$_ka" = "$_kb" ]; then
    printf 'SAME: %s issue key(s), identical in both runs\n' "$(printf '%s' "$_ka" | command grep -c . || true)"
    return 0
  fi
  _only_a="$(comm -23 <(printf '%s\n' "$_ka") <(printf '%s\n' "$_kb") | command grep -v '^$' || true)"
  _only_b="$(comm -13 <(printf '%s\n' "$_ka") <(printf '%s\n' "$_kb") | command grep -v '^$' || true)"
  printf 'FLAP: the two runs disagree on identical state\n'
  [ -n "$_only_a" ] && printf '  only in %s:\n%s\n' "$(basename "$_a")" "$(printf '%s' "$_only_a" | sed 's/^/    /')"
  [ -n "$_only_b" ] && printf '  only in %s:\n%s\n' "$(basename "$_b")" "$(printf '%s' "$_only_b" | sed 's/^/    /')"
  return 1
}

# --- --compare / --live ------------------------------------------------------
_compare_many() {
  local _files=("$@") _worst=0 _out _rc _i
  for _i in $(seq 1 $(( ${#_files[@]} - 1 ))); do
    _out="$(_compare "${_files[0]}" "${_files[$_i]}")"; _rc=$?
    printf 'run1 vs run%s: %s\n' "$(( _i + 1 ))" "$_out"
    # CANNOT VERIFY (2) outranks FLAP (1) outranks SAME (0): an unreadable
    # transcript must never be reported as agreement.
    [ "$_rc" -gt "$_worst" ] && _worst=$_rc
  done
  case "$_worst" in
    0) echo "=== determinism: SAME — the gate reproduced its own issue set ===" ;;
    1) echo "=== determinism: FLAP — see the symmetric difference above (SM 1217341652482828) ===" ;;
    2) echo "=== determinism: CANNOT VERIFY — a transcript was unreadable; this is NOT a pass ===" ;;
  esac
  return "$_worst"
}

if [ "${1:-}" = "--compare" ]; then
  shift
  [ $# -ge 2 ] || { echo "usage: --compare <fileA> <fileB> [fileC...]"; exit 2; }
  _compare_many "$@"; exit $?
fi

if [ "${1:-}" = "--live" ]; then
  N="${2:-2}"
  [ -r "$GATE" ] || { echo "  FAIL  cannot read $GATE"; exit 2; }
  D="$(mktemp -d "${TMPDIR:-/tmp}/gate-determinism.XXXXXX")"
  echo "=== running $GATE $N time(s) — ~182 s each, transcripts in $D ==="
  for i in $(seq 1 "$N"); do
    bash "$GATE" > "$D/run$i.txt" 2>&1
    echo "  run$i exit=$? -> $D/run$i.txt"
  done
  _compare_many "$D"/run*.txt; exit $?
fi

# --- hermetic self-test of the comparator ------------------------------------
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
chk() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (want='$1' got='$2')"; fi; }

S="$(mktemp -d "${TMPDIR:-/tmp}/gate-determinism-drill.XXXXXX")"
trap 'rm -rf "$S"' EXIT
echo "=== gate determinism drill (hermetic — comparator only, no gate run) ==="

fixture() { printf '%s\n' "$2" > "$S/$1"; }
verdict() { local _o _r; _o="$(_compare "$S/$1" "$S/$2")"; _r=$?; printf '%s' "$_r"; }

fixture fail_v "GATE SELF-CHECK: FAIL ❌  (1 issue(s) — fix before writing the handoff)
  - G-V: ~/repos/foo has 3 uncommitted line(s)"
fixture fail_ae "GATE SELF-CHECK: FAIL ❌  (1 issue(s) — fix before writing the handoff)
  - G-AE: census row is missing a verdict contract"
fixture fail_v2 "GATE SELF-CHECK: FAIL ❌  (1 issue(s) — fix before writing the handoff)
  - G-V: ~/repos/foo has 9 uncommitted line(s)"
fixture pass_v "GATE SELF-CHECK: PASS ✅"
fixture fail_two_ab "GATE SELF-CHECK: FAIL ❌  (2 issue(s))
  - G-V: alpha
  - G-AE: beta"
fixture fail_two_ba "GATE SELF-CHECK: FAIL ❌  (2 issue(s))
  - G-AE: beta
  - G-V: alpha"
fixture fail_skip "GATE SELF-CHECK: FAIL ❌  (1 issue(s), 1 check(s) NEVER RAN)
  ! G-AL: charter check never ran
  - G-V: ~/repos/foo has 3 uncommitted line(s)"
fixture garbage "the ssh probe hung and this file is what we got"
fixture empty ""

# --- the ordinary day: agreement must still read as agreement -----------------
chk 0 "$(verdict fail_v fail_v)"       "1  byte-identical FAIL transcripts are SAME"
chk 0 "$(verdict pass_v pass_v)"       "2  byte-identical PASS transcripts are SAME"

# --- THE LESSON THIS DRILL EXISTS FOR ----------------------------------------
# 2026-09-04-flap-detector-must-compare-issue-set. Both fixtures exit 1 and both
# say '1 issue(s)'. An exit-code comparator, and a count comparator, both call
# this stable. It is the most expensive flap there is.
chk 1 "$(verdict fail_v fail_ae)"      "3  G-V swapped for G-AE, BOTH exit 1 -> FLAP  <-- the load-bearing control"

# --- the false positive that would get this detector switched off -------------
# Same finding, volatile field moved. Keyed on the gate letter, so: SAME.
chk 0 "$(verdict fail_v fail_v2)"      "4  same G-V finding, different count in the prose -> SAME (keyed on the letter, not the text)"
chk 0 "$(verdict fail_two_ab fail_two_ba)" "5  same two issues in a different ORDER -> SAME (it is a set, not a sequence)"

# --- the obvious flap, which must not regress --------------------------------
chk 1 "$(verdict pass_v fail_v)"       "6  PASS vs FAIL -> FLAP"

# --- a skipped check is part of the run's identity ---------------------------
chk 1 "$(verdict fail_v fail_skip)"    "7  one run SKIPPED G-AL, the other ran it -> FLAP (a check that never ran is not a check that passed)"

# --- CANNOT VERIFY must never collapse into SAME ------------------------------
chk 2 "$(verdict fail_v garbage)"      "8  a transcript with no verdict block -> CANNOT VERIFY, not SAME"
chk 2 "$(verdict fail_v empty)"        "9  an EMPTY transcript -> CANNOT VERIFY, not SAME"
chk 2 "$(verdict garbage garbage)"     "10 two unreadable transcripts AGREE, and are still CANNOT VERIFY"

# --- anti-gaming: the comparator must not be reading the verdict LINE ---------
# If it were, these two would read as a flap. They must read as SAME: identical
# issue set, different summary prose.
fixture fail_v_reworded "GATE SELF-CHECK: FAIL ❌  (1 issue(s), 0 check(s) NEVER RAN)
  - G-V: ~/repos/foo has 3 uncommitted line(s)"
chk 0 "$(verdict fail_v fail_v_reworded)" "11 identical issue set, different summary line -> SAME (proves the verdict LINE is not the subject)"

# --- anti-gaming: a comparator that always says SAME would pass 1,2,4,5,11 ----
# Controls 3,6,7 are the negatives that kill it; 8,9,10 kill an always-SAME that
# also ignores readability. Assert that the negatives really are negatives.
_neg=0
for _p in "fail_v fail_ae" "pass_v fail_v" "fail_v fail_skip"; do
  set -- $_p; [ "$(verdict "$1" "$2")" = "1" ] && _neg=$((_neg+1))
done
chk 3 "$_neg" "12 all three FLAP controls are genuinely negative (an always-SAME comparator fails 3 of them)"

# --- worst-verdict precedence -------------------------------------------------
_out="$(_compare_many "$S/fail_v" "$S/fail_v" "$S/garbage" 2>/dev/null)"; _r=$?
chk 2 "$_r" "13 across 3 runs, CANNOT VERIFY outranks a SAME pair"
_out="$(_compare_many "$S/fail_v" "$S/fail_v" "$S/fail_ae" 2>/dev/null)"; _r=$?
chk 1 "$_r" "14 across 3 runs, one FLAP outranks a SAME pair"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "=== drill: PASS — $PASS controls (0 skipped), 7 of them negative or anti-gaming ==="
  echo "VERDICTS-EXERCISED: 0,1,2"
  exit 0
fi
echo "=== drill: FAIL — $FAIL of $((PASS+FAIL)) controls failed ==="
exit 1
