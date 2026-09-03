#!/usr/bin/env bash
# verdict-contract-census.sh — a verdict you have never seen FIRE is not a verdict.
#
# WHY THIS EXISTS (2026-09-03, smBacklog-9, card 1218126670100000)
# Two sessions produced SEVEN lying instruments. Every one failed in the FLATTERING
# direction: it agreed with what the session already believed, or it produced a
# confident-looking null nobody argues with. The worst of them, flowers-sms-sender-
# watch.sh v1, shipped a PASS branch that was structurally UNREACHABLE -- its positive
# control grepped a string absent from the route it guards. It sat in front of a proven
# security fix for a session and a half and READ AS CAUTION the whole time.
#
# This census enforces rule A of that card, and only rule A, mechanically:
#   a script that gates a decision declares its exit-code contract, and a drill
#   PROVES, BY RUNNING, that every declared code can actually fire.
#
# HOW IT AVOIDS BEING LYING INSTRUMENT NUMBER EIGHT
# 1. The load-bearing claim is NOT a grep. Greps cannot see `exit "$rc"` -- measured:
#    grepping ~/repos + ~/code found exactly ONE of flowers-sms-sender-watch.sh's three
#    exit codes (it declares 0/20/21; the grep saw "3", from an unrelated line). A
#    pattern that misses the thing it is looking for is indistinguishable from absence.
#    So the census RUNS each drill and reads a line the drill prints only after the
#    branch actually executed:  VERDICTS-EXERCISED: 0,20,21
# 2. It fails CLOSED on an empty subject set. Zero declared contracts exits 2, not 0 --
#    an opt-in census with no subjects is a green light for a room nobody entered.
# 3. It fails CLOSED when drills are skipped. VERDICT_CENSUS_NO_RUN=1 exits 2, loudly.
# 4. The undeclared backlog it prints is stated as a FLOOR, with the reason the true
#    number is higher, because a window (or a count) is a claim about what was
#    OBSERVABLE, not about what is there.
#
# DECLARING A CONTRACT — put this in the script's header (first 80 lines):
#   # @verdict-contract
#   # @verdict 0   every send used a pinned number
#   # @verdict 20  nothing observed in the window
#   # @verdict 21  a send used a non-pinned number
#   # @drill ~/repos/flowers/scripts/flowers-sms-sender-watch-drill.sh
# and make the drill print, once, after its checks:
#   VERDICTS-EXERCISED: 0,20,21
#
# EXIT CODES (this script's own contract):
# @verdict-contract
# @verdict 0  every declared contract is proven by a drill that fired every code
# @verdict 1  a finding: missing/failing drill, or a declared code never fired
# @verdict 2  CANNOT VERIFY: zero subjects, or drills were not run
# @drill ~/code/darwin-mac-ops/verdict-contract-census-drill.sh
# bash 3.2 (stock macOS, 3.2.57) is the only bash on darwin: NO mapfile/readarray, and
# `set -u` explodes on an empty array expansion. name-drift-check.sh learned this first.
set -o pipefail

ROOTS="${VERDICT_CENSUS_ROOTS:-$HOME/Scripts $HOME/repos $HOME/code}"
NO_RUN="${VERDICT_CENSUS_NO_RUN:-0}"
findings=0; subjects=0; proven=0

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
for r in $ROOTS; do
  [ -d "$r" ] || continue
  find "$r" -maxdepth 5 -type f -name '*.sh' \
    ! -name '*.bak*' ! -path '*/node_modules/*' ! -path '*/.git/*' 2>/dev/null >> "$WORK/all"
done
touch "$WORK/all" "$WORK/declared"
nall=$(wc -l < "$WORK/all" | tr -d ' ')
if [ "$nall" -eq 0 ]; then
  echo "  CANNOT VERIFY: the file enumeration returned ZERO .sh files under: $ROOTS"
  echo "  A census of nothing is not a pass."
  exit 2
fi

while IFS= read -r f; do
  head -n 80 "$f" 2>/dev/null | grep -q '^# @verdict-contract' && echo "$f" >> "$WORK/declared"
done < "$WORK/all"
ndec=$(wc -l < "$WORK/declared" | tr -d ' ')

if [ "$ndec" -eq 0 ]; then
  echo "  CANNOT VERIFY: ZERO scripts declare a verdict contract."
  echo "  This census is opt-in, so an empty subject set is not cleanliness -- it is an"
  echo "  unentered room. Declare one (see the header of this file) or retire the gate."
  exit 2
fi

# ---- pass 2: each subject's drill must FIRE every declared code -----------------------
while IFS= read -r f; do
  subjects=$((subjects+1))
  short="${f/#$HOME/~}"
  hdr="$(head -n 80 "$f")"
  codes="$(printf '%s\n' "$hdr" | sed -n 's/^# @verdict[[:space:]]\{1,\}\([0-9]\{1,\}\).*/\1/p' | sort -un | tr '\n' ',' | sed 's/,$//')"
  drill="$(printf '%s\n' "$hdr" | sed -n 's|^# @drill[[:space:]]\{1,\}||p' | head -1)"
  drill="${drill/#\~/$HOME}"

  if [ -z "$codes" ]; then
    echo "  FINDING  $short -- declares @verdict-contract but names NO @verdict codes" >> "$WORK/report"
    findings=$((findings+1)); continue
  fi
  if [ -z "$drill" ]; then
    echo "  FINDING  $short -- declares codes ($codes) but names no @drill. An unproven verdict is a claim, not a control." >> "$WORK/report"
    findings=$((findings+1)); continue
  fi
  if [ ! -f "$drill" ]; then
    echo "  FINDING  $short -- @drill ${drill/#$HOME/~} does not exist" >> "$WORK/report"
    findings=$((findings+1)); continue
  fi
  if [ "$NO_RUN" = "1" ]; then continue; fi

  # </dev/null is LOAD-BEARING, not tidiness: without it the drill inherits this loop's
  # stdin and swallows the rest of "$WORK/declared". Measured 2026-09-03: 2 declared
  # contracts, census reported "1 of 1" -- a silently truncated subject list reporting a
  # clean, confident, completely wrong total. The census-of-lying-instruments was, for
  # about four minutes, a lying instrument.
  out="$(bash "$drill" </dev/null 2>&1)"; drc=$?
  fired="$(printf '%s\n' "$out" | sed -n 's/^VERDICTS-EXERCISED:[[:space:]]*//p' | tail -1 | tr -d ' ')"
  if [ -z "$fired" ]; then
    echo "  FINDING  $short -- its drill ran (exit $drc) but printed no 'VERDICTS-EXERCISED:' line, so NOTHING is known about which branches fired. Silence is not proof." >> "$WORK/report"
    findings=$((findings+1)); continue
  fi
  if [ "$drc" != "0" ]; then
    echo "  FINDING  $short -- its drill FAILED (exit $drc). A control that fails its own checks is decorative, and decorative is indistinguishable from passing." >> "$WORK/report"
    findings=$((findings+1)); continue
  fi
  missing=""
  for c in ${codes//,/ }; do
    case ",$fired," in *",$c,"*) : ;; *) missing="$missing $c" ;; esac
  done
  if [ -n "$missing" ]; then
    echo "  FINDING  $short -- declared code(s)$missing were NEVER FIRED by ${drill/#$HOME/~} (it exercised: $fired). This is exactly the sender-watch v1 defect: a branch that has never run is not a verdict." >> "$WORK/report"
    findings=$((findings+1)); continue
  fi
  proven=$((proven+1))
done < "$WORK/declared"
# NOTE: the loop above must NOT be a pipeline -- a `... | while` subshell would discard
# every counter it increments and this census would report 0 findings, forever, quietly.

# ---- the undeclared backlog, stated as a FLOOR ---------------------------------------
undeclared=0
while IFS= read -r f; do
  head -n 80 "$f" 2>/dev/null | grep -q '^# @verdict-contract' && continue
  mx="$(grep -oE '(^|[[:space:];&|(])exit[[:space:]]+[0-9]+' "$f" 2>/dev/null | grep -oE '[0-9]+$' | sort -un | tail -1)"
  [ -n "$mx" ] && [ "$mx" -ge 2 ] 2>/dev/null && undeclared=$((undeclared+1))
done < "$WORK/all"

if [ "$NO_RUN" = "1" ]; then
  echo "  CANNOT VERIFY: VERDICT_CENSUS_NO_RUN=1 -- $ndec contract(s) were located but NO drill was run,"
  echo "  so not one branch was proven reachable. Skipping the run is the whole failure this census exists to catch."
  exit 2
fi

if [ "$findings" -gt 0 ]; then
  cat "$WORK/report"
  echo "  ---- $proven of $subjects declared contract(s) proven; $findings finding(s)"
  echo "  FLOOR: $undeclared further script(s) carry an exit code >=2 and declare nothing."
  echo "  Read that as a FLOOR, not a total: this detector cannot see \`exit \"\$rc\"\` or"
  echo "  \`exit \$code\`, which is how the proven subject here writes 2 of its 3 exits."
  exit 1
fi

if [ "$subjects" != "$ndec" ]; then
  echo "  CANNOT VERIFY: $ndec contract(s) were located but only $subjects were examined --"
  echo "  the subject loop was truncated. A partial census that reports a confident total is"
  echo "  precisely the failure this file exists to catch. Refusing to call it a pass."
  exit 2
fi
echo "  $proven of $subjects declared verdict contract(s) proven by a drill that FIRED every code."
echo "  FLOOR: $undeclared undeclared script(s) carry an exit code >=2 (a floor -- \`exit \$var\` is invisible here)."
exit 0
