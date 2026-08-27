#!/bin/bash
# gate-skipped-drill.sh — the gate must not certify a run in which a check never ran.
# (born 2026-08-27, wealthTensor-109; AAR green-suite-hid-two-ship-blockers action A2)
#
# THE CLASS THIS CLOSES
# `gate-cannot-verify-drill.sh` (G-AI) asks whether a gate step vanishes when its
# INSTRUMENT is missing. This asks the sibling question it is structurally blind to:
# whether a step vanishes because an UPSTREAM BRANCH took another path — every guard
# properly else-ed, every instrument present, and the step still never runs.
#
# MEASURED, and the reason this file exists. At wealthTensor-108 the gate ran without
# GATE_ROSTER_WHO. G-AL could not identify the session, printed
# `WARN CANNOT VERIFY: no current session tag`, and returned. G-AL#board — the board
# staleness check, a hard blocker — lives INSIDE G-AL's success branch, so it never ran,
# and nothing in the output said so. The gate reported PASS. Four minutes later the same
# gate, re-run with the variable set, found the board stale over two ship-blocking defects.
# A CANNOT VERIFY was read as a pass because the thing it silenced was invisible.
#
# WHAT IS DRILLED, AND WHY IT IS THE REAL TEXT
# The controls EXTRACT `gate_verdict_is_pass` from gate-selfcheck.sh and execute it, rather
# than restating the rule. A drill that carries its own copy of the rule it is checking
# passes forever on the day the rule changes — the copied-not-derived family, which the gate
# has already caught inside itself twice. Extraction is by FUNCTION NAME, which survives
# reformatting; a line-number or if-block extraction would not.
#
#   exit 0 = the gate refuses to certify a skipped check   (and says so)
#   exit 1 = a real finding — the refusal is gone, or the ledger is decorative
#   exit 2 = CANNOT VERIFY — the drill could not run, or failed its own controls. NOT a pass.
set -uo pipefail

GATE="${GATE:-$HOME/Scripts/gate-selfcheck.sh}"
FOUND=0
say()  { printf '%s\n' "$*"; }
bad()  { printf '  RED   %s\n' "$*"; FOUND=1; }
cant() { printf '  CANNOT VERIFY  %s\n' "$*"; exit 2; }

[ -f "$GATE" ] || cant "$GATE does not exist, so nothing was drilled."

# -- extract the verdict predicate, by name -------------------------------------------------
PRED="$(awk '/^gate_verdict_is_pass\(\)/ {print; exit}' "$GATE")"
[ -n "$PRED" ] || cant "gate-selfcheck.sh has no gate_verdict_is_pass function. Either the
      verdict was inlined again (in which case this drill is measuring nothing and the
      refusal is unproven), or the file moved. Do not read this as a pass."

# -- CONTROL 1 (positive): a clean run must still be able to pass ---------------------------
# A refusal that refuses everything is not a gate, it is a wall.
if bash -c "$PRED; FAILS=(); WARNS=(); SKIPPED=(); gate_verdict_is_pass" 2>/dev/null; then
  say "  ok    control 1: a run with nothing failed and nothing skipped still passes"
else
  cant "the verdict predicate refuses a CLEAN run. The drill's own positive control failed,
      so its negative controls below prove nothing."
fi

# -- CONTROL 2 (the bite): one skipped check must sink the verdict --------------------------
if bash -c "$PRED; FAILS=(); WARNS=(); SKIPPED=('G-XX#sub NEVER RAN: drill'); gate_verdict_is_pass" 2>/dev/null; then
  bad "the verdict reports PASS with a check in the SKIPPED ledger. This is exactly the
        -108 shape: an upstream CANNOT VERIFY silences a downstream blocker and the gate
        certifies the run anyway. gate_verdict_is_pass must test \${#SKIPPED[@]}."
else
  say "  ok    control 2: one unrun check is enough to deny the PASS"
fi

# -- CONTROL 3: FAILS must still sink it too ------------------------------------------------
# Guards against a rewrite that swaps one condition in for the other rather than adding it.
if bash -c "$PRED; FAILS=('something'); WARNS=(); SKIPPED=(); gate_verdict_is_pass" 2>/dev/null; then
  bad "the verdict reports PASS with a non-empty FAILS array — the skip check replaced the
        failure check instead of joining it."
else
  say "  ok    control 3: a real failure still denies the PASS"
fi

# -- CONTROL 4: the gate must USE the predicate ---------------------------------------------
# A named predicate nobody calls is a comment with parentheses.
if grep -qE '^if gate_verdict_is_pass; then' "$GATE"; then
  say "  ok    control 4: the gate's verdict is taken FROM the predicate"
else
  bad "gate-selfcheck.sh defines gate_verdict_is_pass but does not branch on it, so the
        drilled rule is not the rule the gate actually applies."
fi

# -- CONTROL 5: the ledger must be written to -----------------------------------------------
# An empty ledger can never deny anything, and would make controls 1-4 vacuously satisfied.
CALLS="$(grep -cE '^[[:space:]]*gate_skipped ' "$GATE")"
if [ "${CALLS:-0}" -ge 1 ]; then
  say "  ok    control 5: $CALLS call site(s) record a skipped downstream check"
else
  bad "no gate step calls gate_skipped, so the SKIPPED ledger can never be non-empty and
        the refusal above is unreachable in practice. Every branch that bypasses a named
        downstream step must name it."
fi

# -- CONTROL 6: a skipped check must be PRINTED, not merely counted -------------------------
# The card's floor: at minimum, print which downstream checks were skipped.
if grep -qE 'printf .*%s.*"\$\{SKIPPED\[@\]\}"' "$GATE"; then
  say "  ok    control 6: the verdict prints the skipped checks by name"
else
  bad "the FAIL verdict never prints \${SKIPPED[@]}, so a reader is told a check was skipped
        without being told WHICH — which is how the -108 warning was waved past."
fi

# -- CONTROL 7: every recorded skip must name a gate step -----------------------------------
BADNAME="$(grep -oE '^[[:space:]]*gate_skipped +"[^"]*"' "$GATE" | grep -vE '"G-[A-Z]+' || true)"
if [ -n "$BADNAME" ]; then
  bad "a gate_skipped call does not name a gate step as its first argument, so the verdict
        would report an unrun check nobody can look up:
$BADNAME"
else
  say "  ok    control 7: every recorded skip names a G-* step"
fi

if [ "$FOUND" -eq 0 ]; then
  say "=== drill: 7/7 controls hold — a skipped check cannot be certified as a pass"
  exit 0
fi
say "=== drill: FINDINGS above. The gate can certify a run in which a check never ran."
exit 1
