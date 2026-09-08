#!/bin/bash
# gate-roll-call-drill.sh — the control on the gate's roll call.
# Born P14, 2026-09-08 (opus-feynmanSync-10). The one honest rc=127 on the board, filled.
#
# ── WHAT IT IS CONTROLLING ────────────────────────────────────────────────────────────
# gate-rollcall.sh exists because a check that passes QUIETLY and a check that NEVER RAN
# are indistinguishable in gate-selfcheck.sh's prose output. feynmanSync-09 measured that
# the wrong way round and nearly shipped it as a headline: G-AK, 0 occurrences in darwin's
# log, read as "never runs on darwin" and actually meant "the census passed".
#
# So the load-bearing assertion of this whole drill is ONE line, check 1:
#
#     a check that is reached, says nothing, and passes MUST still appear, as `pass`.
#
# Everything else here defends that line's meaning. If check 1 could be satisfied by a
# fixture that ALSO pushed a FAIL, the roll call would be crediting the message path and
# the drill would pass on a roll call that cannot see silence at all — the right answer for
# the wrong reason, which is the trap acmeLedger-08 banked and feynmanSync-09 applied. So
# the silent fixture carries NO message, and mutant A proves that is what is being measured.
#
# ── EXIT CONTRACT (an exit code is never read through a pipe — G-AO) ──────────────────
#   0  every control green
#   1  a control FAILED — the roll call is not measuring what it claims
#   2  CANNOT VERIFY — the library or its subject is missing. NOT a pass.
#
# v1.2 (feynmanSync-11, 2026-09-08) adds controls 20-29 for the JUDGMENT half. Their
# load-bearing line is check 22, one step out from check 1: for the nineteen HANDOFF-GATE.md
# steps a session walks by reading prose, A STEP NOBODY WITNESSED AND A STEP NOBODY DECLARED
# WERE THE SAME FACT until v1.2, because neither left anything behind. Check 26 is the fence
# around it -- no judgment row may ever render as `pass`, because `pass` is the mechanical
# half's word for a measured silence and a prose step has none to report.
#
# Portable on purpose: bash 3.2 (darwin) and bash 5 (feynman). No `mapfile`, no `declare -A`,
# no `readlink -f`, no BSD-only `mktemp -t`, and `stat` is never called.

set -u

LIB="${GATE_ROLLCALL_LIB:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)/gate-rollcall.sh}"
GATE_SRC="${GATE_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)/gate-selfcheck.sh}"
REAL_MANIFEST="${GATE_CHECKS_MANIFEST:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)/gate-checks.manifest}"

PASS=0; FAIL=0; NOTE=""
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; return 0; }
cv()   { printf 'gate-roll-call-drill: CANNOT VERIFY -- %s\n' "$1" >&2; exit 2; }

[ -r "$LIB" ] || cv "the library is missing at $LIB -- there is nothing to control"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/grcd.XXXXXX")" || cv "could not make a scratch dir"
trap 'rm -rf "$WORK"' EXIT

# ── the fixture manifest ──────────────────────────────────────────────────────────────
# G-A and G-AB together are the no-prefix-inference control: G-A is declared, G-AB is not,
# and a roll call that matched by string prefix would hand G-AB's FAIL to G-A — a confident
# wrong owner, which is this project's disease wearing an attribution costume.
cat > "$WORK/manifest" <<'MF'
# fixture
G-SILENT	-	passes and says absolutely nothing
G-NOISY	-	fails loudly
G-WARNY	-	warns
G-SKIPPY	-	is skipped by an upstream step
G-NAY	-	has no subject on this box
G-BOTH	-	warns AND fails; fail must win
G-GONE	-	declared, deliberately never reached
G-PARENT	-	speaks under an alias
G-A	-	one letter, and NOT the owner of G-AB
G-PARENT#kid	G-PARENT	the alias
G-JW	judgment	a prose step whose artifact the gate can see
G-JD	judgment	a prose step the session asserts it walked
G-JU	judgment	a prose step nothing witnessed at all
G-JV	judgment	a prose step that speaks a verdict for itself
G-J	judgment	one letter after the hyphen, and NOT the owner of G-JW
MF

# ── the fixture gate ──────────────────────────────────────────────────────────────────
# Mirrors the real gate's shape: four arrays, gate_ran at the top of each "check", one emit.
cat > "$WORK/fixture.sh" <<'FX'
set -u
. "$LIB_UNDER_TEST"
FAILS=(); WARNS=(); SKIPPED=(); NA=()
GATE_CHECKS_MANIFEST="$MF_UNDER_TEST"
GATE_ROLLCALL_DIR="$OUT_UNDER_TEST"
GATE_BOX="fixturebox"

gate_ran "G-SILENT"                      # says nothing at all. THE control.
gate_ran "G-SILENT"                      # ...twice, to prove idempotence
gate_ran "G-NOISY";  FAILS+=("G-NOISY: the sky is falling")
gate_ran "G-WARNY";  WARNS+=("G-WARNY: mild weather")
gate_ran "G-SKIPPY"; SKIPPED+=("G-SKIPPY NEVER RAN: upstream could not verify")
gate_ran "G-NAY";    NA+=("G-NAY N/A: no subject on this box")
gate_ran "G-BOTH";   WARNS+=("G-BOTH: a warning"); FAILS+=("G-BOTH CANNOT VERIFY: and a failure")
gate_ran "G-PARENT"; FAILS+=("G-PARENT#kid: the alias speaks for its parent")
gate_ran "G-A"
gate_ran "G-STOWAWAY"                    # reached, no manifest row
FAILS+=("G-AB: undeclared, and NOT G-A's problem")
# G-GONE is declared and never reached, on purpose.
# --- the judgment half ---------------------------------------------------------------
gate_witness "G-JW" "the artifact is on disk at /fixture/HANDOFF-x-01.md"
gate_witness "G-JW" "...and a second call must not make a second row"
gate_witness "G-JSTRAY" "a witness for an id no manifest row declares"
FAILS+=("G-JV: this prose step spoke a verdict for itself")
# G-JD is claimed via GATE_ANSWERED in run_fixture; G-JU and G-J are claimed by nothing.
gate_rollcall_emit >/dev/null
exit 0
FX

run_fixture() {   # <lib-path> -> writes $WORK/out/fixturebox.tsv
  rm -rf "$WORK/out"; mkdir -p "$WORK/out"
  LIB_UNDER_TEST="$1" MF_UNDER_TEST="$WORK/manifest" OUT_UNDER_TEST="$WORK/out" \
    GATE_ANSWERED="G-JD" \
    bash "$WORK/fixture.sh" >/dev/null 2>&1
  return 0
}
state_of() {   # <id> -> state, or empty
  awk -F'\t' -v id="$1" '!/^#/ && $1==id { print $2; exit }' "$WORK/out/fixturebox.tsv" 2>/dev/null
}
rows_for() {   # <id> -> row count
  awk -F'\t' -v id="$1" '!/^#/ && $1==id { n++ } END { print n+0 }' "$WORK/out/fixturebox.tsv" 2>/dev/null
}

echo "── gate-roll-call-drill · the roll call must measure REACH, not noise ──"
run_fixture "$LIB"
[ -s "$WORK/out/fixturebox.tsv" ] || cv "the fixture produced no sidecar at all -- emit is broken, or the library will not source"

# ── 1. THE LOAD-BEARING ONE ───────────────────────────────────────────────────────────
if [ "$(state_of G-SILENT)" = "pass" ]; then
  ok "1  a check that is reached, PASSES and prints NOTHING still appears, as pass"
else
  bad "1  a silent passing check did not appear as pass (got '$(state_of G-SILENT)')" \
      "this is the whole reason the roll call exists: silence and absence must not be one fact"
fi

# ── 2. the state the instrument was built to be able to say ───────────────────────────
if [ "$(state_of G-GONE)" = "NOT-REACHED" ]; then
  ok "2  a declared check that is never reached says NOT-REACHED, not pass"
else
  bad "2  an unreached check reported '$(state_of G-GONE)'" \
      "if this can read as pass, the roll call certifies checks that did not happen"
fi

# ── 3-6. the ordinary states, because a control that only proves the headline is thin ──
[ "$(state_of G-NOISY)"  = "fail" ]    && ok "3  a FAILS entry renders fail"     || bad "3  G-NOISY -> '$(state_of G-NOISY)'"
[ "$(state_of G-WARNY)"  = "warn" ]    && ok "4  a WARNS entry renders warn"     || bad "4  G-WARNY -> '$(state_of G-WARNY)'"
[ "$(state_of G-SKIPPY)" = "skipped" ] && ok "5  a SKIPPED entry renders skipped" || bad "5  G-SKIPPY -> '$(state_of G-SKIPPY)'"
[ "$(state_of G-NAY)"    = "n/a" ]     && ok "6  an NA entry renders n/a, which is NOT NOT-REACHED" || bad "6  G-NAY -> '$(state_of G-NAY)'"

# ── 7. worst state wins ───────────────────────────────────────────────────────────────
[ "$(state_of G-BOTH)" = "fail" ] && ok "7  fail outranks warn on the same check" \
  || bad "7  G-BOTH -> '$(state_of G-BOTH)'" "a check that failed must not be filed under its milder verdict"

# ── 8. aliases attribute to their declared parent ─────────────────────────────────────
[ "$(state_of G-PARENT)" = "fail" ] && ok "8  an alias's verdict lands on its declared parent" \
  || bad "8  G-PARENT -> '$(state_of G-PARENT)'"

# ── 9-10. both directions of closure ──────────────────────────────────────────────────
[ "$(state_of G-AB)" = "UNDECLARED" ] && ok "9  an id that speaks with no manifest row is named UNDECLARED" \
  || bad "9  G-AB -> '$(state_of G-AB)'" "an undeclared check is invisible to any census that reads the manifest"
[ "$(state_of G-STOWAWAY)" = "UNDECLARED" ] && ok "10 an id that is REACHED with no manifest row is named too" \
  || bad "10 G-STOWAWAY -> '$(state_of G-STOWAWAY)'"

# ── 11. NO PREFIX INFERENCE ───────────────────────────────────────────────────────────
# G-AB failed. G-A is declared and was reached silently. A roll call that matched by string
# prefix would report G-A as fail -- a confident, specific, wrong owner.
[ "$(state_of G-A)" = "pass" ] && ok "11 G-AB's failure is NOT attributed to G-A (no prefix inference)" \
  || bad "11 G-A -> '$(state_of G-A)'" "ownership must come from the manifest, never from a shared prefix"

# ── 12. idempotence ───────────────────────────────────────────────────────────────────
[ "$(rows_for G-SILENT)" = "1" ] && ok "12 gate_ran called twice yields exactly one row" \
  || bad "12 G-SILENT has $(rows_for G-SILENT) rows" "a double-counted check is the 2x-in-one-log artifact again"

# ── 13. an unreadable manifest is LOUD, never an empty sidecar ────────────────────────
rm -rf "$WORK/out2"; mkdir -p "$WORK/out2"
LIB_UNDER_TEST="$LIB" MF_UNDER_TEST="$WORK/no-such-manifest" OUT_UNDER_TEST="$WORK/out2" \
  bash "$WORK/fixture.sh" >/dev/null 2>&1
if grep -q 'MANIFEST-UNREADABLE' "$WORK/out2/fixturebox.tsv" 2>/dev/null; then
  ok "13 a missing manifest writes a sidecar that SAYS SO (not an empty one that reads as 'no checks')"
else
  bad "13 a missing manifest produced no MANIFEST-UNREADABLE row" \
      "an empty roll call is indistinguishable from a gate that ran nothing -- three states, not two"
fi

# ── 14. the observer never changes the verdict ────────────────────────────────────────
rm -rf "$WORK/out3"; mkdir -p "$WORK/out3"
if LIB_UNDER_TEST="$LIB" MF_UNDER_TEST="$WORK/manifest" OUT_UNDER_TEST="/proc/nonexistent/nope" \
     bash "$WORK/fixture.sh" >/dev/null 2>&1; then
  ok "14 an unwritable sidecar directory does NOT fail the caller (the roll call is an observer)"
else
  bad "14 emit propagated a failure to its caller" \
      "a control whose only exits are vandalism or dishonesty gets ignored -- this one must never block a wrap"
fi

# ── 15-16. the REAL gate and the REAL manifest still agree ────────────────────────────
# Static, cheap, and the only checks here that can catch the maintenance failure that
# actually happens: someone adds a check and forgets the row, or renames one and forgets
# the marker. Both directions, because a one-way check would let a new check be invisible
# in exactly the way G-AK was.
if [ -r "$GATE_SRC" ] && [ -r "$REAL_MANIFEST" ]; then
  _declared="$(LC_ALL=C awk -F'\t' '!/^#/ && NF>=2 && $2=="-" { print $1 }' "$REAL_MANIFEST" | sort -u)"
  # LC_ALL=C grep -a, and this is not belt-and-braces fussiness: measured on feynman
  # 2026-09-08, gate-selfcheck.sh carried ONE stray NUL byte, so GNU grep classed the whole
  # file as binary and answered `-o` with the single line "binary file matches" instead of
  # the matches. Check 15 then reported 22 reach units as unmarked -- a confident, specific,
  # WRONG finding, produced on one box and not the other, by an instrument that had silently
  # stopped reading its subject. That is the P14 disease inside P14's own drill. The NUL is
  # fixed and portability-guard check 8 refuses the next one, but a drill that degrades
  # silently when its subject changes shape is not a drill, so it says -a either way.
  _marked="$(LC_ALL=C grep -a -oE '^gate_ran "[^"]+"' "$GATE_SRC" | sed 's/^gate_ran "//; s/"$//' | sort -u)"
  _miss="$(comm -23 <(printf '%s\n' "$_declared") <(printf '%s\n' "$_marked") | grep . || true)"
  _extra="$(comm -13 <(printf '%s\n' "$_declared") <(printf '%s\n' "$_marked") | grep . || true)"
  [ -z "$_miss" ]  && ok "15 every reach unit in the manifest has a gate_ran marker in the gate" \
    || bad "15 declared but never marked: $(printf '%s' "$_miss" | tr '\n' ' ')" \
           "these would report NOT-REACHED on every run -- a permanent red that trains readers to scroll"
  [ -z "$_extra" ] && ok "16 every gate_ran marker in the gate has a manifest row" \
    || bad "16 marked but not declared: $(printf '%s' "$_extra" | tr '\n' ' ')" \
           "add the row, or the next box-coverage census cannot see this check"
else
  NOTE="$NOTE
  note: skipped checks 15-16 -- gate-selfcheck.sh or gate-checks.manifest not readable from here"
fi

# ── 20-26. THE JUDGMENT HALF (v1.2, feynmanSync-11) ───────────────────────────────────
# The mechanical half's headline is "a silent pass and a check that never ran are different
# facts". The judgment half's headline is one step further out and was true of nineteen
# HANDOFF-GATE.md sections until v1.2: A STEP NOBODY WITNESSED AND A STEP NOBODY EVEN
# DECLARED WERE THE SAME FACT, because neither left anything behind. Check 22 is the load-
# bearing one here, and check 26 is the line that keeps the whole thing honest.
[ "$(state_of G-JW)" = "WITNESSED" ] && ok "20 a prose step whose ARTIFACT the gate can see reads WITNESSED" \
  || bad "20 G-JW -> '$(state_of G-JW)'" "an artifact the gate looked at and found is the only objective evidence available here"
[ "$(state_of G-JD)" = "DECLARED" ] && ok "21 a step the SESSION asserts reads DECLARED -- a different word from WITNESSED, on purpose" \
  || bad "21 G-JD -> '$(state_of G-JD)'" "an assertion recorded as an assertion is worth something; recorded as a measurement it is worth less than nothing"
[ "$(state_of G-JU)" = "UNWITNESSED" ] && ok "22 a step with NO artifact and NO assertion reads UNWITNESSED, not silence" \
  || bad "22 G-JU -> '$(state_of G-JU)'" "this is the whole reason the judgment rows exist: a step nobody witnessed must not be indistinguishable from one nobody declared"
[ "$(state_of G-JV)" = "fail" ] && ok "23 a prose step that SPOKE a verdict keeps the verdict -- it does not read WITNESSED over its own failure" \
  || bad "23 G-JV -> '$(state_of G-JV)'" "'it happened' must never be substituted for 'it went well'"
[ "$(state_of G-JSTRAY)" = "UNDECLARED" ] && ok "24 a witness for an id no manifest row declares is named UNDECLARED" \
  || bad "24 G-JSTRAY -> '$(state_of G-JSTRAY)'" "a witness nothing will ever read looks like coverage from inside the gate and is invisible from outside it"
[ "$(state_of G-J)" = "UNWITNESSED" ] && ok "25 G-JW's witness is NOT attributed to G-J (no prefix inference on the judgment side either)" \
  || bad "25 G-J -> '$(state_of G-J)'" "ownership comes from the manifest on both halves, never from a shared prefix"
# 26. THE LINE. Not one judgment row may ever render as `pass`. `pass` in this sidecar means
#     "a mechanical check ran and the gate's arrays are silent about it" -- a measurement. No
#     amount of witnessing tells you a prose step was answered WELL, and the day a judgment
#     row can say `pass` is the day this instrument starts certifying answers it never read.
# Derived from the fixture MANIFEST, not from a name prefix -- a control that identifies its
# own subjects by string prefix is committing the bug check 25 exists to catch, inside the
# check that is supposed to be watching for it.
_jids="$(awk -F'\t' '!/^#/ && NF>=2 && $2=="judgment" { print $1 }' "$WORK/manifest" 2>/dev/null)"
_jpass=""
for _jid in $_jids; do
  [ "$(state_of "$_jid")" = "pass" ] && _jpass="$_jpass $_jid"
done
[ -z "$_jpass" ] && ok "26 no judgment row renders as 'pass' -- the sidecar never certifies an answer it did not read" \
  || bad "26 judgment row(s) reading 'pass':$_jpass" \
         "'pass' is the mechanical half's word for a measured silence; a prose step has no measured silence to report"

# ── 27. a judgment row must name a section that actually exists in the gate DOC ────────
# The manifest's reverse closure for the mechanical half is "an id that speaks with no row".
# For the judgment half it is the other way round: these rows have no marker to compare
# against, so the only thing that can rot is the row naming a HANDOFF-GATE.md section that
# was renamed or removed -- and it would rot SILENTLY, still printing UNWITNESSED forever
# about a step that no longer exists. Static, cheap, and it reads the canonical doc.
GATE_DOC="${GATE_DOC:-$HOME/Desktop/downloads/HANDOFF-GATE.md}"
if [ -r "$REAL_MANIFEST" ] && [ -r "$GATE_DOC" ]; then
  _jrows="$(LC_ALL=C awk -F'\t' '!/^#/ && NF>=2 && $2=="judgment" { print $1 }' "$REAL_MANIFEST" | sort -u)"
  _jorphan=""
  for _jid in $_jrows; do
    LC_ALL=C grep -aqE "^#{2,3} *${_jid}([^A-Za-z0-9#]|\$)" "$GATE_DOC" || _jorphan="$_jorphan $_jid"
  done
  [ -z "$_jorphan" ] && ok "27 every judgment row names a section that still exists in HANDOFF-GATE.md" \
    || bad "27 judgment row(s) naming no section in the gate doc:$_jorphan" \
           "the row would print UNWITNESSED forever about a step that no longer exists -- rot that looks exactly like honest reporting"
else
  NOTE="$NOTE
  note: skipped check 27 -- gate-checks.manifest or $GATE_DOC not readable from here"
fi

# ── MUTANTS · does this drill measure the roll call, or something incidental? ─────────
# These print LAST and their labels (17-19, 28-29) are therefore out of numeric order. That
# is deliberate and not worth "fixing": a mutant replaces the library under test, so every
# state check above has to be finished before the first one runs. The labels are IDENTIFIERS
# -- other files and past handoffs cite them by number -- and renumbering a control to tidy
# the print order would silently repoint every one of those references.
echo "  -- mutants (library replaced; every state check above is complete) --"
# Each mutant breaks ONE mechanism in a copy of the library and asserts that the ONE check
# aimed at it flips. A mutant that flips nothing means the check is decorative; a mutant
# that flips everything means the checks are not independent.
mutate() {   # <name> <sed-program> -> path to the mutant library
  sed "$2" "$LIB" > "$WORK/mutant-$1.sh"
  printf '%s\n' "$WORK/mutant-$1.sh"
}
# A mutant that flips its target proves the check is live. A mutant that flips EVERYTHING
# proves nothing at all -- it would pass even if the checks were interchangeable. So every
# mutant must also leave a named CONTROL id standing: the target moves, the control does not.
MUT_WHY=""
mutant_flips() {   # <name> <sed> <target-id> <target-state-before> <control-id> <control-state>
  local _m _now _ctl
  MUT_WHY=""
  _m="$(mutate "$1" "$2")"
  run_fixture "$_m"
  _now="$(state_of "$3")"; _ctl="$(state_of "$5")"
  if [ "$_now" = "$4" ]; then
    MUT_WHY="the mutant left $3 at '$4' -- the mechanism it breaks is not the one this check reads"
    return 1
  fi
  if [ "$_ctl" != "$6" ]; then
    MUT_WHY="the mutant ALSO moved the control $5 ($6 -> '$_ctl') -- it is too blunt to attribute anything"
    return 1
  fi
  return 0
}

# A · neuter gate_ran. The silent check must stop appearing as pass -- proving check 1
#     measures REACH and not, say, "the id was in the manifest".
if mutant_flips A 's/^  GATE_ROLL_SEEN="\$GATE_ROLL_SEEN\$1 "$/  :/' G-SILENT pass G-NOISY fail; then
  ok "17 MUTANT A (gate_ran neutered): the silent check stops reading as pass, the failing one does not move"
else
  bad "17 MUTANT A: $MUT_WHY" \
      "a silent pass would still be reported even if the gate never touched the check"
fi
# B · neuter the alias lookup. Only the alias case may move.
if mutant_flips B 's|_owner="\$(printf .%s. "\$_aliasmap".*|_owner=""|' G-PARENT fail G-NOISY fail; then
  ok "18 MUTANT B (alias lookup neutered): the aliased check moves, a directly-named one does not"
else
  bad "18 MUTANT B: $MUT_WHY" "check 8 is not measuring alias attribution"
fi
# C · make an unreached check default to pass. This is the ORIGINAL BUG, injected on purpose.
if mutant_flips C 's/^          \*) _state="NOT-REACHED"$/          *) _state="pass"/' G-GONE NOT-REACHED G-SILENT pass; then
  ok "19 MUTANT C (unreached defaults to pass): NOT-REACHED moves, a genuinely-reached pass does not"
else
  bad "19 MUTANT C: $MUT_WHY" "check 2 is not measuring the headline state"
fi

# D · neuter the witness lookup. Only the witnessed step may move; the declared one must not,
#     or checks 20 and 21 are not measuring two different mechanisms.
if mutant_flips D 's|^        elif printf .%s. "\$GATE_ROLL_WIT" .*|        elif false; then|' G-JW WITNESSED G-JD DECLARED; then
  ok "28 MUTANT D (witness lookup neutered): the witnessed step moves, the self-declared one does not"
else
  bad "28 MUTANT D: $MUT_WHY" "check 20 is not measuring the artifact witness"
fi
# E · make an unwitnessed step default to WITNESSED. This is the judgment half's version of
#     the ORIGINAL BUG -- certifying a step nothing looked at -- injected on purpose.
if mutant_flips E 's/^          _jstate="UNWITNESSED"$/          _jstate="WITNESSED"/' G-JU UNWITNESSED G-JW WITNESSED; then
  ok "29 MUTANT E (unwitnessed defaults to WITNESSED): the unwitnessed step moves, a genuinely witnessed one does not"
else
  bad "29 MUTANT E: $MUT_WHY" "check 22 is not measuring the headline state of the judgment half"
fi

run_fixture "$LIB"   # leave the scratch in a truthful state

printf '\ngate-roll-call-drill: %d passed, %d failed%s\n' "$PASS" "$FAIL" "$NOTE"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
