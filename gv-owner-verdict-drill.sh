#!/usr/bin/env bash
# gv-owner-verdict-drill.sh — controls for gate-selfcheck's _gv_owner_verdict.
#
# WHY (feynmanSync-07, 2026-09-07). That helper returned an EMPTY STRING for five
# different situations and G-V printed one sentence for all of them:
#
#     "no identity (`roster whoami` empty: did you `roster leave` before the gate?)"
#
# On feynman that sentence is false. whoami answers correctly; what actually failed is
# that red-owner cannot reach Asana from a box with no token. A remedy aimed at the wrong
# cause is worse than no remedy — it sends the next session to re-check a thing that was
# never broken, and it hides the real blocker behind a plausible one.
#
# The fifth case is the mirror image and the more expensive one: rows exist and at least
# one red is genuinely MINE or an ORPHAN. That is a real finding, and it was arriving as
# "the instrument is broken".
#
# THE FUNCTION IS EXTRACTED FROM gate-selfcheck.sh AND EVAL'D, never copied here. A drill
# that grades a duplicate of the logic proves the duplicate.
#
# rc 0 = every control holds.  rc 1 = at least one did not.  rc 2 = could not extract.
set -uo pipefail
GATE="${GATE_FILE:-$HOME/code/darwin-mac-ops/gate-selfcheck.sh}"
PASS=0; FAIL=0
bold(){ printf '\033[1m%s\033[0m\n' "$*"; }
check(){ # check <name> <expected-prefix-or-EMPTY> <got>
  local name="$1" want="$2" got="$3"
  if [ "$want" = "EMPTY" ]; then
    [ -z "$got" ] && { printf '  ok    %-52s (empty)\n' "$name"; PASS=$((PASS+1)); return; }
    printf '  FAIL  %-52s got "%s", wanted empty\n' "$name" "$got"; FAIL=$((FAIL+1)); return
  fi
  case "$got" in
    "$want"*) printf '  ok    %-52s %s\n' "$name" "$(printf '%s' "$got" | cut -c1-46)"; PASS=$((PASS+1)) ;;
    *) printf '  FAIL  %-52s got "%s", wanted %s*\n' "$name" "$got" "$want"; FAIL=$((FAIL+1)) ;;
  esac
}

[ -f "$GATE" ] || { echo "drill: CANNOT VERIFY — gate not found at $GATE"; exit 2; }
_fn="$(awk '/^_gv_owner_verdict\(\)/,/^}$/' "$GATE")"
[ -n "$_fn" ] || { echo "drill: CANNOT VERIFY — could not extract _gv_owner_verdict from $GATE"; exit 2; }
eval "$_fn" || { echo "drill: CANNOT VERIFY — extracted function did not parse"; exit 2; }

T="$(mktemp -d "${TMPDIR:-/tmp}/gv-owner-drill.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT
_ROSTER_DB="$T/roster.sqlite3"
GATE_ROSTER_WHO="drill-session"
stub(){ printf '%s\n' "$2" > "$T/red-owner.py"; chmod +x "$T/red-owner.py"; _RED_OWNER="$T/red-owner.py"; }

bold "=== _gv_owner_verdict drill ==="

# 1. the tool is not on this box at all.
_RED_OWNER="$T/does-not-exist.py"
check "a missing red-owner says NOTOOL" "NOTOOL" "$(_gv_owner_verdict)"

# 2. THE FEYNMAN CASE: red-owner is present and cannot run (no Asana token). This used to
#    be reported as "no identity -- did you roster leave?", which is a different box, a
#    different fault, and a remedy that fixes nothing.
stub x 'import sys; sys.stderr.write("asana: no token in ~/.config/asana\n"); sys.exit(2)'
_got="$(_gv_owner_verdict)"
check "red-owner that cannot run says NORUN" "NORUN" "$_got"
if printf '%s' "$_got" | grep -q "asana"; then
  printf '  ok    %-52s carries the real stderr\n' "  ...and names the actual cause"; PASS=$((PASS+1))
else
  printf '  FAIL  %-52s lost the stderr that says WHY\n' "  ...and names the actual cause"; FAIL=$((FAIL+1))
fi

# 3. ran cleanly, printed only its human table. The --json contract changed underneath us.
stub x 'print("KEY  VERDICT  OWNER"); print("aar:x  MINE  me")'
check "no parseable JSON says NOJSON" "NOJSON" "$(_gv_owner_verdict)"

# 4. POSITIVE CONTROL — the escape hatch this helper exists for still opens.
stub x 'print("[{\"key\": \"aar:x\", \"verdict\": \"SIBLING\", \"owner\": \"fable-smDrainDesk-07\"}]")'
check "every red a sibling's still says SIBLING" "SIBLING" "$(_gv_owner_verdict)"

# 5. THE MIRROR-IMAGE BUG: a red that is genuinely MINE is a FINDING, not a broken
#    instrument. Before this it returned empty and G-V blamed the identity for it.
stub x 'print("[{\"key\": \"aar:x\", \"verdict\": \"MINE\", \"owner\": \"drill-session\"}]")'
check "a red that is MINE says OWNED" "OWNED" "$(_gv_owner_verdict)"

# 6. ...and the same for an ORPHAN mixed in with a sibling's: ONE non-sibling is enough.
#    Without this, control 4 could be passing because `all()` had been loosened.
stub x 'print("[{\"key\": \"aar:x\", \"verdict\": \"SIBLING\", \"owner\": \"sib\"}, {\"key\": \"aar:y\", \"verdict\": \"ORPHAN\", \"owner\": null}]")'
check "one ORPHAN among siblings still says OWNED" "OWNED" "$(_gv_owner_verdict)"

# 5b/6c. THE EXIT CODE THE STUBS ABOVE LIED ABOUT (smDrainDesk-09, 2026-09-07). The real
#     red-owner exits 1 when it RAN and found reds that are MINE or ORPHANS -- its JSON is on
#     stdout either way. Controls 5 and 6 stub that verdict with exit 0, so they passed while
#     production took rc 1 for NORUN and told feynman "the instrument is broken" over six real
#     orphans. A drill whose stub exits differently from the tool proves the stub.
stub x 'import sys; print("[{\"key\": \"aar:x\", \"verdict\": \"MINE\", \"owner\": \"drill-session\"}]"); sys.exit(1)'
check "MINE with the REAL rc 1 is OWNED, not NORUN" "OWNED" "$(_gv_owner_verdict)"
stub x 'import sys; print("[{\"key\": \"lesson:x\", \"verdict\": \"ORPHAN\", \"owner\": null}]"); sys.exit(1)'
check "ORPHAN with the REAL rc 1 is OWNED, not NORUN" "OWNED" "$(_gv_owner_verdict)"
stub x 'import sys; sys.stderr.write("gate did not run\n"); sys.exit(2)'
check "rc 2 is still NORUN (the contract line is at 2)" "NORUN" "$(_gv_owner_verdict)"

# 6b. THE ACTUAL FEYNMAN CASE, and the one that first slipped past this drill: red-owner
#     runs cleanly and reports ZERO reds while the AAR gate that feeds the block reports
#     one. That is the attributor disagreeing with the gate -- not "all the reds were
#     repos" -- and it used to fall through to the same empty string, which is how the
#     remedy line ended up naming the session identity for a missing Asana token.
stub x 'print("[]")'
check "zero reds while the gate has one says NOREDS" "NOREDS" "$(_gv_owner_verdict)"

# 7. rows that are all repos belong to G-H#22e, not to G-V. Empty is CORRECT here, and it
#    is the one remaining path that legitimately returns nothing.
stub x 'print("[{\"key\": \"repo:~/Scripts\", \"verdict\": \"MINE\", \"owner\": \"drill-session\"}]")'
check "repo-only rows stay G-H's business" "EMPTY" "$(_gv_owner_verdict)"

echo
if [ "$FAIL" -gt 0 ]; then
  bold "=== _gv_owner_verdict drill: FAIL — $FAIL of $((PASS+FAIL)) controls did not hold ==="
  exit 1
fi
bold "=== _gv_owner_verdict drill: PASS — $PASS controls (6 of them causes that used to be one empty string; 3 of them the rc 1 that used to be NORUN) ==="
exit 0
