#!/usr/bin/env bash
# handoff-dod-check-drill.sh — fires every @verdict code of handoff-dod-check.sh on scratch files.
# Written at the wisdomVector desk-out 2026-09-11: G-AP found the contract declared (0,1,2) with
# no drill — "an unproven verdict is a claim, not a control". Each case below is a real handoff
# shape, in a mktemp -d scratch dir, never the live tree. Prints VERDICTS-EXERCISED: for the census.
set -u
S="$(cd "$(dirname "$0")" && pwd)/handoff-dod-check.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/hdc-drill.XXXXXX"); trap 'rm -rf "$T"' EXIT
pass=0; fail=0; fired=""
check() { # $1 label, $2 expected rc, $3... command
  local label="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  if [ "$rc" = "$want" ]; then pass=$((pass+1)); fired="$fired,$rc"; echo "  ok   ($want) $label"
  else fail=$((fail+1)); echo "  FAIL ($want, got $rc) $label"; fi
}
printf '# HANDOFF — drill\n\nDoD: this drill exits 0 when every case matches its declared code, and a reader can mark that right or wrong.\n' > "$T/good.md"
printf '# HANDOFF — drill\n\nNo definition of done anywhere in the first lines of this file.\n' > "$T/nodod.md"
check "a substantive DoD line is OK"                 0 bash "$S" --handoff "$T/good.md"  --errand-declared 0 --dir "$T"
check "no DoD line at all is a FAIL"                 1 bash "$S" --handoff "$T/nodod.md" --errand-declared 0 --dir "$T"
check "an unreadable handoff is CANNOT VERIFY"       2 bash "$S" --handoff "$T/does-not-exist.md"
echo "VERDICTS-EXERCISED:${fired#,}"
echo "-- $pass passed, $fail failed --"
[ "$fail" -eq 0 ]
