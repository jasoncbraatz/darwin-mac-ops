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
PASS=0; FAIL=0; NEG=0
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
check() { # check <name> <expected-rc> <expected-grep-or-->
  local name="$1" want="$2" pat="$3" got="$4" out="$5"
  # A hardcoded "N of them negative" in the summary is doc-rot with a countdown, so the
  # drill counts its own. Negative = a control that demands the census NOT return 0.
  [ "$want" != "0" ] && NEG=$((NEG+1))
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
  # portability-guard.allow (feynmanSync-02): the census gained a checker for it, so the
  # miniature estate has to carry one too -- a new control that its own drill cannot run is
  # exactly the "decorative control" this drill exists to catch. Empty is a valid fixture:
  # entries_of returns [], the checker says "nothing to go stale", and the clean run stays 0.
  : > "$d/Scripts/portability-guard.allow"
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

# 3b. a portability-guard glob that ratifies NOTHING (feynmanSync-02). The checker compares
#     globs against what git actually TRACKS, so this fixture needs a REAL repo -- without one
#     the control would pass for the wrong reason (no repo -> CANNOT VERIFY, not a red), which
#     is the same species of lie this drill exists to catch.
E="$T/pg"; mkestate "$E"
(
  cd "$E/Scripts" && git init -q . && : > real.plist && git add real.plist \
    && git -c user.email=d@d -c user.name=d commit -qm fixture
) >/dev/null 2>&1
printf '%s\n%s\n' \
  '*.plist    | live: really matches real.plist' \
  '*.goneext  | the darwin-only file this excused was deleted in June' \
  > "$E/Scripts/portability-guard.allow"
run "$E"; check "dead portability-guard glob is found" 1 "ratifies nothing" "$RC" "$OUT"

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

# ── THE BOX IS NOT THE ESTATE (feynmanSync-07, 2026-09-07) ────────────────────
#    Every subtractive check judges an entry by walking THIS BOX. darwin clones ~64
#    repos, feynman 15 — so a pattern pointing into a repo that was never cloned here
#    matched zero files, and the census printed STALE and told the session to DELETE
#    the entry out of a shared, git-backed allowlist. Measured on feynman the day these
#    controls were written: 25 of 25 "stale" findings were this, and NOT ONE was real.
#    The pre-existing vacuity guards could not catch it — they fire only when a walk
#    finds ZERO files estate-wide, and a half-populated box sails straight through.

# 16. an absent container is CANNOT VERIFY, never STALE.
E="$T/absent"; mkestate "$E"
cat > "$E/repos/claude-blackbook/scripts/bb-writers-allowlist.json" <<'J'
{"_doc":"fixture","entries":[{"pattern":"~/repos/never-cloned-here/writer.py","reason":"lives on another box"}]}
J
run "$E"; check "absent container is CANNOT VERIFY, not STALE" 2 "CANNOT judge" "$RC" "$OUT"
#     ...and it must not ALSO be accused. The remedy a stale finding prints is "delete the
#     entry", so an accusation alongside the excuse is the whole bug still shipping.
if printf '%s' "$OUT" | grep -q "matches NO file today"; then
  printf '  FAIL  %-46s absent entry was ALSO accused of staleness\n' "absent is not also accused"; FAIL=$((FAIL+1))
else
  printf '  ok    %-46s no stale accusation\n' "absent is not also accused"; PASS=$((PASS+1))
fi

# 17. THE DISCRIMINATOR MUST DISCRIMINATE. Control 16 alone would still pass if the fix
#     were "never call anything stale again", which is an off-switch wearing a fix's
#     clothes. Same estate, one absent container AND one genuine corpse in a repo that IS
#     here: the corpse must still red while the absent one is still excused.
E="$T/absent_mix"; mkestate "$E"
cat > "$E/repos/claude-blackbook/scripts/bb-writers-allowlist.json" <<'J'
{"_doc":"fixture","entries":[
 {"pattern":"~/repos/never-cloned-here/writer.py","reason":"lives on another box"},
 {"pattern":"~/repos/realrepo/DELETED-LAST-YEAR.py","reason":"the repo IS here; the file is not"}]}
J
run "$E"; check "a real corpse still reds beside an absent one" 1 "matches NO file today" "$RC" "$OUT"
check "  ...and the absent one is still excused"        1 "CANNOT judge"           "$RC" "$OUT"

# 18. the same discriminator on phase 4, where guessing is most expensive: a satisfied
#     path-gone tells the next session to DELETE a live ratification. text-gone already
#     returned CANNOT VERIFY for an unreadable subject (control 13); the two PATH verbs
#     did not, so on a box missing the repo they reported the retirement as MET.
E="$T/retire_absent"; mkestate "$E"
printf 'com.fixture.live.*   # RETIRE-WHEN: path-gone:~/repos/never-cloned-here/writer.py — drop when it goes\n' \
    > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "path-gone into an absent repo is CANNOT VERIFY" 2 "cannot tell whether the subject is gone" "$RC" "$OUT"

# 19. a MISSING launchctl BINARY is CANNOT VERIFY, not a traceback. Control 6 covers an
#     EMPTY label list; this covers the tool not existing at all — which is every Linux
#     box in the fleet, and which used to kill the census mid-phase-2 with an uncaught
#     FileNotFoundError. Python exits 1 for that, and G-AK reads 1 as its specific
#     finding: "an exception record excuses a subject that no longer exists". It was
#     neither true nor a finding, and phases 2b-5 never ran at all.
#     PATH is stripped rather than trusting the OS, so this control does real work on
#     darwin instead of passing for free on the box that already lacks launchctl.
E="$T/nolaunchctl"; mkestate "$E"; mkdir -p "$T/emptybin"
OUT="$(PATH="$T/emptybin" RC_HOME="$E" \
      RC_SCAN_ROOTS="$E/Scripts:$E/code/darwin-mac-ops:$E/repos/claude-blackbook/scripts" \
      RC_NO_SWEEP=1 "${BASH:-/bin/bash}" "$CENSUS" 2>&1)"; RC=$?
check "missing launchctl BINARY is CANNOT VERIFY" 2 "launchctl is not installed" "$RC" "$OUT"
if printf '%s' "$OUT" | grep -q "Traceback"; then
  printf '  FAIL  %-46s the census crashed instead of reporting\n' "no traceback on a launchctl-less box"; FAIL=$((FAIL+1))
else
  printf '  ok    %-46s reported, did not crash\n' "no traceback on a launchctl-less box"; PASS=$((PASS+1))
fi

# ─────────────────────────────────────────────────────────────────────────────
# feynmanSync-08 · the verdict/finding JOIN, and the reason that wraps.
# Both of these were live on darwin on 2026-09-07 and INVISIBLE on feynman, because the
# launchd phase does not run on a box with no launchctl. A control that can only pass on
# one box is why they survived: the drill ran green on the box that could not look.
# ─────────────────────────────────────────────────────────────────────────────

# 24. A TRANSIENT job that is legitimately absent today must read DORMANT, and must NOT be
#     counted in the summary's stale tally. Before this, the finding was correctly suppressed
#     while the row still said STALE, so the census printed "stale: 2" one line above rc 0 and
#     "every ratification still describes something true." Both from the same run.
E="$T/transient"; mkestate "$E"
printf '%s\n%s\n' \
  'com.fixture.live.*   # a label the fake launchctl really lists' \
  'com.fixture.gone.*   # TRANSIENT: only registers a label while an update is actually installing' \
  > "$E/code/darwin-mac-ops/launchd-foreign-allowlist.txt"
run "$E"; check "transient absentee reads dormant, not stale" 0 "dormant" "$RC" "$OUT"
check "and the summary tallies it as stale: 0"            0 "stale: 0"  "$RC" "$OUT"

# 25. NEGATIVE TWIN, and the load-bearing control of this pair. Take a COPY of the census with
#     exactly the verdict-join removed -- the pre-feynmanSync-08 behaviour, where row() derives
#     STALE from n alone and cannot see the suppression -- and demand the SELF-CHECK catch the
#     contradiction rather than print a tally that disagrees with its own findings.
#     The mutation lands on a copy inside $T. The live census is never touched: that is the
#     lesson roster-oncommit-drill taught the hard way (-07), where step 1 installed a known-
#     broken tool over the real one with nothing standing between it and step 2.
#     The sed is VERIFIED to have changed something first -- a no-op mutation would make this
#     control pass for the wrong reason, which is the whole species of bug it is here to catch.
MUT="$T/census-desync.sh"
sed 's/verdict=("dormant" if (transient and not n) else None)/verdict=None/' "$CENSUS" > "$MUT"
if cmp -s "$MUT" "$CENSUS"; then
  printf '  FAIL  %-46s the mutation changed nothing (anchor moved?)\n' "self-check control mutates for real"
  FAIL=$((FAIL+1))
else
  printf '  ok    %-46s mutation applied\n' "self-check control mutates for real"; PASS=$((PASS+1))
  OUT="$(RC_HOME="$E" RC_SCAN_ROOTS="$E/Scripts:$E/code/darwin-mac-ops:$E/repos/claude-blackbook/scripts" \
        RC_LAUNCHCTL="$E/labels" RC_NO_SWEEP=1 bash "$MUT" 2>&1)"; RC=$?
  check "a desynced verdict is caught by SELF-CHECK" 1 "SELF-CHECK" "$RC" "$OUT"
fi

# 26. A reason that WRAPS. Phase 4 is the only check that reads RETIRE-WHEN:, and it read
#     exactly one line. Every clause an author wrapped for readability was invisible to it --
#     and invisible reads as "carries no clause", which is what the FLOOR counts. Measured on
#     darwin: com.braatz.travel-mode-rearm carried RETIRE-WHEN *and* REVIEWED, precisely as its
#     own file's documented bar demands, and phase 4 scored it as carrying neither.
#     Here the wrapped clause is one whose condition is MET, so seeing it must turn the census
#     RED. A control that only proved the clause was *parsed* would pass on a parser that read
#     it and threw it away.
E="$T/wrap"; mkestate "$E"
{ printf 'com.fixture.diverge  # the vault copy differs on purpose\n'
  printf '                     # RETIRE-WHEN: path-gone:~/Scripts/not-here.sh — drop it when that goes\n'
} > "$E/code/darwin-mac-ops/launchd-divergence-allowlist.txt"
run "$E"; check "wrapped RETIRE-WHEN is read (and bites)" 1 "condition is now MET" "$RC" "$OUT"

# 27. POSITIVE TWIN of 26, so the fix cannot degrade into "any comment anywhere is a clause".
#     A comment at column 0 is a file or section header. If those attached to whatever entry
#     happened to precede them, a header could retire a live ratification it was never about --
#     the same destructive direction as the STALE remedy itself ("delete the entry").
E="$T/wrapcol0"; mkestate "$E"
{ printf 'com.fixture.diverge  # the vault copy differs on purpose\n'
  printf '# RETIRE-WHEN: path-gone:~/Scripts/not-here.sh — a section header, not this entry.\n'
} > "$E/code/darwin-mac-ops/launchd-divergence-allowlist.txt"
run "$E"; check "a column-0 comment is NOT a continuation" 0 "still describes something true" "$RC" "$OUT"

# 28. A RECORD THAT LIVES ONCE PER REPO. portability-guard.sh reads portability-guard.allow
#     from the toplevel of whatever repo it is committing in, so there are legitimately as
#     many copies as there are repos with a darwin-only file to excuse. The census knew ONE
#     hardcoded path. When darwin-mac-ops grew its own on 2026-09-07 the census failed CLOSED
#     with UNKNOWN EXCEPTION RECORD -- the right refusal for the wrong reason: not an unknown
#     record, the same known record in the second place its own reader looks.
#     The dead glob is planted in the SECOND repo on purpose. A census still asking only about
#     ~/Scripts passes this fixture, which is exactly the regression to catch.
E="$T/pgrepos"; mkestate "$E"
mkdir -p "$E/code/darwin-mac-ops"
(
  cd "$E/Scripts" && git init -q . && : > real.plist && git add real.plist \
    && git -c user.email=d@d -c user.name=d commit -qm fixture
  cd "$E/code/darwin-mac-ops" && git init -q . && : > other.plist && git add other.plist \
    && git -c user.email=d@d -c user.name=d commit -qm fixture
) >/dev/null 2>&1
printf '%s\n' '*.plist | live here' > "$E/Scripts/portability-guard.allow"
printf '%s\n%s\n' '*.plist   | live here too' \
                  '*.goneext | the darwin-only file this excused was deleted in June' \
  > "$E/code/darwin-mac-ops/portability-guard.allow"
run "$E"; check "a dead glob in a SECOND repo's copy is found" 1 "goneext" "$RC" "$OUT"
check "…and it names the repo the glob is dead IN"            1 "darwin-mac-ops" "$RC" "$OUT"

# 29. POSITIVE TWIN: two copies, both entirely live, must stay green. Without this, "judge
#     every copy" could degrade into "any second copy is suspicious", which would make the
#     next repo to grow one wrong by existing.
E="$T/pgrepos2"; mkestate "$E"
mkdir -p "$E/code/darwin-mac-ops"
(
  cd "$E/Scripts" && git init -q . && : > real.plist && git add real.plist \
    && git -c user.email=d@d -c user.name=d commit -qm fixture
  cd "$E/code/darwin-mac-ops" && git init -q . && : > other.plist && git add other.plist \
    && git -c user.email=d@d -c user.name=d commit -qm fixture
) >/dev/null 2>&1
printf '%s\n' '*.plist | live here'     > "$E/Scripts/portability-guard.allow"
printf '%s\n' '*.plist | live here too' > "$E/code/darwin-mac-ops/portability-guard.allow"
run "$E"; check "two fully-live copies stay green" 0 "still describes something true" "$RC" "$OUT"

echo
if [ "$FAIL" -gt 0 ]; then
  bold "=== drill: FAIL — $FAIL of $((PASS+FAIL)) controls did not hold ==="
  exit 1
fi
bold "=== drill: PASS — $PASS controls, $NEG of them negative (the census can still go red, and can still say 'I could not look') ==="
exit 0
