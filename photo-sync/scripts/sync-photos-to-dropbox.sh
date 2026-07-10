#!/bin/bash
# ============================================================================
# sync-photos-to-dropbox.sh
# ----------------------------------------------------------------------------
# One-way COLD-STORAGE backup of family photos/videos:
#     NAS  (my_nas: SMB remote, voyager / share "Jason2")
#       -> Dropbox (dropbox: remote, "jason braatz" account)
#
# Path mirrored exactly:
#     my_nas:Jason2/DROPBOX/Photos and Videos/personal photos/<YEAR>
#  -> dropbox:Photos and Videos/personal photos/<YEAR>
#
# TWO MODES (same script):
#   * Default (hourly agent): sync CURRENT + PREVIOUS year only. Fast, tiny
#     listing — this is the everyday path.
#   * Full sweep (PHOTO_SYNC_FULL=1, run weekly by the -fullsweep agent): sync
#     EVERY year folder on the NAS. Catches stray photos dropped into an old
#     year (a found cache from 2011, etc.) automatically — no manual rclone.
#
# Behaviour (per Jason, 2026-06-02):
#   * Heals + additive. --size-only re-copies any file whose Dropbox size differs
#     (incl. 0-byte/partial); correctly-sized files are skipped. Uses `copy`
#     (never `sync`) so files are NEVER deleted from Dropbox. One-way: NAS read-only.
#     --min-age 15m avoids copying files still being written to the NAS.
#     (Changed from --ignore-existing by Claude 2026-06-15 after 0-byte Orlando incident.)
#   * Quiet by default. Speaks to the Asana "Batter's Box" only when:
#       (ok)     a batch of new files copied  -> thumbs-up + summary
#       (error)  a NON-network failure (token rot, rclone/path/SMB error)
#                -> copy-paste-into-Claude debugging prompt
#       (home-down) NAS unreachable 2+ hrs WHILE darwin is on the home LAN
#                -> real-failure copy-paste-into-Claude prompt (added 2026-07-10)
#       (outage) NAS unreachable 14+ days (away/travel fallback)
#                -> copy-paste-into-Claude "probably a local SMB issue" prompt
#     A normal travel/network miss = total silence. error/outage alerts fire
#     ONCE per streak (no hourly spam) and reset when things recover.
#   * Gentle: year-scoped listing, niced, single-instance lock.
#   * Travel-safe: NAS unreachable -> silent exit 0, retry next hour.
#   * NAS-wake aware: the WD NAS spins disks down; a fresh SMB connection can
#     briefly fail, so we retry the base listing before deciding anything.
#
# Reads the NAS via rclone's own SMB client, so NO /Volumes mount and NO Full
# Disk Access / AppleScript .app wrapper are needed. Plain bash LaunchAgent.
# ============================================================================

set -uo pipefail

RCLONE="/opt/homebrew/bin/rclone"
NAS_IP="voyager.local"   # was 192.168.86.112; drifted 2026-07. mDNS name survives DHCP changes.
SRC_BASE="my_nas:Jason2/DROPBOX/Photos and Videos/personal photos"
DST_BASE="dropbox:Photos and Videos/personal photos"

LOG="$HOME/Library/Logs/photo-sync-dropbox.log"
LOCKDIR="/tmp/photo-sync-dropbox.lock"
NOTIFY="$HOME/bin/photo-sync-notify.py"

STATE_DIR="$HOME/.local/state/photo-sync"
LAST_OK_FILE="$STATE_DIR/last_nas_ok"        # mtime = last time NAS was reachable
OUTAGE_ALERTED="$STATE_DIR/outage_alerted"   # exists once we've flagged a long outage
ERROR_ALERTED="$STATE_DIR/error_alerted"     # exists once we've flagged current error streak
HOME_ALERTED="$STATE_DIR/home_alerted"       # exists once we've flagged a NAS-down-while-HOME failure

OUTAGE_DAYS=14    # away/travel fallback: NAS unreachable this long -> outage alert
WAKE_BUDGET=90    # seconds to keep retrying the NAS base listing (disk spin-up / SMB hiccup)

# Home-aware alerting (added 2026-07-10): Jason is home ~51 wks/yr, so "NAS unreachable
# while HOME" is a real failure, not travel. darwin is "home" if it holds a home-LAN IP.
HOME_NET_PREFIX="192.168.86."   # UPDATE after the network redo
HOME_OUTAGE_HOURS=2             # when home, alert if NAS unreachable at least this long
is_home(){ ifconfig 2>/dev/null | grep -q "inet ${HOME_NET_PREFIX}"; }

# Full-sweep mode: set PHOTO_SYNC_FULL=1 (the weekly -fullsweep agent does this).
FULL="${PHOTO_SYNC_FULL:-0}"

# Junk we never want to back up (and which would otherwise false-trigger alerts)
EXCLUDES=(
  --exclude ".DS_Store"
  --exclude "._*"
  --exclude ".Spotlight-V100/**"
  --exclude ".Trashes/**"
  --exclude ".fseventsd/**"
  --exclude ".TemporaryItems/**"
  --exclude ".DocumentRevisions-V100/**"
  --exclude "Thumbs.db"
  --exclude "@eaDir/**"
)

# Resource manners. Add --bwlimit 8M here if a big batch ever saturates your
# uplink while you're working; leave unset for fastest catch-up.
RCLONE_OPTS=(
  --size-only            # was --ignore-existing; now heals 0-byte/partial uploads (Claude 2026-06-15)
  --min-age 15m          # skip files still being written to NAS (prevents 0-byte capture)
  --transfers 4
  --checkers 8
  --contimeout 30s
  --timeout 5m
  --retries 3
  --low-level-retries 10
  -v
)

mkdir -p "$STATE_DIR"
ts(){ date '+%Y-%m-%d %H:%M:%S'; }
log(){ echo "$(ts) $*" >> "$LOG"; }

# ---- single-instance lock (mkdir is atomic) --------------------------------
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  if [ -f "$LOCKDIR/pid" ] && kill -0 "$(cat "$LOCKDIR/pid" 2>/dev/null)" 2>/dev/null; then
    log "another run active (pid $(cat "$LOCKDIR/pid")); exiting"
    exit 0
  fi
  log "clearing stale lock"
  rm -rf "$LOCKDIR"
  mkdir "$LOCKDIR" 2>/dev/null || { log "could not acquire lock; exiting"; exit 0; }
fi
echo "$$" > "$LOCKDIR/pid"
trap 'rm -rf "$LOCKDIR"' EXIT

# ---- preflight: are we home / is the NAS awake? ----------------------------
if ping -c1 -t5 "$NAS_IP" >/dev/null 2>&1; then
  touch "$LAST_OK_FILE"          # record reachability (also nudges NAS awake)
  rm -f "$OUTAGE_ALERTED" "$HOME_ALERTED"   # outage / home-down (if any) is over
else
  # NAS unreachable. Distinguish "home but NAS down" (real failure -> alert fast)
  # from genuine travel (darwin off the home LAN -> stay quiet until the 14d fallback).
  if [ -f "$LAST_OK_FILE" ]; then
    last_epoch="$(stat -f %m "$LAST_OK_FILE" 2>/dev/null || echo 0)"
    now_epoch="$(date +%s)"
    gap_secs=$(( now_epoch - last_epoch ))
    gap_days=$(( gap_secs / 86400 ))
    gap_hours=$(( gap_secs / 3600 ))
    if is_home && [ "$gap_hours" -ge "$HOME_OUTAGE_HOURS" ] && [ ! -f "$HOME_ALERTED" ]; then
      log "NAS unreachable ${gap_hours}h while HOME -> real-failure alert"
      printf 'darwin is on the home LAN (%s0/24) but voyager has been unreachable for %sh (last seen %s) — this is NOT travel. Likely her DHCP IP drifted again, or she is wedged/asleep. rclone my_nas + this script now target voyager.local; if it still fails, check her on the network or power-cycle her.' "$HOME_NET_PREFIX" "$gap_hours" "$(date -r "$last_epoch" '+%Y-%m-%d %H:%M' 2>/dev/null)" | python3 "$NOTIFY" error >> "$LOG" 2>&1 && touch "$HOME_ALERTED"
    elif [ "$gap_days" -ge "$OUTAGE_DAYS" ] && [ ! -f "$OUTAGE_ALERTED" ]; then
      log "NAS unreachable ${gap_days}d (>= ${OUTAGE_DAYS}) -> outage alert"
      python3 "$NOTIFY" outage "$gap_days" "$(date -r "$last_epoch" '+%Y-%m-%d' 2>/dev/null)" >> "$LOG" 2>&1
      touch "$OUTAGE_ALERTED"
    else
      if is_home; then log "NAS unreachable (${gap_hours}h, home) — within grace, quiet"; else log "NAS unreachable (${gap_days}d, away=travel) — quiet"; fi
    fi
  else
    log "NAS unreachable; no prior success on record — starting outage clock"
    touch "$LAST_OK_FILE"
  fi
  exit 0
fi

# ---- wake the NAS / confirm the share is really listable -------------------
# ping only wakes the controller; the disks (and SMB) may need a few seconds,
# and a fresh SMB connection can transiently fail. Retry the base listing
# until it returns the year folders or we exhaust the wake budget.
years_present=""
waited=0
while :; do
  years_present="$("$RCLONE" lsf "$SRC_BASE" --dirs-only 2>/dev/null)"
  [ -n "$years_present" ] && break
  [ "$waited" -ge "$WAKE_BUDGET" ] && break
  sleep 10
  waited=$(( waited + 10 ))
done

total_new=0
had_error=0
summary=""
errdetail=""

if [ -z "$years_present" ]; then
  # Ping worked but we still can't list the photos base after the wake window.
  # That is NOT travel — it's an rclone-config / SMB-share / credential problem.
  had_error=1
  errdetail="ping to NAS $NAS_IP succeeded, but \`rclone lsf \"$SRC_BASE\"\` returned nothing after ${waited}s of retries. Likely an SMB-share, credential, or rclone-config problem (not travel)."
  log "$errdetail"
else
  # ---- decide which years to sync ------------------------------------------
  if [ "$FULL" = "1" ]; then
    # Full sweep: every 4-digit year folder present on the NAS.
    YEARS=()
    while IFS= read -r _d; do
      _d="${_d%/}"
      case "$_d" in [0-9][0-9][0-9][0-9]) YEARS+=("$_d");; esac
    done <<< "$years_present"
    log "FULL SWEEP across ${#YEARS[@]} year folder(s)"
  else
    # Everyday hourly path: current + previous year (computed live; never hardcoded).
    YEAR_NOW="$(date +%Y)"
    YEARS=( "$YEAR_NOW" "$(( YEAR_NOW - 1 ))" )
  fi
  RUNLOG="$(mktemp)"

  for Y in "${YEARS[@]}"; do
    # Base listed fine, so a missing year is genuinely absent (e.g. early Jan).
    if ! printf '%s\n' "$years_present" | grep -qx "$Y/"; then
      log "year $Y not present on NAS; skipping"
      continue
    fi

    log "syncing year $Y ..."
    : > "$RUNLOG"
    nice -n 10 "$RCLONE" copy "$SRC_BASE/$Y" "$DST_BASE/$Y" "${EXCLUDES[@]}" "${RCLONE_OPTS[@]}" >> "$RUNLOG" 2>&1
    rc=$?
    cat "$RUNLOG" >> "$LOG"

    new="$(grep -c ": Copied (" "$RUNLOG")"
    total_new=$(( total_new + new ))

    if [ "$rc" -ne 0 ]; then
      had_error=1
      errdetail+="[$Y] rclone exited $rc"$'\n'"$(grep -i "ERROR" "$RUNLOG" | tail -5)"$'\n'$'\n'
      log "year $Y FAILED (rc=$rc)"
    elif [ "$new" -gt 0 ]; then
      breakdown="$(grep ": Copied (" "$RUNLOG" \
                    | sed -E 's/.*INFO[[:space:]]*: //; s/: Copied \(.*//' \
                    | awk -F/ '{print $1}' | sort | uniq -c | sed 's/^/    /')"
      summary+="[$Y] $new new file(s):"$'\n'"${breakdown}"$'\n'$'\n'
      log "year $Y: $new new file(s) copied"
    else
      log "year $Y: nothing new"
    fi
  done
  rm -f "$RUNLOG"
fi

# ---- notify (dedup error alerts; ok always confirms a real batch) ----------
if [ "$had_error" -ne 0 ]; then
  if [ ! -f "$ERROR_ALERTED" ]; then
    log "error present -> notifying Batter's Box (Claude prompt)"
    printf '%s' "$errdetail" | python3 "$NOTIFY" error >> "$LOG" 2>&1 && touch "$ERROR_ALERTED"
  else
    log "error present but already alerted this streak — staying quiet"
  fi
else
  rm -f "$ERROR_ALERTED"   # clean run: clear any prior error streak
  if [ "$total_new" -gt 0 ]; then
    sweep_tag=""; [ "$FULL" = "1" ] && sweep_tag=" (full sweep)"
    log "$total_new new file(s)${sweep_tag} -> notifying Batter's Box"
    printf '%s' "$summary" | python3 "$NOTIFY" ok "$total_new" >> "$LOG" 2>&1
  else
    log "no new files — staying quiet"
  fi
fi

log "run complete (new=$total_new, error=$had_error, full=$FULL)"
exit 0
