#!/bin/bash
# =============================================================================
# gate-roster-drill.sh — prove G-H's roster-aware downgrades, offline.
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

# 1 — no GATE_ROSTER_WHO: EVERY live claim is reported. This assertion was inverted on
# 2026-08-15 (opus-acmeLedger-21) because the CODE was deliberately inverted on 2026-08-12
# (1979d80): the old contract "no identity -> never downgrade" failed OPEN, and the gate came
# within one obedient step of committing a sibling's half-written paragraph. The new contract
# is that an unknown identity makes the check MORE cautious, not less — we cannot prove a
# claim is someone else's, so we surface it and let the human decide.
#
# THE DRILL HAD BEEN RED FOR THREE DAYS AND NOBODY SAW IT, because nothing ran it. That is
# why gate-selfcheck.sh now runs this drill as G-H#drill. A drill that is not in a gate is a
# note, not a control.
unset GATE_ROSTER_WHO
chk "sibling" "$(_roster_other_claimant "$REPO")" "#1 no GATE_ROSTER_WHO -> EVERY live claim is reported (fail-safe, post-1979d80)"

# 1b — and with no identity, even a claim in what would be YOUR name is reported. Without an
# identity there is no 'your'. This is the deliberate over-report, pinned so that a future
# 'optimisation' restoring the self-exemption without an identity trips a named assertion.
unset GATE_ROSTER_WHO
chk "sibling" "$(_roster_other_claimant "$REPO")" "#1b no identity -> no self-exemption is possible"

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


# ── #9 · G-H#22c, attribution by FILENAME (acmeLedger-25) ────────────────────────
# Same extract-at-runtime discipline as above: a drill carrying its own copy of the
# logic passes forever while the real thing rots.
sed -n '/^_paths_owned_by_sibling() {/,/^}/p' "$GATE" > "$S/fn2.sh"
if ! grep -q 'kind=.session.' "$S/fn2.sh"; then
  echo "  FAIL  could not extract _paths_owned_by_sibling() from $GATE (moved or renamed?)"
  exit 1
fi
. "$S/fn2.sh"
addses() { # addses <who> <expires-offset>
  _sw="$(printf '%s' "$1" | sed "s/'/''/g")"
  sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster VALUES('$_sw','session','','t',
    strftime('%s','now'), strftime('%s','now')+$2);"
}
GATE_ROSTER_WHO="opus-acmeLedger-25"
addses opus-pitchingMachine-2 3600
addses opus-acmeLedger-25     3600
addses dead-oldSession-9      -3600

# POSITIVE: one untracked file carrying a live sibling's slug is attributed to them.
chk "opus-pitchingMachine-2" \
    "$(_paths_owned_by_sibling "$REPO" '?? HANDOFF-pitchingMachine-2.md')" \
    "#9 a file named for a live sibling is attributed to them"

# NEGATIVE, and the load-bearing one: ONE unattributable path and NOTHING is attributed.
# Otherwise a wrapping session could launder its own mess in behind a sibling's file.
chk "" \
    "$(printf '%s' "$(_paths_owned_by_sibling "$REPO" ' M my-own-half-finished-thing.py
?? HANDOFF-pitchingMachine-2.md')")" \
    "#9b one unattributable path => attribute nothing (no laundering)"

# NEGATIVE: a file named for YOUR OWN session is your problem, not a sibling's.
chk "" "$(_paths_owned_by_sibling "$REPO" '?? HANDOFF-acmeLedger-25.md')" \
    "#9c your own slug never downgrades your own dirt"

# NEGATIVE: an ENDED session's name is not a live excuse.
chk "" "$(_paths_owned_by_sibling "$REPO" '?? notes-oldSession-9.md')" \
    "#9d an expired session's slug does not attribute anything"

# NEGATIVE: a short slug is not evidence — 'cloud-e7J2AZ14' style ids must not match
# random substrings of ordinary filenames.
addses xx-abc 3600
chk "" "$(_paths_owned_by_sibling "$REPO" '?? abc.md')" \
    "#9e a too-short session slug is not evidence"

# a missing roster DB fails CLOSED here too.
ROSTER_DB_SAVED="$_ROSTER_DB"; _ROSTER_DB="$S/does-not-exist.sqlite3"
chk "" "$(_paths_owned_by_sibling "$REPO" '?? HANDOFF-pitchingMachine-2.md')" \
    "#9f missing roster DB -> no attribution, no crash"
_ROSTER_DB="$ROSTER_DB_SAVED"


# ── #10-#12 · IS THE FUNCTION ACTUALLY WIRED IN? (acmeLedger-30) ─────────────────
# Everything above tests _roster_other_claimant() in isolation. A unit test of a
# predicate cannot see whether the CALLER consults it, and on 2026-08-20 the answer was
# "only in one of the two places that needed it": the DIRTY branch downgraded a sibling's
# work to a WARN and the UNPUSHED branch failed the whole gate on the same sibling's
# commits. Every parallel session's wrap hit it. So these three read the SWEEP ITSELF.
SWEEP="$(sed -n '/repo hygiene sweep/,/^# --- G-S/p' "$GATE")"
if [ -z "$SWEEP" ]; then
  bad "#10 could not extract the G-H #22 sweep from $GATE (did the banner change?)"
else
  case "$SWEEP" in
    *'if [ -n "$dirty" ]'*'_claimant'*) ok "#10 the DIRTY branch consults the roster claimant" ;;
    *) bad "#10 the DIRTY branch no longer consults _roster_other_claimant" ;;
  esac
  # The unpushed branch must both KNOW about the claimant and still have a FAIL for the
  # unclaimed case. A downgrade that swallowed the FAIL entirely would pass a naive grep.
  _UP="$(printf '%s\n' "$SWEEP" | sed -n '/ahead.*-gt 0/,/^  fi$/p')"
  case "$_UP" in
    *'_claimant'*) ok "#11 the UNPUSHED branch consults the roster claimant too (G-H#22d)" ;;
    *) bad "#11 the UNPUSHED branch fails the gate on a sibling's in-flight commits — it does not consult _roster_other_claimant" ;;
  esac
  case "$_UP" in
    *'FAILS+='*) ok "#11b ...and an UNCLAIMED repo with unpushed commits is still a FAIL, which is the whole point of the check" ;;
    *) bad "#11b the UNPUSHED branch has no FAIL path left — the downgrade swallowed the control" ;;
  esac
  # G-H#stat, carded by acmeLedger-28: `git status` reports a merely-TOUCHED file as
  # modified from stat data alone. The sweep must refresh the index BEFORE reading status,
  # or it fails the gate on byte-identical content.
  case "$SWEEP" in
    *'update-index --refresh'*'git status --porcelain'*) ok "#12 the sweep refreshes the git index BEFORE reading status (no stat-dirty false FAIL)" ;;
    *) bad "#12 the sweep reads git status without refreshing the index first — a touched-but-unchanged file will be reported as an uncommitted change" ;;
  esac
fi

# ── #13-#14 · and the stat-dirty fix, on a real repo ─────────────────────────────
# You cannot observe a false positive that did not happen, so give it a fixture. Both
# columns matter: the second is what stops somebody "fixing" this by ignoring modified
# files altogether.
if command -v git >/dev/null 2>&1; then
  G="$S/statrepo"; mkdir -p "$G"
  ( cd "$G" && git init -q . && git config user.email d@d && git config user.name d \
    && printf 'hello\n' > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1
  ( cd "$G" && sleep 1 && touch f.txt )
  _st="$( cd "$G" && git update-index --refresh >/dev/null 2>&1 || true; cd "$G" && git status --porcelain )"
  chk "" "$_st" "#13 a TOUCHED but byte-identical file is CLEAN once the index is refreshed"
  ( cd "$G" && printf 'goodbye\n' > f.txt )
  _st2="$( cd "$G" && git update-index --refresh >/dev/null 2>&1 || true; cd "$G" && git status --porcelain )"
  case "$_st2" in
    *f.txt*) ok "#14 ...and a GENUINELY edited file is still DIRTY (the refresh does not blind the sweep)" ;;
    *) bad "#14 a genuinely edited file was reported clean — the refresh is hiding real work" ;;
  esac
else
  bad "#13 git not on PATH — the stat-dirty fixture could not run, so that fix is unproven this run"
fi

# ── #15-#20 · G-H#22e, DIRT KEEPS ITS AUTHOR'S NAME PAST CLAIM TTL (luxuryDesk-03) ──
# SM 1218069101293488, fix 4 of the priority card. The roster prunes a claim on TTL, so a
# sibling quiet for five hours used to have its in-flight dirt re-graded from "WARN, theirs"
# to "FAIL, unowned" for every other desk. `roster claim` now also appends to a claim journal
# beside the DB (same dirname as ROSTER_DB, so THIS scratch DB isolates it), and the gate asks
# red-owner.py (the AAR family's MINE/SIBLING/TRANSFERRED/ORPHAN table) before calling any
# dirt anonymous. Same extract-at-runtime discipline: the function under test is the gate's.
sed -n '/^_dirt_author_verdict() {/,/^}/p' "$GATE" > "$S/fn3.sh"
if ! grep -q 'repo-owner' "$S/fn3.sh"; then
  echo "  FAIL  could not extract _dirt_author_verdict() from $GATE (moved or renamed?)"
  exit 1
fi
_RED_OWNER="${RED_OWNER:-$HOME/repos/ceo-desk/red-owner.py}"
. "$S/fn3.sh"
if [ ! -f "$_RED_OWNER" ]; then
  bad "#15 red-owner.py not found at $_RED_OWNER — G-H#22e is unproven this run"
else
  JOURNAL="$S/claim-journal.jsonl"
  _now="$(date +%s)"
  jrow() { # jrow <who> <resource> <hours-ago>
    printf '{"ts": %s, "who": "%s", "resource": "%s", "task": "t", "event": "claim"}\n' \
      "$(( _now - $3 * 3600 ))" "$1" "$2" >> "$JOURNAL"
  }
  : > "$JOURNAL"
  jrow zzGoneAuthor  gonerepo   5          # claim expired 5h ago, session gone: THE CASE ON THE CARD
  jrow zzQuietLive   quietrepo  5          # claim lapsed 5h ago, but the session row is still live
  jrow zzMeDrill     myrepo     5          # my own lapsed claim
  addses zzQuietLive 3600
  addses zzMeDrill   3600
  export RED_OWNER_STATE="$S/red-owner-state"     # transfers ledger stays scratch too
  _T=$'\t'
  GATE_ROSTER_WHO=zzMeDrill
  _v="$(_dirt_author_verdict "$S/gonerepo")"
  chk "ORPHAN${_T}zzGoneAuthor" "${_v%${_T}*}" "#15 THE CARD'S CASE: claim expired 5h ago, author dead -> ORPHAN that still NAMES zzGoneAuthor (never anonymous)"
  case "$_v" in *"5.0h ago"*) ok "#15b ...and the note says how long ago the author last claimed it" ;; *) bad "#15b note lacks the claim age (got '$_v')" ;; esac
  _v="$(_dirt_author_verdict "$S/quietrepo")"
  chk "SIBLING${_T}zzQuietLive" "${_v%${_T}*}" "#16 claim lapsed 5h ago but the session is LIVE -> SIBLING (WARN naming them), not FAIL"
  _v="$(_dirt_author_verdict "$S/myrepo")"
  chk "MINE${_T}zzMeDrill" "${_v%${_T}*}" "#17 my OWN lapsed claim -> MINE (the journal cannot launder your own dirt)"
  _v="$(_dirt_author_verdict "$S/neverclaimed")"
  chk "ORPHAN${_T}" "${_v%${_T}*}" "#18 never claimed, never journaled -> honest anonymous ORPHAN (the old behaviour, now the exception)"
  # a LIVE claim still outranks the journal (present tense wins)
  addses zzFreshClaimer 3600; add zzFreshClaimer gonerepo 3600
  _v="$(_dirt_author_verdict "$S/gonerepo")"
  chk "SIBLING${_T}zzFreshClaimer" "${_v%${_T}*}" "#19 a fresh live claim outranks an older journal author"
  # fail-closed: a missing red-owner answers NOTHING (the sweep then falls through to the anonymous FAIL)
  _RO_SAVED="$_RED_OWNER"; _RED_OWNER="$S/does-not-exist.py"
  chk "" "$(_dirt_author_verdict "$S/gonerepo")" "#20 missing red-owner.py -> empty answer, no crash (sweep falls through to the anonymous FAIL)"
  _RED_OWNER="$_RO_SAVED"
  unset RED_OWNER_STATE
fi

# ── #21 · IS #22e WIRED INTO THE SWEEP? ──────────────────────────────────────────
if [ -n "$SWEEP" ]; then
  case "$SWEEP" in
    *'_dirt_author_verdict "$repo"'*) ok "#21 the DIRTY branch asks the claim journal for the author before calling dirt anonymous (G-H#22e)" ;;
    *) bad "#21 the DIRTY branch does not consult _dirt_author_verdict — dirt past claim TTL reads as anonymous again" ;;
  esac
  case "$SWEEP" in
    *'ORPHAN)'*'FAILS+='*) ok "#21b ...and an ORPHAN is still a FAIL (attribution, not absolution)" ;;
    *) bad "#21b the ORPHAN branch has no FAIL — the journal became an amnesty" ;;
  esac
fi

echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
