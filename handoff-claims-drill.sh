#!/usr/bin/env bash
# =============================================================================
# handoff-claims-drill.sh -- the RED-PROOF for G-AR's engine, handoff-claims.py.
# -----------------------------------------------------------------------------
# A guard nobody has watched fail is a claim, not a control (G-AP). This drill runs
# handoff-claims.py against fixture handoffs it writes itself, one per verdict, and
# asserts BOTH the tag and the exit code. Then it does the thing wealthTensor-95 paid
# for: it asserts that EVERY key in the engine's CLAIM_TAGS was actually emitted by
# some probe. A verdict added without a probe therefore goes red BY CONSTRUCTION,
# rather than by somebody remembering to add one.
#
# DRILL-SCRATCH: read-only -- every fixture is written under a mktemp -d scratch root
# that is removed on exit; nothing outside it is created, edited or deleted, and the
# destructive fixtures (`rm -rf`, `git push`, `sed -i`) are REFUSED STATICALLY and are
# never executed by construction, which is the property under test.
#
# bash 3.2 (stock macOS) is the floor: NO associative arrays, NO mapfile/readarray.
#
# @verdict-contract
# @verdict 0  every probe produced its expected tag and exit code, and every declared
#             tag in CLAIM_TAGS was exercised
# @verdict 1  a probe did not produce what it declared, or a tag has no probe
# @drill ~/code/darwin-mac-ops/handoff-claims-drill.sh
# =============================================================================
set -uo pipefail

ENGINE="${HANDOFF_CLAIMS_ENGINE:-$(dirname "$0")/handoff-claims.py}"
[ -f "$ENGINE" ] || { echo "FAIL: engine not found at $ENGINE"; exit 1; }

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/handoff-claims-drill.XXXXXX")" || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
ALL="$SCRATCH/all-output.txt"; : > "$ALL"

pass=0; fail=0; n=0

# fixture <name> <body...>  -- writes $SCRATCH/<name>.md from stdin
fixture() { cat > "$SCRATCH/$1.md"; }

# probe <label> <fixture> <expected-exit> <expected-substring> [extra args...]
probe() {
  local label="$1" fx="$2" want_rc="$3" want_s="$4"; shift 4
  local out rc
  out="$(python3 "$ENGINE" --handoff "$SCRATCH/$fx.md" "$@" 2>&1)"; rc=$?
  printf '%s\n' "$out" >> "$ALL"
  n=$((n+1))
  if [ "$rc" != "$want_rc" ]; then
    echo "  FAIL  #$n $label -- exit $rc, expected $want_rc"
    printf '%s\n' "$out" | sed 's/^/          /'
    fail=$((fail+1)); return
  fi
  case "$out" in
    *"$want_s"*) echo "  ok    #$n $label ($want_s, exit $rc)"; pass=$((pass+1)) ;;
    *) echo "  FAIL  #$n $label -- exit $rc ok but never said '$want_s'"
       printf '%s\n' "$out" | sed 's/^/          /'
       fail=$((fail+1)) ;;
  esac
}

echo "=== handoff-claims-drill: red-proof for G-AR ==="

# -- a claim that agrees ------------------------------------------------------ exit 0
fixture ok <<'EOF'
# HANDOFF-fixture-01
```claims
  - id: truth
    cmd: true
    rc: 0
```
EOF
probe "a true claim re-runs and agrees" ok 0 "OK"

# -- no registry at all: green, with the obligation printed -------------------- exit 0
fixture none <<'EOF'
# HANDOFF-fixture-02
Nothing is claimed here, and rc 127 appears only as narrative prose.
EOF
probe "no registry is n/a, not a red" none 0 "declares no \`claims:\` registry"

# -- a claim that disagrees every time ---------------------------------------- exit 1
fixture false <<'EOF'
# HANDOFF-fixture-03
```claims
  - id: liar
    cmd: false
    rc: 0
```
EOF
probe "a false claim is caught" false 1 "FALSE-CLAIM"

# -- a flaky check is NOT a caught liar --------------------------------------- exit 2
cat > "$SCRATCH/flaky.sh" <<'EOF'
#!/bin/bash
C="$(dirname "$0")/flaky.count"
if [ ! -f "$C" ]; then echo 1 > "$C"; exit 1; fi
exit 0
EOF
chmod +x "$SCRATCH/flaky.sh"
fixture flaky <<EOF
# HANDOFF-fixture-04
\`\`\`claims
  - id: flake
    cmd: bash $SCRATCH/flaky.sh
    rc: 0
\`\`\`
EOF
probe "one red then green is FLAKY, not a liar" flaky 2 "FLAKY"

# -- a slow claim not run is not a pass --------------------------------------- exit 2
fixture slow <<'EOF'
# HANDOFF-fixture-05
```claims
  - id: sweep
    cmd: true
    rc: 0
    slow: true
    note: the long one
```
EOF
probe "an un-run slow claim is CANNOT VERIFY" slow 2 "SKIPPED-SLOW"
probe "--claims-all runs it and it agrees" slow 0 "OK" --claims-all

# -- the parser refuses what it cannot read ----------------------------------- exit 1
fixture parse <<'EOF'
# HANDOFF-fixture-06
```claims
  - id: a
    cmd: true
    rc: 0
      this line is not a key
```
EOF
probe "an unparseable line is refused, not skipped" parse 1 "PARSE-REFUSED"

fixture missing <<'EOF'
# HANDOFF-fixture-07
```claims
  - id: norc
    cmd: true
```
EOF
probe "a claim with no rc is refused" missing 1 "MISSING-FIELD"

fixture unknown <<'EOF'
# HANDOFF-fixture-08
```claims
  - id: a
    cmd: true
    rc: 0
    wat: nope
```
EOF
probe "an unknown key is refused" unknown 1 "UNKNOWN-FIELD"

fixture dupe <<'EOF'
# HANDOFF-fixture-09
```claims
  - id: same
    cmd: true
    rc: 0
  - id: same
    cmd: true
    rc: 0
```
EOF
probe "two claims with one id are refused" dupe 1 "DUPLICATE-ID"

fixture badint <<'EOF'
# HANDOFF-fixture-10
```claims
  - id: a
    cmd: true
    rc: zero
```
EOF
probe "a non-integer rc is refused" badint 1 "BAD-INT"

fixture badbool <<'EOF'
# HANDOFF-fixture-11
```claims
  - id: a
    cmd: true
    rc: 0
    slow: maybe
```
EOF
probe "a non-boolean slow is refused" badbool 1 "BAD-BOOL"

fixture badre <<'EOF'
# HANDOFF-fixture-12
```claims
  - id: a
    cmd: true
    rc: 0
    count: 1
    count_re: ([0-9]+
```
EOF
probe "an uncompilable count_re is refused" badre 1 "BAD-COUNT-RE"

fixture nocount <<'EOF'
# HANDOFF-fixture-13
```claims
  - id: a
    cmd: true
    rc: 0
    count: 7
    count_re: ([0-9]+) widgets
```
EOF
probe "a count whose regex matches nothing is unverifiable" nocount 1 "COUNT-NOT-FOUND"

# -- the timeout verdict, made provable in a second --------------------------- exit 1
fixture slowcmd <<'EOF'
# HANDOFF-fixture-14
```claims
  - id: wedged
    cmd: sleep 30
    rc: 0
```
EOF
out="$(HANDOFF_CLAIM_TIMEOUT=1 python3 "$ENGINE" --handoff "$SCRATCH/slowcmd.md" 2>&1)"; rc=$?
printf '%s\n' "$out" >> "$ALL"; n=$((n+1))
case "$out:$rc" in
  *TIMEOUT*:2) echo "  ok    #$n a wedged claim TIMEOUTs -> CANNOT VERIFY, never FALSE-CLAIM (exit $rc)"; pass=$((pass+1)) ;;
  *TIMEOUT*)   echo "  FAIL  #$n a wedged claim timed out but exited $rc, not 2 -- that ACCUSES an honest predecessor of a lie about a command that merely wedged"; fail=$((fail+1)) ;;
  *)           echo "  FAIL  #$n a wedged claim did not time out (exit $rc)"; fail=$((fail+1)) ;;
esac

# -- THE REFUSAL LIST. Nothing below is ever executed; that is the point. ------ exit 1
fixture piped <<'EOF'
# HANDOFF-fixture-15
```claims
  - id: p
    cmd: true | head -1
    rc: 0
```
EOF
probe "a piped claim is refused (the -93 defect)" piped 1 "PIPED-CLAIM"

fixture destructive <<'EOF'
# HANDOFF-fixture-16
```claims
  - id: nope
    cmd: rm -rf /tmp/handoff-claims-drill-should-never-exist
    rc: 0
```
EOF
probe "a destructive program is refused, never run" destructive 1 "REFUSED-PROGRAM"

fixture gitpush <<'EOF'
# HANDOFF-fixture-17
```claims
  - id: nope
    cmd: git -C /tmp push origin main
    rc: 0
```
EOF
probe "a mutating git subcommand is refused" gitpush 1 "git push"

fixture sedi <<'EOF'
# HANDOFF-fixture-18
```claims
  - id: nope
    cmd: sed -i s/a/b/ /etc/hosts
    rc: 0
```
EOF
probe "an in-place edit flag is refused" sedi 1 "REFUSED-ARG"

# NEGATIVE CONTROL for the flag denylist: `grep -i` is the SAME flag and must NOT be
# refused. A denylist that cries wolf is a denylist somebody switches off, and this is
# the probe that would have caught the blanket `-i` the first draft of the engine had.
fixture grepi <<'EOF'
# HANDOFF-fixture-19
```claims
  - id: casefold
    cmd: grep -i -q claims /dev/null
    rc: 1
```
EOF
probe "NEGATIVE CONTROL: grep -i is NOT refused" grepi 0 "OK"

longcmd="true $(python3 -c 'print("x"*420)')"
fixture toolong <<EOF
# HANDOFF-fixture-20
\`\`\`claims
  - id: novella
    cmd: $longcmd
    rc: 0
\`\`\`
EOF
probe "a 400+ char claim is a script, not a claim" toolong 1 "TOO-LONG"

# -- the advisory half: piped verify: lines ------------------------------------ exit 0
fixture advisory <<'EOF'
# HANDOFF-fixture-21
- a carried thread.
  verify: `python3 ~/Scripts/card-lint.py --ratchet | tail -1` -> RATCHET OK
- another one.
  verify: the card is OPEN.
```claims
  - id: truth
    cmd: true
    rc: 0
```
EOF
probe "a piped verify: line is named as an ADVISORY" advisory 0 "PIPED-VERIFY"

# and its negative twin: prose verify: lines must NOT be reported as commands
out="$(python3 "$ENGINE" --handoff "$SCRATCH/advisory.md" 2>&1)"
printf '%s\n' "$out" >> "$ALL"; n=$((n+1))
if printf '%s' "$out" | grep -q "the card is OPEN"; then
  echo "  FAIL  #$n NEGATIVE CONTROL: a prose verify: line was read as a command"; fail=$((fail+1))
else
  echo "  ok    #$n NEGATIVE CONTROL: a prose verify: line is not read as a command"; pass=$((pass+1))
fi

# -- front matter is the OTHER accepted shape, same parser --------------------- exit 0
fixture frontmatter <<'EOF'
---
phase: fixture
claims:
  - id: truth
    cmd: true
    rc: 0
---
# HANDOFF-fixture-22
EOF
probe "a YAML front-matter registry parses with the same grammar" frontmatter 0 "front matter"

# -- --static refuses without executing ---------------------------------------- exit 1
probe "--static refuses a destructive claim with nothing run" destructive 1 "REFUSED-PROGRAM" --static
probe "--static passes a good registry without running it" ok 0 "Nothing was executed" --static

# -- UNREGISTERED-TAG: the emission path is the enforcement point ---------------
n=$((n+1))
utag="$(python3 - "$ENGINE" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("hc", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m._tag("NOT-A-REAL-TAG", "probe"))
PY
)"
printf '%s\n' "$utag" >> "$ALL"
case "$utag" in
  UNREGISTERED-TAG*) echo "  ok    #$n an undeclared tag cannot escape _tag()"; pass=$((pass+1)) ;;
  *) echo "  FAIL  #$n _tag() let an undeclared tag through: $utag"; fail=$((fail+1)) ;;
esac

# -- COVERAGE: every declared tag was exercised by some probe -------------------
echo "--- coverage: every key in CLAIM_TAGS must have been emitted ---"
cov="$(python3 - "$ENGINE" "$ALL" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("hc", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
seen = open(sys.argv[2], encoding="utf-8", errors="replace").read()
missing = [t for t in m.CLAIM_TAGS if t not in seen]
print("TAGS %d MISSING %d %s" % (len(m.CLAIM_TAGS), len(missing), ",".join(missing)))
PY
)"
echo "  $cov"
n=$((n+1))
case "$cov" in
  *"MISSING 0 "*) echo "  ok    #$n every declared verdict has a probe"; pass=$((pass+1)) ;;
  *) echo "  FAIL  #$n a declared verdict has NO probe -- add one here, or delete the tag"
     fail=$((fail+1)) ;;
esac

echo "VERDICTS-EXERCISED: 0,1,2"
echo "=== drill: $pass passed, $fail failed (of $n) ==="
[ "$fail" -eq 0 ] || exit 1
exit 0
