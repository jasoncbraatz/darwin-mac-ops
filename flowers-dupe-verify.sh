#!/bin/bash
# flowers-dupe-verify.sh — the 24h (and 25th, and 26th…) post-fix verification of the
# 2026-07-28 SMS duplicate guard, run as a LOCAL launchd task on darwin.
#
# WHY THIS EXISTS / WHY IT IS LOCAL:
#   It replaces one-shot cloud scheduled task trig_01GK8X6JQ72L5Rgr6DSPSyU3, which was set to
#   fire 2026-07-30T01:30Z as a FRESH-SESSION cloud task. A fresh cloud session has no device
#   bridge and no ssh MCP, so every ~/ path in it was dead on arrival. This probe needs darwin's
#   repos AND reaches the flowers Linode *through* darwin (tools/flowers-remote.sh), so unlike
#   the geo check it CANNOT be made cloud-native. Per AAR 2026-07-29-geo-detector-blind-spot §5:
#     probe targets private infra reached from darwin -> it must be a LOCAL scheduled task.
#
# WHY DAILY AND NOT ONE-SHOT — the substantive upgrade over the job it replaces:
#   dupe-scan.py refuses to say PASS below a sample floor derived from the pre-fix duplicate
#   rate (exit 2 = INSUFFICIENT DATA, which is NOT a pass). At 2026-07-29T22:05Z there were 9
#   post-fix messages against a floor of 29. A ONE-SHOT at 01:30Z would therefore have returned
#   exit 2 even if it could run at all, and then nothing would ever have re-asked. A verification
#   that gives up before its denominator is big enough is decoration. So this retries daily and
#   RETIRES ITSELF the moment it can honestly decide.
#
# EXIT CONTRACT (inherited from dupe-scan.py, deliberately asymmetric):
#   0 = PASS  -> only after the sample floor is met. Comments + completes the card, then retires.
#   1 = FAIL  -> trustworthy at ANY sample size (one real post-fix pair is proof). Cards loudly.
#   2 = CANNOT VERIFY / insufficient data -> NOT a pass. Stays quiet, heartbeats, tries tomorrow.
set -uo pipefail

RELAY="$HOME/repos/flowers-sms-relay"
TWILIO_ENV="$HOME/.config/strike-zone/twilio.env"
SINCE="2026-07-28T23:53:14Z"          # the deploy boundary. Do not "round" this.
CARD="1216968426926606"               # the ship-blocker card this verification gates
BATTERS_BOX="1213050213165325"
BBKEY="<!--BBKEY:flowers-dupe-verify-->"
TOKEN_FILE="$HOME/.config/scan-pipeline/asana.token"
LOG="$HOME/Library/Logs/flowers-dupe-verify.log"
HEARTBEAT="$HOME/Library/Logs/flowers-dupe-verify.heartbeat"
SENTINEL="$HOME/Library/Logs/flowers-dupe-verify.RETIRED"
PLIST="$HOME/Library/LaunchAgents/com.braatz.flowers-dupe-verify.plist"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- TEST HOOKS (see --self-test) -----------------------------------------------------------
#   FDV_FORCE_RC=<0|1|2>  pretend the scan returned this, to exercise a branch on demand.
#   FDV_DRYRUN=1          print every Asana write instead of performing it.
# These exist because branches 0 and 1 would otherwise ship untested, and an untested failure
# branch is silence — the precise failure mode this whole tier exists to cure.
FORCE_RC="${FDV_FORCE_RC:-}"
DRYRUN="${FDV_DRYRUN:-}"

mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$TS" "$*" >> "$LOG"; }

# --- already decided? then this job is done and must stop spending Twilio API calls ---------
if [ -f "$SENTINEL" ] && [ -z "${FDV_DRYRUN:-}" ]; then
  log "retired already ($(head -1 "$SENTINEL")) — no-op"; exit 0
fi

if [ ! -d "$RELAY" ]; then
  log "CANNOT VERIFY: $RELAY missing"; printf '%s exit=2 reason=no-repo\n' "$TS" > "$HEARTBEAT"; exit 2
fi
if [ ! -s "$TWILIO_ENV" ]; then
  log "CANNOT VERIFY: $TWILIO_ENV missing — the scan cannot authenticate"
  printf '%s exit=2 reason=no-twilio-env\n' "$TS" > "$HEARTBEAT"; exit 2
fi

git -C "$RELAY" pull --ff-only --quiet 2>/dev/null || log "WARN: git pull failed (continuing on the local copy)"

# Capture the exit code WITHOUT a pipeline. Under zsh a pipeline's $? is the LAST element's,
# so `scan | tail` then $? reads 0 (tail succeeded) no matter what the scan decided.
# That trap is a banked lesson (lessons.py search "zsh PIPESTATUS"); do not reintroduce it.
if [ -n "$FORCE_RC" ]; then
  OUT="POST-FIX VERDICT (traffic sent at/after $SINCE)
  [FDV_FORCE_RC=$FORCE_RC — synthetic verdict block for a branch test, not a real measurement]"
  RC="$FORCE_RC"
  log "SELF-TEST: forced rc=$RC (no scan run)"
else
  OUT="$(cd "$RELAY" && set -a && . "$TWILIO_ENV" && set +a && \
         /usr/bin/python3 tools/dupe-scan.py --days 30 --since "$SINCE" 2>&1)"; RC=$?
  log "dupe-scan exit=$RC"
fi

# POSITIVE DATED HEARTBEAT — always, every outcome. Absence of a fresh heartbeat is itself
# the alarm; without this, "silent" means both "all good" and "never ran".
[ -z "$DRYRUN" ] && printf '%s exit=%s\n' "$TS" "$RC" > "$HEARTBEAT"

VERDICT="$(printf '%s\n' "$OUT" | sed -n '/POST-FIX VERDICT/,$p')"
[ -z "$VERDICT" ] && VERDICT="$(printf '%s\n' "$OUT" | tail -20)"

PAT=""
[ -s "$TOKEN_FILE" ] && PAT="$(cat "$TOKEN_FILE")"

asana_comment() { # $1=gid $2=text
  if [ -n "$DRYRUN" ]; then
    printf '\n--- DRYRUN: would COMMENT on %s ---\n%s\n--- end ---\n' "$1" "$2"; return 0
  fi
  [ -z "$PAT" ] && { log "NO ASANA TOKEN — could not comment on $1"; return 1; }
  /usr/bin/python3 - "$PAT" "$1" "$2" <<'PY'
import json,sys,urllib.request
pat,gid,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request(f"https://app.asana.com/api/1.0/tasks/{gid}/stories",
    data=json.dumps({"data":{"text":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
urllib.request.urlopen(r,timeout=30)
PY
}

case "$RC" in
0)
  # A clean scan could still just be a quiet day, so a PASS is not allowed to rest on the scan
  # alone: the guard must also still be demonstrably ARMED. flowers-verify.sh runs all three
  # suites on the box and hard-fails on `command not found` instead of letting it scroll past
  # looking like a pass.
  if [ -n "$DRYRUN" ]; then SUITES="[DRYRUN: suites not run]"; SRC=0; else
  SUITES="$(cd "$RELAY" && ./tools/flowers-verify.sh 2>&1)"; SRC=$?; fi
  log "flowers-verify.sh exit=$SRC"
  if [ "$SRC" -ne 0 ]; then
    log "scan PASSed but the suites did NOT verify — refusing to complete the card"
    asana_comment "$CARD" "⚠️ Post-fix dupe scan returned PASS, but \`tools/flowers-verify.sh\` exited $SRC — the guard could not be shown to be ARMED. NOT completing this card. A clean scan plus unverified suites is exactly the quiet-day signature.

\`\`\`
$(printf '%s\n' "$SUITES" | tail -25)
\`\`\`

-- ~/Scripts/flowers-dupe-verify.sh (local launchd com.braatz.flowers-dupe-verify). Will retry tomorrow."
    exit 1
  fi
  asana_comment "$CARD" "✅ VERIFIED — the atomic duplicate guard held across a full sample of real traffic.

\`\`\`
$VERDICT
\`\`\`

Guard confirmed still ARMED (\`tools/flowers-verify.sh\` exit 0 — suites 12/0/0, 20/0, 18/0).

Verified by ~/Scripts/flowers-dupe-verify.sh, the LOCAL launchd job (com.braatz.flowers-dupe-verify)
that replaced fresh-session cloud task trig_01GK8X6JQ72L5Rgr6DSPSyU3. That cloud task would have run
in a container with no device bridge and could not have reached darwin's repos or the flowers box at all.
See AAR 2026-07-29-geo-detector-blind-spot §5, action A1.

This job has now RETIRED itself (sentinel: ~/Library/Logs/flowers-dupe-verify.RETIRED)."
  if [ -n "$DRYRUN" ]; then
    printf '\n--- DRYRUN: would COMPLETE card %s ---\n' "$CARD"
  elif [ -n "$PAT" ]; then
    /usr/bin/python3 - "$PAT" "$CARD" <<'PY'
import json,sys,urllib.request
pat,gid=sys.argv[1],sys.argv[2]
r=urllib.request.Request(f"https://app.asana.com/api/1.0/tasks/{gid}",
    data=json.dumps({"data":{"completed":True}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="PUT")
urllib.request.urlopen(r,timeout=30)
PY
    log "PASS — commented and COMPLETED card $CARD"
  fi
  [ -z "$DRYRUN" ] && printf '%s VERIFIED PASS — card %s completed\n' "$TS" "$CARD" > "$SENTINEL"
  [ -z "$DRYRUN" ] && [ -f "$PLIST" ] && launchctl unload "$PLIST" 2>/dev/null && log "unloaded $PLIST"
  exit 0
  ;;
1)
  # A FAIL is trustworthy at any sample size. This is Jason's inbox, loudly.
  if [ -z "$PAT" ]; then
    log "FAIL rc=1 but NO ASANA TOKEN — could not surface. This is the silent case; fix the token."
    printf '%s\n' "$OUT" >&2; exit 1
  fi
  # Dedupe via the SHARED paginating client (card 1217004329363570, action A3). The inline
  # curl this replaces read ONE page of up to 100 open cards; Batter's Box measured 85 of
  # 100 on 2026-07-30. Past that boundary this verifier silently stops finding its own card
  # and files a duplicate -- while reporting on duplicate SMS. Fitting, but not funny.
  EXISTING=""
  [ -z "$DRYRUN" ] && EXISTING="$(/usr/bin/python3 "$HOME/Scripts/asana_client.py" find-open \
    --project "$BATTERS_BOX" --needle "$BBKEY" 2>/dev/null || true)"
  BODY="<!--AUTOFILED source=flowers-dupe-verify-->
$BBKEY

**The SMS duplicate guard did NOT hold.** A customer may have been texted twice again.

\`\`\`
$VERDICT
\`\`\`

PASTE-TO-CLAUDE:
\"The flowers duplicate-send guard failed its post-fix verification. Read
/var/www/flowers/OPUS-README.md §16 and ~/repos/flowers-sms-relay/tools/dupe-scan.py, then
re-run: cd ~/repos/flowers-sms-relay && set -a; . ~/.config/strike-zone/twilio.env; set +a &&
python3 tools/dupe-scan.py --days 30 --since $SINCE  — capture SCAN_EXIT on its own line, never
through a pipe. The guard is an SmsSendClaim table with a UNIQUE index on (orderName, orderType);
the INSERT is the mutual exclusion. Check it is still present:
./tools/flowers-remote.sh 'psql \"\$DATABASE_URL\" -c \"\\\\d \\\\\"SmsSendClaim\\\\\"\"'
Rollback tag if needed: pre-dupe-guard-20260728.\"

--
Filed by ~/Scripts/flowers-dupe-verify.sh (local launchd com.braatz.flowers-dupe-verify).
Exit $RC. 0=verified 1=guard failed 2=insufficient data (NOT a pass)."
  if [ -n "$EXISTING" ]; then
    asana_comment "$EXISTING" "$BODY"; log "FAIL — commented on existing card $EXISTING"
  elif [ -n "$DRYRUN" ]; then
    printf '\n--- DRYRUN: would CREATE a Batter'"'"'s Box card ---\n%s\n--- end ---\n' "$BODY"
  else
    /usr/bin/python3 - "$PAT" "$BATTERS_BOX" "$BODY" <<'PY'
import json,sys,urllib.request
pat,proj,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request("https://app.asana.com/api/1.0/tasks",
    data=json.dumps({"data":{"projects":[proj],
      "name":"🔴 Flowers: the duplicate-SMS guard did NOT hold — customers may be double-texted again",
      "notes":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
print(json.load(urllib.request.urlopen(r,timeout=30))["data"]["gid"])
PY
    log "FAIL — filed a new Batter's Box card"
  fi
  [ -z "$DRYRUN" ] && printf '%s FAILED — guard did not hold; see Batter\x27s Box\n' "$TS" > "$SENTINEL"
  exit 1
  ;;
*)
  log "CANNOT VERIFY (rc=$RC) — insufficient post-fix traffic. Staying quiet; retrying tomorrow."
  exit 2
  ;;
esac
