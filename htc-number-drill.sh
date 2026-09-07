#!/usr/bin/env bash
# htc-number-drill.sh — controls for gate-selfcheck's _htc_predecessor.
#
# G-AQ can only grade an inbound handoff it can NAME, and the naming was two bugs deep:
#
#   OCTAL — the session number arrives as a STRING, so `07` is octal to bash arithmetic
#   and $((07-1)) is 6. G-AQ looked for HANDOFF-feynmanSync-6.md, did not find it, and
#   reported "the inbound handoff could not be read" — an accusation aimed at the
#   predecessor's paperwork for a defect in the accuser. Worse, it is a WRONG answer only
#   until session 08, where $((08-1)) becomes a hard bash error ("value too great for
#   base"). Control 2 is that landmine, and it is the reason this file exists.
#
#   PADDING — even decoded, 7-1 spells "-6.md" while the file on disk is "-06.md".
#
# The function is EXTRACTED from gate-selfcheck.sh and eval'd, never copied here: a drill
# that grades a duplicate proves the duplicate.
#
# rc 0 = every control holds.  rc 1 = at least one did not.  rc 2 = could not extract.
set -uo pipefail
GATE="${GATE_FILE:-$HOME/code/darwin-mac-ops/gate-selfcheck.sh}"
# A RELATIVE $GATE is resolved HERE, before anything cds away (feynmanSync-09, 2026-09-07).
# This drill runs from a temp dir, so a relative path handed in by a caller resolves to
# nothing and the drill reports "could not extract" -- a true statement with a false cause,
# which the gate then prints as "the function was renamed or reshaped". Resolve against the
# cwd we were STARTED in, which is the only cwd the caller's string was ever relative to.
case "$GATE" in
  /*) : ;;
   *) GATE="$(cd "$(dirname "$GATE")" 2>/dev/null && pwd)/$(basename "$GATE")" ;;
esac

PASS=0; FAIL=0
bold(){ printf '\033[1m%s\033[0m\n' "$*"; }
check(){ # check <name> <expected> <got>
  if [ "$3" = "$2" ]; then printf '  ok    %-50s %s\n' "$1" "${3:-（empty）}"; PASS=$((PASS+1))
  else printf '  FAIL  %-50s got "%s", wanted "%s"\n' "$1" "$3" "$2"; FAIL=$((FAIL+1)); fi
}

[ -f "$GATE" ] || { echo "drill: CANNOT VERIFY — gate not found at $GATE"; exit 2; }
_fn="$(awk '/^_htc_predecessor\(\)/,/^}$/' "$GATE")"
[ -n "$_fn" ] || { echo "drill: CANNOT VERIFY — could not extract _htc_predecessor from $GATE"; exit 2; }
eval "$_fn" || { echo "drill: CANNOT VERIFY — extracted function did not parse"; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/htc-num-drill.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
bold "=== _htc_predecessor drill ==="

# 1. THE CASE THAT SHIPPED: a zero-padded 07 whose predecessor is on disk as 06.
: > "$T/HANDOFF-proj-06.md"
check "07 finds the padded 06 on disk" "$T/HANDOFF-proj-06.md" "$(_htc_predecessor "$T" proj 07)"

# 2. THE LANDMINE. 08 and 09 are not valid octal, so the old inline form was not merely
#    wrong here — it was a hard bash error. If this control ever fails, the gate itself
#    will abort mid-run on the eighth session of any project.
: > "$T/HANDOFF-proj-07.md"
check "08 does not explode on invalid octal" "$T/HANDOFF-proj-07.md" "$(_htc_predecessor "$T" proj 08)"
: > "$T/HANDOFF-proj-08.md"
check "09 does not explode either" "$T/HANDOFF-proj-08.md" "$(_htc_predecessor "$T" proj 09)"

# 3. the padding is REBUILT at the original width — 10 wants 09, not 9.
: > "$T/HANDOFF-proj-09.md"
check "10 asks for 09, not 9" "$T/HANDOFF-proj-09.md" "$(_htc_predecessor "$T" proj 10)"

# 4. the estate writes handoffs both ways, so the BARE spelling still resolves when that
#    is what is actually on disk. Without this the padding fix would just move the bug.
B="$T/bare"; mkdir -p "$B"; : > "$B/HANDOFF-proj-9.md"
check "10 falls back to a bare 9 when that is the file" "$B/HANDOFF-proj-9.md" "$(_htc_predecessor "$B" proj 10)"

# 5. a FIRST handoff has no predecessor, and must say so with silence rather than naming
#    HANDOFF-proj-00.md — G-AQ reads empty as "nothing to grade" and a path as "grade it".
check "session 01 has no predecessor" "" "$(_htc_predecessor "$T" proj 01)"

# 6. NEGATIVE CONTROL: when nothing is on disk it must still NAME the same-width candidate,
#    so G-AQ's CANNOT VERIFY can say which file it wanted. Silence here would be read as
#    "first handoff" and the whole check would vanish — the way G-AA vanished in -24.
E="$T/empty"; mkdir -p "$E"
check "a missing predecessor is still NAMED, not silent" "$E/HANDOFF-proj-06.md" "$(_htc_predecessor "$E" proj 07)"

echo
if [ "$FAIL" -gt 0 ]; then
  bold "=== _htc_predecessor drill: FAIL — $FAIL of $((PASS+FAIL)) controls did not hold ==="
  exit 1
fi
bold "=== _htc_predecessor drill: PASS — $PASS controls ==="
exit 0
