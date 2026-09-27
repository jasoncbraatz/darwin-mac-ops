#!/usr/bin/env bash
# htc-number-drill.sh — controls for gate-selfcheck's handoff-NAME resolution:
# _htc_predecessor (which number) and _htc_resolve_out (which spelling).
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
_fn2="$(awk '/^_htc_resolve_out\(\)/,/^}$/' "$GATE")"
[ -n "$_fn2" ] || { echo "drill: CANNOT VERIFY — could not extract _htc_resolve_out from $GATE"; exit 2; }
eval "$_fn2" || { echo "drill: CANNOT VERIFY — extracted _htc_resolve_out did not parse"; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/htc-num-drill.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
bold "=== _htc_predecessor drill (which NUMBER) ==="

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


# ---------------------------------------------------------------------------
# _htc_resolve_out — WHICH SPELLING. The second naming bug, and the more expensive one:
# a session slug is not always the prefix of its own handoff's filename. ceo-desk sessions
# call themselves `freshcanary-13` and write HANDOFF-ceoFreshCanary-13.md, so the exact-name
# derivation missed and FIVE wrap steps (G-AQ, G-AQ#dod, G-R, G-AR, G-AZ) reported a quiet
# n/a on every handoff that project ever wrote — an n/a a reader cannot tell from "nothing
# to check". SM 1218798969221226, filed by the session it happened to, dead-lettered 147h.
#
# rc contract, drilled below: 0 = one path printed · 1 = nothing matched, nothing printed ·
# 2 = ambiguous, the BASENAMES printed and NOTHING chosen.
bold "=== _htc_resolve_out drill ==="
_rc(){ printf '%s' "$(_htc_resolve_out "$@")"; }        # value only
_rcode(){ _htc_resolve_out "$@" >/dev/null 2>&1; printf '%s' "$?"; }

# 1. THE CASE THAT FILED THE CARD: the slug is a case-insensitive suffix of the filename's
#    project, at a camelCase seam.
C="$T/c1"; mkdir -p "$C"; : > "$C/HANDOFF-ceoFreshCanary-13.md"
check "a ceo-desk prefix resolves from the bare slug" "$C/HANDOFF-ceoFreshCanary-13.md" "$(_rc "$C" freshcanary 13)"

# 2. the NUMBER is decoded, not string-matched — 4 and 04 are one session (the octal half of
#    this file, reused: a fix that only understood '04' would move the bug, not close it).
C="$T/c2"; mkdir -p "$C"; : > "$C/HANDOFF-ceoFoo-04.md"
check "slug -4 matches the file's -04" "$C/HANDOFF-ceoFoo-04.md" "$(_rc "$C" foo 4)"

# 3. NEGATIVE CONTROL, the reason the rule is narrow: a suffix that lands MID-WORD is a
#    coincidence, not a name. Without the boundary test, slug `anary-13` claims the file in
#    control 1 and the gate grades a stranger's handoff with a straight face.
C="$T/c3"; mkdir -p "$C"; : > "$C/HANDOFF-ceoFreshCanary-13.md"
check "a mid-word suffix does NOT match" "" "$(_rc "$C" anary 13)"
check "  ...and says so with rc 1" "1" "$(_rcode "$C" anary 13)"

# 4. a DIFFERENT number never matches, however well the name fits.
C="$T/c4"; mkdir -p "$C"; : > "$C/HANDOFF-ceoFreshCanary-12.md"
check "the right name at the wrong number misses" "" "$(_rc "$C" freshcanary 13)"

# 5. AMBIGUITY IS NOT RESOLVED BY GUESSING: two matches print both basenames and rc 2, so
#    G-AQ's n/a can name them. Grading the WRONG session's handoff is worse than grading
#    none, because the verdict is confident.
C="$T/c5"; mkdir -p "$C"; : > "$C/HANDOFF-ceoFreshCanary-13.md"; : > "$C/HANDOFF-fableFreshCanary-13.md"
check "two matches are reported, not chosen" "HANDOFF-ceoFreshCanary-13.md HANDOFF-fableFreshCanary-13.md" "$(_rc "$C" freshcanary 13)"
check "  ...with rc 2" "2" "$(_rcode "$C" freshcanary 13)"

# 6. HANDOFF-GATE.md lives in the same directory and has no session number. It must never be
#    a candidate — the gate reading the GATE DOC as its own handoff is a closed loop.
C="$T/c6"; mkdir -p "$C"; : > "$C/HANDOFF-GATE.md"
check "HANDOFF-GATE.md is never a candidate" "" "$(_rc "$C" gate 13)"

# 7. the whole-field case still resolves (a slug that IS the project, differing only in case)
C="$T/c7"; mkdir -p "$C"; : > "$C/HANDOFF-Proj-13.md"
check "a case-only difference resolves" "$C/HANDOFF-Proj-13.md" "$(_rc "$C" proj 13)"

# 8. an empty directory is rc 1 and silent — the caller then keeps the exact name it wanted,
#    so the n/a can still say which file it was looking for.
C="$T/c8"; mkdir -p "$C"
check "an empty directory is silent, rc 1" "1" "$(_rcode "$C" freshcanary 13)"

echo
if [ "$FAIL" -gt 0 ]; then
  bold "=== handoff-name drill: FAIL — $FAIL of $((PASS+FAIL)) controls did not hold ==="
  exit 1
fi
bold "=== handoff-name drill: PASS — $PASS controls ==="
exit 0
