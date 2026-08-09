#!/bin/bash
# flowers-hmac-enforce-watch.sh — the day-long (and the day after, and the day after…)
# post-flip watch on SHOPIFY_HMAC_MODE=enforce, run as a LOCAL launchd task on darwin.
#
# WHY THIS EXISTS
#   Card 1217092365565115 says, in as many words: "Flip SHOPIFY_HMAC_MODE=enforce, then WATCH
#   THE LOG FOR A FULL DAY before walking away. Not a glance — file a check that runs tomorrow,
#   because 'I watched it for a minute' is the false green this whole card family exists to
#   catch." This is that check. S38 flipped the mode; a session that flips and then declares
#   victory inside the same ten minutes has measured its own optimism.
#
# WHY IT IS LOCAL AND NOT A COWORK CLOUD SCHEDULED TASK
#   It reads the flowers Linode's pm2 log *through* darwin (tools/flowers-remote.sh) and needs
#   darwin's repos and Asana token. A fresh-session cloud task has no device bridge, so every
#   ~/ path in it is dead on arrival — it would report success having done nothing. That is a
#   banked global lesson (2026-07-31, tags cowork,scheduling,launchd) and the exact bug that
#   AAR 2026-07-29-geo-detector-blind-spot exists to prevent. Same shape as its sibling,
#   flowers-dupe-verify.sh, which this script is deliberately modelled on.
#
# HOW THE POST-FLIP BOUNDARY IS ESTABLISHED — read this before "improving" the greps
#   The [hmac] log lines carry NO timestamp, so a time-based cutover line cannot be drawn from
#   them (S37 had to correlate against nginx and the file mtime to interpret two counts, which
#   is exactly the kind of archaeology a verifier should not depend on). But the line prints the
#   MODE it ran under:
#       [hmac] mode=enforce ok=false reason=hmac-mismatch domain=<store> order=<id|->
#   `mode=enforce` cannot appear before the flip. So the boundary is STRUCTURAL, not temporal —
#   every enforce-mode line is post-flip by construction, immune to clock skew, log rotation
#   ordering and mtime games. Do not replace this with a timestamp heuristic.
#
# WHY `order=-` LINES ARE EXCLUDED FROM THE FAIL TEST — this is not a loophole, it is the test
#   At cutover (2026-08-07 17:45Z) one Shopify delivery was in flight, signed with the admin
#   webhook secret Jason had just deleted. It carries NO order id, the handler 400s it (now
#   401s it), and Shopify therefore RETRIES it on backoff until its window exhausts — no later
#   than 2026-08-09 17:45Z. Proven from nginx: genuine Shopify egress IPs + Shopify-Captain-Hook
#   UA at 17:51:01Z and 18:21:02Z. Counting that retry corpse as a failure would falsify a
#   correct theory with a dead delivery's death rattle. The S19 prediction being tested is about
#   REAL ORDERS, so the test is about lines carrying a real order id. A single enforce-mode
#   mismatch WITH an order id falsifies it, at any sample size, immediately.
#   S38's own negative control (a hand-rolled bogus-signature POST proving the 401 path) also
#   logged order=- and is excluded by the same rule, deliberately.
#
# EXIT CONTRACT (asymmetric on purpose, inherited from flowers-dupe-verify.sh)
#   0 = PASS   -> only after BOTH a full day has elapsed AND enough real orders have verified.
#                 Comments + completes all three cards, banks the verdict, then RETIRES itself.
#   1 = FAIL   -> trustworthy at ANY sample size. One real order failing HMAC under enforce is
#                 a dropped webhook, which is the 2026-07-14 missing-orders incident wearing a
#                 new hat. Cards it loudly, with the revert command in the card body.
#   2 = CANNOT VERIFY -> not enough real orders yet, or the log is unreachable. NOT a pass.
#                 Stays quiet, heartbeats, tries again tomorrow.
set -uo pipefail

RELAY="$HOME/repos/flowers-sms-relay"
FLIP_TS="2026-08-07T18:43:00Z"        # the flip boundary. Do not "round" this.
FLIP_EPOCH=1786128180                 # python3 -c 'import datetime;print(int(datetime.datetime(2026,8,7,18,43,tzinfo=datetime.timezone.utc).timestamp()))'
                                      # (a hand-computed value here was wrong by exactly 86400 on
                                      #  first write — derive it, never eyeball it)
MIN_HOURS=24                          # "watch it for a full day" — the card's words, in code
MIN_ORDERS=3                          # one verified order is an anecdote; three is a sample
DRIVER_CARD="1217092365565115"
COMPANION_CARDS="1216968508495305 1216968620841480"
AAR_SLUG="delivered-text-double-fire" # closing comments MUST carry this or the AAR gate trips
BATTERS_BOX="1213050213165325"
BBKEY="BBKEY flowers-hmac-enforce-watch"
TOKEN_FILE="$HOME/.config/scan-pipeline/asana.token"
LOG="$HOME/Library/Logs/flowers-hmac-enforce-watch.log"
HEARTBEAT="$HOME/Library/Logs/flowers-hmac-enforce-watch.heartbeat"
SENTINEL="$HOME/Library/Logs/flowers-hmac-enforce-watch.RETIRED"
PLIST="$HOME/Library/LaunchAgents/com.braatz.flowers-hmac-enforce-watch.plist"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- TEST HOOKS (see --self-test) -----------------------------------------------------------
#   FHW_FORCE_RC=<0|1|2>   pretend the measurement returned this, to exercise a branch.
#   FHW_DRYRUN=1           print every Asana write instead of performing it.
#   FHW_IGNORE_CLOCK=1     skip the 24h floor (so branch 0 is testable on flip day).
# Branches 0 and 1 would otherwise ship untested, and an untested failure branch is silence —
# the precise failure mode this whole tier exists to cure.
FORCE_RC="${FHW_FORCE_RC:-}"
DRYRUN="${FHW_DRYRUN:-}"
IGNORE_CLOCK="${FHW_IGNORE_CLOCK:-}"

mkdir -p "$(dirname "$LOG")"
log() { printf '%s %s\n' "$TS" "$*" >> "$LOG"; }

if [ "${1:-}" = "--self-test" ]; then
  echo "=== self-test: exercising every branch with FHW_DRYRUN=1 (no Asana writes) ==="
  rc_seen=""
  for f in 2 1 0; do
    echo "--- forcing rc=$f ---"
    FHW_FORCE_RC=$f FHW_DRYRUN=1 FHW_IGNORE_CLOCK=1 bash "$0"; got=$?
    echo "--- branch rc=$f exited $got ---"
    [ "$got" = "$f" ] || { echo "SELF-TEST FAIL: forced $f, got $got"; exit 1; }
    rc_seen="$rc_seen $got"
  done
  echo "SELF-TEST PASS — branches$rc_seen each reached and returned their own code."
  exit 0
fi

# --- already decided? then this job is done and must stop touching production ---------------
if [ -f "$SENTINEL" ] && [ -z "$DRYRUN" ]; then
  log "retired already ($(head -1 "$SENTINEL")) — no-op"; exit 0
fi

if [ ! -d "$RELAY" ]; then
  log "CANNOT VERIFY: $RELAY missing"; printf '%s exit=2 reason=no-repo\n' "$TS" > "$HEARTBEAT"; exit 2
fi

git -C "$RELAY" pull --ff-only --quiet 2>/dev/null || log "WARN: git pull failed (continuing on the local copy)"

NOW_EPOCH="$(date -u +%s)"
ELAPSED_H=$(( (NOW_EPOCH - FLIP_EPOCH) / 3600 ))

if [ -n "$FORCE_RC" ]; then
  RC="$FORCE_RC"
  MODE="enforce"; VALID_ORDERS="$MIN_ORDERS"; BAD_ORDERS=""; BAD_N=0
  VERDICT="[FHW_FORCE_RC=$RC — synthetic verdict block for a branch test, not a real measurement]"
  log "SELF-TEST: forced rc=$RC (nothing measured)"
else
  # ONE remote round-trip, no pipeline between the measurement and its exit code. Rotated logs
  # are included: pm2-logrotate will eventually move the lines we care about out of the live
  # file, and a watcher that only reads the live file quietly starts measuring an empty set.
  OUT="$(cd "$RELAY" && bash tools/flowers-remote.sh '
    L=/root/.pm2/logs
    FILES=$(ls -1 $L/express-ws-app-out*.log 2>/dev/null)
    echo "MODE_ENV=$(grep -m1 "^SHOPIFY_HMAC_MODE=" /var/www/flowers/.env | cut -d= -f2)"
    echo "VALID_ORDERS=$(sudo grep -h "mode=enforce ok=true" $FILES 2>/dev/null | grep -o "order=[0-9]\+" | sort -u | wc -l | tr -d " ")"
    echo "BAD_LINES<<EOF"
    sudo grep -h "mode=enforce ok=false" $FILES 2>/dev/null | grep "order=[0-9]" | tail -20
    echo "EOF"
    echo "ORPHAN_RETRIES=$(sudo grep -h "mode=enforce ok=false.*order=-" $FILES 2>/dev/null | wc -l | tr -d " ")"
  ' 2>&1)"; RRC=$?

  if [ "$RRC" -ne 0 ]; then
    log "CANNOT VERIFY: remote read failed rc=$RRC"
    printf '%s exit=2 reason=remote-unreachable\n' "$TS" > "$HEARTBEAT"
    printf '%s\n' "$OUT" >> "$LOG"
    exit 2
  fi

  MODE="$(printf '%s\n' "$OUT" | sed -n 's/^MODE_ENV=//p' | tail -1)"
  VALID_ORDERS="$(printf '%s\n' "$OUT" | sed -n 's/^VALID_ORDERS=//p' | tail -1)"
  ORPHANS="$(printf '%s\n' "$OUT" | sed -n 's/^ORPHAN_RETRIES=//p' | tail -1)"
  BAD_ORDERS="$(printf '%s\n' "$OUT" | sed -n '/^BAD_LINES<<EOF$/,/^EOF$/p' | sed '1d;$d')"
  BAD_N="$(printf '%s' "$BAD_ORDERS" | grep -c . || true)"
  : "${VALID_ORDERS:=0}"; : "${BAD_N:=0}"; : "${MODE:=unknown}"; : "${ORPHANS:=0}"

  VERDICT="POST-FLIP VERDICT (boundary = mode=enforce lines, flip $FLIP_TS)
  elapsed since flip     : ${ELAPSED_H}h  (floor ${MIN_HOURS}h)
  SHOPIFY_HMAC_MODE now  : $MODE
  distinct orders VALID  : $VALID_ORDERS  (floor $MIN_ORDERS)
  order-bearing FAILURES : $BAD_N   <-- any non-zero falsifies the S19 prediction
  orphan retries (order=-): $ORPHANS  (expected; the pre-cutover retry corpse, dead by 2026-08-09 17:45Z)"

  # --- decide. FAIL first: it is trustworthy at any sample size. ---------------------------
  if [ "$MODE" != "enforce" ]; then
    RC=1
    VERDICT="$VERDICT

DRIFT: SHOPIFY_HMAC_MODE is '$MODE', not 'enforce'. The watch is measuring nothing."
    log "FAIL — mode drift: $MODE"
  elif [ "$BAD_N" -gt 0 ]; then
    RC=1
    VERDICT="$VERDICT

FALSIFIED. Real orders are failing HMAC under enforce, which means they are being 401'd
and DROPPED. Offending lines (last 20):
$BAD_ORDERS"
    log "FAIL — $BAD_N order-bearing enforce mismatches"
  elif [ -z "$IGNORE_CLOCK" ] && [ "$ELAPSED_H" -lt "$MIN_HOURS" ]; then
    RC=2; log "CANNOT VERIFY — only ${ELAPSED_H}h elapsed of ${MIN_HOURS}h"
  elif [ "$VALID_ORDERS" -lt "$MIN_ORDERS" ]; then
    RC=2; log "CANNOT VERIFY — only $VALID_ORDERS verified orders of $MIN_ORDERS"
  else
    RC=0; log "PASS — $VALID_ORDERS orders verified, 0 order-bearing failures, ${ELAPSED_H}h elapsed"
  fi
fi

# POSITIVE DATED HEARTBEAT — always, every outcome. Absence of a fresh heartbeat is itself the
# alarm; without this, "silent" means both "all good" and "never ran".
[ -z "$DRYRUN" ] && printf '%s exit=%s valid=%s bad=%s mode=%s\n' \
  "$TS" "$RC" "${VALID_ORDERS:-?}" "${BAD_N:-?}" "${MODE:-?}" > "$HEARTBEAT"

PAT=""
[ -s "$TOKEN_FILE" ] && PAT="$(cat "$TOKEN_FILE")"

# --- ASANA WRITES: THE EXIT CODES ARE LOAD-BEARING ------------------------------------------
# Read this before "simplifying" these three functions.
#
#   0  = the write HAPPENED.
#   44 = the card is GONE (HTTP 404). Benign — a card that no longer exists needs no closing —
#        so it must NOT block retirement, but it must NEVER be logged as a completion.
#   1  = anything else (auth, 5xx, network). The write did NOT happen and we do not know when
#        it will, so the caller must refuse to retire and try again tomorrow.
#
# WHY THIS EXISTS (S48, 2026-08-09). Before today these functions returned an exit code that
# nobody read, because the PASS branch was written with SEMICOLONS under `set -uo pipefail`
# (no `-e`):
#
#     asana_comment "$c" "$BODY"; asana_complete "$c"; log "PASS — commented + completed $c"
#
# so a write that raised still logged PASS. The 02:15Z 2026-08-09 run did exactly that: it
# logged `PASS — commented + completed 1216968620841480` for a card that DOES NOT EXIST, then
# wrote `VERIFIED PASS — 3 cards completed` into the sentinel and unloaded its own launchd job.
# It retired on a claim it never checked. That is precisely the false-green this entire tier of
# scripts was built to catch, committed by the catcher — so the log line and the retirement
# decision are now both downstream of a checked exit code, and never the other way around.
#
# The general rule, banked as a lesson: A LOG LINE IS NOT EVIDENCE. If the success message can
# be printed on a path where the work failed, the message is decoration, not instrumentation.
_asana_write() { # $1=url-suffix $2=method $3=json-payload $4=gid(for messages)
  /usr/bin/python3 - "$PAT" "$1" "$2" "$3" "$4" <<'PY'
import sys,urllib.request,urllib.error
pat,suffix,method,payload,gid = sys.argv[1:6]
r=urllib.request.Request(f"https://app.asana.com/api/1.0/tasks/{suffix}",
    data=payload.encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method=method)
try:
    urllib.request.urlopen(r,timeout=30)
except urllib.error.HTTPError as e:
    sys.stderr.write("asana %s %s -> HTTP %s for card %s\n" % (method,suffix,e.code,gid))
    sys.exit(44 if e.code == 404 else 1)
except Exception as e:
    sys.stderr.write("asana %s %s -> %s for card %s\n" % (method,suffix,e,gid))
    sys.exit(1)
PY
}

asana_comment() { # $1=gid $2=text
  # FHW_FORCE_ASANA_RC returns BEFORE any network call, so a drill can exercise the failure
  # branches (1 = unconfirmed, 44 = card gone) without a bogus token ever leaving the machine.
  # Without this the fix shipped here would itself be untested — which is the whole complaint.
  [ -n "${FHW_FORCE_ASANA_RC:-}" ] && return "$FHW_FORCE_ASANA_RC"
  if [ -n "$DRYRUN" ]; then
    printf '\n--- DRYRUN: would COMMENT on %s ---\n%s\n--- end ---\n' "$1" "$2"; return 0
  fi
  _asana_write "$1/stories" POST \
    "$(/usr/bin/python3 -c 'import json,sys; print(json.dumps({"data":{"text":sys.argv[1]}}))' "$2")" "$1"
}

asana_complete() { # $1=gid
  [ -n "${FHW_FORCE_ASANA_RC:-}" ] && return "$FHW_FORCE_ASANA_RC"
  if [ -n "$DRYRUN" ]; then
    printf '\n--- DRYRUN: would COMPLETE card %s ---\n' "$1"; return 0
  fi
  _asana_write "$1" PUT '{"data":{"completed":true}}' "$1"
}

if [ -z "$PAT" ] && [ -z "$DRYRUN" ]; then
  log "rc=$RC but NO ASANA TOKEN — could not surface. This is the silent case; fix the token."
  printf '%s\n' "$VERDICT" >&2; exit "$RC"
fi

case "$RC" in
0)
  # AAR: line is load-bearing — aar.py gate refuses silent closures (card 1217019582084476).
  BODY="✅ HMAC ENFORCE VERIFIED — the S19 prediction held all the way through.

\`\`\`
$VERDICT
\`\`\`

The falsifiable prediction written down back in S19 — *Shopify signs with the OWNING app's
secret, so once only blip's subscriptions remain, mismatches go to zero with no code change* —
is now confirmed against real traffic under enforce, not just monitor. Jason's 10 minutes in
Shopify admin were the whole fix; the code was right the entire time.

AAR: $AAR_SLUG  (action A2 — 'resolve BEFORE anyone flips HMAC_MODE to enforce')

Rollback, still real and still one line:
  cp /var/www/flowers/.env.bak-hmacenforce-20260807 /var/www/flowers/.env && pm2 restart express-ws-app --update-env

Verified by ~/Scripts/flowers-hmac-enforce-watch.sh, the LOCAL launchd job
(com.braatz.flowers-hmac-enforce-watch) — local because a cloud scheduled task has no device
bridge and could not have reached darwin or the flowers box at all. This job has now RETIRED
itself (sentinel: ~/Library/Logs/flowers-hmac-enforce-watch.RETIRED)."
  # Every card must be ACCOUNTED FOR before this job is allowed to retire. "Accounted for"
  # means either the write succeeded, or the card is provably gone (404) and so needs nothing.
  # An unconfirmed write leaves ALL_OK=0, which withholds the sentinel — and withholding the
  # sentinel is what makes tomorrow's run retry instead of no-op. Self-healing by omission.
  ALL_OK=1
  for c in $DRIVER_CARD $COMPANION_CARDS; do
    asana_comment "$c" "$BODY"; CRC=$?
    asana_complete "$c";        XRC=$?
    if [ "$CRC" = 0 ] && [ "$XRC" = 0 ]; then
      log "PASS — commented + completed $c"
    elif [ "$CRC" = 44 ] || [ "$XRC" = 44 ]; then
      log "PASS — card $c is GONE (HTTP 404); nothing to close. Not a failure, not a completion."
    else
      ALL_OK=0
      log "ASANA WRITE UNCONFIRMED for card $c (comment rc=$CRC, complete rc=$XRC) — NOT retiring."
    fi
  done

  if [ "$ALL_OK" = 1 ]; then
    [ -z "$DRYRUN" ] && printf '%s VERIFIED PASS — every card accounted for\n' "$TS" > "$SENTINEL"
    [ -z "$DRYRUN" ] && [ -f "$PLIST" ] && launchctl unload "$PLIST" 2>/dev/null && log "unloaded $PLIST"
    exit 0
  fi

  # The MEASUREMENT passed; only the bookkeeping is unconfirmed. Say so in the heartbeat rather
  # than in a fresh Batter's Box card — filing a card requires the very API that just failed.
  log "measurement PASSed but at least one Asana write was unconfirmed — sentinel withheld, job NOT retired, will retry tomorrow."
  [ -z "$DRYRUN" ] && printf '%s exit=%s valid=%s bad=%s mode=%s asana=UNCONFIRMED\n' \
    "$TS" "$RC" "${VALID_ORDERS:-?}" "${BAD_N:-?}" "${MODE:-?}" > "$HEARTBEAT"
  exit 0
  ;;
1)
  EXISTING=""
  if [ -z "$DRYRUN" ]; then
    EXISTING="$(/usr/bin/python3 "$HOME/Scripts/asana_client.py" find-open \
      --project "$BATTERS_BOX" --needle "$BBKEY" 2>/dev/null)"; DEDUPE_RC=$?
    if [ "$DEDUPE_RC" -ge 2 ]; then
      # Lookup BROKE (not "no card exists"): filing now duplicates the card when Asana
      # recovers (measured on aar-gate 2026-08-06). Skip filing; next run retries.
      log "FAIL but dedupe lookup BROKE (find-open rc=$DEDUPE_RC) — NOT filing, to avoid a duplicate; next run retries"
      exit 1
    fi
  fi
  BODY="<!--AUTOFILED source=flowers-hmac-enforce-watch-->
$BBKEY

**Shopify webhooks are being REJECTED under HMAC enforce.** Every 401 here is an order the
relay never processed — the 2026-07-14 missing-orders incident wearing a new hat.

\`\`\`
$VERDICT
\`\`\`

REVERT FIRST, DIAGNOSE SECOND (this is reversible and it is one line):
  cd ~/repos/flowers-sms-relay && ./tools/flowers-remote.sh 'cp /var/www/flowers/.env.bak-hmacenforce-20260807 /var/www/flowers/.env && pm2 restart express-ws-app --update-env'

PASTE-TO-CLAUDE:
\"Shopify HMAC enforce is dropping real webhooks on the flowers relay. Revert to monitor with
the command above FIRST, confirm with: ./tools/flowers-remote.sh 'grep ^SHOPIFY_HMAC_MODE /var/www/flowers/.env'.
Then read Asana card $DRIVER_CARD and AAR $AAR_SLUG (action A2). The S19 prediction was that
Shopify signs each webhook with the OWNING app's client secret, so after Jason deleted the
admin Notifications-page webhooks on 2026-08-07 17:45Z only blip's remained and every delivery
should verify against SHOPIFY_ATX_CLIENT_SECRET / SHOPIFY_SF_CLIENT_SECRET. An order-bearing
mismatch under enforce falsifies that — which means our own secret handling is wrong, a
different and more serious bug than the tidy one. Say that out loud rather than quietly
patching. Verifier is /var/www/flowers/server.ts verifyShopifyHmac(); the secrets map is at
the top of that file. Check whether the failing store's secret in .env still matches the
client secret shown in the blip app's Shopify admin — a rotated secret is the first suspect.\"

--
Filed by ~/Scripts/flowers-hmac-enforce-watch.sh (local launchd com.braatz.flowers-hmac-enforce-watch).
Exit $RC. 0=verified 1=webhooks being dropped 2=insufficient data (NOT a pass)."
  # SURFACED=1 only once Asana has actually accepted the news. This branch means real webhooks
  # are being DROPPED, so the sentinel — which permanently silences this job — must not be
  # written on the strength of an unverified write. Before S48 it was written unconditionally:
  # if the filing failed, the job recorded "see Batter's Box", retired itself, and pointed at a
  # card that was never created. A dropped-orders incident would have died in a log file.
  SURFACED=0
  if [ -n "$EXISTING" ]; then
    if asana_comment "$EXISTING" "$BODY"; then
      SURFACED=1; log "FAIL — commented on existing card $EXISTING"
    else
      log "FAIL — could NOT comment on existing card $EXISTING (rc=$?) — not surfaced."
    fi
  elif [ -n "$DRYRUN" ]; then
    printf '\n--- DRYRUN: would CREATE a Batter'"'"'s Box card ---\n%s\n--- end ---\n' "$BODY"
    SURFACED=1
  else
    if NEWGID=$(/usr/bin/python3 - "$PAT" "$BATTERS_BOX" "$BODY" <<'PY'
import json,sys,urllib.request,urllib.error
pat,proj,body=sys.argv[1],sys.argv[2],sys.argv[3]
r=urllib.request.Request("https://app.asana.com/api/1.0/tasks",
    data=json.dumps({"data":{"projects":[proj],
      "name":"\U0001F534 Flowers: HMAC enforce is REJECTING real Shopify webhooks — orders are being dropped",
      "notes":body}}).encode(),
    headers={"Authorization":"Bearer "+pat,"Content-Type":"application/json"},method="POST")
try:
    print(json.load(urllib.request.urlopen(r,timeout=30))["data"]["gid"])
except Exception as e:
    sys.stderr.write("asana create failed: %s\n" % e); sys.exit(1)
PY
    ); then
      SURFACED=1; log "FAIL — filed a new Batter's Box card $NEWGID"
    else
      log "FAIL — could NOT file a Batter's Box card — the failure is NOT surfaced anywhere but this log."
    fi
  fi

  if [ "$SURFACED" = 1 ]; then
    [ -z "$DRYRUN" ] && printf '%s FAILED — webhooks dropped under enforce; see Batter\x27s Box\n' "$TS" > "$SENTINEL"
  else
    # No sentinel => this job runs again tomorrow and tries to surface the incident again.
    log "sentinel withheld — the incident was never surfaced, so this job must NOT go quiet."
    [ -z "$DRYRUN" ] && printf '%s exit=%s valid=%s bad=%s mode=%s asana=UNCONFIRMED\n' \
      "$TS" "$RC" "${VALID_ORDERS:-?}" "${BAD_N:-?}" "${MODE:-?}" > "$HEARTBEAT"
  fi
  exit 1
  ;;
*)
  log "CANNOT VERIFY (rc=$RC) — not enough post-flip order traffic yet. Staying quiet, retrying tomorrow."
  exit 2
  ;;
esac
