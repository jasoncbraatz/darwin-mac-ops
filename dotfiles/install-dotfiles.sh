#!/bin/bash
# =============================================================================
# install-dotfiles.sh — put this Mac's global shell/git config in place, DERIVED
# from the repo instead of copied out of it.
#
#   install-dotfiles.sh              # install (idempotent)
#   install-dotfiles.sh --dry-run    # say what it WOULD do, change nothing
#   install-dotfiles.sh --uninstall  # restore prior state (see "Undo" below)
#   install-dotfiles.sh --quiet      # only the summary line
#
# WHY THIS SCRIPT EXISTS (S47):
#
# BOOTSTRAP.md walks a fresh Mac from bare metal to both pipelines running, and
# it never mentioned dotfiles. No script installed them either, and no gate check
# looked. So a rebuild that followed the runbook perfectly, end to end, came up
# WITHOUT:
#
#   • .zshenv        — which is load-bearing, not cosmetic. It puts
#                      /opt/homebrew/bin on PATH for NON-INTERACTIVE zsh (ssh,
#                      MCP, launchd), which is the only reason `gh` resolves in
#                      automation; and it sets `no_nomatch` for those shells, so
#                      an unmatched glob passes through like bash instead of
#                      ABORTING THE LINE (that one distilled four blackbook
#                      leaves). Missing it does not announce itself — scripts
#                      just start failing in ways that look like other bugs.
#   • .gitignore_global — the `*.bak` AND `*.bak.*` rules, whose absence has
#                      bitten twice: a dirty repo tripping the HANDOFF-GATE, and
#                      junk rsync'd to the runtime box.
#
# SYMLINKS, NOT COPIES — on purpose. dotfiles/README.md used to say `cp`, which
# makes ~/.gitignore_global an install-day SNAPSHOT: edit the repo copy and the
# machine keeps using the frozen one, silently, forever. That is the
# COPIED-not-DERIVED family (tenth instance in this estate; init.templateDir was
# the ninth). A symlink is the derived form: `git pull` is the deploy.
#
# The obvious objection is availability — a dangling symlink if the repo moves.
# Measured, not assumed: zsh treats an unreadable ~/.zshenv exactly like an
# absent one (no error, no abort), and git treats a missing excludesfile the same
# way. And the estate ALREADY hard-depends on this path existing, because
# core.hooksPath points into it — so the symlink adds no new failure domain.
#
# Undo — one command, and it leaves the machine WORKING, not bare:
#   install-dotfiles.sh --uninstall
# replaces each symlink with the file that was there before (the .bak-predotfiles
# stash), or, if there wasn't one, a plain copy of the repo's version — i.e. the
# pre-S47 `cp` shape. It never leaves you with no .zshenv, because a Mac with no
# .zshenv is a Mac where automation can't find gh.
# =============================================================================
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd -P)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DRY=0; UNINSTALL=0; QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --quiet)     QUIET=1; shift ;;
    # DERIVED, not a copied line range: a hardcoded "2,40p" silently truncates
    # the help the moment the header grows (COPIED-not-DERIVED, again).
    -h|--help) awk 'NR>1 && /^# ={10,}/{n++; next} n==1' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# MANIFEST — "<repo-relative source>|<absolute target>". bash 3.2 (darwin ships
# 2007's) has no associative arrays, so this is a plain list.
MANIFEST="
.zshenv|$HOME/.zshenv
.zshrc|$HOME/.zshrc
gitignore_global|$HOME/.gitignore_global
"

n_ok=0; n_changed=0; n_warn=0

# NOT `printf ... | while`: a pipe puts the loop in a SUBSHELL and every counter
# increment below evaporates, so the summary line would report 0 changes on a run
# that changed everything. Here-string keeps it in this shell (bash 3.2 has <<<).
while IFS= read -r row; do
  [ -n "$row" ] || continue
  src_rel="${row%%|*}"; dst="${row##*|}"
  src="$DOTFILES_DIR/$src_rel"
  name="${dst/#$HOME/~}"

  if [ ! -r "$src" ]; then
    say "  WARN  $name -- source missing in repo ($src_rel)"; n_warn=$((n_warn+1)); continue
  fi

  # -ef (inode), never = (string): $HOME/code and $HOME/Code are the same
  # directory on case-insensitive APFS, so a string compare would "fix" an
  # already-correct link on every run from the other spelling.
  linked=0
  [ -e "$dst" ] && [ "$dst" -ef "$src" ] && linked=1

  if [ "$UNINSTALL" -eq 1 ]; then
    if [ "$linked" -eq 0 ]; then
      say "  skip  $name -- not ours (left exactly as found)"; n_ok=$((n_ok+1)); continue
    fi
    # newest stash for this target, if any
    stash="$(ls -1t "$dst".bak-predotfiles-* 2>/dev/null | head -1)"
    if [ "$DRY" -eq 1 ]; then
      say "  would RESTORE $name <- ${stash:-copy of repo version}"; n_changed=$((n_changed+1)); continue
    fi
    rm -f "$dst"
    if [ -n "$stash" ] && [ -r "$stash" ]; then
      mv "$stash" "$dst"; say "  restored $name <- ${stash##*/}"
    else
      cp "$src" "$dst"; say "  restored $name <- copy of repo version (pre-S47 shape)"
    fi
    n_changed=$((n_changed+1)); continue
  fi

  if [ "$linked" -eq 1 ]; then
    say "  ok    $name -> ${src/#$HOME/~}"; n_ok=$((n_ok+1)); continue
  fi

  if [ "$DRY" -eq 1 ]; then
    if [ -e "$dst" ] || [ -L "$dst" ]; then say "  would LINK  $name (stashing the current file first)"
    else say "  would LINK  $name"; fi
    n_changed=$((n_changed+1)); continue
  fi

  # Reversibility BEFORE the change: stash whatever is there, even if it looks
  # identical to the repo copy. "It was the same anyway" is a claim about a file
  # nobody is going to be able to check after it is gone.
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-predotfiles-$TS" || { say "  WARN  $name -- could not stash, left alone"; n_warn=$((n_warn+1)); continue; }
    say "  stashed $name -> ${dst##*/}.bak-predotfiles-$TS"
  fi
  ln -s "$src" "$dst" || { say "  WARN  $name -- symlink failed"; n_warn=$((n_warn+1)); continue; }
  say "  linked  $name -> ${src/#$HOME/~}"
  n_changed=$((n_changed+1))
done <<< "$MANIFEST"

# --- git's global excludesfile -----------------------------------------------
# --includes matters: a plain `--global --get` does NOT follow include.path
# directives (git defaults --includes OFF when a specific file is named), so if
# this key ever moves into an included fragment, the naive read returns empty and
# this script would happily re-set a key that is already live. Measured S47.
gex_state="untouched"
if [ "$UNINSTALL" -eq 1 ]; then
  if [ -e "$HOME/.gitignore_global" ]; then
    gex_state="left-set (file still present)"
  else
    if [ "$DRY" -eq 1 ]; then gex_state="would-unset"
    else git config --global --unset core.excludesfile 2>/dev/null && gex_state="unset" || gex_state="already-absent"; fi
  fi
else
  cur="$(git config --global --includes --get core.excludesfile 2>/dev/null)" || cur=""
  if [ -n "$cur" ] && [ -e "$cur" ] && [ "$cur" -ef "$HOME/.gitignore_global" ]; then
    gex_state="already-set"
  elif [ "$DRY" -eq 1 ]; then
    gex_state="would-set"
  else
    git config --global core.excludesfile "$HOME/.gitignore_global" && gex_state="set" || gex_state="set-FAILED"
  fi
fi

verb="linked"; [ "$UNINSTALL" -eq 1 ] && verb="restored"
[ "$DRY" -eq 1 ] && verb="would-$verb"
printf 'dotfiles: %s=%s already-ok=%s warn=%s  excludesfile=%s  (source %s)\n' \
  "$verb" "$n_changed" "$n_ok" "$n_warn" "$gex_state" "${DOTFILES_DIR/#$HOME/~}"
[ "$n_warn" -eq 0 ]
