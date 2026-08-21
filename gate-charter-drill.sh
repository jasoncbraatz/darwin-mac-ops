#!/bin/bash
# gate-charter-drill.sh — controls for the charter force function (G-AL).
#
# G-AL turns "did this session know what done looks like?" into a blocker. That is a check
# whose whole value is its ability to go RED, so it does not get to ship untested. Everything
# below runs against fixtures in a temp dir via the env overrides both tools already honour
# (PROJECT_CHARTERS, CLAUDE_SESSION_STATE, BP_CRITERIA, BP_DONE) — it installs nothing, and
# never touches the real registry, the real ledger, or the real DONE.md.
#
# rc 0 = every control holds · 1 = a control failed · 2 = the tools under test are missing.
set -uo pipefail
CR="${CHARTER_READ:-$HOME/Scripts/charter-read.sh}"
GD="${GEN_DONE:-$HOME/repos/braatzio-plan/v3/tools/gen-done.py}"
PASS=0; FAIL=0
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
chk() { # chk <name> <want-rc> <got-rc> <want-pattern|-> <output>
  if [ "$3" != "$2" ]; then printf '  FAIL  %-52s rc=%s (wanted %s)\n' "$1" "$3" "$2"; FAIL=$((FAIL+1)); return; fi
  if [ "$4" != "-" ] && ! printf '%s' "$5" | grep -qE "$4"; then
    printf '  FAIL  %-52s rc ok but output lacks /%s/\n' "$1" "$4"; FAIL=$((FAIL+1)); return; fi
  printf '  ok    %-52s rc=%s\n' "$1" "$3"; PASS=$((PASS+1))
}
[ -x "$CR" ] || { echo "drill: CANNOT VERIFY — $CR missing or not executable"; exit 2; }
[ -f "$GD" ] || { echo "drill: CANNOT VERIFY — $GD missing"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkfix() { # a miniature project with a charter, and a session that has not read it
  mkdir -p "$T/state" "$T/proj/v3"
  printf 'demo\tDEMO\t%s/proj/v3/crit.tsv\tprintf "## The board\\ndemo board\\n## Every criterion\\n"\n' "$T" > "$T/charters.tsv"
  printf 'LX\tLayer 0\ta criterion that is met\tcmd:true\n'  > "$T/proj/v3/crit.tsv"
  printf 'LY\tLayer 0\ta criterion that is not\tcmd:false\n' >> "$T/proj/v3/crit.tsv"
  echo demo-3 > "$T/state/current"
  : > "$T/state/demo-3.log"
}
run_cr() { OUT="$(PROJECT_CHARTERS="$T/charters.tsv" CLAUDE_SESSION_STATE="$T/state" bash "$CR" "$@" 2>&1)"; RC=$?; }
run_gd() { OUT="$(BP_CRITERIA="$T/proj/v3/crit.tsv" BP_DONE="$T/proj/v3/DONE.md" python3 "$GD" "$@" 2>&1)"; RC=$?; }

bold "=== charter force-function drill ==="

# 1 POSITIVE — a registered project reads its board and stamps the ledger.
mkfix; run_cr
chk "registered project reads + stamps" 0 "$RC" "stamped demo@" "$OUT"
grep -q '^CHARTER demo ' "$T/state/demo-3.log" \
  && { printf '  ok    %-52s\n' "the stamp really landed in the ledger"; PASS=$((PASS+1)); } \
  || { printf '  FAIL  %-52s\n' "the stamp really landed in the ledger"; FAIL=$((FAIL+1)); }

# 2 NEGATIVE — an UNREGISTERED project is a finding, not a shrug. A project nobody has
#   written a definition of done for is the state this whole mechanism exists to surface.
mkfix; echo other-1 > "$T/state/current"; run_cr
chk "unregistered project is rc=2, not a pass" 2 "$RC" "nobody has written down what DONE" "$OUT"

# 3 NEGATIVE — a MISSING registry fails closed. Silence here would mean every project on the
#   machine silently has no charter requirement.
mkfix; OUT="$(PROJECT_CHARTERS="$T/nope.tsv" CLAUDE_SESSION_STATE="$T/state" bash "$CR" 2>&1)"; RC=$?
chk "missing registry is CANNOT VERIFY" 2 "$RC" "registry.*is missing" "$OUT"

# 4 NEGATIVE — a project whose criteria file has VANISHED is worse than one that never had
#   one, and must say so rather than passing.
mkfix; rm -f "$T/proj/v3/crit.tsv"; run_cr
chk "vanished criteria file is CANNOT VERIFY" 2 "$RC" "WORSE state" "$OUT"

# 5 NON-VACUITY — a criteria file that parses to ZERO rows must not render as a finished
#   project. An empty board is a broken parser, not a done project. (acmeLedger-21's rule,
#   and the shape that let -24's G-AA turn a FAIL into a PASS by deleting a directory.)
mkfix; printf '# only comments here\n' > "$T/proj/v3/crit.tsv"; run_gd
chk "zero criteria is CANNOT VERIFY, not done" 2 "$RC" "ZERO criteria" "$OUT"

# 6 the generator must actually MEASURE: one true check and one false check cannot both pass.
mkfix; run_gd
chk "generator writes a board" 0 "$RC" "wrote" "$OUT"
grep -q 'LY.*OPEN' "$T/proj/v3/DONE.md" \
  && { printf '  ok    %-52s\n' "a failing criterion renders OPEN, not CLOSED"; PASS=$((PASS+1)); } \
  || { printf '  FAIL  %-52s\n' "a failing criterion renders OPEN, not CLOSED"; FAIL=$((FAIL+1)); }
grep -q 'LX.*CLOSED' "$T/proj/v3/DONE.md" \
  && { printf '  ok    %-52s\n' "a passing criterion renders CLOSED"; PASS=$((PASS+1)); } \
  || { printf '  FAIL  %-52s\n' "a passing criterion renders CLOSED"; FAIL=$((FAIL+1)); }

# 7 STALENESS — a lane that changes status must make DONE.md stale, or the committed board
#   is a doc about a world that moved on (which is the whole disease).
run_gd --check
chk "fresh DONE.md passes --check" 0 "$RC" "matches measured reality" "$OUT"
printf 'LY\tLayer 0\ta criterion that is not\tcmd:true\n' > "$T/proj/v3/crit.tsv"   # LY just closed
run_gd --check
chk "a lane that CLOSED makes DONE.md stale" 1 "$RC" "STALE" "$OUT"

# 8 an unrecognised check type must be CANNOT VERIFY, never a silent pass.
mkfix; printf 'LZ\tLayer 0\tinvented check type\tvibes:it feels done\n' > "$T/proj/v3/crit.tsv"; run_gd
grep -q 'CANNOT VERIFY' "$T/proj/v3/DONE.md" \
  && { printf '  ok    %-52s\n' "unknown check type is CANNOT VERIFY"; PASS=$((PASS+1)); } \
  || { printf '  FAIL  %-52s\n' "unknown check type is CANNOT VERIFY"; FAIL=$((FAIL+1)); }

# 9 a manual criterion must NEVER auto-close. A human gate that a script can satisfy is not
#   a human gate — and L3's done-when is "Stephanie can onboard and run solo".
mkfix; printf 'LM\tLayer 3\tStephanie runs solo\tmanual:a human watches a human\n' > "$T/proj/v3/crit.tsv"; run_gd
grep -q 'PENDING-HUMAN' "$T/proj/v3/DONE.md" \
  && { printf '  ok    %-52s\n' "a manual criterion never auto-closes"; PASS=$((PASS+1)); } \
  || { printf '  FAIL  %-52s\n' "a manual criterion never auto-closes"; FAIL=$((FAIL+1)); }

echo
# --- ROSTER IDENTITIES (2026-08-19, acmeLedger-26) --------------------------------------
# The estate's session identities are <tier>-<task>-<NN>, and the tier vocabulary is not
# fixed. G-AL carried a hardcoded `orchestrator|big|mid|fast|cloud` strip that had no `opus`,
# so every Opus session warned "no charter registered for project opusacmeledger" while
# session-in resolved the same project fine. These controls pin the resolution instead of
# the list, so the next new tier cannot reintroduce it.
mkfix
for who in demo-3 opus-demo-3 big-demo-12 fable-demo-1 rail-demo-1786812293; do
  run_cr --resolve "$who"
  chk "roster identity '$who' resolves to its charter" 0 "$RC" "^demo	" "$OUT"
done

# NEGATIVE — segment-dropping must not turn an unknown project into a known one.
run_cr --resolve opus-nosuchproject-9
chk "unknown project stays unresolved (rc=3)" 3 "$RC" "no charter registered" "$OUT"

# NEGATIVE — a candidate too short to be a name must not prefix-match anything.
run_cr --resolve x-9
chk "a 1-char identity resolves nothing" 3 "$RC" "no charter registered" "$OUT"

# PREFIX — the voice-box shape (per-phase slugs) still resolves, at every tier.
printf 'demoPhase\tDEMO2\t%s/proj/v3/crit.tsv\tprintf "## The board\\n"\n' "$T" >> "$T/charters.tsv"
run_cr --resolve opus-demoPhaseCorpus-2
chk "per-phase slug prefix-matches under a tier prefix" 0 "$RC" "^demoPhase	" "$OUT"

# ANTI-DIVERGENCE — G-AL must ASK charter-read, not carry its own copy of the row loop.
# Both historical bugs here were copies drifting apart while the drill watched only one of
# them. This control fails if a second implementation reappears.
GS="${GATE_SELFCHECK:-$HOME/Scripts/gate-selfcheck.sh}"
if [ -r "$GS" ]; then
  if grep -q 'CHARTER_READ" --resolve' "$GS" && ! grep -qE '_kn=.*sed -E .s/-\[0-9\]' "$GS"; then
    printf '  ok    %-52s\n' "G-AL delegates the match (no second copy)"; PASS=$((PASS+1))
  else
    printf '  FAIL  %-52s\n' "G-AL has its own matcher again — they WILL drift"; FAIL=$((FAIL+1))
  fi
else
  printf '  WARN  %-52s\n' "gate-selfcheck.sh unreadable; anti-divergence control skipped"
fi

# 12 · THE LEDGER NAME. A session writes its charter stamp under the SLUG
#   (`wealthTensor-101.log`) and this gate is handed the ROSTER IDENTITY
#   (`big-wealthTensor-101`). charter-read.sh normalises the tier prefix when it WRITES; until
#   wealthTensor-101 the gate did not when it READ, so the exact-file grep missed, the warm
#   scan below it graded the session against whichever SIBLING `find` returned first, and G-AL
#   printed `ok` naming a stranger's ledger. Every tier-prefixed session -- which is every
#   session that follows its handoff's `GATE_ROSTER_WHO=` instruction -- was vacuous.
if [ -r "$GS" ]; then
  if grep -q '_ch_cands+=("$SESSION_STATE/${_ch_tag#\*-}.log")' "$GS"; then
    printf '  ok    %-52s\n' "G-AL tries the tier-stripped ledger name"; PASS=$((PASS+1))
  else
    printf '  FAIL  %-52s\n' "G-AL will miss its own stamp under a roster id"; FAIL=$((FAIL+1))
  fi
  # NEGATIVE — and this is the control that matters, because the hard-coded tier list is the
  # thing that ALREADY drifted here once: it had no `opus`, so every Opus session warned "no
  # charter registered". One leading `<word>-` is stripped and the file's EXISTENCE decides.
  if grep -qE '_ch_(tag|cands).*(orchestrator\|big\|mid\|fast\|cloud|big\|mid)' "$GS"; then
    printf '  FAIL  %-52s\n' "a hard-coded tier list is back — it WILL drift again"; FAIL=$((FAIL+1))
  else
    printf '  ok    %-52s\n' "no hard-coded tier list in the ledger-name path"; PASS=$((PASS+1))
  fi
else
  printf '  WARN  %-52s\n' "gate-selfcheck.sh unreadable; ledger-name controls skipped"
fi

if [ "$FAIL" -gt 0 ]; then bold "=== drill: FAIL — $FAIL of $((PASS+FAIL)) controls did not hold ==="; exit 1; fi
bold "=== drill: PASS — $PASS controls, 10 of them negative (G-AL can still go red) ==="
exit 0
