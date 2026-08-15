#!/bin/bash
# gate-changelog-drill.sh -- the control for G-L#35c (header version has a changelog entry).
#   born 2026-08-15, stateMachineRename-1
#
# WHY A DRILL FOR FOUR LINES OF GREP
#   Because the first version of this drill stopped controlling within ninety seconds of being
#   written. It hardcoded `sed 's/Version 2\.56/Version 9.99/'` to build its positive control;
#   the very next edit bumped the file to v2.57, the sed matched nothing, the "positive control"
#   fed the checker an UNMODIFIED file, and it printed PASS -- a green light from a control that
#   had quietly stopped controlling. That is v2.52's failure verbatim (two controls that were not
#   controlling) and gate-roster-drill.sh's (failing since 2026-08-12, unnoticed, because no gate
#   ran it), reproduced inside the fix for the sixth instance of a third one. So: every control
#   here DERIVES the version from the file, and this drill is WIRED into the gate rather than
#   left to be run by whoever remembers.
#
# EXIT: 0 all controls green · 1 a control misbehaved (the checker is broken) · 2 CANNOT VERIFY

set -o pipefail
GATE="${CANON_GATE:-$HOME/Desktop/downloads/HANDOFF-GATE.md}"
[ -r "$GATE" ] || { echo "CANNOT VERIFY: cannot read $GATE"; exit 2; }

# The subject under test, byte-identical in intent to the block in gate-selfcheck.sh.
_check() {
  local f="$1" hv
  hv="$(grep -m1 -oE 'Version [0-9]+\.[0-9]+' "$f" 2>/dev/null | sed 's/Version //')"
  [ -z "$hv" ] && return 2
  grep -qE "^- v${hv//./\\.} " "$f" || return 1
  return 0
}

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAILED=0
say() { printf '  %-6s %s\n' "$1" "$2"; }

# --- derive the live version; everything below is built FROM it, never hardcoded -------------
VER="$(grep -m1 -oE 'Version [0-9]+\.[0-9]+' "$GATE" | sed 's/Version //')"
if [ -z "$VER" ]; then echo "CANNOT VERIFY: no 'Version X.YY' in $GATE header"; exit 2; fi

# C1 NEGATIVE control: the real file must pass.
_check "$GATE"; rc=$?
if [ $rc -eq 0 ]; then say ok "C1 real file (v$VER) passes"; else say FAIL "C1 real file returned rc=$rc, expected 0"; FAILED=1; fi

# C2 POSITIVE control: bump the header to a version that HAS no entry -> must FAIL (rc 1).
#     "9.99" is safe only because C3 proves the entry for it genuinely does not exist.
sed "s/Version ${VER//./\\.}/Version 9.99/" "$GATE" > "$TMP/bumped.md"
if grep -qE '^Version 9\.99|Version 9\.99' "$TMP/bumped.md"; then :; else say FAIL "C2 setup: the version rewrite did not take -- this drill is not controlling"; FAILED=1; fi
_check "$TMP/bumped.md"; rc=$?
if [ $rc -eq 1 ]; then say ok "C2 header bumped to an entry-less version -> FAIL (can go red)"; else say FAIL "C2 returned rc=$rc, expected 1 -- the checker cannot go red"; FAILED=1; fi

# C3 the positive control is not vacuous: v9.99 must really have no changelog line.
if grep -qE '^- v9\.99 ' "$GATE"; then say FAIL "C3 v9.99 has a real changelog entry -- pick another sentinel version"; FAILED=1; else say ok "C3 sentinel version has no entry (C2 is not vacuous)"; fi

# C4 CANNOT VERIFY control: no Version line at all -> rc 2, never a silent pass.
printf '# gate with no version header\n- v1.0 an entry\n' > "$TMP/noversion.md"
_check "$TMP/noversion.md"; rc=$?
if [ $rc -eq 2 ]; then say ok "C4 missing Version header -> CANNOT VERIFY (not a pass)"; else say FAIL "C4 returned rc=$rc, expected 2"; FAILED=1; fi

# C5 the drill's own subject is the LIVE gate, not a fixture copy that could drift.
if grep -q 'grep -qE "\^- v\${_hv//./\\\\.} "' "$HOME/code/darwin-mac-ops/gate-selfcheck.sh" 2>/dev/null; then
  say ok "C5 gate-selfcheck.sh still carries the block this drill controls"
else
  say FAIL "C5 could not find the G-L#35c grep in gate-selfcheck.sh -- the drill is controlling a block that no longer exists (or was reworded); re-sync _check() with it"
  FAILED=1
fi

if [ "$FAILED" -eq 0 ]; then echo "=== drill: G-L#35c green (5 controls, 3 of them negative/vacuity) ==="; exit 0; fi
echo "=== drill: G-L#35c FAILED -- the changelog check is not trustworthy this run ==="; exit 1
