#!/usr/bin/env bash
# gate-seam-audit-drill.sh — controls for gate-selfcheck's G-BB, the seam audit at wrap.
#
# SM 1219339796975909 (seam recipe leg 1), ncFeynman1009wp i3 2026-10-09. G-BB turns
# `seam.py audit`'s exit code into a verdict: 4 RED, 0 ok, 2 n/a (try the next candidate),
# anything else CANNOT VERIFY. Its failing state and its no-pattern state are both "the audit
# said something", so the control that matters is that each rc lands in exactly one bucket.
# The block is EXTRACTED from gate-selfcheck.sh and eval'd, never copied (htc-number-drill.sh:16).
#
# rc 0 = every control holds.  rc 1 = at least one did not.  rc 2 = could not extract.
set -uo pipefail
GATE="${GATE_FILE:-$HOME/code/darwin-mac-ops/gate-selfcheck.sh}"
case "$GATE" in
  /*) : ;;
   *) GATE="$(cd "$(dirname "$GATE")" 2>/dev/null && pwd)/$(basename "$GATE")" ;;
esac

PASS=0; FAIL=0
check(){ # check <name> <expected> <got>
  if [ "$3" = "$2" ]; then printf '  ok    %-52s %s\n' "$1" "$3"; PASS=$((PASS+1))
  else printf '  FAIL  %-52s got "%s", wanted "%s"\n' "$1" "$3" "$2"; FAIL=$((FAIL+1)); fi
}

[ -f "$GATE" ] || { echo "drill: CANNOT VERIFY — gate not found at $GATE"; exit 2; }
_blk="$(awk '/^gate_ran "G-BB"$/,/^# G-BB-END/' "$GATE" | sed '$d')"
case "$_blk" in *seam.py*audit*) : ;; *) echo "drill: CANNOT VERIFY — could not extract the G-BB block from $GATE"; exit 2 ;; esac

T="$(mktemp -d "${TMPDIR:-/tmp}/gate-seam-drill.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
# the stub: rc per project from $T/rc.<project> (default 2 = no pattern); logs who it was asked about
cat > "$T/seam.py" <<'PY'
import os, sys
p = sys.argv[sys.argv.index("--project") + 1]
open(os.path.join(os.path.dirname(__file__), "asked"), "a").write(p + "\n")
f = os.path.join(os.path.dirname(__file__), "rc." + p)
rc = int(open(f).read()) if os.path.exists(f) else 2
print("stub seam audit %s rc=%d" % (p, rc)); sys.exit(rc)
PY

# run <block> <tag> [rc-file assignments project=rc ...] -> "F<n> W<n> N<n>"
run() {
  local blk="$1" tag="$2"; shift 2
  rm -f "$T"/rc.* "$T/asked"
  local kv; for kv in "$@"; do printf '%s' "${kv#*=}" > "$T/rc.${kv%%=*}"; done
  (
    gate_ran(){ :; }; bold(){ :; }
    FAILS=(); WARNS=(); NA=(); QUIET=0
    gate_na(){ NA+=("$1 N/A: $2"); }
    unset SEAM_PROJECT; SEAM_PY="${RUN_SEAM_PY:-$T/seam.py}"; _ch_tag="$tag"; GATE_ROSTER_WHO=drill
    eval "$blk" >/dev/null 2>&1
    printf 'F%d W%d N%d' "${#FAILS[@]}" "${#WARNS[@]}" "${#NA[@]}"
  )
}

echo "=== G-BB · each seam.py rc lands in exactly one bucket ==="
check "rc 4 on the stripped tag -> RED"            "F1 W0 N0" "$(run "$_blk" opus-fooProj-12 fooProj=4)"
check "rc 0 -> ok, nothing pushed"                 "F0 W0 N0" "$(run "$_blk" opus-fooProj-12 fooProj=0)"
check "rc 2 on every candidate -> n/a"             "F0 W0 N1" "$(run "$_blk" opus-fooProj-12)"
check "rc 3 (board dark) -> CANNOT VERIFY warn"    "F0 W1 N0" "$(run "$_blk" opus-fooProj-12 fooProj=3)"
check "rc 1 (crash) -> CANNOT VERIFY warn"         "F0 W1 N0" "$(run "$_blk" opus-fooProj-12 fooProj=1)"
check "stripped=2, raw tag drifts -> RED"          "F1 W0 N0" "$(run "$_blk" fooProj-3 fooProj=4)"
run "$_blk" opus-fooProj-12 >/dev/null
check "candidates asked in order (stripped, raw)"  "fooProj opus-fooProj" "$(tr '\n' ' ' < "$T/asked" | sed 's/ $//')"
check "no session tag -> n/a, seam not asked"      "F0 W0 N1" "$(run "$_blk" '')"
check "seam.py missing -> CANNOT VERIFY warn"      "F0 W1 N0" "$(RUN_SEAM_PY="$T/none.py" run "$_blk" opus-fooProj-12)"

echo "=== mutant: rc 4 read as clean must be caught ==="
_mut="${_blk/      4) _sm_done=1/      4|0) _sm_done=1; break ;; 9) _sm_done=1}"
[ "$_mut" != "$_blk" ] || { echo "drill: CANNOT VERIFY — mutant did not apply"; exit 2; }
_m="$(run "$_mut" opus-fooProj-12 fooProj=4)"
if [ "$_m" != "F1 W0 N0" ]; then printf '  ok    %-52s %s\n' "mutant (4 == 0) goes green -> killed" "$_m"; PASS=$((PASS+1))
else printf '  FAIL  %-52s survived\n' "mutant (4 == 0)"; FAIL=$((FAIL+1)); fi

echo "gate-seam-audit-drill: $PASS ok, $FAIL failed"
[ "$FAIL" -eq 0 ]
