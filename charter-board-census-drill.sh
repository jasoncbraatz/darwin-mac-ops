#!/bin/bash
# charter-board-census-drill.sh — controls for charter-board-census.sh.
#
# Born smDrainHandoff-17 (2026-09-04), SM card 1217904193313336, alongside the census.
#
# A DRILL THAT IS NOT IN A GATE IS A NOTE, NOT A CONTROL — gate-roster-drill.sh's own
# header, and the reason this file is wired at G-AL#census in gate-selfcheck.sh.
#
# Hermetic: every control builds its own registry, its own criteria files and its own
# board ENGINE (a stub whose exit code is an argument) under a temp dir, and points the
# census at them through CBC_REG / CBC_STATE. Nothing here reads or writes the real
# registry, the real boards, or the real rotation ledger.
#
# ...WHICH IS EXACTLY WHY THE CENSUS WAS ALSO POINTED AT A REAL ROW BEFORE IT WAS TRUSTED
# (smDrainHandoff-16's bank: a detector that has only ever seen fixtures reports on your
# beliefs, not on the world). The first design of the census used a git-commit-date proxy
# for staleness. It passed a drill like this one and called all nineteen real rows GREEN;
# a real `board.py --check` found voiceBox, mcpMirror and wealthTensor STALE in the same
# minute. Fixtures could not have contradicted it. Keep both halves.
#
# NEGATIVE CONTROLS (4 of 14) assert the census does NOT fire: on a healthy registry, on
# --list, on the difference between CANNOT VERIFY and STALE, and on a fresh row sitting
# beside a stale one. A drill with no FAIL-direction controls only proves the tool is loud.
#
# EXIT: 0 all controls pass · 1 at least one control failed · 2 the census is missing
set -uo pipefail
CENSUS="${CBCD_CENSUS:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/charter-board-census.sh}"
[ -x "$CENSUS" ] || { echo "drill: CANNOT VERIFY -- $CENSUS missing or not executable"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n     %s\n' "$1" "${2:-}"; }
chk(){ # chk <name> <expected-rc> <actual-rc> [detail]
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected rc $2, got $3. ${4:-}"; fi; }

# the stub board engine: exit code is argv[1], and it records that it RAN.
cat > "$T/stub.sh" <<'STUB'
#!/bin/bash
echo "ran" >> "$STUB_MARK"
echo "board: stub says rc=$1"
exit "$1"
STUB
chmod +x "$T/stub.sh"
export STUB_MARK="$T/ran"

# reg <file> <key:rc> ...   -- build a registry; each row gets a real criteria file
reg(){ local f="$1"; shift; : > "$f"; echo "# fixture registry" >> "$f"
  local spec k rc
  for spec in "$@"; do k="${spec%%:*}"; rc="${spec##*:}"
    : > "$T/crit-$k.tsv"
    printf '%s\t~/x\t%s\t%s %s --brief\n' "$k" "$T/crit-$k.tsv" "$T/stub.sh" "$rc" >> "$f"
  done; }

run(){ CBC_REG="$1" CBC_STATE="$2" CBC_TIMEOUT=20 "$CENSUS" "${@:3}" 2>&1; }

echo "=== charter-board-census-drill ==="

# 1 · a fresh row is fresh
reg "$T/r1" a:0; OUT=$(run "$T/r1" "$T/s1"); RC=$?
chk "1  a row whose board engine exits 0 is reported fresh (rc 0)" 0 "$RC" "$OUT"

# 2 · a stale row is a finding
reg "$T/r2" a:1; OUT=$(run "$T/r2" "$T/s2"); RC=$?
if [ "$RC" = 1 ] && printf '%s' "$OUT" | command grep -q "STALE"; then ok "2  engine rc 1 => STALE and census rc 1"
else no "2  engine rc 1 => STALE and census rc 1" "rc=$RC :: $OUT"; fi

# 3 · CANNOT VERIFY IS A FINDING, NOT A PASS. The whole point: an unreadable board must
#     never be indistinguishable from a fresh one.
reg "$T/r3" a:2; OUT=$(run "$T/r3" "$T/s3"); RC=$?
if [ "$RC" = 1 ] && printf '%s' "$OUT" | command grep -q "CANNOT VERIFY"; then ok "3  engine rc 2 => CANNOT VERIFY counted as a finding (rc 1), never a pass"
else no "3  engine rc 2 => CANNOT VERIFY counted as a finding (rc 1), never a pass" "rc=$RC :: $OUT"; fi

# 4 · a vanished criteria file is a finding, not a skip
reg "$T/r4" a:0; rm -f "$T/crit-a.tsv"; OUT=$(run "$T/r4" "$T/s4"); RC=$?
if [ "$RC" = 1 ] && printf '%s' "$OUT" | command grep -q "MISSING"; then ok "4  missing criteria file is a finding, not a silent skip"
else no "4  missing criteria file is a finding, not a silent skip" "rc=$RC :: $OUT"; fi
: > "$T/crit-a.tsv"

# 5 · a brief-command the census cannot turn into a --check is a finding (fails CLOSED)
printf '# f\nz\t~/x\t%s\t%s 0\n' "$T/crit-a.tsv" "$T/stub.sh" > "$T/r5"
OUT=$(run "$T/r5" "$T/s5"); RC=$?
if [ "$RC" = 1 ] && printf '%s' "$OUT" | command grep -q "no --brief"; then ok "5  a row with no --brief flag fails CLOSED, it is not skipped"
else no "5  a row with no --brief flag fails CLOSED, it is not skipped" "rc=$RC :: $OUT"; fi

# 6 · an empty registry is CANNOT VERIFY (rc 2), never a clean pass
printf '# only comments\n\n' > "$T/r6"; OUT=$(run "$T/r6" "$T/s6"); RC=$?
chk "6  a registry that enumerates nothing is rc 2, not rc 0" 2 "$RC" "$OUT"

# 7 · an unreadable registry is CANNOT VERIFY, not silence
OUT=$(run "$T/does-not-exist" "$T/s7"); RC=$?
chk "7  a missing registry is rc 2 CANNOT VERIFY" 2 "$RC" "$OUT"

# 8 · --rotate 1 checks exactly one row
reg "$T/r8" a:0 b:0 c:0; : > "$STUB_MARK"
OUT=$(run "$T/r8" "$T/s8" --rotate 1); RC=$?
N=$(wc -l < "$STUB_MARK" | tr -d ' ')
if [ "$RC" = 0 ] && [ "$N" = 1 ]; then ok "8  --rotate 1 runs the board engine exactly once (3 rows registered)"
else no "8  --rotate 1 runs the board engine exactly once (3 rows registered)" "rc=$RC engine-runs=$N"; fi

# 9 · rotation ADVANCES -- a second run picks a different row. Without this the gate would
#     re-measure one project forever and the other eighteen stay unmeasured, which is the
#     exact hole the census exists to close, rebuilt inside the fix.
OUT2=$(run "$T/r8" "$T/s8" --rotate 1)
F1=$(printf '%s' "$OUT"  | awk '/fresh/{print $2}')
F2=$(printf '%s' "$OUT2" | awk '/fresh/{print $2}')
if [ -n "$F1" ] && [ -n "$F2" ] && [ "$F1" != "$F2" ]; then ok "9  the second --rotate 1 measures a DIFFERENT row ($F1 then $F2)"
else no "9  the second --rotate 1 measures a DIFFERENT row" "first='$F1' second='$F2'"; fi

# 10 · a never-measured row sorts FIRST -- a newly registered project is next in line, not last
printf 'b\t%d\nc\t%d\n' "$(date +%s)" "$(date +%s)" > "$T/s10"
reg "$T/r10" a:0 b:0 c:0
OUT=$(run "$T/r10" "$T/s10" --rotate 1)
if printf '%s' "$OUT" | command grep -q "fresh *a"; then ok "10 a row absent from the rotation ledger is measured before rows measured today"
else no "10 a row absent from the rotation ledger is measured before rows measured today" "$OUT"; fi

# --- NEGATIVE CONTROLS: these must NOT fire. They are insensitive to the census being
# --- right about staleness, which is what makes them controls and not decoration.

# 11 · NEGATIVE: a healthy registry is rc 0 with no findings
reg "$T/r11" a:0 b:0 c:0; OUT=$(run "$T/r11" "$T/s11"); RC=$?
if [ "$RC" = 0 ] && ! printf '%s' "$OUT" | command grep -q "FINDING"; then ok "11 NEG a registry of fresh boards prints no finding and exits 0"
else no "11 NEG a registry of fresh boards prints no finding and exits 0" "rc=$RC :: $OUT"; fi

# 12 · NEGATIVE: --list is READ-ONLY -- it enumerates without running a single board engine
reg "$T/r12" a:1 b:1; : > "$STUB_MARK"
OUT=$(run "$T/r12" "$T/s12" --list); RC=$?
N=$(wc -c < "$STUB_MARK" | tr -d ' ')
if [ "$RC" = 0 ] && [ "$N" = 0 ]; then ok "12 NEG --list runs no board engine and stays rc 0 even where every board is stale"
else no "12 NEG --list runs no board engine and stays rc 0 even where every board is stale" "rc=$RC engine-bytes=$N"; fi

# 13 · NEGATIVE: rc 2 is reserved for "no subject". A registry full of STALE rows is rc 1,
#      never rc 2 -- collapsing the two would let a real finding read as a harness problem.
reg "$T/r13" a:1 b:1 c:1; OUT=$(run "$T/r13" "$T/s13"); RC=$?
chk "13 NEG a registry where every board is stale is rc 1, not rc 2" 1 "$RC" "$OUT"

# 14 · NEGATIVE: one stale row does not contaminate its neighbours -- the fresh row is still
#      reported fresh, so the census names WHICH board rotted rather than the registry.
reg "$T/r14" a:0 b:1; OUT=$(run "$T/r14" "$T/s14"); RC=$?
if [ "$RC" = 1 ] && printf '%s' "$OUT" | command grep -q "fresh *a" && printf '%s' "$OUT" | command grep -q "STALE *b"; then
  ok "14 NEG a stale row beside a fresh one leaves the fresh one reported fresh"
else no "14 NEG a stale row beside a fresh one leaves the fresh one reported fresh" "rc=$RC :: $OUT"; fi

echo "charter-board-census-drill: $PASS passed, $FAIL failed ($((PASS+FAIL)) controls, 4 of them negative)"
[ "$FAIL" = 0 ] || exit 1
