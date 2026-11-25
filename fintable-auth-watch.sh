#!/bin/bash
# fintable-auth-watch.sh — make a dead Fintable session LOUD instead of silent.
#
# WHY THIS EXISTS (card 1218107129933249, filed by big_worker-smBacklog-4, 2026-09-02)
#   fintable-mcp's auth is a cookie-backed browser session that expires on no fixed schedule.
#   Before this watcher, the ONLY thing that ever surfaced an expiry was a session happening to
#   ask fintable a money question mid-task and getting back an HTTP 419. Every day between the
#   actual expiry and that lucky question, the honest answer to "what has been charged?" was
#   unavailable and nothing said so — the exact "fails only when someone asks" failure mode the
#   card names. This is step 1 of that card's three-step job: make the expiry a dated, daily
#   notice instead of a silent gap. (Step 2 — re-authenticating — needs Jason's logged-in Chrome;
#   step 3 — switching to Fintable's official API v2 key auth so this whole class of failure goes
#   away — needs Jason to mint a key. Neither is this script's job.)
#
# WHY IT IS LOCAL AND NOT A COWORK CLOUD SCHEDULED TASK
#   The auth path is rookiepy reading Jason's actual Chrome cookie jar on darwin (see
#   fintable-mcp/src/fintable_mcp/server.py's _extract_cookies_from_chrome). A fresh cloud
#   session has no such jar and would report "auth dead" every single day regardless of the
#   real state — a false alarm machine, which is worse than the silence it replaces. Same
#   reasoning as flowers-hmac-enforce-watch.sh's local/cloud split.
#
# EXIT CONTRACT
#   0 = auth is fine (fintable_list_accounts returned real JSON) -- success is silent.
#   1 = auth is dead (or the probe itself errored) -- a dated notice is filed/bumped.
set -uo pipefail

FINTABLE_MCP_SRC="$HOME/repos/fintable-mcp/src"
# the system /usr/bin/python3 lacks httpx/rookiepy/pydantic (same gotcha nightCrew hit on
# braatz-tiers-smoke.py and verify-bbadjuster.sh G3 -- a venv or managed python on PATH ahead
# of the real interpreter); fintable-mcp ships no dedicated venv, so pin the one on this darwin
# box that MEASURED clean: /opt/homebrew/bin/python3.
FINTABLE_PY="/opt/homebrew/bin/python3"
STATE_MACHINE_PROJECT="1215913700958709"
BBKEY='fintable:cookie-auth-expires-silent'
# BBKEY matches the ORIGINAL card's own tag (1218107129933249) so this watcher's daily finding
# lands as a comment on the card that already tracks this, never a fresh duplicate.
TOKEN_FILE="$HOME/.config/scan-pipeline/asana.token"
LOG="$HOME/Library/Logs/fintable-auth-watch.log"
HEARTBEAT="$HOME/Library/Logs/fintable-auth-watch.heartbeat"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$TS" "$*" >> "$LOG"; }

SELFTEST=""
[ "${1:-}" = "--selftest" ] && SELFTEST=1
# DRILL-SCRATCH: read-only -- --selftest only classifies hard-coded strings in-process, no file
# or network writes of any kind, same shape as detector-heartbeat-watch.sh's age_verdict self-test.
# TEST HOOKS — the FAIL branch (the one that actually files/comments) would otherwise ship
# untested, same reasoning as detector-heartbeat-watch.sh's FORCE/DRYRUN pair.
FORCE_FAIL="${FAW_FORCE_FAIL:-}"
DRYRUN="${FAW_DRYRUN:-}"

if [ -n "$SELFTEST" ]; then
  echo "self-test: the probe-output classifier must sort known fintable-mcp error strings as FAIL"
  echo "and a plausible success payload as OK."
  FAIL=0
  check() { # $1=desc $2=input $3=want(OK|FAIL)
    local got
    if printf '%s' "$2" | grep -qiE 'Authentication (failed|not configured)|Not authenticated|HTTP (401|419)'; then
      got=FAIL
    else
      got=OK
    fi
    if [ "$got" = "$3" ]; then echo "  ✓ $1 -> $got"; else echo "  ✗ $1 -> $got (wanted $3)"; FAIL=1; fi
  }
  check "auth not configured message"  'Authentication not configured. Either:
  0. Use --persist-cookies ...'                                                   FAIL
  check "419 session expired message"  'Error: Authentication failed (HTTP 419). Your session has likely expired.' FAIL
  check "redirected-to-login message"  'Not authenticated: Fintable redirected to /login (session cookie expired or missing).' FAIL
  check "real account JSON"            '{"total": 3, "accounts": [{"name": "Ally", "balance": "1234.56"}]}' OK
  echo
  [ "$FAIL" -eq 0 ] && echo "ALL GREEN" || echo "SELF-TEST FAILED"
  exit "$FAIL"
fi

PROBE_OUT="$(PYTHONPATH="$FINTABLE_MCP_SRC" timeout 45 "$FINTABLE_PY" -c '
import asyncio, sys
from fintable_mcp.server import fintable_list_accounts, ListAccountsInput
try:
    print(asyncio.run(fintable_list_accounts(ListAccountsInput())))
except Exception as e:
    print(f"PROBE EXCEPTION: {e}")
' 2>>"$LOG")"
PROBE_RC=$?
[ -n "$FORCE_FAIL" ] && PROBE_OUT='Error: Authentication failed (HTTP 419). Your session has likely expired. (forced)'

PROBE_OUT_HEAD="${PROBE_OUT:0:200}"; PROBE_OUT_HEAD="${PROBE_OUT_HEAD//$'\n'/ }"
log "probe rc=$PROBE_RC output_head=$PROBE_OUT_HEAD"

if [ "$PROBE_RC" -eq 0 ] && ! printf '%s' "$PROBE_OUT" | grep -qiE 'Authentication (failed|not configured)|Not authenticated|HTTP (401|419)|PROBE EXCEPTION'; then
  printf '%s status=OK\n' "$TS" > "$HEARTBEAT"
  log "auth OK — success is silent"
  exit 0
fi

printf '%s status=FAIL\n' "$TS" > "$HEARTBEAT"
BODY="<!--AUTOFILED source=fintable-auth-watch-->
<!--BBKEY:$BBKEY-->

Daily scheduled probe (fintable-auth-watch.sh, darwin launchd) found Fintable auth dead as of $TS:

\`\`\`
${PROBE_OUT:0:1000}
\`\`\`

This is the exact \"fails only when someone asks\" failure this watcher exists to make loud — see
card 1218107129933249 for the full job (re-auth needs Jason's logged-in Chrome; the durable fix is
switching to Fintable's official API v2 key auth, which also needs Jason to mint a key).

Success is silent — a healthy day files nothing further on this card."

if [ -n "$DRYRUN" ]; then
  printf '\n--- DRYRUN: would file/append this card ---\n%s\n--- end ---\n' "$BODY"
  exit 1
fi

[ -s "$TOKEN_FILE" ] || { log "NO ASANA TOKEN — cannot report the finding"; exit 1; }
PAT="$(cat "$TOKEN_FILE")"

EXISTING="$(/usr/bin/python3 "$HOME/Scripts/asana_client.py" find-open \
  --project "$STATE_MACHINE_PROJECT" --needle "<!--BBKEY:$BBKEY-->" 2>/dev/null)"; DEDUPE_RC=$?
if [ "$DEDUPE_RC" -ge 2 ]; then
  log "dedupe lookup BROKE (find-open rc=$DEDUPE_RC) — NOT filing, to avoid a duplicate"
  exit 1
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
  if [ "$WRC" -eq 0 ]; then log "FAIL — commented on existing card $EXISTING"
  else log "FAIL — comment on card $EXISTING UNCONFIRMED (asana write rc=$WRC); next firing retries"
  fi
else
  /usr/bin/python3 - "$PAT" "$STATE_MACHINE_PROJECT" "$BODY" <<'PY'
import json,sys,urllib.request
pat,proj,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request("https://app.asana.com/api/1.0/tasks",
    data=json.dumps({"data":{"projects":[proj],
      "name":"[defect] Fintable auth is silently dead (HTTP 419) -- scheduled probe",
      "notes":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
print(json.load(urllib.request.urlopen(r,timeout=30))["data"]["gid"])
PY
  WRC=$?
  if [ "$WRC" -eq 0 ]; then log "FAIL — filed a new card (no existing card found by BBKEY)"
  else log "FAIL — card filing UNCONFIRMED (asana write rc=$WRC); next firing retries via dedupe"
  fi
fi
exit 1
