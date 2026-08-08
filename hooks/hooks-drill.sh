#!/bin/bash
# =============================================================================
# hooks-drill.sh — prove the estate pre-commit hook OFFLINE, on scratch repos.
#
# A control you can only test in production is a control nobody tests (S44,
# roster-drill.sh). This one is louder than most, because installing
# core.hooksPath can SILENTLY disable a repo's existing hooks -- so #5, #6 and #7
# are not nice-to-haves, they are the reason this file exists.
#
#   bash hooks-drill.sh          # 10 assertions, scratch dirs, zero live repos touched
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

echo "=== drill: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
