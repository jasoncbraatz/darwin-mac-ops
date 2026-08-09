#!/bin/bash
# aar-gate-daily.sh — the daily AAR/RCA gate, run as a LOCAL launchd task on darwin.
#
# WHY LOCAL AND NOT A CLOUD SCHEDULED TASK: aar.py and the AAR markdown live on darwin.
# A fresh-session Cowork cloud task has no device bridge and no ssh MCP, so every ~/ path
# is dead on arrival. Scheduling this in the cloud would reproduce, exactly, the bug this
# entire tier was built to prevent. See AAR 2026-07-29-geo-detector-blind-spot.
#
# WHY THIS WRAPPER EXISTS AT ALL: `aar.py gate` exiting 1 inside launchd is a tree falling
# in an empty forest. A detector whose only output is an exit code nobody reads is a
# silent-success detector — the precise failure mode being cured. So this script:
#   * files the failure into Batter's Box (Jason's actual inbox), deduped, and
#   * writes a POSITIVE DATED HEARTBEAT on every run, pass or fail, so "no output"
#     is distinguishable from "never ran".
set -uo pipefail

BLACKBOOK="$HOME/repos/claude-blackbook"
AAR_PY="$BLACKBOOK/aar.py"
LOG="$HOME/Library/Logs/aar-gate.log"
HEARTBEAT="$HOME/Library/Logs/aar-gate.heartbeat"
BATTERS_BOX="1213050213165325"
# HTML-comment form is REQUIRED: bb-close-on-clear.py matches <!--BBKEY:([^>]*)-->,
# and the plain-line form this used to carry was invisible to it (BBKEY backlog,
# card 1217015004006698). The card body and the dedupe --needle below are THE SAME
# STRING; if you change one without the other this job stops finding its own card
# and files a duplicate every single day.
BBKEY="<!--BBKEY:aar-gate-violations-->"
TOKEN_FILE="$HOME/.config/scan-pipeline/asana.token"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
# AGD_DRYRUN=1 -> print the card body instead of filing it, and do not touch the
# heartbeat (a dry run must not look like a real run to the staleness sentinel).
# This exists so the body this job WOULD file can be captured for the close-on-clear
# ratification drill (CLOSE-ON-CLEAR.md 6, --sample-file) without a card reaching
# Jason's board. Force a violation to exercise it, read-only:
#   AGD_DRYRUN=1 AAR_SWEEP_BASELINE=2026-07-01 ~/Scripts/aar-gate-daily.sh
DRYRUN="${AGD_DRYRUN:-}"

mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$TS" "$*" >> "$LOG"; }

if [ ! -x "$AAR_PY" ]; then
  log "CANNOT VERIFY: $AAR_PY missing"; echo "missing $AAR_PY" >&2; exit 2
fi

# reconcile in — the corpus is on GitHub; darwin may be stale
git -C "$BLACKBOOK" pull --ff-only --quiet 2>/dev/null || log "WARN: git pull failed (continuing on the local copy)"

OUT="$(/usr/bin/python3 "$AAR_PY" gate --days 7 2>&1)"; RC=$?
log "gate exit=$RC"

# POSITIVE HEARTBEAT — always, pass or fail. Absence of this file being fresh is itself
# the alarm; `aar.py heartbeat` reads the DB, this is the human/ops-readable twin.
[ -z "$DRYRUN" ] && printf '%s exit=%s\n' "$TS" "$RC" > "$HEARTBEAT"

[ "$RC" -eq 0 ] && { log "PASS"; exit 0; }

# --- surface it, or it never happened -------------------------------------------------
PAT=""
[ -s "$TOKEN_FILE" ] && PAT="$(cat "$TOKEN_FILE")"
if [ -z "$PAT" ]; then
  log "FAIL rc=$RC but NO ASANA TOKEN — could not surface. This is the silent case; fix the token."
  echo "$OUT" >&2; exit "$RC"
fi

# dedupe: if an INCOMPLETE card already carries our key, comment on it instead of piling up.
#
# ROUTED THROUGH THE SHARED CLIENT (card 1217004329363570, action A3). What used to be here
# was an inline curl that read ONE page of open cards -- up to 100 -- and searched it. On
# 2026-07-30 Batter's Box was measured at 85 open cards against that cap of 100. Past the
# boundary the lookup silently stops finding the existing card, and this job starts filing a
# DUPLICATE every single day: precisely the outcome the dedupe exists to prevent, and
# invisible because a short page is indistinguishable from a complete one.
# Eight copies of this block existed. asana_client.py pages to exhaustion or raises.
EXISTING=""
if [ -z "$DRYRUN" ]; then
  EXISTING="$(/usr/bin/python3 "$HOME/Scripts/asana_client.py" find-open \
    --project "$BATTERS_BOX" --needle "$BBKEY" 2>/dev/null)"; DEDUPE_RC=$?
  if [ "$DEDUPE_RC" -ge 2 ]; then
    # The lookup BROKE (rc=$DEDUPE_RC: network/token/client), which is NOT "no card
    # exists". Filing now duplicates the card the moment Asana comes back — measured
    # on aar-gate 2026-08-06. Skip filing; next run retries with the world healthy.
    log "FAIL rc=$RC but dedupe lookup BROKE (find-open rc=$DEDUPE_RC) — NOT filing, to avoid a duplicate; next run retries"
    echo "$OUT" >&2; exit "$RC"
  fi
fi

# rc=1 covers BOTH halves of the gate -- a completed card owing an AAR, AND the sweep
# finding uncarded incident signal. The old title named only the first, so a sweep-only
# failure arrived under a headline that was simply false. Say what is true for both.
TITLE="⚾ AAR gate: $( [ "$RC" -eq 2 ] && echo 'CANNOT VERIFY (not a pass)' || echo 'an AAR obligation is outstanding' )"
# NOTE the <!--AUTOFILED--> marker: this job is the FIRST adopter of the declaration
# contract it enforces. Without it, the gate's own card would be gated by the gate.
BODY="<!--AUTOFILED source=aar-gate-daily-->
$BBKEY

$OUT

--
Filed by ~/Scripts/aar-gate-daily.sh (local launchd task on darwin, com.braatz.aar-gate).
Exit $RC. 0=pass 1=violations 2=CANNOT VERIFY (which is NOT a pass).
To clear each violation: comment 'AAR: <slug>' on the card (after aar.py validate passes),
or 'NO-AAR: <20+ chars of real reason>'. Gate doc: HANDOFF-GATE.md §G-V."

if [ -n "$DRYRUN" ]; then
  printf '\n--- DRYRUN: would file/comment this Batter\x27s Box card ---\n%s\n%s\n--- end ---\n' "$TITLE" "$BODY"
  log "DRYRUN rc=$RC — printed, filed nothing"
  exit "$RC"
fi
if [ -n "$EXISTING" ]; then
  /usr/bin/python3 - "$PAT" "$EXISTING" "$BODY" <<'PY'
import json,sys,urllib.request
pat,gid,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request(f"https://app.asana.com/api/1.0/tasks/{gid}/stories",
    data=json.dumps({"data":{"text":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
urllib.request.urlopen(r,timeout=30)
PY
  WRC=$?
  # S49: the log line is DOWNSTREAM of a checked write code (a log line is not evidence).
  if [ "$WRC" -eq 0 ]; then
    log "FAIL rc=$RC — commented on existing card $EXISTING"
  else
    log "FAIL rc=$RC — comment on card $EXISTING UNCONFIRMED (asana write rc=$WRC); next firing retries"
  fi
else
  /usr/bin/python3 - "$PAT" "$BATTERS_BOX" "$TITLE" "$BODY" <<'PY'
import json,sys,urllib.request
pat,proj,title,body=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
r=urllib.request.Request("https://app.asana.com/api/1.0/tasks",
    data=json.dumps({"data":{"projects":[proj],"name":title,"notes":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
print(json.load(urllib.request.urlopen(r,timeout=30))["data"]["gid"])
PY
  WRC=$?
  if [ "$WRC" -eq 0 ]; then
    log "FAIL rc=$RC — filed a new Batter's Box card"
  else
    log "FAIL rc=$RC — card filing UNCONFIRMED (asana write rc=$WRC); NOT filed, next firing retries via dedupe"
  fi
fi
exit "$RC"
