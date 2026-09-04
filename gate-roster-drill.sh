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
  # as the setup that feeds it. (deskTenancy-02: and NAME the columns -- the real roster
  # migrated the scratch DB to 7 columns mid-drill and every positional INSERT broke, 9 FAILs.)
  _aw="$(printf '%s' "$1" | sed "s/'/''/g")"; _ar="$(printf '%s' "$2" | sed "s/'/''/g")"
  sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster(who,kind,resource,task,started,expires) VALUES('$_aw','claim','$_ar','t',
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

# 4b — an UNEXPIRED but STALE claim is not a live one either (luxuryDesk-14, 2026-09-02).
# `join` auto-claims the everything folder for 24h; a desk that died at hour 1 leaves a claim
# that is "live" by expiry for another 23h. The board (`roster who`) and red-owner.py call a
# claim >4h old STALE; this function called it LIVE and held the FAIL->WARN downgrade open.
# One threshold, one reader: the function asks `roster live-claimant` now. Both halves pinned:
sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster(who,kind,resource,task,started,expires) VALUES('parity01','claim','stale-live-repo','t',
  strftime('%s','now')-20*3600, strftime('%s','now')+4*3600);"
chk "" "$(_roster_other_claimant "$S/stale-live-repo")" "#4b a 20h-old claim with 4h of TTL left does NOT downgrade (fresh, not merely unexpired)"
sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster(who,kind,resource,task,started,expires) VALUES('parity02','claim','fresh-repo','t',
  strftime('%s','now')-3*3600, strftime('%s','now')+4*3600);"
chk "parity02" "$(_roster_other_claimant "$S/fresh-repo")" "#4c ...and a 3h-old claim still does (the threshold is 4h, the roster's STALE_CLAIM_H)"
case "$(sed -n '/^_roster_other_claimant() {/,/^}/p' "$GATE")" in
  *'live-claimant'*) ok "#4d the gate ASKS roster (live-claimant) rather than carrying its own liveness SQL" ;;
  *) bad "#4d the gate no longer calls 'roster live-claimant' — a second copy of the threshold is back" ;;
esac

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
  sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster(who,kind,resource,task,started,expires) VALUES('$_sw','session','','t',
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

# ── #22 · G-H#22f, DIRT IS ATTRIBUTED BY MTIME TO THE SIBLING WHO WAS LIVE (deskTenancy-01) ──
# luxuryDesk-18 hit it live: cekuC4JA wrote n8n-stack files 10:53–10:57 while on the roster with
# no claim and no journal row, and the gate told -18 the dirt was YOURS. The function under test
# is the gate's own, extracted at runtime; the roster is THIS scratch DB; the files are touched
# to chosen mtimes so the windows are exact.
sed -n '/^_dirt_mtime_sibling() {/,/^}/p' "$GATE" > "$S/fn4.sh"
if ! grep -q 'kind=.session' "$S/fn4.sh"; then
  bad "#22 could not extract _dirt_mtime_sibling() from $GATE — G-H#22f is unproven this run"
else
  . "$S/fn4.sh"
  sqlite3 "$ROSTER_DB" "DELETE FROM roster WHERE kind='session';"
  _now="$(date +%s)"
  addses_at() { # addses_at <who> <started-seconds-ago> <expires-offset>
    sqlite3 "$ROSTER_DB" "INSERT OR REPLACE INTO roster(who,kind,resource,task,started,expires) VALUES('$1','session','','t', $(( _now - $2 )), $(( _now + $3 )));"
  }
  addses_at zzMeDrill     3600  3600     # I sat down 1h ago
  addses_at zzLiveSib     7200  3600     # the sibling sat down 2h ago, still live
  addses_at zzGoneSib    10800 -600      # a sibling whose session EXPIRED 10 min ago
  M="$S/mtrepo"; mkdir -p "$M"
  _touch_ago() { touch -t "$(date -r $(( _now - $2 )) +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$(( _now - $2 ))" +%Y%m%d%H%M.%S)" "$1"; }
  : > "$M/a.txt"; _touch_ago "$M/a.txt" 5400          # 90 min ago: inside zzLiveSib's window, BEFORE mine
  GATE_ROSTER_WHO=zzMeDrill
  _T=$'\t'
  _v="$(_dirt_mtime_sibling "$M" "?? a.txt")"
  chk "zzLiveSib" "${_v%%${_T}*}" "#22a THE CARD'S CASE: unclaimed, unjournaled dirt written while zzLiveSib was live -> attributed to zzLiveSib (WARN 'claim owed by', not YOURS)"
  case "$_v" in *"inside YOURS too"*) bad "#22a2 the note blames my window for a file written before I sat down" ;; *) ok "#22a2 ...and the note does NOT say my window covers it (it was written before I sat down)" ;; esac
  : > "$M/b.txt"; _touch_ago "$M/b.txt" 600           # 10 min ago: inside BOTH windows
  _v="$(_dirt_mtime_sibling "$M" "?? b.txt")"
  case "$_v" in "zzLiveSib${_T}"*"inside YOURS too"*) ok "#22b a file written while BOTH were live is still the sibling's WARN — and the note says my window covers it too (no laundering in silence)" ;; *) bad "#22b ambiguous-window note missing (got '$_v')" ;; esac
  : > "$M/c.txt"; _touch_ago "$M/c.txt" 9000          # 150 min ago: BEFORE zzLiveSib sat down
  chk "" "$(_dirt_mtime_sibling "$M" "?? c.txt")" "#22c dirt older than every live sibling's window -> nothing attributed (falls through to the FAIL)"
  chk "" "$(_dirt_mtime_sibling "$M" "?? a.txt
?? c.txt")" "#22d ONE unattributable path poisons the set -> nothing attributed (fail-closed, like #22c)"
  chk "" "$(_dirt_mtime_sibling "$M" " D gone.txt")" "#22e a DELETED path has no mtime -> nothing attributed (fail-closed)"
  sqlite3 "$ROSTER_DB" "DELETE FROM roster WHERE who='zzLiveSib';"
  chk "" "$(_dirt_mtime_sibling "$M" "?? a.txt")" "#22f with the sibling gone (only an EXPIRED one left) -> nothing attributed; an expired session is not a window"
  # #22i/#22j (deskTenancy-02): `expires` is a 24h TTL; LIVENESS is last_seen (THE ONE RULE,
  # `roster constants`). The handoff's case: a quiet-6h sibling inside its TTL counted as a
  # window here while `roster who` called it quiet. Scratch schema pre-dates the column, so
  # add it the way the real migration does.
  # (the scratch DB may already carry the column: any `roster` call above migrates it)
  sqlite3 "$ROSTER_DB" "PRAGMA table_info(roster);" | grep -q '|last_seen|' || sqlite3 "$ROSTER_DB" "ALTER TABLE roster ADD COLUMN last_seen INTEGER;"
  addses_at zzQuietSib 28800 57600     # sat down 8h ago, 16h of TTL left, never seen since
  sqlite3 "$ROSTER_DB" "UPDATE roster SET last_seen=started WHERE who='zzQuietSib';"
  chk "" "$(_dirt_mtime_sibling "$M" "?? a.txt")" "#22i a sibling QUIET >QUIET_H but inside its TTL is NOT a window -> nothing attributed (roster who and #22f agree)"
  sqlite3 "$ROSTER_DB" "UPDATE roster SET last_seen=$(( _now - 300 )) WHERE who='zzQuietSib';"
  _v="$(_dirt_mtime_sibling "$M" "?? a.txt")"
  chk "zzQuietSib" "${_v%%${_T}*}" "#22j ...and the same sibling SEEN 5 min ago is a window again (its 8h-old start still covers a.txt)"
  case "$SWEEP" in
    *'_dirt_mtime_sibling "$repo" "$dirty"'*'claim owed by'*) ok "#22g the sweep asks _dirt_mtime_sibling before the anonymous FAIL and the WARN says 'claim owed by'" ;;
    *) bad "#22g G-H#22f is not wired into the DIRTY branch (or the WARN lost its 'claim owed by' wording)" ;;
  esac
  case "$SWEEP" in
    *'(G-H#22f), so it is being reported as YOURS'*) ok "#22h ...and the anonymous FAIL survives beneath it (attribution, not absolution)" ;;
    *) bad "#22h the anonymous FAIL is gone — #22f became an amnesty" ;;
  esac
fi

# ── #23 · G-H#22g-unrostered, THE ACTOR THE ROSTER CANNOT SEE (smDrainHandoff-2) ──
# SM 1218125780430801. #22c/#22c-content/#22e/#22f are four voices asking the SAME source —
# the roster — and they are all blind to a session that never ran `roster join`. When they all
# decline, the fallback beneath them said "reported as YOURS", which is a wrong answer, not a
# weak one, and its only remedy is to commit a sibling's in-flight work. This rung looks at the
# one thing none of them do: a repo does not commit itself, so a RECENT HEAD proves an actor.
# Same extract-at-runtime discipline — the function under test is the gate's own.
sed -n '/^_dirt_recent_unrostered() {/,/^}/p' "$GATE" > "$S/fn5.sh"
if ! grep -q 'QUIET_H' "$S/fn5.sh"; then
  bad "#23 could not extract _dirt_recent_unrostered() from $GATE — G-H#22g-unrostered is unproven this run"
elif ! command -v git >/dev/null 2>&1; then
  bad "#23 git not on PATH — G-H#22g-unrostered is unproven this run"
else
  . "$S/fn5.sh"
  _mkrepo() { # _mkrepo <dir> <committer-date-or-empty>
    mkdir -p "$1"
    ( cd "$1" && git init -q . && git config user.email d@d && git config user.name "zzUnrostered" \
      && printf 'x\n' > f.txt && git add f.txt \
      && if [ -n "$2" ]; then GIT_AUTHOR_DATE="$2" GIT_COMMITTER_DATE="$2" git commit -qm init; else git commit -qm init; fi ) >/dev/null 2>&1
  }
  # POSITIVE, and it is THE CARD'S CASE: book-typeset's HEAD was authored nine minutes before
  # smBacklog-5's wrap by a session with no roster row. A fresh HEAD in an unclaimed repo is an
  # actor the roster cannot name -> UNATTRIBUTED, with the commit as the evidence.
  U="$S/freshrepo"; _mkrepo "$U" ""
  _v="$(_dirt_recent_unrostered "$U")"
  case "$_v" in
    *"authored by \"zzUnrostered\""*"min ago"*) ok "#23a THE CARD'S CASE: a HEAD inside the live window names the actor the roster cannot -> UNATTRIBUTED, not YOURS" ;;
    *) bad "#23a a fresh HEAD in an unclaimed repo attributed nothing (got '$_v')" ;;
  esac
  case "$_v" in *"including you"*) ok "#23a2 ...and the note says the roster names nobody INCLUDING you — the whole point is that it stops guessing" ;; *) bad "#23a2 the note no longer says the roster cannot name you either (got '$_v')" ;; esac
  # NEGATIVE, and the load-bearing one: a STALE HEAD attributes NOTHING. Weeks of uncommitted
  # work in a repo nobody has touched is the bite this check was BUILT for (Jason's), and it has
  # no recent actor to point at. If this control ever flips, the downgrade has eaten the check.
  O="$S/oldrepo"; _mkrepo "$O" "2026-01-01T00:00:00+0000"
  chk "" "$(_dirt_recent_unrostered "$O")" "#23b a HEAD older than QUIET_H attributes NOTHING -> the anonymous FAIL stands (the weeks-of-dirt bite is intact)"
  # NEGATIVE: clock skew is not evidence. A commit dated in the future must not read as 'recent'.
  F="$S/futurerepo"; _mkrepo "$F" "$(date -r $(( $(date +%s) + 7200 )) +%Y-%m-%dT%H:%M:%S 2>/dev/null || date -d "@$(( $(date +%s) + 7200 ))" +%Y-%m-%dT%H:%M:%S)"
  chk "" "$(_dirt_recent_unrostered "$F")" "#23c a future-dated (clock-skewed) commit proves nothing -> nothing attributed"
  # NEGATIVE: fail-closed on a repo with NO commits, and on a directory that is not a repo at all.
  E="$S/emptyrepo"; mkdir -p "$E"; ( cd "$E" && git init -q . ) >/dev/null 2>&1
  chk "" "$(_dirt_recent_unrostered "$E")" "#23d a repo with no commits has no actor -> nothing attributed, no crash"
  N="$S/notarepo"; mkdir -p "$N"
  chk "" "$(_dirt_recent_unrostered "$N")" "#23e a non-repo path -> nothing attributed, no crash (fail-closed)"
fi

# ── #24 · IS #22g-unrostered WIRED IN, AT THE RIGHT RUNG? ────────────────────────
# A predicate the sweep never calls is a note, not a control — and one called too EARLY is worse
# than absent, because an anonymous "UNATTRIBUTED" would pre-empt #22f's answer, which actually
# NAMES a live sibling. Both anonymous-FAIL sites (the ORPHAN-with-no-author branch and the
# no-verdict default) had the same wrong fallback, so both must have the same new rung.
if [ -n "$SWEEP" ]; then
  _n="$(printf '%s\n' "$SWEEP" | grep -c '_dirt_recent_unrostered "\$repo"')"
  chk "2" "$_n" "#24 BOTH anonymous-FAIL sites consult _dirt_recent_unrostered (G-H#22g-unrostered)"
  case "$SWEEP" in
    *'UNATTRIBUTED, which is the answer, not a softer way of saying YOURS'*) ok "#24b the WARN says UNATTRIBUTED out loud — the card's whole finding is that 'YOURS' was a wrong answer, not a weak one" ;;
    *) bad "#24b the UNATTRIBUTED wording is gone — the WARN no longer distinguishes 'cannot tell' from 'yours'" ;;
  esac
  case "$SWEEP" in
    *'Do NOT commit it blind'*'roster claim'*) ok "#24c ...and it hands the reader BOTH branches: do not commit a sibling's work, and if it IS yours you owe a claim (it declines to guess, it does not grant an amnesty)" ;;
    *) bad "#24c the WARN lost one of its two branches — either the 'do not commit' instruction or the 'if it is yours, claim it' one" ;;
  esac
  # ORDERING: the mtime rung, which NAMES a live sibling, must be asked BEFORE the anonymous one.
  _mt_at="$(printf '%s\n' "$SWEEP" | grep -n '_dirt_mtime_sibling "\$repo" "\$dirty"' | head -1 | cut -d: -f1)"
  _ur_at="$(printf '%s\n' "$SWEEP" | grep -n '_dirt_recent_unrostered "\$repo"' | head -1 | cut -d: -f1)"
  if [ -n "$_mt_at" ] && [ -n "$_ur_at" ] && [ "$_mt_at" -lt "$_ur_at" ]; then
    ok "#24d #22f (names a live sibling) is asked BEFORE #22g-unrostered (names nobody) — a stronger answer is never pre-empted by a weaker one"
  else
    bad "#24d the anonymous UNATTRIBUTED rung is asked before #22f — an answer that NAMES a sibling is being pre-empted (mt=$_mt_at ur=$_ur_at)"
  fi
  # ...and the FAIL still exists beneath BOTH of them. #22h pins one; this pins that neither was
  # swallowed, which is the failure mode a downgrade actually has.
  # anchored on FAILS+= on purpose: the sweep's own comments quote the sentence, and a control
  # that counts PROSE would go green on a rung that had been reduced to a comment about itself.
  _f="$(printf '%s\n' "$SWEEP" | grep -c 'FAILS+=.*so it is being reported as YOURS')"
  chk "2" "$_f" "#24e both anonymous FAILs survive beneath the new rung (attribution, not absolution)"
  # --- SM 1218147386804343 · the ORPHAN remediation must survive its own failure mode ---
  # The gate FAILs an orphan by telling the reader to run `red-owner.py transfer`. That command has
  # two ways to answer "is not a live red right now" that mean opposite things (a root red-owner does
  # not scan = a dead end; a tree that went clean = nothing owed), and the carding session could not
  # tell them apart. Anchored on FAILS+= for the same reason #24e is: the comment above the rung
  # quotes the remediation, and a prose-counting control goes green on a rung reduced to prose.
  _rem="$(printf '%s\n' "$SWEEP" | grep -c 'FAILS+=.*red-owner.py transfer')"
  chk "1" "$_rem" "#25 the ORPHAN FAIL still names red-owner.py transfer as the remediation"
  case "$SWEEP" in
    *'SCOPE gap'*'CLEAN = the dirt cleared'*)
      ok "#25a ...and it tells the reader how to read that command's refusal — SCOPE gap (remediation can never succeed) vs CLEAN (red cleared, nothing owed)" ;;
    *) bad "#25a the ORPHAN remediation no longer distinguishes red-owner's two refusals, so a session that hits one is back to guessing (SM 1218147386804343)" ;;
  esac
  case "$SWEEP" in
    *"Do NOT commit a dead session's half-finished work as your own"*)
      ok "#25b NEGATIVE CONTROL: the new sentence did not displace the doctrine line it sits beside" ;;
    *) bad "#25b the ORPHAN FAIL lost 'do NOT commit a dead session's half-finished work' — the remediation grew and the prohibition went with it" ;;
  esac
fi

echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
