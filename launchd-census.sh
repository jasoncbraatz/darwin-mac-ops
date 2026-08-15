#!/bin/bash
# launchd-census.sh — inventory darwin's scheduled jobs and prove each one is repo-backed
#                     AND that the backed copy would actually reproduce it.
#
# WHY THIS EXISTS (found S38, 2026-08-07, while installing com.braatz.flowers-hmac-enforce-watch)
#   darwin's automation is real infrastructure — the AAR gate, the detector heartbeat watch, the
#   dsh-fire poller darlish itself rides on — and every one of those jobs is DEFINED by a plist
#   in ~/Library/LaunchAgents. Some plists are repo-backed per-project (strike-zone/provision/launchd,
#   darwin-mac-ops/photo-sync/launchagents, ...). Many are not backed anywhere at all. Per the
#   geography doctrine darwin is the workshop, not the vault: it is one uninsured SSD with an
#   unknown MTBF. A dead disk would take the *schedule* with it — the scripts survive in git, but
#   nothing would remember that aar-gate runs at 09:00 or that the poller has a 60s interval, and
#   the loss is silent because a job that never runs looks exactly like a job with nothing to say.
#
# WHAT acmeLedger-23 FOUND IN IT (2026-08-15) — three ways this asked a narrower question than
# its own title. acmeLedger-22 proved every gate step still SPEAKS when its instrument is gone;
# the next question is whether the instrument that speaks is aimed at the right subject.
#
#   D1 THE SUBJECT WAS A HARDCODED GUESS. The census enumerated
#         launchctl list | grep -E '^(com\.braatz|com\.strikezone)\.'
#      while its banner promised "every loaded job". Those are the two namespaces that happened
#      to exist on 2026-08-07. Measured on 2026-08-15: `com.user.ttyd` — a loaded, KeepAlive,
#      writable-shell job listening on *:7681 — had never once been in this census's subject.
#      It reported "N repo-backed, 0 unbacked" and was telling the truth about a set that did
#      not contain the job. A filter written as an allowlist of the known fails OPEN on the new:
#      the next `com.foo.*` job anyone installs is invisible on the day it is installed.
#      NOW: enumerate everything loaded, subtract Apple and `application.*` GUI registrations,
#      subtract a FOREIGN allowlist that carries a reason per entry, and treat whatever is left
#      as ESTATE — including namespaces nobody has thought of yet. Unknown counts as ours.
#
#   D2 "BACKED" MEANT A FILE OF THAT NAME EXISTED, NOT THAT IT WOULD REPRODUCE THE JOB. The old
#      test was `find -name "$label.plist"` + "is it in a git repo". It never opened either file.
#      This header says the point is that "a rebuild inherits them"; existence is not inheritance.
#      Measured: ~/repos/ttyd-darwin/com.user.ttyd.plist is committed, and it omits the `-c
#      user:pass` argument the live job runs with. Restoring that vault copy onto a rebuilt Mac
#      does not fail — it starts `ttyd -W zsh` with NO AUTHENTICATION: a writable shell on every
#      interface. The backed copy diverged from the live one in the fail-OPEN direction and the
#      check that exists to make rebuilds safe returned ok. NOW: compare content, and count
#      DIVERGED as its own outcome with its own exit code.
#
#   D3 `| head -1` MADE THE COMPARISON SUBJECT NONDETERMINISTIC. Three copies of the ttyd plist
#      exist under the search roots, one of them inside ~/Desktop/downloads/model-name-recon/ —
#      a stale nested clone in the working cache. Whichever `find` happened to print first would
#      have been the "backing". NOW: collect every hit, prefer real vault repos over the
#      everything-folder cache, and say out loud when copies disagree with each other.
#
#   This is READ-ONLY and writes no cards. It prints drift; a human (or gate-selfcheck) acts on it.
#
# EXIT CONTRACT
#   0 = every loaded ESTATE job has a repo-backed plist whose content matches the live one
#       (or whose divergence is ratified with a reason)
#   1 = at least one job is unbacked (its schedule exists nowhere but this Mac) or loaded-but-gone
#   2 = could not enumerate (launchctl or the LaunchAgents dir unavailable) — NOT a pass
#   3 = backed but DIVERGED and unratified: the vault copy would not reproduce the running job
set -uo pipefail

AGENTS="${LC_AGENTS:-$HOME/Library/LaunchAgents}"
SEARCH_ROOTS="${LC_SEARCH_ROOTS:-$HOME/code/darwin-mac-ops $HOME/repos $HOME/Scripts $HOME/Desktop/downloads}"
# Two allowlists, each carrying a REASON per line, same shape as bb-writers-allowlist.json.
# Overridable so the drill can point them at fixtures.
FOREIGN_LIST="${LC_FOREIGN_LIST:-$HOME/code/darwin-mac-ops/launchd-foreign-allowlist.txt}"
DIVERGE_LIST="${LC_DIVERGE_LIST:-$HOME/code/darwin-mac-ops/launchd-divergence-allowlist.txt}"
QUIET="${LC_QUIET:-}"
# The drill feeds a canned `launchctl list` so the classifier can be exercised without
# installing real jobs on Jason's Mac.
LOADED_FIXTURE="${LC_LOADED_FIXTURE:-}"

[ -d "$AGENTS" ] || { echo "CANNOT VERIFY: $AGENTS missing" >&2; exit 2; }
if [ -z "$LOADED_FIXTURE" ]; then
  command -v launchctl >/dev/null || { echo "CANNOT VERIFY: no launchctl" >&2; exit 2; }
fi

# --- read the allowlists (blank lines and #-comments ignored; a bare glob is the pattern) -------
# A missing allowlist is NOT fatal: with no foreign entries every third-party job simply lands in
# ESTATE and gets reported as unbacked. That is the fail-closed direction, which is the one we
# want when a control's own config goes missing.
read_globs() {  # $1=file
  [ -f "$1" ] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | grep -v '^$'
}
FOREIGN_GLOBS="$(read_globs "$FOREIGN_LIST")"
DIVERGE_GLOBS="$(read_globs "$DIVERGE_LIST")"

matches_any() {  # $1=label, $2=newline-separated globs
  local label="$1" globs="$2" g
  [ -n "$globs" ] || return 1
  while IFS= read -r g; do
    [ -n "$g" ] || continue
    # shellcheck disable=SC2254
    case "$label" in $g) return 0 ;; esac
  done <<< "$globs"
  return 1
}

# --- enumerate what is LOADED ------------------------------------------------------------------
# The census is over what is LOADED, not what is on disk: a .disabled/.bak/.RETIRED plist sitting
# in the folder is archaeology, but a loaded job with no backup is a live single point of failure.
if [ -n "$LOADED_FIXTURE" ]; then
  RAW="$(cat "$LOADED_FIXTURE")"
else
  RAW="$(launchctl list 2>/dev/null | awk '{print $3}')"
fi
# Drop the header row and PID/status columns that awk can pick up on odd lines.
ALL="$(printf '%s\n' "$RAW" | grep -vE '^(Label|0x[0-9a-f]+|-|[0-9]+)?$' | sort -u)"
[ -n "$ALL" ] || { echo "CANNOT VERIFY: launchctl listed no jobs at all" >&2; exit 2; }

n_all=0; n_apple=0; n_gui=0; n_foreign=0
ESTATE=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  n_all=$((n_all+1))
  case "$label" in
    com.apple.*)      n_apple=$((n_apple+1));   continue ;;
    application.*)    n_gui=$((n_gui+1));       continue ;;   # GUI app registrations, not schedules
  esac
  if matches_any "$label" "$FOREIGN_GLOBS"; then
    n_foreign=$((n_foreign+1)); continue
  fi
  ESTATE="$ESTATE$label
"
done <<< "$ALL"

n_estate="$(printf '%s' "$ESTATE" | grep -c . || true)"
# NON-VACUITY. A classifier that lands zero jobs in ESTATE has almost certainly been mis-aimed
# (an over-broad foreign glob, a fixture typo) and would then report a serene "0 unbacked".
# acmeLedger-22's G-AH lesson, one file over: a verdict tool that never counts what it scanned
# cannot tell "found nothing" from "looked at nothing".
if [ "$n_estate" -eq 0 ]; then
  echo "CANNOT VERIFY: classified $n_all loaded job(s) and NONE landed in the estate bucket -- the filter is broken, not the estate empty" >&2
  echo "               (apple=$n_apple gui=$n_gui foreign=$n_foreign; check $FOREIGN_LIST for an over-broad glob)" >&2
  exit 2
fi

backed=0; unbacked=0; missing=0; diverged=0; ratified=0
UNBACKED_LIST=""; DIVERGED_LIST=""

# ── PLIST INDEX · walk the roots ONCE (acmeLedger-24, 2026-08-15) ───────────────────────
# D1's widening (acmeLedger-23) turned the subject from 2 hardcoded namespaces into every
# loaded estate job -- correct, and it moved the per-label `find $SEARCH_ROOTS` from ~7
# iterations to 36. One of those roots is ~/Desktop/downloads, the everything folder, which
# is large enough that a `grep -r` over it times out a 180s dx call. MEASURED: the census
# took 279s standalone, and gate-selfcheck.sh runs it on every wrap. That is the shape of a
# control people quietly stop running, and "a disabled gate is indistinguishable from a
# passing one" is this estate's own rule. Same subject, same answers, one walk instead of 36.
#
# Non-vacuity: an EMPTY index means the roots are not on this machine or find broke, not that
# nothing is backed. Without this, all 36 jobs would read "unbacked" and the remedy would tell
# someone to commit 36 plists that are already committed -- the acmeLedger-23 exit-3 lesson.
PLIST_INDEX="$(mktemp -t lcidx)"
trap 'rm -f "$PLIST_INDEX"' EXIT
find $SEARCH_ROOTS -name '*.plist' -not -path "$AGENTS/*" -not -path '*/.git/*' 2>/dev/null | sort > "$PLIST_INDEX"
if [ ! -s "$PLIST_INDEX" ]; then
  echo "launchd-census: CANNOT VERIFY -- the plist index is EMPTY: no *.plist found anywhere under" >&2
  echo "                $SEARCH_ROOTS" >&2
  echo "                Every job would read as unbacked, which would be the index failing, not the estate." >&2
  echo "launchd-census: CANNOT VERIFY (empty plist index over the search roots)"
  exit 2
fi

while IFS= read -r label; do
  [ -n "$label" ] || continue
  src="$AGENTS/$label.plist"
  if [ ! -f "$src" ]; then
    # loaded but no plist on disk — a job running from a definition that has already vanished
    missing=$((missing+1)); UNBACKED_LIST="$UNBACKED_LIST
  $label  (LOADED but no plist in $AGENTS — definition already gone)"
    continue
  fi

  # Collect EVERY backing candidate, not just whichever find printed first (D3). A hit only
  # counts if it is inside a git repo -- a loose copy in a non-repo directory is not a vault.
  hits=""
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    git -C "$(dirname "$h")" rev-parse --git-dir >/dev/null 2>&1 || continue
    hits="$hits$h
"
  done <<< "$(awk -F/ -v want="$label.plist" '$NF == want' "$PLIST_INDEX")"

  if [ -z "$hits" ]; then
    unbacked=$((unbacked+1)); UNBACKED_LIST="$UNBACKED_LIST
  $label  (plist exists, but only on this Mac)"
    continue
  fi

  # Prefer a hit outside the everything folder: ~/Desktop/downloads is Jason's working CACHE,
  # explicitly "a great cache, not a vault", and it holds stale nested clones. A copy there is
  # accepted as a last resort but never as the canonical backing while a real repo copy exists.
  primary="$(printf '%s' "$hits" | grep -v "^$HOME/Desktop/downloads/" | head -1)"
  [ -n "$primary" ] || primary="$(printf '%s' "$hits" | head -1)"

  if cmp -s "$src" "$primary"; then
    backed=$((backed+1))
    [ -z "$QUIET" ] && printf '  ok        %-46s -> %s\n' "$label" "${primary/#$HOME/~}"
    continue
  fi

  # Backed, but the vault copy would NOT reproduce the running job (D2).
  if matches_any "$label" "$DIVERGE_GLOBS"; then
    ratified=$((ratified+1)); backed=$((backed+1))
    [ -z "$QUIET" ] && printf '  ok(div)   %-46s -> %s  (divergence ratified in %s)\n' \
      "$label" "${primary/#$HOME/~}" "$(basename "$DIVERGE_LIST")"
    continue
  fi
  diverged=$((diverged+1))
  DIVERGED_LIST="$DIVERGED_LIST
  $label
    live:   $src
    vault:  $primary
$(diff -u "$primary" "$src" 2>/dev/null | sed -n '3,40p' | sed 's/^/      /')"
done <<< "$ESTATE"

printf '\nlaunchd-census: %d repo-backed (%d ratified-divergent), %d unbacked, %d loaded-but-missing, %d DIVERGED — %d estate job(s) of %d loaded (apple=%d gui=%d foreign=%d)\n' \
  "$backed" "$ratified" "$unbacked" "$missing" "$diverged" "$n_estate" "$n_all" "$n_apple" "$n_gui" "$n_foreign"

if [ "$unbacked" -gt 0 ] || [ "$missing" -gt 0 ]; then
  printf 'UNBACKED — these schedules exist nowhere but darwin:%s\n' "$UNBACKED_LIST"
  printf '\nFix: copy each plist beside the script it runs, inside that script'"'"'s repo, then commit.\n'
  exit 1
fi
if [ "$diverged" -gt 0 ]; then
  printf 'DIVERGED — the vault copy would NOT reproduce the running job:%s\n' "$DIVERGED_LIST"
  printf '\nFix: reconcile the two, or ratify the difference WITH A REASON in %s\n' "${DIVERGE_LIST/#$HOME/~}"
  printf '     (a deliberate omission — e.g. a credential that must not be committed — is a\n'
  printf '      legitimate ratification ONLY if restoring without it fails CLOSED. Check that.)\n'
  exit 3
fi
exit 0
