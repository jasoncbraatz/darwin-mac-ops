#!/bin/bash
# =============================================================================
# hooks-drill.sh — prove the estate pre-commit hook OFFLINE, on scratch repos.
#
# A control you can only test in production is a control nobody tests (S44,
# roster-drill.sh). This one is louder than most, because installing
# core.hooksPath can SILENTLY disable a repo's existing hooks -- so #5, #6 and #7
# are not nice-to-haves, they are the reason this file exists.
#
#   bash hooks-drill.sh          # scratch dirs, scratch ~/.gitconfig, zero live repos touched
#
# ⚠ HERMETIC OR IT IS NOT A DRILL. Until S46 this file exported GIT_CONFIG_NOSYSTEM
# but NOT GIT_CONFIG_GLOBAL, so every `git` below read Jason's real ~/.gitconfig.
# That was invisible while the estate had no global git settings — and the instant
# S46 set a global core.hooksPath the drill went 16 passed / 1 FAILED on a change
# that was working perfectly. A test that only passes because the machine happens
# to be configured a certain way is not testing the thing it claims to test.
#
# ⚠ The needle is SYNTHESIZED AT RUNTIME, never written literally in this file.
# A test for a secret scanner that spells its own needle becomes a permanent
# allowlist entry -- the scanner bites the test, and the fix is to blind the
# scanner to the one file that proves it works. (S44 hit the same wall twice:
# once in the allowlist's own reason text, once in a handoff doc.)
# =============================================================================
set -uo pipefail
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  ok    %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; }
chk()  { if [ "$1" = "$2" ]; then ok "$3"; else bad "$3 (want=$1 got=$2)"; fi; }

HEX32="0123456789abcdef0123456789abcdef"
NEEDLE="shp""at_$HEX32"                      # split literal: this file never matches itself

SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/hooks-drill.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
export GIT_CONFIG_NOSYSTEM=1
# The other half of hermetic: a scratch global config, so the drill neither reads
# nor writes the real ~/.gitconfig. Assertions #13-#16 SET a global core.hooksPath
# on purpose; without this line they would rewrite Jason's.
export GIT_CONFIG_GLOBAL="$SCRATCH/gitconfig"
: > "$GIT_CONFIG_GLOBAL"
git config --global user.email drill@local
git config --global user.name  drill
git config --global commit.gpgsign false

newrepo() {  # newrepo <name> -> prints path
  local d="$SCRATCH/$1"
  mkdir -p "$d"; git -C "$d" init -q 2>/dev/null
  git -C "$d" config user.email drill@local; git -C "$d" config user.name drill
  git -C "$d" config commit.gpgsign false
  printf '%s' "$d"
}
install_into() { bash "$HOOKS_DIR/install-estate-hooks.sh" --repo "$1" --quiet >/dev/null 2>&1; }
commit_rc() {   # commit_rc <repo> <msg> -> exit code of git commit
  git -C "$1" commit -q -m "$2" >"$SCRATCH/out.$$" 2>&1; echo $?
}

echo "=== estate hooks drill (scratch: $SCRATCH) ==="

# 1 — a clean commit passes
r="$(newrepo clean)"; install_into "$r"
echo "hello" > "$r/a.txt"; git -C "$r" add a.txt
chk 0 "$(commit_rc "$r" clean)" "#1 clean commit passes"

# 2 — a staged credential is BLOCKED
r="$(newrepo blocked)"; install_into "$r"
printf 'token = "%s"\n' "$NEEDLE" > "$r/seed.ts"; git -C "$r" add seed.ts
rc="$(commit_rc "$r" secret)"
[ "$rc" -ne 0 ] && ok "#2 staged credential is BLOCKED (rc=$rc)" || bad "#2 staged credential was NOT blocked"

# 3 — the same hit, allowlisted, passes and REPORTS the suppression
r="$(newrepo allowed)"; install_into "$r"
printf 'token = "%s"\n' "$NEEDLE" > "$r/seed.ts"; git -C "$r" add seed.ts
printf 'allowed/seed.ts   # drill fixture, synthesized needle, not a credential\n' > "$SCRATCH/allow"
GE_ALLOW="$SCRATCH/allow" git -C "$r" commit -q -m allowed >"$SCRATCH/o3" 2>&1; rc=$?
chk 0 "$rc" "#3 allowlisted hit passes"
grep -q "suppressed by" "$SCRATCH/o3" && ok "#3b suppression is reported, never silent" \
                                      || bad "#3b suppression was SILENT"

# 4 — an UNSTAGED credential does not block (index-scan, not working-tree)
r="$(newrepo unstaged)"; install_into "$r"
echo "clean" > "$r/a.txt"; git -C "$r" add a.txt
printf 'token = "%s"\n' "$NEEDLE" > "$r/dirty.ts"      # present on disk, never staged
chk 0 "$(commit_rc "$r" unstaged)" "#4 unstaged credential does not block (scans the INDEX)"

# 5 — a pre-existing .git/hooks/pre-commit still runs after install (THE chain risk)
r="$(newrepo chain)"
printf '#!/bin/bash\ntouch "%s/chain-ran"\nexit 0\n' "$SCRATCH" > "$r/.git/hooks/pre-commit"
chmod +x "$r/.git/hooks/pre-commit"; install_into "$r"
echo hi > "$r/a.txt"; git -C "$r" add a.txt; commit_rc "$r" chain >/dev/null
[ -f "$SCRATCH/chain-ran" ] && ok "#5 pre-existing .git/hooks/pre-commit STILL RUNS" \
                            || bad "#5 pre-existing repo hook was silently DISABLED"

# 6 — a pre-existing core.hooksPath (the ~/Desktop/downloads shape) still runs
r="$(newrepo prevpath)"; mkdir -p "$r/.githooks"
printf '#!/bin/bash\ntouch "%s/prevpath-ran"\nexit 0\n' "$SCRATCH" > "$r/.githooks/pre-commit"
chmod +x "$r/.githooks/pre-commit"; git -C "$r" config core.hooksPath .githooks
install_into "$r"
echo hi > "$r/a.txt"; git -C "$r" add a.txt; commit_rc "$r" prevpath >/dev/null
[ -f "$SCRATCH/prevpath-ran" ] && ok "#6 pre-existing core.hooksPath STILL RUNS (relative, resolved from toplevel)" \
                               || bad "#6 pre-existing core.hooksPath was silently DISABLED"
chk ".githooks" "$(git -C "$r" config --get estatehooks.prev)" "#6b prior hooksPath recorded"

# 7 — re-running the installer does NOT overwrite estatehooks.prev (self-chain loop)
install_into "$r"; install_into "$r"
chk ".githooks" "$(git -C "$r" config --get estatehooks.prev)" "#7 re-install does not clobber prev (no self-chain)"

# 8 — --uninstall restores the prior state exactly
bash "$HOOKS_DIR/install-estate-hooks.sh" --repo "$r" --uninstall --quiet >/dev/null 2>&1
chk ".githooks" "$(git -C "$r" config --get core.hooksPath)" "#8 uninstall restores prior core.hooksPath"
git -C "$r" config --get estatehooks.prev >/dev/null 2>&1 \
  && bad "#8b uninstall left estatehooks.prev behind" || ok "#8b uninstall clears its own bookkeeping"
r2="$(newrepo nopath)"; install_into "$r2"
bash "$HOOKS_DIR/install-estate-hooks.sh" --repo "$r2" --uninstall --quiet >/dev/null 2>&1
git -C "$r2" config --get core.hooksPath >/dev/null 2>&1 \
  && bad "#8c uninstall left core.hooksPath on a repo that had none" \
  || ok "#8c uninstall unsets core.hooksPath where there was none"

# 9 — a missing SSOT lib fails CLOSED
r="$(newrepo failclosed)"; install_into "$r"
printf 'x\n' > "$r/a.txt"; git -C "$r" add a.txt
ESTATE_SECRET_LIB="$SCRATCH/does-not-exist.sh" git -C "$r" commit -q -m fc >"$SCRATCH/o9" 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "#9 missing secret-re.sh fails CLOSED (rc=$rc)" || bad "#9 missing SSOT lib PASSED — fails open"

# 10 — deleting a file that contained a credential does not block the deletion
r="$(newrepo deletion)"; printf 'token = "%s"\n' "$NEEDLE" > "$r/old.ts"
git -C "$r" add old.ts; git -C "$r" commit -q --no-verify -m seed >/dev/null 2>&1
install_into "$r"; git -C "$r" rm -q old.ts
chk 0 "$(commit_rc "$r" delete)" "#10 removing a credential-bearing file is not blocked"

# 11 — an ALIASED hooks dir (case-variant / symlink) counts as already wired, not as drift.
# Without an inode compare, running the installer via ~/Code vs ~/code re-records prev on
# every repo and makes G-AF report the whole estate as unprotected.
r="$(newrepo alias)"; install_into "$r"
ln -s "$HOOKS_DIR" "$SCRATCH/hooks-alias"
out="$(bash "$SCRATCH/hooks-alias/install-estate-hooks.sh" --repo "$r" 2>&1 | tail -1)"
case "$out" in *"already-ok=1"*) ok "#11 aliased hooks dir counts as already wired (inode compare)" ;;
                *) bad "#11 aliased hooks dir re-wired: $out" ;; esac

# 12 — ESTATE_HOOK_DRYRUN reports the chain target instead of running it
r="$(newrepo dryrun)"
printf '#!/bin/bash\ntouch "%s/should-not-run"\nexit 0\n' "$SCRATCH" > "$r/.git/hooks/pre-commit"
chmod +x "$r/.git/hooks/pre-commit"; install_into "$r"
out="$(cd "$r" && ESTATE_HOOK_DRYRUN=1 ESTATE_HOOK_NAME=pre-commit bash "$HOOKS_DIR/_chain.sh")"
case "$out" in *"/.git/hooks/pre-commit"*) ok "#12 dry-run reports the chain target" ;;
                *) bad "#12 dry-run output wrong: $out" ;; esac
[ -f "$SCRATCH/should-not-run" ] && bad "#12b dry-run EXECUTED the chained hook" \
                                 || ok "#12b dry-run does not execute the chained hook"

# -----------------------------------------------------------------------------
# #13-#18 — THE GLOBAL DEFAULT (S46). This is the layer that makes a FRESH CLONE
# protected, so it is the layer that has to be drilled hardest: S45's protection
# lived entirely in .git/config, which is untracked and never cloned.
# -----------------------------------------------------------------------------
git config --global core.hooksPath "$HOOKS_DIR"

# 13 — a repo with NO local config at all is protected by the global default.
# This is literally the fresh-clone case: nobody ran anything in this repo.
r="$(newrepo globalonly)"
printf 'token = "%s"\n' "$NEEDLE" > "$r/seed.ts"; git -C "$r" add seed.ts
rc="$(commit_rc "$r" globalsecret)"
[ "$rc" -ne 0 ] && ok "#13 global default protects a repo with ZERO local config (fresh-clone case)" \
                || bad "#13 global default did NOT protect an unwired repo"
[ -z "$(git -C "$r" config --local --get core.hooksPath)" ] \
  && ok "#13b ...and it did so with no per-repo state written" \
  || bad "#13b unexpected local core.hooksPath appeared"

# 14 — under the global default, a repo's OWN .git/hooks/pre-commit still runs.
# estatehooks.prev is unset here, so this exercises _chain.sh's fallback branch —
# the one that stops the global setting from silently disarming every repo hook
# on the machine, including ones outside the gate roots entirely.
r="$(newrepo globalchain)"
printf '#!/bin/bash\ntouch "%s/gchain-ran"\nexit 0\n' "$SCRATCH" > "$r/.git/hooks/pre-commit"
chmod +x "$r/.git/hooks/pre-commit"
echo hi > "$r/a.txt"; git -C "$r" add a.txt; commit_rc "$r" gchain >/dev/null
[ -f "$SCRATCH/gchain-ran" ] && ok "#14 own .git/hooks/pre-commit still runs under the GLOBAL default" \
                             || bad "#14 global default silently disabled the repo's own hook"

# 15 — a repo with its OWN local core.hooksPath IGNORES the global default.
# Not a bug: git config is most-specific-wins. It is the whole reason the per-repo
# installer still exists, and the reason G-AF still has to walk every repo.
r="$(newrepo localwins)"; mkdir -p "$r/.githooks"
printf '#!/bin/bash\nexit 0\n' > "$r/.githooks/pre-commit"; chmod +x "$r/.githooks/pre-commit"
git -C "$r" config core.hooksPath .githooks
printf 'token = "%s"\n' "$NEEDLE" > "$r/seed.ts"; git -C "$r" add seed.ts
chk 0 "$(commit_rc "$r" localwins)" "#15 a local core.hooksPath OVERRIDES the global default (documents the residual gap)"

git config --global --unset core.hooksPath 2>/dev/null || true

# 16 — a full-estate run SETS the global key, and --uninstall REMOVES it.
# ESTATE_HOOK_ROOTS keeps this hermetic: a real full-estate run would walk ~/repos.
mkdir -p "$SCRATCH/fakeroot"; r16="$(newrepo ../fakeroot/r16)"
ESTATE_HOOK_ROOTS="$SCRATCH/fakeroot" bash "$HOOKS_DIR/install-estate-hooks.sh" --quiet >/dev/null 2>&1
g="$(git config --global --get core.hooksPath 2>/dev/null)"
[ -n "$g" ] && [ "$g" -ef "$HOOKS_DIR" ] && ok "#16 full-estate install sets the global default" \
                                         || bad "#16 full-estate install did NOT set the global default (got: ${g:-empty})"
ESTATE_HOOK_ROOTS="$SCRATCH/fakeroot" bash "$HOOKS_DIR/install-estate-hooks.sh" --uninstall --quiet >/dev/null 2>&1
git config --global --get core.hooksPath >/dev/null 2>&1 \
  && bad "#16b --uninstall left the global default behind (the documented one-command undo would be a lie)" \
  || ok "#16b --uninstall removes the global default too"

# 17 — --repo is SURGICAL and must never reach into ~/.gitconfig. hooks-drill.sh
# itself depends on this: install_into() runs on every scratch repo above.
r="$(newrepo surgical)"; install_into "$r"
git config --global --get core.hooksPath >/dev/null 2>&1 \
  && bad "#17 --repo wrote a GLOBAL key" || ok "#17 --repo never touches the global config"

# 18 — a global core.hooksPath owned by SOMEONE ELSE is not clobbered, and not
# silently removed by --uninstall either. Destroying a setting we did not create
# is the fastest way to make a security control something people rip out.
mkdir -p "$SCRATCH/foreign-hooks"
git config --global core.hooksPath "$SCRATCH/foreign-hooks"
ESTATE_HOOK_ROOTS="$SCRATCH/fakeroot" bash "$HOOKS_DIR/install-estate-hooks.sh" --quiet >/dev/null 2>&1
chk "$SCRATCH/foreign-hooks" "$(git config --global --get core.hooksPath)" "#18 a foreign global core.hooksPath is not overwritten"
ESTATE_HOOK_ROOTS="$SCRATCH/fakeroot" bash "$HOOKS_DIR/install-estate-hooks.sh" --uninstall --quiet >/dev/null 2>&1
chk "$SCRATCH/foreign-hooks" "$(git config --global --get core.hooksPath)" "#18b ...and --uninstall leaves it alone"
git config --global --unset core.hooksPath 2>/dev/null || true

# -----------------------------------------------------------------------------
# #19-#26 — THE PAN LAYER (S15 2026-09-04, SM 1217561601836055). G-AF was green at
# 114 of 114 repos while every one of them accepted a card number, because coverage
# and capability read identically when green and only coverage was ever measured.
# These are the capability assertions: they ask whether the scanner can SEE a PAN,
# which is a different question from whether the scanner is installed.
#
# ⚠ SAME SYNTHESIS RULE AS $NEEDLE, and it bites harder here: a card-shaped literal
# in this file makes the estate's own secret sweep bite the test that proves it
# works, and the "fix" is to blind the scanner to it. Every PAN below is assembled
# at runtime from fragments that are individually not card-shaped.
# -----------------------------------------------------------------------------
V16="411111111111""1111"      # Visa test PAN, Luhn-valid, split literal
AX15="37828224631""0005"      # Amex test PAN
MC16="555555555555""4444"     # Mastercard test PAN

# 19 — a staged PAN is BLOCKED. This is THE assertion the card was filed for; it
# fails on every build of this hook before S15.
r="$(newrepo pan)"; install_into "$r"
printf 'customer card %s\n' "$V16" > "$r/order.txt"; git -C "$r" add order.txt
rc="$(commit_rc "$r" pan)"
[ "$rc" -ne 0 ] && ok "#19 staged card number is BLOCKED (rc=$rc)" \
                || bad "#19 staged card number was NOT blocked — the hook is blind to PANs"

# 19b — the block NAMES it as a PAN and MASKS it. A scanner that prints the card it
# just refused has written the card into a terminal, a log and a CI transcript.
grep -q "PAN:" "$SCRATCH/out.$$" && ok "#19b the block reports it as a PAN" \
                                || bad "#19b the block does not say the hit is a card number"
grep -q "$V16" "$SCRATCH/out.$$" \
  && bad "#19c the hook PRINTED THE FULL CARD NUMBER — the control leaked what it refused" \
  || ok "#19c the card number is masked in the block output (first-6/last-4 only)"

# 20 — a PAN at END OF LINE is caught. Its own control because it is exactly the bug
# the first build of ge_pan_token had: `read` drops a final chunk with no trailing
# newline, so a card ending a line was silently invisible while the same card
# mid-line was caught. A detector with a blind spot shaped like "last thing on the
# line" is worse than none, because card numbers are usually the last thing on the line.
r="$(newrepo paneol)"; install_into "$r"
printf 'card=%s' "$V16" > "$r/eol.txt"; git -C "$r" add eol.txt
[ "$(commit_rc "$r" paneol)" -ne 0 ] && ok "#20 a PAN at end-of-line (no trailing newline) is BLOCKED" \
                                     || bad "#20 a PAN at END OF LINE slipped through"

# 21 — SEPARATED forms are caught. Humans write cards with spaces and dashes; a
# detector that only sees the unbroken form misses the way the number is actually typed.
r="$(newrepo pansep)"; install_into "$r"
printf 'on file: 4242 4242 4242 4242 (exp 12/28)\n' > "$r/notes.md"; git -C "$r" add notes.md
[ "$(commit_rc "$r" pansep)" -ne 0 ] && ok "#21 a space-separated PAN is BLOCKED" \
                                     || bad "#21 a space-separated PAN slipped through"
r="$(newrepo pandash)"; install_into "$r"
printf 'card 4242-4242-4242-4242\n' > "$r/notes.md"; git -C "$r" add notes.md
[ "$(commit_rc "$r" pandash)" -ne 0 ] && ok "#21b a dash-separated PAN is BLOCKED" \
                                      || bad "#21b a dash-separated PAN slipped through"

# 22 — a 15-digit Amex is caught. Length-agnostic-within-the-brand-set, not "16 digits".
r="$(newrepo panamex)"; install_into "$r"
printf 'amex %s\n' "$AX15" > "$r/a.txt"; git -C "$r" add a.txt
[ "$(commit_rc "$r" panamex)" -ne 0 ] && ok "#22 a 15-digit Amex PAN is BLOCKED" \
                                      || bad "#22 a 15-digit Amex PAN slipped through"

# -----------------------------------------------------------------------------
# #23-#25 — NEGATIVE CONTROLS. These are the reason the detector is Luhn + IIN +
# length and not "a run of >=12 digits" (global lesson 2026-08-07). A secret gate
# that fails closed on order ids and timestamps does not get tightened; it gets
# UNINSTALLED, and then the estate has no gate at all. Each of these MUST pass.
# -----------------------------------------------------------------------------
# 23 — a 16-digit run that fails Luhn is NOT a card. One digit off $V16.
r="$(newrepo panluhn)"; install_into "$r"
printf 'order_id = 411111111111111''2\n' > "$r/o.txt"; git -C "$r" add o.txt
chk 0 "$(commit_rc "$r" panluhn)" "#23 a Luhn-INVALID 16-digit run commits freely (not a card)"

# 24 — a long digit blob is NOT a card, even though it contains Luhn-valid substrings.
# The over-19-digit rule is the single largest false-positive reduction available.
r="$(newrepo panblob)"; install_into "$r"
printf 'nonce 9814072356124093871665204391\ntimestamp 20260904215600123456\n' > "$r/b.txt"
git -C "$r" add b.txt
chk 0 "$(commit_rc "$r" panblob)" "#24 a >19-digit blob commits freely (nonce/timestamp, not a card)"

# 25 — a sha, a uuid and a phone number commit freely. The everyday shapes.
r="$(newrepo panshapes)"; install_into "$r"
printf 'sha a1b2c3d4e5f60718293a4b5c6d7e8f9012345678\nuuid 550e8400-e29b-41d4-a716-446655440000\nphone +1 512 555 0134\nepoch 1788482629\n' > "$r/s.txt"
git -C "$r" add s.txt
chk 0 "$(commit_rc "$r" panshapes)" "#25 sha / uuid / phone / epoch commit freely"

# 26 — a PAN is allowlistable by PATH through the SAME allowlist as every other hit,
# and the suppression is reported. A fixture repo that legitimately holds a published
# test card needs an exit that is not "widen the needle".
r="$(newrepo panallow)"; install_into "$r"
printf 'fixture %s\n' "$MC16" > "$r/fixtures.json"; git -C "$r" add fixtures.json
printf 'panallow/fixtures.json   # drill fixture, published test card, no cardholder exists\n' > "$SCRATCH/panallow.allow"
GE_ALLOW="$SCRATCH/panallow.allow" git -C "$r" commit -q -m panallow >"$SCRATCH/o26" 2>&1; rc=$?
chk 0 "$rc" "#26 an allowlisted PAN path commits"
grep -q "suppressed by" "$SCRATCH/o26" && ok "#26b the PAN suppression is reported, never silent" \
                                       || bad "#26b the PAN suppression was SILENT"

echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
