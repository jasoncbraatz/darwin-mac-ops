#!/usr/bin/env bash
# handoff-thread-continuity-drill.sh — prove handoff-thread-continuity.sh can still go RED.
#
# A drill that is not in a gate is a note, not a control (gate-roster-drill.sh's own header),
# and a control that has never been seen to fail is decorative. This one runs the SHIPPED
# script -- it never re-implements the rule -- and it drives it in both directions.
#
# TWO OF THE CONTROLS USE REAL HISTORY, NOT A FIXTURE. The bug this check exists for is
# reproducible from files that are already in git: ~/Desktop/downloads/HANDOFF-smBacklog-12.md
# genuinely drops gids 1217015004006698 and 1218065539722208, both of which -13 carries. Those
# two controls are the card's own DONE WHEN (1218152478656223), executed rather than asserted.
# They SKIP (loudly, and never silently pass) if the downloads checkout is not present, because
# a control whose subject is absent has not run.
#
# EXIT CODES (this drill's own contract):
# @verdict-contract
# @verdict 0  every control held
# @verdict 1  a control did not hold -- the continuity check has lost a direction
# @drill ~/code/darwin-mac-ops/handoff-thread-continuity-drill.sh
set -o pipefail

HTC="${HTC:-$(cd "$(dirname "$0")" && pwd)/handoff-thread-continuity.sh}"
DL="${HTC_FIXTURE_DIR:-$HOME/Desktop/downloads}"
pass=0; fail=0; skip=0
codes_seen=""

ok()   { printf '  ok    %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail+1)); }
note() { printf '  SKIP  %s\n' "$1"; skip=$((skip+1)); }
saw()  { case ",$codes_seen," in *",$1,"*) : ;; *) codes_seen="${codes_seen:+$codes_seen,}$1" ;; esac; }

# run <inbound> <outbound> -> sets RC and OUT
run() { OUT="$(bash "$HTC" --inbound "$1" --outbound "$2" 2>&1)"; RC=$?; saw "$RC"; }

if [ ! -r "$HTC" ]; then
  echo "  FAIL  handoff-thread-continuity.sh not found at $HTC -- nothing was proven"
  echo "=== drill: FAIL ==="
  exit 1
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
G1=1218065539722208   # smKondo punch list -- one of the two threads -12 really dropped
G2=1217015004006698   # A1 dedupe ratchet [sev-2] -- the other
G3=1218126670100000   # a genuinely DIFFERENT card, used as the load-bearing negative

cat > "$T/in.md" <<EOF
# inbound
- OPEN: the smKondo punch list, gid $G1 -- 13/18 items live
- OPEN: the A1 dedupe ratchet, gid $G2 [sev-2]
EOF

echo "=== handoff-thread-continuity drill ==="

# ---- 1-2. THE CARD'S OWN DONE WHEN, against real history ------------------------------
if [ -r "$DL/HANDOFF-smBacklog-12.md" ] && [ -r "$DL/HANDOFF-smBacklog-13.md" ]; then
  run "$DL/HANDOFF-smBacklog-13.md" "$DL/HANDOFF-smBacklog-12.md"
  if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "DROPPED $G2" && printf '%s' "$OUT" | grep -q "DROPPED $G1"; then
    ok "REAL HISTORY: smBacklog-12's handoff FAILS, naming both gids it silently dropped"
  else
    bad "REAL HISTORY: -12 should FAIL naming $G1 and $G2 (rc=$RC): $OUT"
  fi

  run "$DL/HANDOFF-smBacklog-12.md" "$DL/HANDOFF-smBacklog-13.md"
  if [ "$RC" -eq 0 ]; then
    ok "REAL HISTORY: smBacklog-13's handoff PASSES -- it carries every thread it inherited"
  else
    bad "REAL HISTORY: -13 should PASS (rc=$RC): $OUT"
  fi
else
  note "the real-history controls: $DL/HANDOFF-smBacklog-1{2,3}.md not readable, so the card's own DONE WHEN went unexercised this run"
fi

# ---- 3. the bug itself, synthetic: a dropped gid is a FAIL ----------------------------
cat > "$T/drop.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1.
verify: bb-card.py show $G1 -- still open?
EOF
run "$T/in.md" "$T/drop.md"
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "DROPPED $G2"; then
  ok "a thread present inbound and absent outbound is a FAIL, named by gid"
else
  bad "a dropped gid should FAIL (rc=$RC): $OUT"
fi

# ---- 4. NEGATIVE: dropping ON PURPOSE, with a receipt, is a WIN -----------------------
cat > "$T/dropped-well.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1.
verify: bb-card.py show $G1 -- still open?

DROPPED: the A1 dedupe ratchet, gid $G2 -- closed by -11, confirmed 2026-09-03.
verify: bb-card.py show $G2 -- completed=true -> stays dropped
EOF
run "$T/in.md" "$T/dropped-well.md"
if [ "$RC" -eq 0 ] && ! printf '%s' "$OUT" | grep -q NOVERIFY; then
  ok "NEGATIVE: a thread retired with a receipt + verify: line PASSES (dropping is a WIN)"
else
  bad "a documented drop should PASS with no NOVERIFY (rc=$RC): $OUT"
fi

# ---- 5-6. ANTI-GAMING: pasting the inbound back does not count -------------------------
cat > "$T/fenced.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1.
verify: bb-card.py show $G1

Here is last session's handoff, pasted for reference:

\`\`\`
- OPEN: the A1 dedupe ratchet, gid $G2 [sev-2]
\`\`\`
EOF
run "$T/in.md" "$T/fenced.md"
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "DROPPED $G2"; then
  ok "ANTI-GAMING: a gid only inside a fenced block is NOT carried"
else
  bad "a fenced-only gid should still be DROPPED (rc=$RC): $OUT"
fi

cat > "$T/quoted.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1.
verify: bb-card.py show $G1

> - OPEN: the A1 dedupe ratchet, gid $G2 [sev-2]
EOF
run "$T/in.md" "$T/quoted.md"
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "DROPPED $G2"; then
  ok "ANTI-GAMING: a gid only inside a blockquote is NOT carried"
else
  bad "a blockquoted-only gid should still be DROPPED (rc=$RC): $OUT"
fi

# ---- 7. LOAD-BEARING NEGATIVE: coverage is per-gid, never a count ----------------------
cat > "$T/substitute.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1.
verify: bb-card.py show $G1
Also picked up a brand new one, gid $G3.
verify: bb-card.py show $G3
EOF
run "$T/in.md" "$T/substitute.md"
if [ "$RC" -eq 1 ] && printf '%s' "$OUT" | grep -q "DROPPED $G2"; then
  ok "LOAD-BEARING: a NEW gid does not substitute for a dropped one (per-gid, not a count)"
else
  bad "a substituted gid should not excuse the drop (rc=$RC): $OUT"
fi

# ---- 8-9. the verify: half -- advisory, and PINNED as non-blocking ---------------------
cat > "$T/noverify.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1. Still live.
Carried: the A1 dedupe ratchet, gid $G2. Still live.
EOF
run "$T/in.md" "$T/noverify.md"
if printf '%s' "$OUT" | grep -q "NOVERIFY $G1" && printf '%s' "$OUT" | grep -q "NOVERIFY $G2"; then
  ok "a carried thread with NO verify: line is reported -- this is the v2.23 rule's teeth"
else
  bad "carried-without-verify should emit NOVERIFY for both (rc=$RC): $OUT"
fi
if [ "$RC" -eq 0 ]; then
  ok "NEGATIVE: NOVERIFY does NOT move the exit code -- a missing liveness check is a WARN, a dropped thread is a FAIL, and a tightening must argue with card 1218152478656223 first"
else
  bad "NOVERIFY must stay non-blocking; rc was $RC"
fi

cat > "$T/verified.md" <<EOF
# outbound
Carried: the smKondo punch list, gid $G1.
verify: backlog-rank.py | grep $G1
Carried: the A1 dedupe ratchet, gid $G2.
verify: bb-card.py show $G2
EOF
run "$T/in.md" "$T/verified.md"
if [ "$RC" -eq 0 ] && ! printf '%s' "$OUT" | grep -q NOVERIFY; then
  ok "NEGATIVE: a handoff that obeys v2.23 is SILENT -- a control that speaks every run is a control nobody reads"
else
  bad "a fully compliant handoff should be silent (rc=$RC): $OUT"
fi

# ---- 10-12. CANNOT VERIFY, three ways, and none of them is a pass ----------------------
run "$T/nonexistent-inbound.md" "$T/verified.md"
if [ "$RC" -eq 2 ]; then ok "a MISSING inbound handoff is CANNOT VERIFY (2), never a silent pass"
else bad "missing inbound should be rc 2, got $RC"; fi

run "$T/in.md" "$T/nonexistent-outbound.md"
if [ "$RC" -eq 2 ]; then ok "a MISSING outbound handoff is CANNOT VERIFY (2)"
else bad "missing outbound should be rc 2, got $RC"; fi

printf '# outbound with no cards at all\nWe shipped a thing.\n' > "$T/nogids-in.md"
run "$T/nogids-in.md" "$T/verified.md"
if [ "$RC" -eq 2 ]; then
  ok "an inbound that parses to ZERO gids is CANNOT VERIFY -- an empty parse is a broken parser"
else
  bad "zero-gid inbound should be rc 2, got $RC"
fi

# ---- 13. the prose filter is asked of BOTH sides, symmetrically ------------------------
cat > "$T/fenced-in.md" <<EOF
# inbound
\`\`\`
- OPEN: the A1 dedupe ratchet, gid $G2
\`\`\`
- OPEN: the smKondo punch list, gid $G1
EOF
run "$T/fenced-in.md" "$T/drop.md"
if [ "$RC" -eq 0 ]; then
  ok "SYMMETRY: a gid the INBOUND only quoted in a fence is not a thread the outbound must carry"
else
  bad "an inbound fenced-only gid should not be demanded (rc=$RC): $OUT"
fi

printf 'VERDICTS-EXERCISED: %s\n' "$codes_seen"
if [ "$fail" -eq 0 ]; then
  printf '=== drill: PASS — %d controls (%d skipped), 8 of them negative or anti-gaming ===\n' "$pass" "$skip"
  exit 0
fi
printf '=== drill: FAIL — %d of %d controls did not hold ===\n' "$fail" "$((pass+fail))"
exit 1
