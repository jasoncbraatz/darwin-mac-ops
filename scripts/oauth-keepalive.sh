#!/bin/bash
# oauth-keepalive.sh — self-heal darwin's fuel gauge when the OAuth token has gone 401.
# Run by launchagents/com.braatz.oauth-keepalive.plist in the launchd GUI domain, every 30 min
# on darwin; by systemd/oauth-keepalive.timer (systemd --user) every 30 min on Linux, where
# ~/.claude/.credentials.json is a plain file any shell can refresh (smDrainDesk-14, 2026-09-08:
# feynman's personal tank read 401 for a day because nothing there ever ran `claude -p ok`).
# Install on either: scripts/oauth-keepalive-agent.sh --install
#
# WHY (AAR fuel-gauge-lost-its-needle A1, 2026-09-07 · FEYNMAN-FRICTION F13/F20): the macOS login
# keychain is LOCKED to every shell that is not launchd's GUI domain — ssh AND darlish. So when the
# CLI's OAuth token expires (~01:00Z on 09-07), nothing a cloud desk can run will refresh it:
# `claude -p` says "Not logged in", the fuel probe reads 401, the rail prints an ESTIMATE that read
# 59% while the truth was 84%, and the billing-guard wrote RUNNER-STOP for four lanes. The one thing
# that DOES refresh it is `claude` running in the GUI domain — which is exactly where this job runs.
#
# HEALTHY = SILENT, and CHEAP: it reads the probe's last verdict off disk and only spends a
# `claude -p ok --max-turns 1` (a handful of tokens, fast_worker tier) when that verdict is 401.
# Then it re-runs the probe so the gauge has a real reading before the next fuel-guard tick asks.
set -u
ST="$HOME/.local/state/pitching-machine"
# FUEL_USAGE_JSON / PM_DIR / CLAUDE_BIN are overridable so the 401 branch can be DRILLED against a
# fixture without running the real probe from a domain where the keychain is locked (F13).
FU="${FUEL_USAGE_JSON:-$ST/fuel-usage.json}"
PM="${PM_DIR:-$HOME/repos/pitching-machine}"
LOG="${KEEPALIVE_LOG:-$ST/oauth-keepalive.log}"   # overridable so the drill never writes the LIVE log (smDrainDesk-14)
# The CLI's path differs by box (homebrew on darwin, /usr/local/bin on feynman); PATH first,
# then darwin's homebrew as the last resort -- a keepalive that cannot find `claude` refreshes
# nothing and logs "FAILED — token needs a human" for a token a human never had to touch.
CLAUDE="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo /opt/homebrew/bin/claude)}"
# Linux keeps the token in a plain file; darwin keeps it in the keychain (no file -> "unknown").
CREDS="${CLAUDE_CREDS:-$HOME/.claude/.credentials.json}"
mkdir -p "$ST"
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
http=$(/usr/bin/python3 - "$FU" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get("http", "none") if not d.get("ok") else "ok")
except Exception:
    print("unreadable")
PY
)
# The probe's verdict is not the only witness. curie, 2026-09-26 (fuelbar-01): the access token
# expired 19:36Z, one refresh attempt failed, and the NEXT probe read 429 (rate_limit_error) instead of
# 401 -- which this script filed under "not a token fault" and left alone, so the gauge stayed dark
# with a perfectly good refresh token (17 days left) sitting in the file. So also ask the token itself.
tok=$(/usr/bin/python3 - "$CREDS" <<'PY' 2>/dev/null
import json, sys, time
try:
    c = json.load(open(sys.argv[1]))["claudeAiOauth"]
    print("expired" if c["expiresAt"] / 1000 < time.time() else "live")
except Exception:
    print("unknown")
PY
)
[ "$http" != ok ] && [ "$tok" = expired ] && case "$http" in 401|403) ;; *) http="$http+expired" ;; esac
case "$http" in
  ok)  echo "$(now) ok — token live, nothing to do" >> "$LOG"; exit 0 ;;
  401|403|*+expired)
    # COOLDOWN (fuelKeepalive-01, 2026-09-30): the plist now WATCHES fuel-usage.json, so this job
    # fires the instant the probe writes a 401 (v2 waited up to 30 min on a clock: the token died
    # 06:39Z, three minutes after a 06:36Z "ok", and darwin's gauge sat dark). Our own re-probe
    # rewrites that same file -- if it still reads 401, the watch would re-fire us every launchd
    # throttle (10 s), each one a billed `claude -p`. One attempt per cooldown window, silently.
    STAMP="${KEEPALIVE_STAMP:-$ST/oauth-keepalive.last-attempt}"
    COOL="${KEEPALIVE_COOLDOWN_S:-600}"
    last=$(cat "$STAMP" 2>/dev/null || echo 0)
    case "$last" in ''|*[!0-9]*) last=0 ;; esac
    [ $(( $(date +%s) - last )) -lt "$COOL" ] && exit 0
    date +%s > "$STAMP"
    echo "$(now) http=$http — refreshing in the GUI domain" >> "$LOG"
    # fast_worker per ~/Scripts/models.json; a keepalive that bills orchestrator tokens is a leak.
    model=$(/usr/bin/python3 -c 'import json;print(json.load(open("'"$HOME"'/Scripts/models.json"))["tiers"]["fast_worker"]["alias"])' 2>/dev/null || echo haiku)
    # claude -p prints its errors on STDOUT; v1 sent stdout to /dev/null, so the 2026-09-26 curie
    # failure left no reason behind. Keep the output; log its tail when it fails.
    refresh() { out=$("$CLAUDE" -p ok --max-turns 1 --model "$model" </dev/null 2>&1); }
    refresh; rc=$?
    # feynman 2026-10-02 (fuelbar-01): "Failed to refresh OAuth token: another Claude Code process is
    # refreshing it or exited mid-refresh ... retry in a minute". Claude Code guards the refresh with a
    # mkdir lock; a process killed mid-refresh (rail timeouts) leaves it behind, and on feynman a session
    # had renamed six of them aside BY HAND (.oauth_refresh.lock.stale-*). So: if the lock is older than
    # 5 min and no claude process is alive, it is litter -- RENAME it aside (never delete), then take
    # the one patient retry the CLI itself asks for.
    if [ $rc != 0 ] && printf '%s' "$out" | grep -q "another Claude Code process is refreshing"; then
      LOCK="${CLAUDE_REFRESH_LOCK:-$HOME/.claude/.oauth_refresh.lock}"
      if [ -n "${KEEPALIVE_IGNORE_PROCS:-}" ]; then alive=no      # drill only
      elif pgrep -u "$(id -u)" -f '(^|/)claude( |$)' >/dev/null; then alive=yes; else alive=no; fi
      if [ -d "$LOCK" ] && [ "$alive" = no ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
        mv "$LOCK" "$LOCK.stale-$(date -u +%Y%m%dT%H%M%SZ)" && echo "$(now) refresh lock was stale (>5 min, no claude alive) — renamed aside" >> "$LOG"
      fi
      echo "$(now) refresh lock busy — one patient retry in ${KEEPALIVE_RETRY_S:-60}s" >> "$LOG"
      sleep "${KEEPALIVE_RETRY_S:-60}"; refresh; rc=$?
    fi
    if [ $rc = 0 ]; then
      # Re-run the WHOLE tick (probe + publish to the n8n hub + guard), not just the probe
      # (fuelKeepalive-01, 2026-09-30 08:30Z): feynman's tick published its 401 to the hub, this
      # job healed feynman 4 s later with a bare probe, and darwin's FuelBar showed feynman as an
      # error for 30 min because the healed record never left the box. Bare probe = fallback only.
      if [ -f "$PM/scripts/fuel-tick.sh" ]; then
        echo "$(now) claude -p ok returned 0 — re-running fuel-tick (probe + publish + guard)" >> "$LOG"
        /bin/bash "$PM/scripts/fuel-tick.sh" >> "$LOG" 2>&1
      else
        echo "$(now) claude -p ok returned 0 — re-probing (no fuel-tick.sh: local only)" >> "$LOG"
        /usr/bin/python3 "$PM/scripts/fuel_gauge.py" probe >> "$LOG" 2>&1
      fi
      rc=$?
      echo "$(now) probe rc=$rc" >> "$LOG"
      exit $rc
    else
      echo "$(now) claude -p FAILED: $(printf '%s' "$out" | tail -3 | tr '\n' ' ' | cut -c1-300)" >> "$LOG"
      # Not necessarily a human's job: a transient 429/5xx on the refresh heals on the next tick
      # (the expired-token check above keeps retrying). Only a dead REFRESH token needs `claude /login`.
      echo "$(now) will retry next tick; if every tick fails, run claude /login on this box" >> "$LOG"
      exit 1
    fi ;;
  *)
    # not a token problem (network, 5xx, unreadable file): the probe's own timer will retry;
    # a keepalive that swings at every red would spend tokens on outages.
    echo "$(now) http=$http — not a token fault, leaving it to the probe" >> "$LOG"; exit 0 ;;
esac
