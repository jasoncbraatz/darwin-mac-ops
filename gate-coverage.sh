#!/bin/bash
# gate-coverage.sh — the box-coverage question, asked HONESTLY.
# Born P14, 2026-09-08 (opus-feynmanSync-10).
#
# ── THE QUESTION, AND WHY IT HAD NO INSTRUMENT ────────────────────────────────────────
# -07, -08 and -09 all left the same thread standing: WHICH GATE CHECKS ONLY EVER RUN ON
# ONE BOX? -09 tried to answer it by diffing the two boxes' gate LOGS and got a headline
# that was false — G-AK, 0 occurrences on darwin, reads as "never runs here" and meant
# "the census passed silently". The method was invalid, and every future attempt built on
# gate OUTPUT would have failed the same way, always in the same direction: reading a
# quiet pass as a check that never ran.
#
# So this tool does not read gate output. It joins the ROLL-CALL SIDECARS that
# gate-rollcall.sh writes on every run, where a silent pass is a row that says `pass` and
# a check that never ran is a row that says `NOT-REACHED`. Different facts, different words.
#
# ── USAGE ─────────────────────────────────────────────────────────────────────────────
#   gate-coverage.sh                       # every <box>.tsv in the sidecar dir
#   gate-coverage.sh a.tsv b.tsv [...]     # explicit sidecars (e.g. one fetched off feynman)
#
# ── EXIT CONTRACT (G-AO: never read through a pipe) ───────────────────────────────────
#   0  every declared check was reached on every box compared
#   1  a coverage GAP: some check is reached on one box and not another, or nowhere
#   2  CANNOT VERIFY — fewer than two comparable sidecars, or they disagree about which
#      manifest they were measured against. A join across two different manifests is not a
#      comparison; it is two measurements wearing one table, which is how -09's method lied.
set -u

DIR="${GATE_ROLLCALL_DIR:-$HOME/.cache/gate-rollcall}"
FILES=""
if [ "$#" -gt 0 ]; then
  FILES="$*"
else
  for f in "$DIR"/*.tsv; do
    case "$f" in *-[0-9]*T[0-9]*Z.tsv) continue ;; esac   # skip the timestamped history
    [ -r "$f" ] && FILES="$FILES $f"
  done
fi

N=0; for f in $FILES; do [ -r "$f" ] && N=$((N+1)); done
if [ "$N" -lt 2 ]; then
  echo "gate-coverage: CANNOT VERIFY -- found $N readable sidecar(s); the coverage question needs at least two boxes." >&2
  echo "  Run the gate on each box, then bring the other box's ~/.cache/gate-rollcall/<box>.tsv here." >&2
  exit 2
fi

# --- do they even describe the same subject? -----------------------------------------
# A manifest mismatch is CANNOT VERIFY, not a finding. Two boxes measured against
# different check lists produce a table full of confident, meaningless differences.
# v1.1: compare the manifest's FINGERPRINT, not its basename. Basenames are identical on
# every box by construction, so the v1.0 check could not fail -- a guard that cannot fire is
# indistinguishable from no guard, which is the shape this whole tool exists to expose. A
# sidecar written by an older library carries no fingerprint; say so rather than assuming.
MFS=""
for f in $FILES; do
  _fp="$(sed -n 's/.*manifest_fp=\([^ ]*\).*/\1/p' "$f" | head -1)"
  [ -n "$_fp" ] || _fp="UNFINGERPRINTED($(basename "$f"))"
  MFS="$MFS$_fp
"
done
if [ "$(printf '%s' "$MFS" | sort -u | grep -c .)" -gt 1 ]; then
  echo "gate-coverage: CANNOT VERIFY -- the sidecars were measured against DIFFERENT manifests:" >&2
  printf '%s' "$MFS" | sort -u | sed 's/^/    /' >&2
  echo "    (an UNFINGERPRINTED entry came from gate-rollcall.sh < 1.1 -- re-run the gate on that box)" >&2
  exit 2
fi

echo "── gate coverage · $N box(es) ──"
for f in $FILES; do
  sed -n '2p' "$f" | sed 's/^# /  /'
done
echo

# --- build the table -----------------------------------------------------------------
BOXES=""
for f in $FILES; do
  b="$(sed -n 's/.*[ #]box=\([A-Za-z0-9_.-]*\).*/\1/p' "$f" | head -1)"
  [ -n "$b" ] || b="$(basename "$f" .tsv)"
  BOXES="$BOXES $b"
done

# ids, in the order the first sidecar lists them (= manifest order)
first="$(echo $FILES | awk '{print $1}')"
IDS="$(awk -F'\t' '!/^#/ && NF>=2 { print $1 }' "$first")"

# --- the JUDGMENT half is NOT a coverage question, and must not be scored as one --------
# gate-rollcall.sh v1.2 added rows for the 19 HANDOFF-GATE.md steps a session walks by
# reading prose. They have no box routing: a judgment step is walked by a SESSION, so every
# box will report the same thing about it, and "UNWITNESSED on both boxes" is not a gap in
# coverage -- it is the honest state of nearly all of them today.
#
# Scoring them here would be worse than useless in the specific way this tool exists to
# prevent: they are neither NOT-REACHED nor ABSENT, so the pre-v1.2 loop would have counted
# every one of them as REACHED ON EVERY BOX and quietly inflated a clean "zero gaps" answer
# with 19 rows nothing measured. A census that counts unmeasured things as measured is the
# whole disease.
#
# Collected from ALL sidecars, not just the first: a row that is WITNESSED on one box and
# UNWITNESSED on another is still a judgment row, and reading only the first sidecar would
# let the second box's copy fall through into the mechanical table.
# NEWLINE-SENTINELLED ON BOTH SIDES. A prefix match here would let "G-A" answer for "G-AB"
# -- the same confident-wrong-owner bug gate-rollcall.sh refuses in three separate places,
# and the one the roll-call drill's control 11 exists to hold. It would be quiet, too: G-A is
# a judgment row and G-AB is a judgment row, so today it would merely skip the right rows for
# the wrong reason, and go wrong the day one of them is promoted to a mechanical check.
JUDG_IDS="
"
for f in $FILES; do
  JUDG_IDS="$JUDG_IDS$(awk -F'\t' '!/^#/ && ($2=="WITNESSED" || $2=="DECLARED" || $2=="UNWITNESSED") { print $1 }' "$f")
"
done
_is_judg() { case "$JUDG_IDS" in *"
$1
"*) return 0 ;; esac; return 1; }

printf '  %-21s' "check"
for b in $BOXES; do printf '%-14s' "$b"; done
printf '\n'
printf '  %-21s' "-------------------"
for b in $BOXES; do printf '%-14s' "------------"; done
printf '\n'

GAPS=0; DEAD=0
for id in $IDS; do
  _is_judg "$id" && continue
  row=""; reached=0; unreached=0
  for f in $FILES; do
    s="$(awk -F'\t' -v i="$id" '!/^#/ && $1==i { print $2; exit }' "$f")"
    [ -n "$s" ] || s="ABSENT"
    case "$s" in
      NOT-REACHED|ABSENT) unreached=$((unreached+1)) ;;
      *) reached=$((reached+1)) ;;
    esac
    row="$row$(printf '%-14s' "$s")"
  done
  mark=" "
  if [ "$reached" -eq 0 ]; then mark="x"; DEAD=$((DEAD+1))
  elif [ "$unreached" -gt 0 ]; then mark="!"; GAPS=$((GAPS+1)); fi
  printf '%s %-21s%s\n' "$mark" "$id" "$row"
done

# --- the judgment half, reported and never scored ------------------------------------
_JN="$(printf '%s\n' "$JUDG_IDS" | sed '/^$/d' | sort -u | grep -c . || true)"
if [ "${_JN:-0}" -gt 0 ]; then
  echo
  echo "  ── judgment steps · walked by a session, not by any box ──"
  printf '  %-21s' "step"
  for b in $BOXES; do printf '%-14s' "$b"; done
  printf '\n'
  for id in $(printf '%s\n' "$JUDG_IDS" | sed '/^$/d' | sort -u); do
    row=""
    for f in $FILES; do
      s2="$(awk -F'\t' -v i="$id" '!/^#/ && $1==i { print $2; exit }' "$f")"
      [ -n "$s2" ] || s2="ABSENT"
      row="$row$(printf '%-14s' "$s2")"
    done
    printf '  %-21s%s\n' "$id" "$row"
  done
  echo "  (UNWITNESSED is not a gap and not a red. It is the gate saying out loud that"
  echo "   nothing recorded whether a prose step happened -- a fact it could not state"
  echo "   at all before roll-call v1.2. It does not enter the exit code below.)"
fi

echo
echo "  ── the answer ──"
if [ "$GAPS" -eq 0 ] && [ "$DEAD" -eq 0 ]; then
  echo "  ZERO coverage gaps: every declared check was REACHED on every box compared."
  echo "  Any difference above is a difference of VERDICT (a platform n/a, a routing fact, a"
  echo "  real red) — not of coverage. That distinction is the whole point of the sidecar:"
  echo "  gate output could not draw it, and reading it off gate output inverted the answer."
else
  [ "$GAPS" -gt 0 ] && echo "  ! $GAPS check(s) reached on some boxes and NOT on others — a genuine coverage gap."
  [ "$DEAD" -gt 0 ] && echo "  x $DEAD check(s) reached on NO box — declared and never running anywhere."
  echo "  A gap is a routing question first (does that box hold the subject?) and a bug second."
fi
[ "$GAPS" -eq 0 ] && [ "$DEAD" -eq 0 ] || exit 1
exit 0
