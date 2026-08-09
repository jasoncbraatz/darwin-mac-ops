#!/bin/bash
# filer-honesty-drill.sh (S48, 2026-08-09) — prove that a self-retiring filer CANNOT report a
# success it did not achieve.
#
# WHY THIS EXISTS
#   On 2026-08-09 at 02:15Z, flowers-hmac-enforce-watch.sh logged
#       PASS — commented + completed 1216968620841480
#   for a card that does not exist, then wrote "VERIFIED PASS — 3 cards completed" into its
#   sentinel and unloaded its own launchd job. The Asana write had raised; the log line was on
#   the same line, separated by a SEMICOLON, under `set -uo pipefail` with no `-e`. Nothing was
#   checked. The job retired on its own unverified say-so.
#
#   That is the exact false-green this whole tier of scripts exists to catch, committed by the
#   catcher. The scripts are fixed. THIS drill is what stops the fix from rotting: it forces the
#   failure branches and asserts that the success line and the sentinel both stay away.
#
# THE INVARIANT UNDER TEST — one sentence:
#   A filer may only go quiet once every card is ACCOUNTED FOR: written, or provably gone.
#
# HERMETIC BY CONSTRUCTION
#   - runs each script under a scratch $HOME, so LOG / HEARTBEAT / SENTINEL / LaunchAgents all
#     land in a temp dir and Jason's real ones are never touched;
#   - forces the Asana return code with FHW_FORCE_ASANA_RC / FDV_FORCE_ASANA_RC, which return
#     BEFORE any network call, so no token is used and nothing is ever sent to Asana;
#   - asserts on the two artifacts that actually decide the job's fate: the LOG line and the
#     SENTINEL file. Not on stdout, which is decoration.
#
# Run:  bash ~/code/darwin-mac-ops/filer-honesty-drill.sh
set -uo pipefail

HMAC="$HOME/code/darwin-mac-ops/flowers-hmac-enforce-watch.sh"
PASS=0; FAIL=0
note(){ printf '  %s\n' "$*"; }
ok(){   PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad(){  FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
check(){ # $1=label $2=condition-result(0/1)
  [ "$2" = 0 ] && ok "$1" || bad "$1"
}

# Build a scratch HOME that satisfies the script's early guards without touching anything real.
mkscratch(){
  S="$(mktemp -d)"
  mkdir -p "$S/Library/Logs" "$S/Library/LaunchAgents" \
           "$S/repos/flowers-sms-relay" "$S/.config/scan-pipeline"
  # A token must be non-empty or the script exits early down the "NO ASANA TOKEN" path. It is
  # never used: FHW_FORCE_ASANA_RC returns before any request is built.
  echo "drill-token-never-sent" > "$S/.config/scan-pipeline/asana.token"
  printf '%s' "$S"
}

run_hmac(){ # $1=scratch $2=forced asana rc
  HOME="$1" FHW_FORCE_RC=0 FHW_IGNORE_CLOCK=1 FHW_FORCE_ASANA_RC="$2" \
    bash "$HMAC" >/dev/null 2>&1
  echo $?
}

echo "=== filer-honesty-drill: a filer may not claim what it did not do ==="

# ---------------------------------------------------------------------------------------------
echo
echo "[1] Asana write FAILS (rc=1) — the regression that started all this"
S="$(mkscratch)"; RC="$(run_hmac "$S" 1)"
LOG="$S/Library/Logs/flowers-hmac-enforce-watch.log"
SEN="$S/Library/Logs/flowers-hmac-enforce-watch.RETIRED"
grep -q "ASANA WRITE UNCONFIRMED" "$LOG" 2>/dev/null; check "logs the write as UNCONFIRMED" $?
grep -q "PASS — commented + completed" "$LOG" 2>/dev/null
[ $? -ne 0 ] && ok "does NOT log a completion it never made" || bad "STILL logs a false completion"
[ ! -f "$SEN" ]; check "sentinel WITHHELD (job will retry tomorrow)" $?
grep -q "asana=UNCONFIRMED" "$S/Library/Logs/flowers-hmac-enforce-watch.heartbeat" 2>/dev/null
check "heartbeat carries asana=UNCONFIRMED" $?
note "exit=$RC (measurement passed; only the bookkeeping is unconfirmed)"
rm -rf "$S"

# ---------------------------------------------------------------------------------------------
echo
echo "[2] Card is GONE (rc=44) — benign: a deleted card needs no closing"
S="$(mkscratch)"; RC="$(run_hmac "$S" 44)"
LOG="$S/Library/Logs/flowers-hmac-enforce-watch.log"
SEN="$S/Library/Logs/flowers-hmac-enforce-watch.RETIRED"
grep -q "is GONE (HTTP 404)" "$LOG" 2>/dev/null; check "logs the card as gone, not as completed" $?
grep -q "PASS — commented + completed" "$LOG" 2>/dev/null
[ $? -ne 0 ] && ok "does NOT claim a completion for a card that is gone" || bad "claims a completion for a gone card"
[ -f "$SEN" ]; check "sentinel WRITTEN (gone cards are accounted for, so retiring is correct)" $?
note "exit=$RC"
rm -rf "$S"

# ---------------------------------------------------------------------------------------------
echo
echo "[3] Asana write SUCCEEDS (rc=0) — the happy path still retires"
S="$(mkscratch)"; RC="$(run_hmac "$S" 0)"
LOG="$S/Library/Logs/flowers-hmac-enforce-watch.log"
SEN="$S/Library/Logs/flowers-hmac-enforce-watch.RETIRED"
grep -q "PASS — commented + completed" "$LOG" 2>/dev/null; check "logs the completion" $?
[ -f "$SEN" ]; check "sentinel WRITTEN" $?
grep -q "every card accounted for" "$SEN" 2>/dev/null; check "sentinel says every card accounted for" $?
note "exit=$RC"
rm -rf "$S"

# ---------------------------------------------------------------------------------------------
echo
echo "[4] Both scripts' own branch self-tests still pass"
for s in "$HMAC" "$HOME/code/darwin-mac-ops/flowers-dupe-verify.sh"; do
  out="$(bash "$s" --self-test 2>&1 | tail -1)"
  case "$out" in
    SELF-TEST\ PASS*) ok "$(basename "$s") --self-test" ;;
    *)                bad "$(basename "$s") --self-test → $out" ;;
  esac
done

# ---------------------------------------------------------------------------------------------
echo
echo "[5] No filer may pair an Asana write with an unconditional success line"
# The literal shape of the original defect: a write and its own PASS log on one line, joined by
# a semicolon. Greps the sources so a future edit cannot quietly reintroduce it.
HITS=0
for s in "$HMAC" "$HOME/code/darwin-mac-ops/flowers-dupe-verify.sh"; do
  if grep -nE '^[^#]*asana_(comment|complete)[^;]*;[[:space:]]*log "(PASS|FAIL)' "$s"; then
    HITS=$((HITS+1))
  fi
done
[ "$HITS" = 0 ]; check "no 'write; log PASS' one-liners remain in either filer" $?

echo
echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" = 0 ] || exit 1
