#!/bin/bash
# detector-heartbeat-watch.sh — the watcher that makes SILENCE mean something.
#
# THE PROBLEM IT SOLVES (AAR 2026-07-29-geo-detector-blind-spot, action A4):
# a detector whose only success signal is "no output" cannot be distinguished from a detector
# that never ran. The geo check proved this the expensive way: it fired three times, never did
# what it was told, and nobody noticed for ~29 hours across two firings. Adding a POSITIVE
# DATED HEARTBEAT to each detector is half the fix. This script is the other half — somebody
# has to notice when the heartbeat stops.
#
# WHY IT IS LOCAL AND THE DETECTORS IT WATCHES ARE NOT: the detectors probe PUBLIC endpoints,
# so they are cloud-native and must not depend on this laptop. The WATCHER only needs Asana,
# and it files into Batter's Box, which is where Jason already lives. A watcher on darwin
# watching a cloud detector is deliberate belt-and-suspenders: neither can die quietly, because
# they fail in different places for different reasons.
#
# REGISTRY: one line per watched machine —  <name>|<asana-card-gid>|<max-age-hours>
# The card must carry exactly one <!--STATE {...,"updated":"<iso8601>"}--> marker.
set -uo pipefail

WATCHED=(
  "geo-buypath-watch|1217003763638321|36"   # daily 12:15Z cloud task; 36h = one missed run + slack
)

BATTERS_BOX="1213050213165325"
TOKEN_FILE="$HOME/.config/scan-pipeline/asana.token"
LOG="$HOME/Library/Logs/detector-heartbeat-watch.log"
HEARTBEAT="$HOME/Library/Logs/detector-heartbeat-watch.heartbeat"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$TS" "$*" >> "$LOG"; }

SELFTEST=""
[ "${1:-}" = "--selftest" ] && SELFTEST=1
# TEST HOOKS — the STALE branch (the one that actually files the card) would otherwise ship
# untested, and an untested alerting branch is silence, which is the bug this script cures.
#   DHW_FORCE_STALE=1  treat every heartbeat as stale, whatever its age.
#   DHW_DRYRUN=1       print the card instead of writing it to Asana.
FORCE_STALE="${DHW_FORCE_STALE:-}"
DRYRUN="${DHW_DRYRUN:-}"

PAT=""
[ -s "$TOKEN_FILE" ] && PAT="$(cat "$TOKEN_FILE")"
if [ -z "$PAT" ] && [ -z "$SELFTEST" ]; then
  log "NO ASANA TOKEN — the watcher itself is blind. Fix the token."
  printf '%s exit=2 reason=no-token\n' "$TS" > "$HEARTBEAT"; exit 2
fi

# The age calculation is the whole load-bearing part of this script, so it is a pure function
# with a self-test. A watcher whose arithmetic is wrong is worse than no watcher: it is a
# green light nobody earned.
age_verdict() { # $1=updated-iso  $2=max-age-hours  $3=now-iso  -> prints "OK <h>" | "STALE <h>" | "UNPARSEABLE"
  /usr/bin/python3 - "$1" "$2" "$3" <<'PY'
import sys,datetime
upd,maxh,now=sys.argv[1],float(sys.argv[2]),sys.argv[3]
try:
    f="%Y-%m-%dT%H:%M:%SZ"
    u=datetime.datetime.strptime(upd,f); n=datetime.datetime.strptime(now,f)
except Exception:
    print("UNPARSEABLE"); sys.exit(0)
h=(n-u).total_seconds()/3600.0
print(("STALE " if h>maxh else "OK ")+f"{h:.1f}")
PY
}

if [ -n "$SELFTEST" ]; then
  echo "self-test: stale must read STALE, fresh must read OK, garbage must read UNPARSEABLE."
  echo
  FAIL=0
  check() { # $1=desc $2=got $3=want-prefix
    case "$2" in "$3"*) echo "  ✓ $1 -> $2";; *) echo "  ✗ $1 -> $2 (wanted $3)"; FAIL=1;; esac; }
  check "1h old, max 36h"    "$(age_verdict 2026-07-29T11:00:00Z 36 2026-07-29T12:00:00Z)" "OK"
  check "35.9h old, max 36h" "$(age_verdict 2026-07-28T00:07:00Z 36 2026-07-29T12:00:00Z)" "OK"
  check "37h old, max 36h"   "$(age_verdict 2026-07-27T23:00:00Z 36 2026-07-29T12:00:00Z)" "STALE"
  check "8 days old"         "$(age_verdict 2026-07-21T12:00:00Z 36 2026-07-29T12:00:00Z)" "STALE"
  check "garbage timestamp"  "$(age_verdict not-a-date 36 2026-07-29T12:00:00Z)"           "UNPARSEABLE"
  check "empty timestamp"    "$(age_verdict '' 36 2026-07-29T12:00:00Z)"                   "UNPARSEABLE"
  echo
  [ "$FAIL" -eq 0 ] && echo "ALL GREEN — the staleness arithmetic is load-bearing." || echo "SELF-TEST FAILED"
  exit "$FAIL"
fi

PROBLEMS=""
for entry in "${WATCHED[@]}"; do
  NAME="${entry%%|*}"; REST="${entry#*|}"; GID="${REST%%|*}"; MAXH="${REST##*|}"
  NOTES="$(curl -s -H "Authorization: Bearer $PAT" \
    "https://app.asana.com/api/1.0/tasks/$GID?opt_fields=notes" \
    | /usr/bin/python3 -c "import sys,json
try: print((json.load(sys.stdin).get('data') or {}).get('notes') or '')
except Exception: pass" 2>/dev/null)"
  if [ -z "$NOTES" ]; then
    PROBLEMS="$PROBLEMS
  • $NAME — could not read its heartbeat card ($GID). Asana error, or the card was deleted."
    log "$NAME: card unreadable"; continue
  fi
  UPD="$(printf '%s' "$NOTES" | /usr/bin/python3 -c "
import sys,re,json
m=re.search(r'<!--STATE (\{.*?\})-->', sys.stdin.read(), re.S)
print(json.loads(m.group(1)).get('updated','') if m else '')" 2>/dev/null)"
  V="$(age_verdict "${UPD:-}" "$MAXH" "$TS")"
  [ -n "$FORCE_STALE" ] && V="STALE 999.0"
  log "$NAME: updated=${UPD:-<none>} verdict=$V"
  case "$V" in
    OK*) ;;
    STALE*)
      PROBLEMS="$PROBLEMS
  • $NAME — last heartbeat ${UPD}, which is ${V#STALE }h ago (limit ${MAXH}h). The detector has NOT run."
      ;;
    *)
      PROBLEMS="$PROBLEMS
  • $NAME — its card has no readable <!--STATE {...}--> marker. Either it never wrote one, or the marker was mangled."
      ;;
  esac
done

[ -z "$DRYRUN" ] && printf '%s problems=%s\n' "$TS" "$( [ -z "$PROBLEMS" ] && echo none || echo yes )" > "$HEARTBEAT"
[ -z "$PROBLEMS" ] && { log "all heartbeats fresh"; exit 0; }

BODY="<!--AUTOFILED source=detector-heartbeat-watch-->
BBKEY detector-heartbeat-stale

**A detector has gone quiet, and quiet is not the same as fine.**
$PROBLEMS

Silence from a detector means one of two very different things — \"nothing is wrong\" or \"I never
ran\". This card exists because something stopped saying which. The underlying check may be fine;
what is definitely broken is our ability to know.

PASTE-TO-CLAUDE:
\"A detector heartbeat went stale. Read ~/Code/darwin-mac-ops/detector-heartbeat-watch.sh for the
registry of watched machines and their Asana state cards. For geo-buypath-watch: the detector is the
cloud scheduled task 'Daily buy-path geo check — SF + ATX' (trig_01NFe9etvXZwgEVNTayL5xbH, cron
15 12 * * *); check whether it fired and whether it wrote its <!--STATE--> marker back to Asana card
1217003763638321. You can run the probe yourself right now from anywhere:
python3 ~/repos/shopify-theme-corpus/scripts/geo_buypath_watch.py  (stdlib only, no credentials).
Context: AAR 2026-07-29-geo-detector-blind-spot, action A4.\"

--
Filed by ~/Scripts/detector-heartbeat-watch.sh (local launchd com.braatz.detector-heartbeat-watch)."

if [ -n "$DRYRUN" ]; then
  printf '\n--- DRYRUN: would file/append this Batter'"'"'s Box card ---\n%s\n--- end ---\n' "$BODY"
  exit 1
fi
# Dedupe via the SHARED paginating client (card 1217004329363570, action A3). The inline
# curl this replaces read ONE page of up to 100 open cards; Batter's Box measured 85 of 100
# on 2026-07-30. Past that boundary this watcher silently stops finding its own card and
# files a fresh duplicate on every run.
EXISTING="$(/usr/bin/python3 "$HOME/Scripts/asana_client.py" find-open \
  --project "$BATTERS_BOX" --needle 'BBKEY detector-heartbeat-stale' 2>/dev/null || true)"

if [ -n "$EXISTING" ]; then
  /usr/bin/python3 - "$PAT" "$EXISTING" "$BODY" <<'PY'
import json,sys,urllib.request
pat,gid,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request(f"https://app.asana.com/api/1.0/tasks/{gid}/stories",
    data=json.dumps({"data":{"text":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
urllib.request.urlopen(r,timeout=30)
PY
  log "STALE — commented on existing card $EXISTING"
else
  /usr/bin/python3 - "$PAT" "$BATTERS_BOX" "$BODY" <<'PY'
import json,sys,urllib.request
pat,proj,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request("https://app.asana.com/api/1.0/tasks",
    data=json.dumps({"data":{"projects":[proj],
      "name":"🔇 A detector went quiet — its heartbeat is stale (we cannot tell 'fine' from 'never ran')",
      "notes":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
print(json.load(urllib.request.urlopen(r,timeout=30))["data"]["gid"])
PY
  log "STALE — filed a new Batter's Box card"
fi
exit 1
