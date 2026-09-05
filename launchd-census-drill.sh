#!/usr/bin/env bash
# launchd-census-drill.sh — the control for launchd-census.sh.
#
# WHY (acmeLedger-23, 2026-08-15). launchd-census answered a narrower question than its title
# for eight days and nothing noticed, because the only way to check it was to read it. Its three
# defects were all invisible from the outside: a hardcoded label filter that fails OPEN on new
# namespaces, an existence test standing in for an equivalence test, and a `head -1` that made
# the comparison subject nondeterministic. Each is now a check below, WITH the fixture that made
# it fail before the fix -- a drill whose fixtures only ever pass is a drill that cannot go red.
#
# Everything runs on fixtures via the census's LC_* overrides. It installs nothing, loads nothing,
# and never touches ~/Library/LaunchAgents.
#
# EXIT: 0 = all checks pass · 1 = a check failed · 2 = the drill itself could not run
set -uo pipefail

CENSUS="${CENSUS:-$HOME/code/darwin-mac-ops/launchd-census.sh}"
[ -x "$CENSUS" ] || { echo "DRILL CANNOT RUN: $CENSUS missing or not executable" >&2; exit 2; }

WORK="$(mktemp -d -t lcdrill)"
trap 'rm -rf "$WORK"' EXIT
pass=0; fail=0
ck() {  # ck <name> <want_rc> <got_rc> [extra]
  if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ok    %-56s rc=%s %s\n' "$1" "$3" "${4:-}"
  else fail=$((fail+1)); printf '  FAIL  %-56s want rc=%s got rc=%s %s\n' "$1" "$2" "$3" "${4:-}"; fi
}

mkdir -p "$WORK/agents" "$WORK/vault" "$WORK/cache"
git -C "$WORK/vault" init -q 2>/dev/null; git -C "$WORK/cache" init -q 2>/dev/null

plist() {  # plist <path> <label> <arg>
  cat > "$1" <<EOP
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>Label</key><string>$2</string>
<key>ProgramArguments</key><array><string>$3</string></array>
</dict></plist>
EOP
}

printf 'com.braatz.known\ncom.newnamespace.surprise\ncom.apple.something\napplication.com.foo.Bar\ncom.adobe.vendor\n' > "$WORK/loaded"
printf 'com.adobe.*   # vendor\n' > "$WORK/foreign"
: > "$WORK/diverge"

: > "$WORK/ephemeral"
run() { LC_AGENTS="$WORK/agents" LC_SEARCH_ROOTS="$WORK/vault $WORK/cache" \
        LC_FOREIGN_LIST="$WORK/foreign" LC_DIVERGE_LIST="$WORK/diverge" \
        LC_EPHEMERAL_LIST="$WORK/ephemeral" \
        LC_LOADED_FIXTURE="$WORK/loaded" LC_QUIET=1 bash "$CENSUS" 2>&1; }

echo "=== launchd-census-drill ==="

# 1. D1 POSITIVE CONTROL. An unknown namespace must land in ESTATE and be demanded, not skipped.
#    This is the com.user.ttyd shape: under the OLD filter this job produced no line at all and
#    the census exited 0. If this check ever goes green with rc=0, the filter has regressed to an
#    allowlist of the familiar.
plist "$WORK/agents/com.braatz.known.plist"        com.braatz.known        /bin/true
cp "$WORK/agents/com.braatz.known.plist" "$WORK/vault/com.braatz.known.plist"
plist "$WORK/agents/com.newnamespace.surprise.plist" com.newnamespace.surprise /bin/true
out="$(run)"; rc=$?
ck "D1 unknown namespace is ESTATE and reported unbacked" 1 "$rc"
case "$out" in *com.newnamespace.surprise*) pass=$((pass+1)); echo "  ok    D1 the unknown job is NAMED in the output";;
  *) fail=$((fail+1)); echo "  FAIL  D1 unknown job absent from output (it vanished, the old bug)";; esac

# 2. D1 NEGATIVE CONTROL. Excused via the foreign allowlist, the same job must go quiet.
#    Proves the allowlist is actually consulted and the check above was not passing for free.
printf 'com.adobe.*   # vendor\ncom.newnamespace.*  # drill fixture\n' > "$WORK/foreign"
out="$(run)"; rc=$?
ck "D1 same job, foreign-allowlisted, is excused" 0 "$rc"

# 3. NON-VACUITY. An over-broad glob that empties the estate bucket must be CANNOT VERIFY (2),
#    never a serene pass. acmeLedger-22's G-AH lesson: "found nothing" != "looked at nothing".
printf 'com.*   # deliberately over-broad\n' > "$WORK/foreign"
out="$(run)"; rc=$?
ck "non-vacuity: over-broad foreign glob => CANNOT VERIFY" 2 "$rc"
printf 'com.adobe.*   # vendor\ncom.newnamespace.*  # drill fixture\n' > "$WORK/foreign"

# 4. D2 POSITIVE CONTROL. A vault copy that differs must be DIVERGED (3), not "backed".
#    This is the ttyd shape: same filename, different content, silently green before today.
plist "$WORK/vault/com.braatz.known.plist" com.braatz.known /bin/false
out="$(run)"; rc=$?
ck "D2 same name, different content => DIVERGED" 3 "$rc"
case "$out" in *"would NOT reproduce"*) pass=$((pass+1)); echo "  ok    D2 the diff is shown, not just counted";;
  *) fail=$((fail+1)); echo "  FAIL  D2 no diff in output";; esac

# 5. D2 NEGATIVE CONTROL. Ratified with a reason, the same divergence is accepted.
printf 'com.braatz.known   # drill fixture: ratified on purpose\n' > "$WORK/diverge"
out="$(run)"; rc=$?
ck "D2 ratified divergence is accepted" 0 "$rc"
: > "$WORK/diverge"

# 6. D3. Two copies exist; the one in the everything-folder CACHE must not be chosen as the
#    backing while a real vault copy exists. Fixture: cache copy MATCHES live, vault copy does
#    not -- so picking the cache would print a false green. Under `find | head -1` the winner
#    depended on path ordering, i.e. on nothing.
# The path shape matters: the census recognises the cache by the literal prefix
# "$HOME/Desktop/downloads/", so the fixture has to live at that shape or the check passes for
# free. It did, on the first run of this drill -- the fixture was $WORK/downloads and D3 went
# green against a census that had not been asked the question. Reproduce the real path, or the
# control is theatre.
mkdir -p "$WORK/Desktop/downloads"; git -C "$WORK/Desktop/downloads" init -q 2>/dev/null
cp "$WORK/agents/com.braatz.known.plist" "$WORK/Desktop/downloads/com.braatz.known.plist"
out="$(HOME="$WORK" LC_AGENTS="$WORK/agents" LC_SEARCH_ROOTS="$WORK/vault $WORK/Desktop/downloads" \
       LC_FOREIGN_LIST="$WORK/foreign" LC_DIVERGE_LIST="$WORK/diverge" \
       LC_LOADED_FIXTURE="$WORK/loaded" LC_QUIET=1 bash "$CENSUS" 2>&1)"; rc=$?
ck "D3 a matching copy under Desktop/downloads cannot mask a stale vault" 3 "$rc"

# 7. The census must still refuse to guess when it cannot enumerate at all.
out="$(LC_AGENTS="$WORK/nonexistent" bash "$CENSUS" 2>&1)"; rc=$?
ck "missing LaunchAgents dir => CANNOT VERIFY, not a pass" 2 "$rc"

# 8. A missing foreign allowlist must fail CLOSED (everything becomes estate), never fail open.
out="$(LC_AGENTS="$WORK/agents" LC_SEARCH_ROOTS="$WORK/vault" \
       LC_FOREIGN_LIST="$WORK/nope.txt" LC_DIVERGE_LIST="$WORK/diverge" \
       LC_LOADED_FIXTURE="$WORK/loaded" LC_QUIET=1 bash "$CENSUS" 2>&1)"; rc=$?
ck "missing foreign allowlist fails CLOSED (more estate, not less)" 1 "$rc"

# 9. EPHEMERAL POSITIVE CONTROL (smDrainGate4, 2026-09-05; SM 1218198174895655). A job that is
#    ours, loaded, and has NO vault copy at all -- the com.braatz.travel-mode-rearm shape, replanted
#    with a runtime `until_dt` every time so no fixed body is ever committed. Before this category
#    existed, this was counted UNBACKED and failed the gate: the false positive the card measured.
# com.braatz.known's vault copy was deliberately diverged in check 4 and its ratification was
# cleared again in check 5 -- drop it from the loaded set here so it cannot smuggle a rc=3 into
# what is meant to be a pure test of the ephemeral path.
printf 'com.newnamespace.surprise\ncom.apple.something\napplication.com.foo.Bar\ncom.adobe.vendor\ncom.braatz.travel-mode-rearm\n' > "$WORK/loaded"
plist "$WORK/agents/com.braatz.travel-mode-rearm.plist" com.braatz.travel-mode-rearm /bin/true
printf 'com.braatz.travel-mode-rearm   # drill fixture: no fixed body, see launchd-ephemeral-allowlist.txt\n' > "$WORK/ephemeral"
out="$(run)"; rc=$?
ck "ephemeral-listed job with no vault copy is NOT unbacked" 0 "$rc"
# Run once more WITHOUT -quiet (matches ok(div)'s own convention) to prove it is NAMED, not
# silently absorbed -- same shape as D1's "the unknown job is NAMED" positive control.
out_loud="$(LC_AGENTS="$WORK/agents" LC_SEARCH_ROOTS="$WORK/vault $WORK/cache" \
       LC_FOREIGN_LIST="$WORK/foreign" LC_DIVERGE_LIST="$WORK/diverge" \
       LC_EPHEMERAL_LIST="$WORK/ephemeral" LC_LOADED_FIXTURE="$WORK/loaded" bash "$CENSUS" 2>&1)"
case "$out_loud" in *"ok(ephem)"*) pass=$((pass+1)); echo "  ok    ephemeral job is NAMED ok(ephem) in the output, not silently dropped";;
  *) fail=$((fail+1)); echo "  FAIL  ephemeral job did not print an ok(ephem) line";; esac

# 10. EPHEMERAL NEGATIVE CONTROL. Same shape, no allowlist entry -- must still be UNBACKED (1).
#     Proves check 9 passed because of the allowlist, not because an unbacked job is now free.
: > "$WORK/ephemeral"
out="$(run)"; rc=$?
ck "same job, NOT ephemeral-listed, is unbacked as before" 1 "$rc"
printf 'com.braatz.known\ncom.newnamespace.surprise\ncom.apple.something\napplication.com.foo.Bar\ncom.adobe.vendor\n' > "$WORK/loaded"
rm -f "$WORK/agents/com.braatz.travel-mode-rearm.plist"

printf '\nlaunchd-census-drill: %d passed, %d failed (%d checks, 5 of them negative controls)\n' \
  "$pass" "$fail" "$((pass+fail))"
[ "$fail" -eq 0 ] || exit 1
echo "PASS"
