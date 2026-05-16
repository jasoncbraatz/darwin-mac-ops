#!/bin/bash
# Pull nightly miniblog Postgres dumps from n8n to the NAS.
# Triggered by LaunchAgent com.braatz.miniblog-backup-pull at 03:45 local time.
#
# Source: n8n:/opt/backups/miniblog/ (created by /opt/miniblog/scripts/backup-pg.sh at 03:15 UTC)
# Dest:   /Volumes/Jason2/BACKUPS/miniblog/

set -uo pipefail   # NB: NO -e so the log always gets written

SRC="claudeApp@10.10.10.1:/opt/backups/miniblog/"
DST="/Volumes/Jason2/BACKUPS/miniblog/"
LOG="$HOME/Library/Logs/miniblog-backup-pull.log"
KEY="$HOME/.ssh/id_ed25519_n8n_backup"

mkdir -p "$(dirname "$LOG")"
echo "[$(date -Iseconds)] start pull from $SRC to $DST (uid=$(id -u))" >> "$LOG"

if ! mkdir -p "$DST" 2>>"$LOG"; then
  echo "[$(date -Iseconds)] FATAL: cannot create $DST. Likely macOS TCC blocking SMB write from this process context." >> "$LOG"
  exit 1
fi

/usr/bin/rsync -avz --delete --partial \
  -e "ssh -i $KEY -o StrictHostKeyChecking=accept-new -o BatchMode=yes" \
  "$SRC" "$DST" >> "$LOG" 2>&1
RC=$?

echo "[$(date -Iseconds)] pull complete, rsync exit=$RC" >> "$LOG"
exit "$RC"
