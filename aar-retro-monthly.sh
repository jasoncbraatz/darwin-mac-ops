#!/bin/bash
# aar-retro-monthly.sh — the monthly AAR retro, run as a LOCAL launchd task on darwin.
# Same reasoning as aar-gate-daily.sh: aar.py and the corpus live here, so a fresh-session
# cloud task could not reach them. See AAR 2026-07-29-geo-detector-blind-spot.
#
# --write saves the report under aars/retro/; --card files it to Batter's Box, the inbox
# Jason actually reads. 60 days beats 30: it spans two cycles, so a vector has room to
# show itself as a vector rather than a coincidence.
set -uo pipefail

BLACKBOOK="$HOME/repos/claude-blackbook"
LOG="$HOME/Library/Logs/aar-retro.log"
HEARTBEAT="$HOME/Library/Logs/aar-retro.heartbeat"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$(dirname "$LOG")"

git -C "$BLACKBOOK" pull --ff-only --quiet 2>/dev/null || echo "$TS WARN: git pull failed" >> "$LOG"

/usr/bin/python3 "$BLACKBOOK/aar.py" retro --days 60 --write --card >> "$LOG" 2>&1
RC=$?
printf '%s exit=%s\n' "$TS" "$RC" > "$HEARTBEAT"
echo "$TS retro exit=$RC (0=clean 1=candidates found 2=partial/CANNOT VERIFY)" >> "$LOG"

# commit the written report so the corpus stays repo-backed (GitHub is the SSOT)
if git -C "$BLACKBOOK" status --porcelain aars/retro 2>/dev/null | grep -q .; then
  git -C "$BLACKBOOK" add aars/retro
  git -C "$BLACKBOOK" commit -qm "aar: monthly retro $(date -u +%Y-%m-%d)" && \
  git -C "$BLACKBOOK" push -q && echo "$TS retro report committed + pushed" >> "$LOG"
fi
exit "$RC"
