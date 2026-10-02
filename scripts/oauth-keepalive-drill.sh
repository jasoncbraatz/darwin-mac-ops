#!/bin/bash
# oauth-keepalive-drill.sh — prove the keepalive heals a 401 and ignores everything else.
# Fixtures only: a stub `claude`, a stub fuel_gauge.py, a temp state dir. Never touches the real gauge.
set -u
D=$(mktemp -d "${TMPDIR:-/tmp}/ka-drill.XXXXXX") || exit 2
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/pm/scripts" "$D/st"
printf '#!/bin/bash\necho "$@" > "%s/claude.args"; exit 0\n' "$D" > "$D/claude"; chmod +x "$D/claude"
printf '#!/bin/bash\necho fail > "%s/claude.args"; echo "API Error: 429 rate_limit_error"; exit 1\n' "$D" > "$D/claude-bad"; chmod +x "$D/claude-bad"
printf 'import sys; open("%s/probed","w").write("yes"); print("stub probe ok")\n' "$D" > "$D/pm/scripts/fuel_gauge.py"
KA="$(dirname "$0")/oauth-keepalive.sh"
pass=0; total=0
ok(){ total=$((total+1)); if [ "$1" = 0 ]; then pass=$((pass+1)); echo "  ok   $2"; else echo "  FAIL $2"; fi; }
run(){ HOME_SAVE=$HOME; FUEL_USAGE_JSON="$D/fu.json" PM_DIR="$D/pm" KEEPALIVE_LOG="$D/keepalive.log" KEEPALIVE_STAMP="$D/stamp" KEEPALIVE_COOLDOWN_S="${COOL:-0}" CLAUDE_CREDS="$D/creds.json" CLAUDE_REFRESH_LOCK="$D/lock" KEEPALIVE_RETRY_S=0 KEEPALIVE_IGNORE_PROCS=1 CLAUDE_BIN="$1" bash "$KA" >/dev/null 2>&1; echo $?; }
# 1. healthy -> no claude call, rc 0
echo '{"ok": true, "http": 200}' > "$D/fu.json"; rm -f "$D/claude.args" "$D/probed"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && [ ! -e "$D/claude.args" ] && echo 0 || echo 1) "healthy: rc=0, claude not called"
# 2. 401 -> claude called with --max-turns 1, probe re-run, rc 0
echo '{"ok": false, "http": 401, "error": "expired"}' > "$D/fu.json"; rm -f "$D/claude.args" "$D/probed"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && grep -q -- "--max-turns 1" "$D/claude.args" 2>/dev/null && [ -e "$D/probed" ] && echo 0 || echo 1) "401: claude -p called (max-turns 1), probe re-run, rc=0"
# 3. 401 but claude fails -> rc 1, no probe
rm -f "$D/claude.args" "$D/probed"
rc=$(run "$D/claude-bad"); ok $([ "$rc" = 1 ] && [ ! -e "$D/probed" ] && echo 0 || echo 1) "401 + claude fails: rc=1, probe NOT run"
# 4. 503 -> not a token fault, claude not called, rc 0
echo '{"ok": false, "http": 503}' > "$D/fu.json"; rm -f "$D/claude.args" "$D/probed"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && [ ! -e "$D/claude.args" ] && echo 0 || echo 1) "503: left to the probe, claude not called"
# 5. unreadable file -> rc 0, claude not called
rm -f "$D/fu.json" "$D/claude.args"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && [ ! -e "$D/claude.args" ] && echo 0 || echo 1) "missing gauge file: rc=0, claude not called"
# 6. 429 but the token file says EXPIRED -> refresh anyway (curie 2026-09-26: 429 masked a dead access token)
echo '{"ok": false, "http": 429}' > "$D/fu.json"; rm -f "$D/claude.args" "$D/probed"
echo '{"claudeAiOauth": {"expiresAt": 1000}}' > "$D/creds.json"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && [ -e "$D/claude.args" ] && [ -e "$D/probed" ] && echo 0 || echo 1) "429 + expired token file: refreshed anyway, probe re-run"
# 7. 429 with a LIVE token -> not a token fault, claude not called
echo '{"claudeAiOauth": {"expiresAt": 99999999999999}}' > "$D/creds.json"; rm -f "$D/claude.args" "$D/probed"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && [ ! -e "$D/claude.args" ] && echo 0 || echo 1) "429 + live token: left to the probe, claude not called"
# 8. a failed refresh leaves its REASON in the log (v1 threw claude's stdout away)
echo '{"ok": false, "http": 401}' > "$D/fu.json"; rm -f "$D/creds.json" "$D/keepalive.log"
rc=$(run "$D/claude-bad"); ok $([ "$rc" = 1 ] && grep -q "429 rate_limit_error" "$D/keepalive.log" && echo 0 || echo 1) "failed refresh logs claude's own error text"
rm -f "$D/creds.json"
# 9. COOLDOWN (fuelKeepalive-01): the plist WATCHES fuel-usage.json, so our own re-probe re-fires us.
#    A second 401 inside the window must NOT spend another claude -p; one outside it must.
echo '{"ok": false, "http": 401}' > "$D/fu.json"; date +%s > "$D/stamp"; rm -f "$D/claude.args" "$D/probed"
rc=$(COOL=600 run "$D/claude"); ok $([ "$rc" = 0 ] && [ ! -e "$D/claude.args" ] && echo 0 || echo 1) "401 inside cooldown: silent, claude not called (no watch loop)"
echo $(( $(date +%s) - 601 )) > "$D/stamp"
rc=$(COOL=600 run "$D/claude"); ok $([ "$rc" = 0 ] && [ -e "$D/claude.args" ] && echo 0 || echo 1) "401 after cooldown: refreshed again"
# 10. the installed plist is event-driven AND keeps its clock parachute
PL="$(dirname "$0")/../launchagents/com.braatz.oauth-keepalive.plist"
ok $(grep -q '<key>WatchPaths</key>' "$PL" && grep -q 'fuel-usage.json' "$PL" && grep -q '<key>StartInterval</key>' "$PL" && echo 0 || echo 1) "plist watches fuel-usage.json and keeps StartInterval"
# 11. a healed token is PUBLISHED, not just probed (fuelKeepalive-01, feynman 08:30Z): when
#     fuel-tick.sh exists the keepalive runs it (probe + hub publish + guard) instead of a bare probe.
printf 'echo ticked > "%s/ticked"\n' "$D" > "$D/pm/scripts/fuel-tick.sh"
echo '{"ok": false, "http": 401}' > "$D/fu.json"; rm -f "$D/claude.args" "$D/probed" "$D/ticked" "$D/stamp"
rc=$(run "$D/claude"); ok $([ "$rc" = 0 ] && [ -e "$D/ticked" ] && [ ! -e "$D/probed" ] && echo 0 || echo 1) "401 healed: full fuel-tick re-run (publishes to hub), not a bare probe"
rm -f "$D/pm/scripts/fuel-tick.sh"
# 9. lock contention: first refresh says "another Claude Code process is refreshing", retry succeeds
cat > "$D/claude-lock" <<STUB
#!/bin/bash
if [ ! -e "$D/tried" ]; then touch "$D/tried"; echo "Failed to refresh OAuth token: another Claude Code process is refreshing it or exited mid-refresh."; exit 1; fi
echo "\$@" > "$D/claude.args"; exit 0
STUB
chmod +x "$D/claude-lock"
echo '{"ok": false, "http": 401}' > "$D/fu.json"; rm -f "$D/claude.args" "$D/probed" "$D/tried"
mkdir -p "$D/lock"; touch -t 202001010000 "$D/lock"
rc=$(run "$D/claude-lock"); ok $([ "$rc" = 0 ] && [ -e "$D/probed" ] && echo 0 || echo 1) "refresh-lock busy: one patient retry heals it"
# 10. ...and the >5-min orphan lock was RENAMED aside (never deleted)
ok $([ ! -d "$D/lock" ] && ls -d "$D"/lock.stale-* >/dev/null 2>&1 && echo 0 || echo 1) "orphaned refresh lock renamed aside, not deleted"
# 11. a FRESH lock (<5 min) is left alone -- it may belong to a live refresh
rm -rf "$D"/lock*; mkdir -p "$D/lock"; rm -f "$D/tried" "$D/probed"
rc=$(run "$D/claude-lock"); ok $([ -d "$D/lock" ] && echo 0 || echo 1) "fresh refresh lock left alone"
echo "oauth-keepalive-drill: $pass/$total"
[ "$pass" = "$total" ]
