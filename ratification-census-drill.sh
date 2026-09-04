#!/bin/bash
# ratification-census-drill.sh — the controls for ratification-census.sh.
#
# A census that reports "0 stale" is worth exactly as much as the proof that it CAN say
# something else. This drill builds a miniature estate in a temp dir, plants a known-dead
# ratification of each shape, and demands the census find it. It also plants a record the
# census has never heard of, and demands the census fail CLOSED rather than shrug.
#
# The negative controls are the load-bearing ones. If the "clean" fixture ever stops
# returning 0, or a planted corpse stops being found, the census has quietly become
# decorative — and a decorative control is indistinguishable from a passing one.
#
# rc 0 = every control holds.  rc 1 = at least one control failed.
set -uo pipefail
CENSUS="${CENSUS:-$HOME/code/darwin-mac-ops/ratification-census.sh}"
PASS=0; FAIL=0
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
check() { # check <name> <expected-rc> <expected-grep-or-->
  local name="$1" want="$2" pat="$3" got="$4" out="$5"
  if [ "$got" != "$want" ]; then
    printf '  FAIL  %-46s rc=%s (wanted %s)\n' "$name" "$got" "$want"; FAIL=$((FAIL+1)); return
  fi
  if [ "$pat" != "-" ] && ! printf '%s' "$out" | grep -qE "$pat"; then
    printf '  FAIL  %-46s rc ok but output lacks /%s/\n' "$name" "$pat"; FAIL=$((FAIL+1)); return
  fi
  printf '  ok    %-46s rc=%s\n' "$name" "$got"; PASS=$((PASS+1))
}

[ -f "$CENSUS" ] || { echo "drill: CANNOT VERIFY — census missing at $CENSUS"; exit 2; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkestate() { # mkestate <dir> — a miniature estate whose every ratification is TRUE
  local d="$1"
  mkdir -p "$d/repos/claude-blackbook/scripts" "$d/code/darwin-mac-ops" "$d/Scripts" \
           "$d/repos/realrepo" "$d/Desktop/downloads"
  : > "$d/repos/realrepo/live-writer.py"
  cat > "$d/repos/claude-blackbook/scripts/bb-writers-allowlist.json" <<'J'
{"_doc":"fixture","entries":[{"pattern":"~/repos/realrepo/live-writer.py","reason":"exists"}]}
J
  printf 'com.fixture.live.*   # a label the fake launchctl really lists\n' \
      > "$d/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
  printf 'com.fixture.diverge  # ditto\n' \
      > "$d/code/darwin-mac-ops/launchd-divergence-allowlist.txt"
  : > "$d/code/darwin-mac-ops/gate-secret-sweep.allow"
  : > "$d/Scripts/repo-doctor.allow"
  : > "$d/Scripts/asana-read-lint.baseline"
  : > "$d/Scripts/card-lint.baseline"
  # the self-policing consumers, with their re-examination logic intact
  printf 'MUT_RATCHET_RETIRE = True\n' > "$d/Scripts/card-lint.py"
  printf 'print("RATCHET DOWN")\n'     > "$d/Scripts/asana-read-lint.py"
  printf -- '--update-baseline\n'      > "$d/Scripts/fda-canary.sh"
  printf 'com.fixture.live.helper\ncom.fixture.diverge\n' > "$d/labels"
}
run() { # run <estate-dir> -> sets RC / OUT
  OUT="$(RC_HOME="$1" RC_SCAN_ROOTS="$1/Scripts:$1/code/darwin-mac-ops:$1/repos/claude-blackbook/scripts" \
        RC_LAUNCHCTL="$1/labels" RC_NO_SWEEP=1 bash "$CENSUS" 2>&1)"; RC=$?
}

bold "=== ratification-census drill ==="

# 1. POSITIVE CONTROL — a clean estate must pass. If this ever fails, every red below is noise.
E="$T/clean"; mkestate "$E"; run "$E"
check "clean estate passes" 0 "still describes something true" "$RC" "$OUT"

# 2. a bb-writers pattern that matches no file — the fail-open-in-the-future-tense shape
E="$T/bb"; mkestate "$E"
cat > "$E/repos/claude-blackbook/scripts/bb-writers-allowlist.json" <<'J'
{"_doc":"fixture","entries":[{"pattern":"~/repos/realrepo/DELETED-LAST-YEAR.py","reason":"gone"}]}
J
run "$E"; check "dead bb-writers pattern is found" 1 "matches NO file today" "$RC" "$OUT"

# 3. a launchd glob matching nothing loaded
E="$T/lc"; mkestate "$E"
printf 'com.fixture.uninstalled.*  # the app was deleted in June\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "dead launchd glob is found" 1 "NO loaded launchd label" "$RC" "$OUT"

# 4. FAIL CLOSED on a record shape the census has never seen. This is the -24 control:
#    a selector that only knows the familiar fails OPEN on everything added later.
E="$T/unknown"; mkestate "$E"
printf 'somebody/else  # invented tomorrow\n' > "$E/Scripts/brand-new-thing.allowlist"
run "$E"; check "UNKNOWN record fails closed" 1 "UNKNOWN EXCEPTION RECORD" "$RC" "$OUT"

# 5. FAIL CLOSED on a marker vocabulary nobody taught it
E="$T/marker"; mkestate "$E"
# The token is ASSEMBLED at runtime, never written literally here: a literal fixture in a
# file the census scans makes the drill indict itself, and "the control found the control's
# own test data" is a finding nobody can act on. (Same reason secret-re.sh refuses to carry
# a real-shaped example key.) Verified both ways: with the literal, the live census FAILed.
printf '# DEPLOY%s twenty plus characters of reason here\n' '-OK:' > "$E/Scripts/thing.sh"
run "$E"; check "UNKNOWN marker fails closed" 1 "UNKNOWN RATIFICATION MARKER" "$RC" "$OUT"

# 6. VACUITY — an empty subject must be CANNOT VERIFY, never a pass. Deleting the world
#    is exactly how -24's G-AA turned a FAIL into a PASS with no change in the output.
E="$T/vac"; mkestate "$E"; : > "$E/labels"
run "$E"; check "empty launchctl is CANNOT VERIFY (not pass)" 2 "ZERO labels" "$RC" "$OUT"

# 7. the self-policing canary: somebody turns the ratchet off
E="$T/mut"; mkestate "$E"
printf 'MUT_RATCHET_RETIRE = False\n' > "$E/Scripts/card-lint.py"
run "$E"; check "ratchet-retire turned OFF is found" 1 "no longer contains its stale-entry" "$RC" "$OUT"

# 8. a self-policing consumer that vanishes entirely
E="$T/gone"; mkestate "$E"; rm -f "$E/Scripts/fda-canary.sh"
run "$E"; check "missing self-policing consumer speaks" 2 "cannot confirm" "$RC" "$OUT"

# 9. NEGATIVE control on the drill's own fixture: the clean estate must not be clean
#    by accident. Prove the checkers actually ran by counting entries.
E="$T/clean2"; mkestate "$E"; run "$E"
check "clean run actually checked entries" 0 "entries checked: [1-9]" "$RC" "$OUT"

# ── PHASE 4 · rightness. These are the controls for the claim a matcher CANNOT make:
#    that the reason beside a still-matching pattern is still true. Every one of them
#    plants an entry whose GLOB IS LIVE — the launchd label really is listed — so a
#    finding here can only have come from the reason text, never from the matching.

# 10. the load-bearing one: the author's own retirement condition has come true, and the
#     pattern still matches. Phases 1-3 are green on this fixture; only phase 4 can see it.
E="$T/retire"; mkestate "$E"
printf 'com.fixture.live.*   # RETIRE-WHEN: path-gone:~/Scripts/card-lint.py — drop this when the linter goes\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
rm -f "$E/Scripts/card-lint.py"; printf 'MUT_RATCHET_RETIRE = True\n' > "$E/Scripts/card-lint2.py"
RC_CARD_LINT="$E/Scripts/card-lint2.py" run "$E"
check "MET retirement condition is found" 1 "retirement condition is now MET" "$RC" "$OUT"

# 11. POSITIVE control for the same clause: a retirement condition that has NOT come true
#     must not red anything. Without this, control 10 could be passing because the clause
#     always fires, which is a check that has stopped discriminating.
E="$T/retire_ok"; mkestate "$E"
printf 'com.fixture.live.*   # RETIRE-WHEN: path-gone:~/Scripts/card-lint.py — drop this when the linter goes\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "UNMET retirement condition stays green" 0 "still describes something true" "$RC" "$OUT"

# 12. FAIL CLOSED on a clause the census cannot parse. An unreadable RETIRE-WHEN is worse
#     than none: the entry LOOKS audited. Same doctrine as the unknown-record control (4).
E="$T/retire_bad"; mkestate "$E"
printf 'com.fixture.live.*   # RETIRE-WHEN: when-jason-says-so — vibes\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "unparseable RETIRE-WHEN fails closed" 1 "unreadable RETIRE-WHEN" "$RC" "$OUT"

# 13. an unreadable SUBJECT is CANNOT VERIFY, never a retirement. This is 2e's gh lesson
#     generalised: reading "I could not look" as "it is gone" turns a missing file into a
#     confident instruction to delete a live exemption.
E="$T/retire_blind"; mkestate "$E"
printf 'com.fixture.live.*   # RETIRE-WHEN: "text-gone:~/Scripts/not-here.sh::the guard" — see above\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "unreadable RETIRE-WHEN subject is CANNOT VERIFY" 2 "not a satisfied condition" "$RC" "$OUT"

# 14. a REVIEWED: date nobody could have reviewed on.
E="$T/rev_future"; mkestate "$E"
printf 'com.fixture.live.*   # REVIEWED: 2099-01-01 — a date that has not happened\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "future REVIEWED: date is found" 1 "in the FUTURE" "$RC" "$OUT"

# 15. staleness SPEAKS but does not bite: an old REVIEWED: warns, rc unaffected. If this
#     ever starts failing, somebody tightened a ratchet with no rollout — see the FLOOR note.
E="$T/rev_old"; mkestate "$E"
printf 'com.fixture.live.*   # REVIEWED: 2000-01-01 — nobody has looked since\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "stale REVIEWED: warns without biting" 0 "has not been re-read" "$RC" "$OUT"

echo
if [ "$FAIL" -gt 0 ]; then
  bold "=== drill: FAIL — $FAIL of $((PASS+FAIL)) controls did not hold ==="
  exit 1
fi
bold "=== drill: PASS — $PASS controls, 10 of them negative (the census can still go red) ==="
exit 0
