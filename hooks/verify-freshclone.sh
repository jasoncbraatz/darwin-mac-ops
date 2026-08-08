#!/bin/bash
# verify-freshclone.sh — S46 real-world proof of the layer hooks-drill.sh cannot reach.
#
# The drill runs on scratch repos with a scratch ~/.gitconfig, which is exactly right
# for testing the mechanism and exactly wrong for answering "is THIS Mac protected?".
# This script uses the real machine, the real ~/.gitconfig, and a real clone: a fresh
# clone with ZERO per-repo state must pass a clean commit and REFUSE a credential.
#
# Safe to run any time. Everything happens in a mktemp dir that is removed at the end;
# no live repo is touched and no config is written.
# Needle synthesized at runtime -- a test that spells its own needle becomes a
# permanent allowlist entry (S44/S45).
set -uo pipefail
S="$(mktemp -d /tmp/s46-verify.XXXXXX)"
HEX32="0123456789abcdef0123456789abcdef"
NEEDLE="shp""at_$HEX32"
echo "scratch: $S"
echo "global core.hooksPath: [$(git config --global --get core.hooksPath)]"
echo ""

echo "### 1. fresh clone, local origin (nobody ran anything in it)"
# Cloned from the local working copy, not GitHub: dx's non-interactive shell has no
# SSH agent, and the point under test is git's CLONE-TIME config inheritance, which is
# identical either way. (A GitHub clone was tried first and failed on auth, not on hooks.)
ORIGIN="${S46_ORIGIN:-$HOME/repos/saturday-sanity-check}"
if [ ! -d "$ORIGIN/.git" ]; then echo "   SKIP: no origin repo at $ORIGIN (set S46_ORIGIN=)"; rm -rf "$S"; exit 2; fi
git clone -q "$ORIGIN" "$S/fresh" 2>&1 | tail -2
echo "   local core.hooksPath: [$(git -C "$S/fresh" config --local --get core.hooksPath)]  (expect EMPTY)"
echo "   estatehooks.prev:     [$(git -C "$S/fresh" config --local --get estatehooks.prev)]  (expect EMPTY)"

echo ""
echo "### 2. clean commit in the fresh clone -> must PASS"
echo "hello" > "$S/fresh/s46-probe.txt"
git -C "$S/fresh" add s46-probe.txt
git -C "$S/fresh" -c user.email=v@local -c user.name=v -c commit.gpgsign=false commit -q -m "s46 probe clean" >"$S/o2" 2>&1
echo "   rc=$?  (expect 0)"; head -3 "$S/o2" | sed 's/^/     /'

echo ""
echo "### 3. staged credential in the fresh clone -> must BLOCK"
printf 'token = "%s"\n' "$NEEDLE" > "$S/fresh/s46-leak.ts"
git -C "$S/fresh" add s46-leak.ts
git -C "$S/fresh" -c user.email=v@local -c user.name=v -c commit.gpgsign=false commit -m "s46 probe leak" >"$S/o3" 2>&1
rc=$?
echo "   rc=$rc  (expect NON-ZERO)"
grep -E 'BLOCKED|match:' "$S/o3" | sed 's/^/     /'

echo ""
echo "### 4. a bare 'git init' scratch repo is covered too (not just clones)"
mkdir -p "$S/initrepo"; git init -q "$S/initrepo"
printf 'k="%s"\n' "$NEEDLE" > "$S/initrepo/x.ts"; git -C "$S/initrepo" add x.ts
git -C "$S/initrepo" -c user.email=v@local -c user.name=v -c commit.gpgsign=false commit -m x >"$S/o4" 2>&1
echo "   rc=$?  (expect NON-ZERO)"

echo ""
echo "### 5. cost on the fattest fork (staged-paths-only scan)"
if [ -d "$HOME/repos/librechat" ]; then T0=$(date +%s%N)
  ( cd "$HOME/repos/librechat" && ESTATE_HOOK_DRYRUN= bash "$HOME/code/darwin-mac-ops/hooks/pre-commit" >/dev/null 2>&1 )
  T1=$(date +%s%N); echo "   librechat pre-commit: $(( (T1-T0)/1000000 ))ms"
else echo "   (librechat not present)"; fi

echo ""
echo "### cleanup"; rm -rf "$S"; echo "   removed $S"
