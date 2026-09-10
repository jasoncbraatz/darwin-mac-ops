#!/usr/bin/env bash
# handoff-dod-check.sh — every handoff declares a DoD, and an ERRAND claim is FALSIFIABLE.
#
#   handoff-dod-check.sh --handoff PATH [--errand-declared 0|1] [--dir DIR]
#   handoff-dod-check.sh --handoff PATH --since 2026-09-10   # sweep: skip pre-rule docs
#   handoff-dod-check.sh --static            # prove the verdicts with no files on disk
#
# @verdict-contract
#   0  OK            a DoD line is present, substantive, and consistent with the session
#   1  FAIL          missing, vacuous, falsified, or contradicting the session's own declaration
#   2  CANNOT VERIFY the handoff could not be read (never a pass, never a FAIL)
#
# WHY THIS EXISTS (ADR-handoff-dod-is-required-and-errand-is-a-claim.md)
#   "No DoD" and "forgot the DoD" are indistinguishable from outside, so ABSENCE cannot be
#   how an errand says it is an errand. Jason, 2026-09-10, on why this is not paranoia:
#   the estate intermixes model tiers, and "it's pretty absolute on an errand, but a
#   lighter model may drift."
#
#   His first instinct was a free-text placeholder ("DoD: Just this task"). That was
#   argued down and the reason is the whole design: A PLACEHOLDER IS CHEAPER TO TYPE
#   THAN THE REAL THING, so it becomes the path of least resistance for exactly the
#   lighter model it was meant to catch -- converting a catchable red (missing) into an
#   uncatchable green (present but vacuous). The estate has been bitten by that shape
#   twice already: `needs-design` was retired for being "a question you didn't ask", and
#   on NVRC2-8866 a `Card Fee Waived` attribute naming who/why/when collapsed to the
#   single word `Yes` -- order still right, audit reason gone.
#
#   So the errand form is a CLAIM, not a shrug: "no successor session". A lighter model
#   can still stamp it on real project work -- but that is now a LIE THIS SCRIPT CAN
#   CATCH, because a successor handoff appearing on disk falsifies it. A grep for a
#   placeholder catches nothing; this catches the case the rule exists for.
#
#   And the vocabulary is deliberately NOT new. The estate already had two accepted
#   spellings of "this is an errand" -- ROSTER_FOUNDING_CHECK=0 and GATE_UNCHARTERED --
#   and the bug fixed at 09:36 on the very day this was written was those two spellings
#   not matching. A third way to say the same thing would have rebuilt that bug
#   somewhere new, so --errand-declared is fed FROM the existing predicate rather than
#   from a token anyone types.
set -uo pipefail

HANDOFF=""; DIR=""; DECLARED=""; STATIC=0; SINCE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --handoff) HANDOFF="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    --errand-declared) DECLARED="${2:-}"; shift 2 ;;
    --since) SINCE="${2:-}"; shift 2 ;;
    --static) STATIC=1; shift ;;
    -h|--help) sed -n '2,45p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# The DoD line. Front-loaded on purpose: a definition of done buried on page three is a
# document nobody aimed at. 40 lines is the same window brief-check.sh uses for its stamp.
HEAD_LINES=40
# An ERRAND claim must carry a sentence saying WHAT was finished. This number is the
# anti-placeholder guard and nothing more: "DoD: ERRAND" alone is 12 characters and
# "DoD: ERRAND -- no successor session." is 36, so the floor sits above the shrug and
# below any honest sentence. It is not a quality judgement -- G-AN owns that.
ERRAND_MIN_CHARS=60

verdict() { printf '%s\n' "$2"; exit "$1"; }

# ---- the classifier, extracted so --static can exercise it with no files -------------
# Returns: MISSING | ERRAND | ERRAND_VACUOUS | PROJECT
classify() {   # classify <the DoD line, or empty>
  local line="$1"
  [ -n "$line" ] || { printf 'MISSING'; return; }
  case "$line" in
    *ERRAND*)
      if [ "${#line}" -lt "$ERRAND_MIN_CHARS" ]; then printf 'ERRAND_VACUOUS'
      else printf 'ERRAND'; fi ;;
    *) printf 'PROJECT' ;;
  esac
}

dod_line() {   # dod_line <file> -> the first DoD line in the head window, or empty
  head -n "$HEAD_LINES" "$1" 2>/dev/null \
    | grep -m1 -E '^[^A-Za-z0-9]{0,4}DoD:' \
    | sed -E 's/^[^A-Za-z0-9]{0,4}//' \
    | tr -d '\r'
}

# A successor is what falsifies an ERRAND claim. Padded and bare spellings both count --
# HANDOFF-foo-02.md and HANDOFF-foo-2.md are the same successor, and only checking one
# spelling is how a guard passes a case it was built to catch.
successor_of() {   # successor_of <dir> <project> <n-as-written> -> path, or empty
  local d="$1" proj="$2" n="$3" dec cand
  dec=$((10#$n)) 2>/dev/null || return 0
  for cand in "$(printf "%0${#n}d" "$((dec+1))")" "$((dec+1))"; do
    [ -f "$d/HANDOFF-$proj-$cand.md" ] && { printf '%s' "$d/HANDOFF-$proj-$cand.md"; return 0; }
  done
  return 0
}

# ---- --static: prove every verdict WITHOUT touching the filesystem -------------------
# The house rule this obeys: a guard that cannot fire is a decoration, and one that cannot
# fire QUIETLY is a decoration that lies. These are the classifier's own controls; the
# drill covers the file-and-successor half.
if [ "$STATIC" = "1" ]; then
  fail=0
  ck() { # ck <name> <expected> <line>
    local got; got="$(classify "$3")"
    if [ "$got" = "$2" ]; then echo "PASS: $1"
    else echo "FAIL: $1 -- wanted $2, got $got"; fail=1; fi
  }
  ck "an absent line is MISSING"            MISSING        ""
  ck "a real project DoD is PROJECT"        PROJECT        "DoD: the census exits 0 on both stores and a fresh order stays clean."
  ck "a substantive errand claim is ERRAND" ERRAND         "DoD: ERRAND -- no successor session. Order NVRC2-8946 entered, card run, shredded."
  ck "the bare token is VACUOUS"            ERRAND_VACUOUS "DoD: ERRAND"
  # THE CONTROL THAT MATTERS: Jason's original placeholder must NOT read as a valid errand.
  # If this ever passes as ERRAND, the guard has become the thing it was built to refuse.
  ck "the rejected placeholder is not a valid errand" PROJECT "DoD: Just this task"
  [ "$fail" = 0 ] && { echo "ALL STATIC CONTROLS PASS"; exit 0; } || { echo "STATIC CONTROLS FAILED"; exit 1; }
fi

# ---- live ---------------------------------------------------------------------------
[ -n "$HANDOFF" ] || verdict 2 "CANNOT VERIFY: no --handoff given"
[ -r "$HANDOFF" ] || verdict 2 "CANNOT VERIFY: cannot read $HANDOFF"

# -- THE GRANDFATHER CLAUSE (measured 2026-09-10, and it is the whole reason this exists)
# 196 of the 197 handoffs in the everything folder carry NO DoD line in the head window.
# 80 of them DO discuss a definition of done further down -- so the concept was never
# absent from the estate, only from a slot a machine could find. Those documents predate
# the rule and are not in violation of it.
#
# The GATE needs none of this: G-AQ only ever grades the handoff THIS session just wrote,
# so its scope is forward by construction. --since exists for the estate-wide SWEEP, which
# without it would open with 196 red lines on day one -- and a wall of permanent reds
# trains readers to scroll, which is how the genuinely-broken checks sitting in the same
# block go unread (gate-selfcheck's own G-AP-340 wallpaper finding). Pass the date the
# practice started; anything older is skipped, not excused.
if [ -n "$SINCE" ]; then
  _sd="$(date -j -f %Y-%m-%d "$SINCE" +%s 2>/dev/null || date -d "$SINCE" +%s 2>/dev/null)"
  # portable stat, GNU FIRST: on Linux `stat -f` means --file-system and returns a REPORT,
  # so the reversed order never fails over -- the caller silently gets a blob for a number.
  _hm="$(stat -c %Y "$HANDOFF" 2>/dev/null || stat -f %m "$HANDOFF" 2>/dev/null)"
  case "$_sd$_hm" in
    ''|*[!0-9]*) : ;;   # a date we could not parse is not a licence to skip -- fall through and grade
    *) [ "$_hm" -lt "$_sd" ] && verdict 0 "G-AQ#dod n/a -- $(basename "$HANDOFF") predates the rule ($SINCE)" ;;
  esac
fi

BASE="$(basename "$HANDOFF")"
[ -n "$DIR" ] || DIR="$(dirname "$HANDOFF")"
LINE="$(dod_line "$HANDOFF")"
KIND="$(classify "$LINE")"

case "$KIND" in
  MISSING)
    verdict 1 "G-AQ#dod: $BASE carries NO 'DoD:' line in its first $HEAD_LINES lines. Absence cannot mean 'errand' -- that is indistinguishable from a session that simply forgot, which is the whole reason this check exists. Add ONE line near the top: a project DoD someone could mark right or wrong, or 'DoD: ERRAND -- no successor session. <what was finished>.'" ;;
  ERRAND_VACUOUS)
    verdict 1 "G-AQ#dod: $BASE declares ERRAND but says nothing ('$LINE'). An errand's DoD is a CLAIM that no successor follows, and a claim has to say what was finished to be worth checking. A bare token is the placeholder this rule was written to refuse." ;;
esac

# The session's own declaration must agree with the document. Disagreement in either
# direction is a real finding, not a formatting nit: a project that quietly calls itself
# an errand escapes the charter board, and an errand carrying a project DoD invents a
# successor that will never come.
if [ -n "$DECLARED" ]; then
  if [ "$DECLARED" = "1" ] && [ "$KIND" = "PROJECT" ]; then
    verdict 1 "G-AQ#dod: this session declared an ERRAND at roster join (ROSTER_FOUNDING_CHECK=0 / GATE_UNCHARTERED) but $BASE carries a PROJECT DoD. One of the two is wrong, and the gate cannot tell which. Line: '$LINE'"
  fi
  if [ "$DECLARED" = "0" ] && [ "$KIND" = "ERRAND" ]; then
    verdict 1 "G-AQ#dod: $BASE declares ERRAND but this session did NOT declare one at roster join. An errand is asserted in BOTH places or in neither -- otherwise the charter board and the handoff disagree about whether anyone is coming back."
  fi
fi

# The falsifiable half. Only an ERRAND makes a claim about the future, so only an ERRAND
# can be caught lying.
if [ "$KIND" = "ERRAND" ]; then
  PROJ="$(printf '%s' "$BASE" | sed -E 's/^HANDOFF-(.+)-([0-9]+)[a-z]?\.md$/\1/')"
  N="$(printf '%s' "$BASE" | sed -E 's/^HANDOFF-(.+)-([0-9]+)[a-z]?\.md$/\2/')"
  case "$N" in
    ''|*[!0-9]*) : ;;   # unnumbered handoff: nothing to falsify against, and that is not a fault
    *)
      SUCC="$(successor_of "$DIR" "$PROJ" "$N")"
      [ -n "$SUCC" ] && verdict 1 "G-AQ#dod: $BASE claims ERRAND -- no successor session -- and $(basename "$SUCC") EXISTS. The claim is false on its face. Either that handoff is the successor (so this was never an errand: give it a real DoD), or it is unrelated work that reused the slug (rename it -- a slug collision makes both boards unreadable)."
      ;;
  esac
fi

verdict 0 "G-AQ#dod OK -- $BASE: $KIND"
