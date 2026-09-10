#!/usr/bin/env bash
# handoff-dod-drill.sh — prove handoff-dod-check.sh can actually FIRE, on real files.
#
# The static controls inside the check exercise its CLASSIFIER with no filesystem. This
# drill exercises the half that needs one: the successor lookup, the declaration
# cross-check, and the CANNOT-VERIFY path. Exit 0 = the guard behaves.
#
# Why a drill and not a grep for the function name: the estate has shipped a guard that
# was present and inert twice this month -- a `sed -E ":a;...;ta"` idiom BSD sed rejects
# (silent no-op, phoneorder-verify-span), and a PAN mask that lived at one print site
# while a second printer put the digits straight back. A presence-grep passes both.
# Feed every guard one real input and watch it fire.
set -uo pipefail
CHK="${1:-$HOME/code/darwin-mac-ops/handoff-dod-check.sh}"
[ -x "$CHK" ] || { echo "FAIL: no such check: $CHK"; exit 1; }

T="$(mktemp -d "${TMPDIR:-/tmp}/dodrill.XXXXXX")" || { echo "FAIL: mktemp"; exit 1; }
# mktemp -t NAME is BSD-only and GNU exits 1 without the X's, leaving the caller an EMPTY
# path -- which then rm -rf's the wrong thing. The X form is portable both ways.
trap 'rm -rf "$T"' EXIT
fail=0

mk() { printf '%s\n' "$2" > "$T/$1"; }
# every fixture needs body past the DoD line, or the head-window test proves nothing
body() { printf '\nsome prose\nmore prose\n' >> "$T/$1"; }

ck() { # ck <name> <want-rc> <args...>
  local name="$1" want="$2"; shift 2
  local out rc
  out="$("$CHK" "$@" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ]; then echo "PASS: $name"
  else echo "FAIL[$name]: wanted rc=$want, got rc=$rc"; echo "       $out"; fail=1; fi
}

# ---- the positive cases -------------------------------------------------------------
mk HANDOFF-alpha-01.md 'DoD: ERRAND -- no successor session. Entered one order and shredded the tape.'
body HANDOFF-alpha-01.md
ck "a substantive errand with no successor PASSES" 0 --handoff "$T/HANDOFF-alpha-01.md"

mk HANDOFF-beta-01.md 'DoD: the census exits 0 on both stores and a fresh order stays clean.'
body HANDOFF-beta-01.md
ck "a project DoD PASSES" 0 --handoff "$T/HANDOFF-beta-01.md"

# ---- NEGATIVE CONTROLS: each must FIRE ----------------------------------------------
mk HANDOFF-gamma-01.md 'This handoff forgot to say what done looks like.'
body HANDOFF-gamma-01.md
ck "NEGATIVE -- a missing DoD FAILS" 1 --handoff "$T/HANDOFF-gamma-01.md"

mk HANDOFF-delta-01.md 'DoD: ERRAND'
body HANDOFF-delta-01.md
ck "NEGATIVE -- a bare ERRAND token FAILS" 1 --handoff "$T/HANDOFF-delta-01.md"

# THE ONE THIS RULE EXISTS FOR: an errand claim falsified by a successor on disk.
mk HANDOFF-eps-01.md 'DoD: ERRAND -- no successor session. Nothing at all remains to pick up here.'
body HANDOFF-eps-01.md
mk HANDOFF-eps-02.md 'DoD: the successor that proves the claim above was a lie.'
body HANDOFF-eps-02.md
ck "NEGATIVE -- ERRAND with a PADDED successor FAILS" 1 --handoff "$T/HANDOFF-eps-01.md"

# the bare spelling of the same successor must catch it too; checking only one spelling
# is how a guard sails past the case it was built for
mk HANDOFF-zeta-01.md 'DoD: ERRAND -- no successor session. Nothing at all remains to pick up here.'
body HANDOFF-zeta-01.md
mk HANDOFF-zeta-2.md 'DoD: the bare-spelled successor.'
body HANDOFF-zeta-2.md
ck "NEGATIVE -- ERRAND with a BARE successor FAILS" 1 --handoff "$T/HANDOFF-zeta-01.md"

# declaration cross-check, both directions
mk HANDOFF-eta-01.md 'DoD: a real project criterion someone could mark right or wrong today.'
body HANDOFF-eta-01.md
ck "NEGATIVE -- session declared ERRAND, doc says PROJECT, FAILS" 1 \
   --handoff "$T/HANDOFF-eta-01.md" --errand-declared 1

mk HANDOFF-theta-01.md 'DoD: ERRAND -- no successor session. One errand, finished, nothing remains.'
body HANDOFF-theta-01.md
ck "NEGATIVE -- doc says ERRAND, session did NOT declare one, FAILS" 1 \
   --handoff "$T/HANDOFF-theta-01.md" --errand-declared 0

# JASON'S ORIGINAL PLACEHOLDER. It was argued down before shipping; this control is what
# stops it being reintroduced by a future session that finds it convenient. It reads as a
# PROJECT DoD, so on an errand-declared session it trips the mismatch -- which is exactly
# the outcome that makes the placeholder useless as an escape hatch.
mk HANDOFF-iota-01.md 'DoD: Just this task'
body HANDOFF-iota-01.md
ck "NEGATIVE -- the rejected placeholder does not buy an errand a pass" 1 \
   --handoff "$T/HANDOFF-iota-01.md" --errand-declared 1

# ---- CANNOT VERIFY is neither a pass nor a FAIL -------------------------------------
ck "an unreadable handoff is CANNOT VERIFY (2), not a pass" 2 --handoff "$T/nope-does-not-exist.md"
ck "no --handoff at all is CANNOT VERIFY (2)" 2

# ---- the check's own static controls must still hold --------------------------------
if "$CHK" --static >/dev/null 2>&1; then echo "PASS: the check's static controls still hold"
else echo "FAIL: the check's own --static controls are broken"; fail=1; fi

[ "$fail" = 0 ] && { echo "ALL TESTS PASS"; exit 0; } || { echo "SOME TESTS FAILED"; exit 1; }
