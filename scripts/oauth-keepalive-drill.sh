#!/bin/bash
# oauth-keepalive-drill.sh — prove the keepalive heals a 401 and ignores everything else.
# Fixtures only: a stub `claude`, a stub fuel_gauge.py, a temp state dir. Never touches the real gauge.
set -u
D=$(mktemp -d "${TMPDIR:-/tmp}/ka-drill.XXXXXX") || exit 2
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/pm/scripts" "$D/st"
printf '#!/bin/bash\necho "$@" > "%s/claude.args"; exit 0\n' "$D" > "$D/claude"; chmod +x "$D/claude"
printf '#!/bin/bash\necho fail > "%s/claude.args"; exit 1\n' "$D" > "$D/claude-bad"; chmod +x "$D/claude-bad"
printf 'import sys; open("%s/probed","w").write("yes"); print("stub probe ok")\n' "$D" > "$D/pm/scripts/fuel_gauge.py"
KA="$(dirname "$0")/oauth-keepalive.sh"
pass=0; total=0
ok(){ total=$((total+1)); if [ "$1" = 0 ]; then pass=$((pass+1)); echo "  ok   $2"; else echo "  FAIL $2"; fi; }
run(){ HOME_SAVE=$HOME; FUEL_USAGE_JSON="$D/fu.json" PM_DIR="$D/pm" KEEPALIVE_LOG="$D/keepalive.log" CLAUDE_BIN="$1" bash "$KA" >/dev/null 2>&1; echo $?; }
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
echo "oauth-keepalive-drill: $pass/$total"
[ "$pass" = "$total" ]
