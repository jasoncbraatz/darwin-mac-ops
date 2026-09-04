#!/bin/bash
# =============================================================================
# gate-probe-tristate-drill.sh — prove G-T#43/#45/#46's TRI-STATE probe parsing,
# offline. State Machine 1217341652482828.
#
# WHY THIS EXISTS. The card is "gate-selfcheck.sh FLAPS: PASS/FAIL/PASS on
# identical clean state". Its named mechanism is a remote ssh probe whose answer
# is cut off MID-STREAM by `timeout 14`: bytes arrive but a line is short. The old
# code knew only "unreachable" and "answered", so the third state collapsed into
# whichever of the two was silently wrong — a conjured SCHEDULER MISSING finding
# in one place, a conjured all-clear in another. You cannot test that against the
# real probe, because it only appears when the network happens to stutter. So the
# fixture IS the truncated answer, and every subject here is a string.
#
# The function under test is EXTRACTED FROM gate-selfcheck.sh AT RUN TIME, not
# copied here: a drill that carries its own copy of the logic passes forever while
# the real thing rots. (Same contract as gate-roster-drill.sh.)
#
# HERMETIC: no ssh, no gate run, no estate. It reads gate-selfcheck.sh and nothing else.
#
#   bash gate-probe-tristate-drill.sh
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
GATE="${GATE_SELFCHECK:-$HERE/gate-selfcheck.sh}"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
chk() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (want='$1' got='$2')"; fi; }

[ -r "$GATE" ] || { echo "  FAIL  cannot read $GATE"; exit 2; }

S="$(mktemp -d "${TMPDIR:-/tmp}/gate-probe-tristate-drill.XXXXXX")"
trap 'rm -rf "$S"' EXIT

# Extract the live function definition. Bounded by its own closing brace at col 0.
sed -n '/^_probe_field() {/,/^}/p' "$GATE" > "$S/fn.sh"
if ! grep -q 'return 2' "$S/fn.sh"; then
  echo "  FAIL  could not extract _probe_field() from $GATE (did it move or get renamed?)"
  exit 1
fi
echo "=== G-T probe tri-state drill (extracted $(wc -l < "$S/fn.sh") lines from $(basename "$GATE")) ==="
. "$S/fn.sh"

# probe <text> <line> <shape> -> "rc|value", so one assertion covers both halves of the
# contract. A function that returns the right rc with the wrong value is still broken.
probe() { local _v _r; _v="$(_probe_field "$1" "$2" "$3")"; _r=$?; printf '%s|%s' "$_r" "$_v"; }

SHA_A="1234567890abcdef1234567890abcdef12345678"
SHA_B="fedcba0987654321fedcba0987654321fedcba09"

# --- the ANSWERED state: the ordinary day, which must keep working -------------------
chk "0|$SHA_A" "$(probe "$SHA_A
$SHA_B
1" 1 sha)" "1  a well-formed 40-hex sha parses, rc 0"
chk "0|$SHA_B" "$(probe "$SHA_A
$SHA_B
1" 2 sha)" "2  positional parse still reads line 2, rc 0"
chk "0|1"      "$(probe "$SHA_A
$SHA_B
1" 3 num)" "3  a well-formed count parses, rc 0"

# --- the ABSENT state: unreachable box, and it must NOT become a value ----------------
chk "1|" "$(probe "" 1 sha)" "4  nothing came back at all -> rc 1 ABSENT, no value"
chk "1|" "$(probe "$SHA_A" 3 num)" "5  a SHORT answer (line 3 never arrived) -> rc 1 ABSENT, not 0"

# --- the ANSWERED-BUT-UNPARSEABLE state: the card's actual mechanism ------------------
# 6 is the load-bearing one. A sha cut in half is still hex; only the LENGTH catches it,
# and without this the truncated value compares unequal to gh HEAD and the gate emits a
# parity WARN naming a commit that never existed. A future "simplification" that drops the
# {40} anchor for a cheaper [0-9a-f]+ test trips HERE and not in production.
chk "2|1234567890abcdef1234" "$(probe "1234567890abcdef1234" 1 sha)" \
  "6  a TRUNCATED sha is rc 2 UNPARSEABLE, raw value echoed  <-- the flap's mechanism"
chk "2|deadbeefZZZ" "$(probe "deadbeefZZZ" 1 sha)" "7  a non-hex sha line is rc 2, raw echoed"
chk "2|-bash:sudo:commandnotfound" "$(probe "-bash: sudo: command not found
3" 1 num)" "8  an ssh/sudo stderr fragment where a COUNT belongs is rc 2, not a count"
chk "2|12abc" "$(probe "12abc" 1 num)" "9  a count with a truncated tail is rc 2, not 12"

# --- the sentinel the probes themselves emit -----------------------------------------
chk "0|MISSING" "$(probe "MISSING
$SHA_B
1" 1 sha)" "10 the probe's own MISSING sentinel passes through as rc 0"

# --- NEGATIVE CONTROLS: the real findings must still fire (attribution, not amnesty) ---
# The whole change is a WARN-adding one, but it re-gates three EXISTING findings behind an
# rc test. If the rc test is ever wrong in the permissive direction, these three go quiet
# and the gate stops noticing a genuinely missing scheduler / dirty box. So assert the
# values the call sites branch on, not merely that nothing crashed.
chk "0|0" "$(probe "$SHA_A
$SHA_B
0" 3 num)" "11 a GENUINE zero scheduler count is rc 0 + '0' — the SCHEDULER MISSING warn survives"
chk "0|7" "$(probe "7
2" 1 num)" "12 a GENUINE dirty count is rc 0 + '7' — the UNCOMMITTED warn survives"
chk "0|2" "$(probe "7
2" 2 num)" "13 a GENUINE unpushed count is rc 0 + '2' — the UNPUSHED warn survives"

# --- WIRING: the fix is only a fix at the call sites ---------------------------------
# Anchored on the CODE, never on the prose. Session 2 of smDrainHandoff learned this the
# hard way on G-H#24e: a grep for a SENTENCE counts the comment block that quotes the
# sentence it replaced, and the control goes green on a rung reduced to prose about itself.
# The comments above _probe_field DO quote `${BOX_SCHED_N:-0}` verbatim, so a naive grep
# here would report 4 live conflations that do not exist.
N_CONFLATE="$(grep -ac '^[[:space:]]*if \[ "\${\(BOX_SCHED_N\|PROV_DIRTY\|FLW_DIRTY\):-0}"' "$GATE")"
chk "0" "$N_CONFLATE" "14 zero LIVE \${VAR:-0} conflations remain (prose that quotes them is fine)"

N_CALLS="$(grep -ac '_probe_field "\$\(BOX_PROBE\|PROV_PROBE\|FLW_PROBE\)"' "$GATE")"
chk "7" "$N_CALLS" "15 all SEVEN probe fields go through _probe_field (3 box + 2 prov + 2 flowers)"

# A count, not a boolean: every unparseable branch must actually be reachable from a site.
N_UWARN="$(grep -ac 'WARNS+=("G-T#4[0-9a-z]*u:' "$GATE")"
if [ "${N_UWARN:-0}" -ge 6 ]; then ok "16 every probe field has an UNPARSEABLE warn branch ($N_UWARN found, >=6)"
else bad "16 too few UNPARSEABLE warn branches (got $N_UWARN, want >=6)"; fi

# The card's words: WARN with the raw value, never FAIL. If any unparseable branch ever
# gets promoted to FAILS+=, a network hiccup starts blocking wraps — the opposite failure.
if grep -aq 'FAILS+=("G-T#4[0-9a-z]*u:' "$GATE"; then
  bad "17 an UNPARSEABLE branch became a FAIL — a network hiccup must never block a wrap"
else ok "17 no UNPARSEABLE branch is a FAIL (card: WARN with the raw value, never FAIL)"; fi

echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
