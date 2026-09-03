#!/usr/bin/env bash
# verdict-contract-census-drill.sh — prove the census can still go red, and prove it is
# reading what it claims to read.
#
# WHY (smBacklog-9, 2026-09-03, card 1218126670100000): this census exists because seven
# instruments in two sessions lied in the flattering direction. A census built to catch
# that, which itself has never been seen to go red, would be lying instrument number
# eight -- and it would be the funniest one, so it gets a drill on day one.
#
# The fixtures below are synthetic and live in a private mktemp -d, NOT a shared /tmp
# path: smBacklog-7's roster drill accused roster of 3-12 failures because two concurrent
# runs on a SHARED scratch db wiped each other's fixtures. Scope before you assert.
set -o pipefail
C="$HOME/code/darwin-mac-ops/verdict-contract-census.sh"
pass=0; fail=0; fired=""
chk () { # name expected actual
  if [ "$2" = "$3" ]; then echo "  PASS  $1 (exit $3)"; pass=$((pass+1))
  else echo "  FAIL  $1 -- expected exit $2, got $3"; fail=$((fail+1)); fi
  case ",$fired," in *",$3,"*) : ;; *) fired="${fired:+$fired,}$3" ;; esac
}
echo "=== verdict-contract census: branch reachability drill ==="
[ -f "$C" ] || { echo "  FAIL  census missing at $C"; exit 2; }

BOX="$(mktemp -d)"; trap 'rm -rf "$BOX"' EXIT
mk_subject () { # dir codes... ; writes subject.sh naming drill.sh
  d="$1"; shift; mkdir -p "$d"
  { echo '#!/usr/bin/env bash'
    echo '# @verdict-contract'
    for c in "$@"; do echo "# @verdict $c synthetic branch $c"; done
    echo "# @drill $d/drill.sh"
    echo 'exit 0'
  } > "$d/subject.sh"
}
mk_drill () { # dir exitcode fired-csv
  d="$1"; { echo '#!/usr/bin/env bash'
            echo "echo \"VERDICTS-EXERCISED: $3\""
            echo "exit $2"; } > "$d/drill.sh"
}

# --- 2 = CANNOT VERIFY: .sh files exist, but not one declares a contract ---------------
mkdir -p "$BOX/none"; printf '#!/usr/bin/env bash\nexit 3\n' > "$BOX/none/plain.sh"
VERDICT_CENSUS_ROOTS="$BOX/none" bash "$C" >/dev/null 2>&1
chk "CANNOT-VERIFY fires on an empty subject set" 2 $?

# --- 2 = CANNOT VERIFY: subjects found, drills deliberately not run --------------------
mk_subject "$BOX/ok" 0 20 21; mk_drill "$BOX/ok" 0 "0,20,21"
VERDICT_CENSUS_ROOTS="$BOX/ok" VERDICT_CENSUS_NO_RUN=1 bash "$C" >/dev/null 2>&1
chk "CANNOT-VERIFY fires when the drills are skipped" 2 $?

# --- 0 = PASS: every declared code was actually fired ----------------------------------
VERDICT_CENSUS_ROOTS="$BOX/ok" bash "$C" >/dev/null 2>&1
chk "PASS verdict fires" 0 $?

# --- 1 = FINDING: a declared code the drill never fired --------------------------------
mk_subject "$BOX/gap" 0 20 21; mk_drill "$BOX/gap" 0 "0,20"
VERDICT_CENSUS_ROOTS="$BOX/gap" bash "$C" >/dev/null 2>&1
chk "FINDING fires on an unfired declared code" 1 $?

# --- 1 = FINDING: the drill exists but never says which branches fired -----------------
mk_subject "$BOX/mute" 0 20; mkdir -p "$BOX/mute"
printf '#!/usr/bin/env bash\necho all good\nexit 0\n' > "$BOX/mute/drill.sh"
VERDICT_CENSUS_ROOTS="$BOX/mute" bash "$C" >/dev/null 2>&1
chk "FINDING fires on a silent drill (silence is not proof)" 1 $?

# --- 1 = FINDING: the drill itself failed ---------------------------------------------
mk_subject "$BOX/red" 0 20; mk_drill "$BOX/red" 1 "0,20"
VERDICT_CENSUS_ROOTS="$BOX/red" bash "$C" >/dev/null 2>&1
chk "FINDING fires when the drill fails its own checks" 1 $?

# --- 1 = FINDING: contract declared, no @drill named ----------------------------------
mkdir -p "$BOX/nodrill"
printf '#!/usr/bin/env bash\n# @verdict-contract\n# @verdict 0 fine\nexit 0\n' > "$BOX/nodrill/subject.sh"
VERDICT_CENSUS_ROOTS="$BOX/nodrill" bash "$C" >/dev/null 2>&1
chk "FINDING fires on a contract with no drill" 1 $?

# --- NEGATIVE CONTROL -----------------------------------------------------------------
# The pass above must come from the CODES matching, not merely from a VERDICTS-EXERCISED
# line being present. Same passing fixture, one extra declared code, nothing else changed:
# if this still exits 0, the census is reading the line's existence and not its contents,
# and every "proven" verdict in this estate would be worthless.
mk_subject "$BOX/ok" 0 20 21 22   # drill still fires only 0,20,21
VERDICT_CENSUS_ROOTS="$BOX/ok" bash "$C" >/dev/null 2>&1
chk "negative control: one extra declared code flips PASS to FINDING" 1 $?

# UNPROVEN BRANCH, NAMED OUT LOUD (the point of this whole lane is not to hide these):
# the census also carries a subject-count mismatch guard (exit 2 when it located more
# contracts than it examined). It was born from a real defect -- a drill inheriting the
# loop's stdin ate the rest of the subject list and the census said "1 of 1" -- but now
# that `</dev/null` closes the only known cause, no fixture here can produce it. It is
# defence-in-depth, not a proven verdict, and it is listed here rather than counted as
# one. Exit code 2 itself IS proven, twice, above.
echo "  ---- $pass passed, $fail failed ----"
echo "VERDICTS-EXERCISED: $fired"
[ "$fail" = "0" ]
