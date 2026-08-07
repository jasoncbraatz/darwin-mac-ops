#!/bin/bash
# launchd-census.sh — inventory darwin's scheduled jobs and prove each one is repo-backed.
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
#   This is READ-ONLY and writes no cards. It prints drift; a human (or gate-selfcheck) acts on it.
#
# EXIT CONTRACT
#   0 = every loaded com.braatz/com.strikezone job has a plist copy somewhere under a git repo
#   1 = at least one job is unbacked (its schedule exists nowhere but this Mac)
#   2 = could not enumerate (launchctl or the LaunchAgents dir unavailable) — NOT a pass
set -uo pipefail

AGENTS="$HOME/Library/LaunchAgents"
SEARCH_ROOTS="$HOME/code/darwin-mac-ops $HOME/repos/strike-zone $HOME/repos $HOME/Scripts"
QUIET="${LC_QUIET:-}"

[ -d "$AGENTS" ] || { echo "CANNOT VERIFY: $AGENTS missing" >&2; exit 2; }
command -v launchctl >/dev/null || { echo "CANNOT VERIFY: no launchctl" >&2; exit 2; }

# The census is over what is LOADED, not what is on disk: a .disabled/.bak/.RETIRED plist sitting
# in the folder is archaeology, but a loaded job with no backup is a live single point of failure.
LOADED="$(launchctl list 2>/dev/null | awk '{print $3}' | grep -E '^(com\.braatz|com\.strikezone)\.' | sort -u)"
[ -n "$LOADED" ] || { echo "CANNOT VERIFY: launchctl listed no com.braatz/com.strikezone jobs" >&2; exit 2; }

backed=0; unbacked=0; missing=0; UNBACKED_LIST=""
while IFS= read -r label; do
  [ -n "$label" ] || continue
  src="$AGENTS/$label.plist"
  if [ ! -f "$src" ]; then
    # loaded but no plist on disk — a job running from a definition that has already vanished
    missing=$((missing+1)); UNBACKED_LIST="$UNBACKED_LIST
  $label  (LOADED but no plist in $AGENTS — definition already gone)"
    continue
  fi
  # repo-backed = a file of the same name exists under a search root that is inside a git repo
  hit="$(find $SEARCH_ROOTS -name "$label.plist" -not -path "$AGENTS/*" 2>/dev/null | head -1)"
  if [ -n "$hit" ] && git -C "$(dirname "$hit")" rev-parse --git-dir >/dev/null 2>&1; then
    backed=$((backed+1))
    [ -z "$QUIET" ] && printf '  ok        %-46s -> %s\n' "$label" "${hit/#$HOME/~}"
  else
    unbacked=$((unbacked+1)); UNBACKED_LIST="$UNBACKED_LIST
  $label  (plist exists, but only on this Mac)"
  fi
done <<< "$LOADED"

printf '\nlaunchd-census: %d repo-backed, %d unbacked, %d loaded-but-missing\n' \
  "$backed" "$unbacked" "$missing"
if [ "$unbacked" -gt 0 ] || [ "$missing" -gt 0 ]; then
  printf 'UNBACKED — these schedules exist nowhere but darwin:%s\n' "$UNBACKED_LIST"
  printf '\nFix: copy each plist beside the script it runs, inside that script'"'"'s repo, then commit.\n'
  exit 1
fi
exit 0
