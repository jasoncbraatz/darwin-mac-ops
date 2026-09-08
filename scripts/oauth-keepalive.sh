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
LOG="$ST/oauth-keepalive.log"
# The CLI's path differs by box (homebrew on darwin, /usr/local/bin on feynman); PATH first,
# then darwin's homebrew as the last resort -- a keepalive that cannot find `claude` refreshes
# nothing and logs "FAILED — token needs a human" for a token a human never had to touch.
CLAUDE="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || echo /opt/homebrew/bin/claude)}"
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
case "$http" in
  ok)  echo "$(now) ok — token live, nothing to do" >> "$LOG"; exit 0 ;;
  401|403)
    echo "$(now) http=$http — refreshing in the GUI domain" >> "$LOG"
    # fast_worker per ~/Scripts/models.json; a keepalive that bills orchestrator tokens is a leak.
    model=$(/usr/bin/python3 -c 'import json;print(json.load(open("'"$HOME"'/Scripts/models.json"))["tiers"]["fast_worker"]["alias"])' 2>/dev/null || echo haiku)
    if "$CLAUDE" -p ok --max-turns 1 --model "$model" >/dev/null 2>>"$LOG"; then
      echo "$(now) claude -p ok returned 0 — re-probing" >> "$LOG"
      /usr/bin/python3 "$PM/scripts/fuel_gauge.py" probe >> "$LOG" 2>&1
      rc=$?
      echo "$(now) probe rc=$rc" >> "$LOG"
      exit $rc
    else
      echo "$(now) claude -p FAILED — token needs a human (claude login in a GUI terminal)" >> "$LOG"
      exit 1
    fi ;;
  *)
    # not a token problem (network, 5xx, unreadable file): the probe's own timer will retry;
    # a keepalive that swings at every red would spend tokens on outages.
    echo "$(now) http=$http — not a token fault, leaving it to the probe" >> "$LOG"; exit 0 ;;
esac
