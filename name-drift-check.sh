#!/bin/bash
# name-drift-check.sh -- a renamed shared object must not keep teaching its old name
#   from the front doors.   (born 2026-08-15, stateMachineRename-1)
#
# WHY THIS EXISTS
#   Asana project 1215913700958709 was renamed Bullpen -> "State Machine" on 2026-07-10.
#   The rename was done PROPERLY: banked as a lesson, banner'd at the top of
#   BATTERS-BOX-HYGIENE.md, GID unchanged so zero code broke, UNDO recorded. And it
#   rotted anyway -- for FIVE WEEKS the two files a zero-memory session reads FIRST
#   (CLAUDE.md / AGENTS.md) still had a section titled "## Bullpen" teaching the dead
#   name as current. Jason found it by eye on 2026-08-15. Nothing was watching, so
#   nothing complained. This is the thing that watches.
#
#   Same family as G-L#35b (a RANGE copied into prose rots). A NAME copied into prose
#   rots identically. No reason to learn that once per renamed object.
#
# THE RULE (loose on purpose, so it does not cry wolf)
#   A front door may say a retired name as much as it likes -- history is real and
#   rewriting it is worse than leaving it. What it may NOT do is say the retired name
#   WITHOUT ACKNOWLEDGING the rename somewhere in the same file. One "fka Bullpen" or
#   one RENAME banner is enough: the reader is oriented, the drift is dead.
#
# EXIT CODES (load-bearing; the gate branches on all three)
#   0  clean
#   1  DRIFT -- a front door teaches a dead name with no acknowledgement
#   2  CANNOT VERIFY -- registry unreadable/empty, a scoped file missing, zero files
#      scanned, or the self-controls misbehaved. Exit 2 is NOT a pass.
#
# SCOPE IS NARROW ON PURPOSE, AND PRINTED, NEVER SILENT
#   Front doors + constitution + canon. Dated SESSION-*/HANDOFF-*/RETRO-* notes and the
#   lessons corpus are EXCLUDED: those are period-correct records of what was true that
#   day, and flagging them is exactly the cry-wolf that gets a detector muted.
#
# ADDING A RENAME: append one row to retired-names.tsv. That is the whole procedure.
#
# bash 3.2 (stock macOS): no mapfile, and no `set -u` -- an empty array expansion under
# `set -u` is an unbound-variable error there, which would turn a CLEAN run into a crash.

set -o pipefail

REG="${NAME_DRIFT_REGISTRY:-$HOME/code/darwin-mac-ops/retired-names.tsv}"

DOCS=(
  "$HOME/Desktop/downloads/CLAUDE.md"
  "$HOME/Desktop/downloads/AGENTS.md"
  "$HOME/Desktop/downloads/HANDOFF-GATE.md"
  "$HOME/Desktop/downloads/STANDING-BRIEF-CURRENT.md"
  "$HOME/repos/strike-zone/CLAUDE.md"
  "$HOME/repos/strike-zone/constitution/GM-PLAYBOOK.md"
  "$HOME/repos/strike-zone/email-dj/CANON-GEOGRAPHY-AND-ORCHESTRATION.md"
  "$HOME/repos/strike-zone/email-dj/BATTERS-BOX-HYGIENE.md"
  "$HOME/repos/claude-blackbook/CLAUDE.md"
  "$HOME/Scripts/SPEC-darwin-jobqueue.md"
)

DRIFT=(); CANNOT=(); SCANNED=0

# -- registry ---------------------------------------------------------------
if [ ! -r "$REG" ]; then
  echo "CANNOT VERIFY: retired-names registry not readable: ${REG/#$HOME/~}"
  echo "  restore it:  git -C ~/code/darwin-mac-ops checkout -- retired-names.tsv"
  exit 2
fi

REGFILE="$(mktemp)"; trap 'rm -f "$REGFILE"; rm -rf "$CTLDIR"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$REG" > "$REGFILE"
ROWS=$(wc -l < "$REGFILE" | tr -d ' ')
if [ "${ROWS:-0}" -eq 0 ]; then
  echo "CANNOT VERIFY: ${REG/#$HOME/~} has zero usable rows, so nothing was checked."
  echo "  A checker with an empty subject certifies nothing. Exit 2 is not a pass."
  exit 2
fi

# -- the one predicate, used by both the real sweep and the controls ---------
# _drifts <file> <retired_regex> <ack_regex>   -> rc 0 means DRIFT
_drifts() {
  grep -qE "$2" "$1" 2>/dev/null || return 1   # never mentions it        -> fine
  grep -qE "$3" "$1" 2>/dev/null && return 1   # mentions + acknowledges  -> fine
  return 0                                      # mentions, no ack        -> DRIFT
}

# -- validate the registry ONCE, not once per file ---------------------------
# (first cut reported a malformed row ten times -- once per front door. A detector
#  that shouts the same defect N times trains the reader to skim it.)
BADROW=0
while IFS=$'\t' read -r pat cur since ack; do
  if [ -z "$pat" ] || [ -z "$cur" ] || [ -z "$since" ] || [ -z "$ack" ]; then
    echo "CANNOT VERIFY: malformed row in ${REG/#$HOME/~} (need 4 TAB-separated fields: retired_regex, current_name, retired_on, ack_regex)"
    echo "  offending row began: ${pat:-(empty)}"
    BADROW=1
  fi
done < "$REGFILE"
[ "$BADROW" -eq 1 ] && exit 2

# -- self-controls: a detector that can no longer go red must not go green ----
CTLDIR="$(mktemp -d)"
printf 'The Bullpen is where state lives.\n'                       > "$CTLDIR/positive.md"
printf 'The State Machine (fka "Bullpen") is where state lives.\n' > "$CTLDIR/negative.md"
if ! _drifts "$CTLDIR/positive.md" '[Bb]ullpen' 'fka .?[Bb]ullpen'; then
  echo "CANNOT VERIFY: the POSITIVE control was NOT flagged -- this checker can no longer go red."
  echo "  A sweep that cannot fail proves nothing about the front doors it just called clean."
  exit 2
fi
if _drifts "$CTLDIR/negative.md" '[Bb]ullpen' 'fka .?[Bb]ullpen'; then
  echo "CANNOT VERIFY: the NEGATIVE control WAS flagged -- this checker cries wolf on acknowledged renames."
  exit 2
fi

# -- the sweep ---------------------------------------------------------------
for f in "${DOCS[@]}"; do
  if [ ! -r "$f" ]; then
    CANNOT[${#CANNOT[@]}]="scoped front door missing/unreadable: ${f/#$HOME/~}"
    continue
  fi
  SCANNED=$((SCANNED + 1))
  while IFS=$'\t' read -r pat cur since ack; do
    if _drifts "$f" "$pat" "$ack"; then
      n=$(grep -cE "$pat" "$f" 2>/dev/null || echo '?')
      DRIFT[${#DRIFT[@]}]="${f/#$HOME/~}: $n hit(s) for retired name /$pat/ (now \"$cur\", retired $since), no acknowledgement anywhere in the file -- rename the prose, or add an 'fka' note / RENAME banner"
    fi
  done < "$REGFILE"
done

if [ "$SCANNED" -eq 0 ]; then
  echo "CANNOT VERIFY: zero front doors were readable, so nothing was checked."
  [ ${#CANNOT[@]} -gt 0 ] && printf '  - %s\n' "${CANNOT[@]}"
  exit 2
fi

echo "=== name-drift: $SCANNED front door(s) x $ROWS retired name(s); both controls green ==="
echo "    scope excludes dated SESSION-*/HANDOFF-*/RETRO-* notes and the lessons corpus (period-correct by design)"

if [ ${#CANNOT[@]} -gt 0 ]; then printf '  CANNOT VERIFY: %s\n' "${CANNOT[@]}"; exit 2; fi
if [ ${#DRIFT[@]}  -gt 0 ]; then printf '  DRIFT: %s\n'         "${DRIFT[@]}";  exit 1; fi
echo "    clean -- no front door teaches a retired name unacknowledged."
exit 0
