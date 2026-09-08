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
gate_rollcall_emit >/dev/null
exit 0
FX

run_fixture() {   # <lib-path> -> writes $WORK/out/fixturebox.tsv
  rm -rf "$WORK/out"; mkdir -p "$WORK/out"
  LIB_UNDER_TEST="$1" MF_UNDER_TEST="$WORK/manifest" OUT_UNDER_TEST="$WORK/out" \
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
  _declared="$(awk -F'\t' '!/^#/ && NF>=2 && $2=="-" { print $1 }' "$REAL_MANIFEST" | sort -u)"
  _marked="$(grep -oE '^gate_ran "[^"]+"' "$GATE_SRC" | sed 's/^gate_ran "//; s/"$//' | sort -u)"
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

# ── 17-19. MUTANTS · does this drill measure the roll call, or something incidental? ──
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

run_fixture "$LIB"   # leave the scratch in a truthful state

printf '\ngate-roll-call-drill: %d passed, %d failed%s\n' "$PASS" "$FAIL" "$NOTE"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
