#!/bin/bash
# =============================================================================
# gate-roster-drill.sh — prove G-H's roster-aware DIRTY downgrade, offline.
#
# The downgrade turns a FAIL into a WARN. That is the most dangerous direction a
# control can move, so it does not get to ship untested — and it cannot be tested
# in production, because it only fires when a CONCURRENT session happens to be
# mid-edit in a repo under the roots. (The first attempt at a live canary evaporated
# when the sibling session committed its work between two gate runs.)
#
# The function under test is EXTRACTED FROM gate-selfcheck.sh AT RUN TIME, not
# copied here: a drill that carries its own copy of the logic passes forever while
# the real thing rots. If the extraction stops matching, the drill fails loudly.
#
#   bash gate-roster-drill.sh
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd -P)"
GATE="${GATE_SELFCHECK:-$HERE/gate-selfcheck.sh}"
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
chk() { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (want='$1' got='$2')"; fi; }

command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 missing — cannot drill"; exit 2; }

S="$(mktemp -d "${TMPDIR:-/tmp}/gate-roster-drill.XXXXXX")"
trap 'rm -rf "$S"' EXIT

# Extract the live function definition. Bounded by its own closing brace at col 0.
sed -n '/^_roster_other_claimant() {/,/^}/p' "$GATE" > "$S/fn.sh"
if ! grep -q 'GATE_ROSTER_WHO' "$S/fn.sh"; then
  echo "  FAIL  could not extract _roster_other_claimant() from $GATE (did it move or get renamed?)"
  exit 1
fi
echo "=== G-H roster downgrade drill (extracted $(wc -l < "$S/fn.sh") lines from $(basename "$GATE")) ==="

export ROSTER_DB="$S/roster.sqlite3"
sqlite3 "$ROSTER_DB" "CREATE TABLE roster(who TEXT NOT NULL, kind TEXT NOT NULL,
  resource TEXT NOT NULL DEFAULT '', task TEXT NOT NULL DEFAULT '',
  started INTEGER NOT NULL, expires INTEGER NOT NULL, PRIMARY KEY (who,kind,resource));"
add() { # add <who> <resource> <expires-offset-seconds>
  # The FIXTURE has to escape too. First cut of this drill did not, and #8 "failed"
  # on a broken INSERT rather than on the function under test — a fixture bug wearing
  # a finding's clothes. Worth keeping the memory: an assertion is only as trustworthy
  # as the setup that feeds it.
  _aw="$(printf '%s' "$1" | sed "s/'/''/g")"; _ar="$(printf '%s' "$2" | sed "s/'/''/g")"
  sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster VALUES('$_aw','claim','$_ar','t',
    strftime('%s','now'), strftime('%s','now')+$3);"
}
_ROSTER_DB="$ROSTER_DB"
. "$S/fn.sh"

REPO="$S/n8n-stack"; mkdir -p "$REPO"

add sibling      n8n-stack       3600      # live claim by someone else
add me           other-repo      3600
add ghost        expired-repo    -3600     # already expired

# 1 — the default: no GATE_ROSTER_WHO, nothing is EVER downgraded.
unset GATE_ROSTER_WHO
chk "" "$(_roster_other_claimant "$REPO")" "#1 no GATE_ROSTER_WHO -> no downgrade (byte-identical to pre-S46)"

# 2 — a live claim by ANOTHER session is found, by repo basename.
GATE_ROSTER_WHO=me
chk "sibling" "$(_roster_other_claimant "$REPO")" "#2 live sibling claim is found (matched on basename)"

# 3 — THE self-exempt hole: your own claim must never downgrade your own dirt.
GATE_ROSTER_WHO=sibling
chk "" "$(_roster_other_claimant "$REPO")" "#3 your OWN claim does not exempt you"

# 4 — an EXPIRED claim is not a live one. Stale claims are expired truth generators.
GATE_ROSTER_WHO=me
chk "" "$(_roster_other_claimant "$S/expired-repo")" "#4 an expired claim does not downgrade"

# 5 — an unclaimed repo still fails.
chk "" "$(_roster_other_claimant "$S/unclaimed")" "#5 unclaimed dirty repo is untouched (still a FAIL)"

# 6 — a claim recorded as a FULL PATH matches too (roster resources are free text).
add pathclaimer "$S/fullpath-repo" 3600
chk "pathclaimer" "$(_roster_other_claimant "$S/fullpath-repo")" "#6 a full-path claim matches as well as a basename"

# 7 — a missing roster DB fails CLOSED (no downgrade), it does not crash.
ROSTER_DB_SAVED="$_ROSTER_DB"; _ROSTER_DB="$S/does-not-exist.sqlite3"
chk "" "$(_roster_other_claimant "$REPO")" "#7 missing roster DB -> no downgrade, no crash"
_ROSTER_DB="$ROSTER_DB_SAVED"

# 8 — a quote in a session name cannot break out of the SQL.
add "o'brien" quoted-repo 3600
chk "o'brien" "$(_roster_other_claimant "$S/quoted-repo")" "#8 apostrophes in names are escaped, not injected"
GATE_ROSTER_WHO="o'brien"
chk "" "$(_roster_other_claimant "$S/quoted-repo")" "#8b ...and the self-check still matches through the escaping"

echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
