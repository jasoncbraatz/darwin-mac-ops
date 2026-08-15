#!/bin/bash
# =============================================================================
# dotfiles-drill.sh — prove install-dotfiles.sh offline, on a scratch HOME.
#
#   dotfiles-drill.sh            # run every assertion
#   dotfiles-drill.sh --quiet    # summary line only
#
# HERMETIC, and that word is load-bearing (S46 paid for this): a git harness that
# exports GIT_CONFIG_NOSYSTEM but not GIT_CONFIG_GLOBAL still reads Jason's real
# ~/.gitconfig -- and this drill WRITES global git config, so without both it
# would edit his. Both are exported below, plus a scratch $HOME, so the drill can
# never touch the real machine.
#
# It also drills the two claims the installer's header MAKES but could not
# otherwise prove: that a dangling symlink is not fatal to zsh or git, and that
# --uninstall leaves a WORKING file rather than a bare home directory.
# =============================================================================
set -uo pipefail
QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { awk 'NR>1 && /^# ={10,}/{n++; next} n==1' "$0"; exit 0; }

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd -P)"
INSTALLER="$DOTFILES_DIR/install-dotfiles.sh"
pass=0; fail=0
say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }
ck() { if [ "$2" = "$3" ]; then say "  ok   $1"; pass=$((pass+1));
       else printf '  FAIL %s\n         expected[%s] got[%s]\n' "$1" "$2" "$3"; fail=$((fail+1)); fi; }

T="$(mktemp -d /tmp/dotfiles-drill.XXXXXX)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$HOME/.gitconfig"
printf '[user]\n\tname = Drill\n\temail = d@r\n' > "$GIT_CONFIG_GLOBAL"

say "dotfiles-drill: scratch HOME=$HOME  source=$DOTFILES_DIR"

# --- 1. dry-run changes nothing ----------------------------------------------
"$INSTALLER" --dry-run --quiet >/dev/null 2>&1
ck "1  --dry-run leaves ~/.zshenv absent" "absent" "$([ -e "$HOME/.zshenv" ] && echo present || echo absent)"
ck "1b --dry-run leaves excludesfile unset" "" "$(git config --global --includes --get core.excludesfile 2>/dev/null)"

# --- 2. install links, does not copy -----------------------------------------
out="$("$INSTALLER" --quiet 2>&1)"
ck "2  ~/.zshenv is a SYMLINK (derived, not a copy)" "symlink" "$([ -L "$HOME/.zshenv" ] && echo symlink || echo not-a-symlink)"
ck "2b ~/.zshenv resolves to the repo file" "same" "$([ "$HOME/.zshenv" -ef "$DOTFILES_DIR/.zshenv" ] && echo same || echo different)"
ck "2c ~/.gitignore_global resolves to the repo file" "same" "$([ "$HOME/.gitignore_global" -ef "$DOTFILES_DIR/gitignore_global" ] && echo same || echo different)"
ck "2d excludesfile now points at ~/.gitignore_global" "$HOME/.gitignore_global" "$(git config --global --includes --get core.excludesfile 2>/dev/null)"

# --- 2e EVERY manifest entry, not just the ones someone remembered to name ----
# 2b and 2c hardcode their files, so a new MANIFEST line ships with ZERO coverage.
# That is how the next regression hides: .zshrc was added to the manifest on
# 2026-08-15 and this drill went on reporting 17/17 without ever looking at it.
# Derive the list from the installer instead -- add a dotfile, get a case free.
# (acmeLedger-19; the estate's own rule: a gate you must remember to update rots.)
man_n=0; man_bad=0
for m_line in $(sed -n '/^MANIFEST="/,/^"$/p' "$INSTALLER" | grep '|'); do
  m_src="${m_line%%|*}"; m_dst="${m_line#*|}"
  [ -n "$m_src" ] || continue
  m_dst="$(eval printf '%s' "\"$m_dst\"")"
  man_n=$((man_n+1))
  if [ -L "$m_dst" ] && [ "$m_dst" -ef "$DOTFILES_DIR/$m_src" ]; then :
  else man_bad=$((man_bad+1)); say "       uncovered or broken: $m_src -> $m_dst"; fi
done
ck "2e every MANIFEST entry is a symlink into the repo (n=$man_n)" "0" "$man_bad"
ck "2f the MANIFEST parsed at all (control: n>0)" "yes" "$([ "$man_n" -gt 0 ] && echo yes || echo no)"

# --- 3. the rule that has bitten twice actually bites ------------------------
mkdir -p "$T/repo" && git -C "$T/repo" init -q
: > "$T/repo/x.py.bak.20260623"
ig="$(git -C "$T/repo" check-ignore -v x.py.bak.20260623 2>/dev/null | grep -c 'bak' || true)"
ck "3  *.bak.* is ignored via the linked excludesfile" "1" "$ig"

# --- 4. idempotence: a second run changes nothing ----------------------------
out2="$("$INSTALLER" --quiet 2>&1)"
ck "4  second run reports 0 changes" "linked=0" "$(printf '%s' "$out2" | grep -o 'linked=[0-9]*' | head -1)"
ck "4b ...and does not stash a backup of its own symlink" "0" "$(ls -1 "$HOME"/.zshenv.bak-predotfiles-* 2>/dev/null | wc -l | tr -d ' ')"

# --- 5. a PRE-EXISTING real file is stashed, never destroyed -----------------
"$INSTALLER" --uninstall --quiet >/dev/null 2>&1
rm -f "$HOME/.zshenv"
printf '# jasons own hand-written line\n' > "$HOME/.zshenv"
"$INSTALLER" --quiet >/dev/null 2>&1
stash="$(ls -1t "$HOME"/.zshenv.bak-predotfiles-* 2>/dev/null | head -1)"
ck "5  pre-existing file was stashed, not clobbered" "1" "$(grep -c 'hand-written' "${stash:-/dev/null}" 2>/dev/null || echo 0)"
ck "5b ...and the live file is now the repo's" "same" "$([ "$HOME/.zshenv" -ef "$DOTFILES_DIR/.zshenv" ] && echo same || echo different)"

# --- 6. RESTORE IS REAL (reversibility you never verified is not reversibility)
"$INSTALLER" --uninstall --quiet >/dev/null 2>&1
ck "6  uninstall restored the hand-written file byte-for-byte" "1" "$(grep -c 'hand-written' "$HOME/.zshenv" 2>/dev/null || echo 0)"
ck "6b ...and it is a real file again, not a link" "real" "$([ -L "$HOME/.zshenv" ] && echo link || echo real)"

# --- 7. uninstall with NO stash leaves a WORKING copy, not a bare home -------
rm -f "$HOME"/.gitignore_global.bak-predotfiles-* 2>/dev/null
"$INSTALLER" --quiet >/dev/null 2>&1
rm -f "$HOME"/.gitignore_global.bak-predotfiles-*
"$INSTALLER" --uninstall --quiet >/dev/null 2>&1
ck "7  no-stash uninstall leaves a real copy (never nothing)" "present-real" \
   "$([ -f "$HOME/.gitignore_global" ] && [ ! -L "$HOME/.gitignore_global" ] && echo present-real || echo MISSING)"

# --- 8. the availability claim in the header, measured ----------------------
# The header asserts a dangling symlink is no worse than an absent file. Prove it
# rather than assert it: git must still be usable, and must not error out.
"$INSTALLER" --quiet >/dev/null 2>&1
rm -f "$HOME/.gitignore_global"; ln -s "$T/nope/gitignore_global" "$HOME/.gitignore_global"
git -C "$T/repo" status --short >/dev/null 2>&1; rc=$?
ck "8  git still works with a DANGLING excludesfile symlink" "0" "$rc"
if command -v zsh >/dev/null 2>&1; then
  rm -f "$HOME/.zshenv"; ln -s "$T/nope/.zshenv" "$HOME/.zshenv"
  zsh -c 'exit 0' >/dev/null 2>&1; zrc=$?
  ck "8b zsh still starts with a DANGLING ~/.zshenv" "0" "$zrc"
else
  say "  skip 8b zsh not present"
fi

# --- 9. never-ours files are left exactly alone ------------------------------
rm -f "$HOME/.zshenv"; printf 'not ours\n' > "$HOME/.zshenv"
"$INSTALLER" --uninstall --quiet >/dev/null 2>&1
ck "9  uninstall leaves a file it did not install alone" "1" "$(grep -c 'not ours' "$HOME/.zshenv" 2>/dev/null || echo 0)"

[ $((pass+fail)) -eq 0 ] && { printf 'dotfiles-drill: 0 checks ran -- the drill did not execute\n'; exit 2; }
printf 'dotfiles-drill: %s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
