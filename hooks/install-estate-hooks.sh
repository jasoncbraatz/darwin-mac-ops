#!/bin/bash
# =============================================================================
# install-estate-hooks.sh — point every repo under the gate ROOTS at the estate
# hooks dir, without killing any hook the repo already had.
#
#   install-estate-hooks.sh                # install (idempotent)
#   install-estate-hooks.sh --dry-run      # say what it WOULD do, change nothing
#   install-estate-hooks.sh --uninstall    # restore each repo's prior state exactly
#   install-estate-hooks.sh --root ~/foo   # extra root (repeatable)
#   install-estate-hooks.sh --repo ~/bar   # just this one repo (repeatable)
#
# ROOTS are kept identical to gate-selfcheck.sh's, on purpose: the installer and
# the G-AF check must walk the SAME estate or "all repos protected" is a lie about
# a smaller estate than the one you have. (S44's whole finding was a gate that
# could not see 18 of 83 repos.)
#
# Reversibility, first: the ONLY mutations are two git-config keys per repo
# (core.hooksPath, estatehooks.prev/installed). --uninstall puts every one back.
# =============================================================================
set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
ROOTS=("$HOME/repos" "$HOME/code" "$HOME/Desktop/downloads" "$HOME/Scripts" \
       "$HOME/Desktop/downloads/model-name-recon/repos")   # keep in sync with gate-selfcheck.sh
declare -a ONLY=()
DRY=0; UNINSTALL=0; QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --root) ROOTS[${#ROOTS[@]}]="$2"; shift 2 ;;
    --repo) ONLY[${#ONLY[@]}]="$2"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

declare -a REPOS=()
if [ "${#ONLY[@]}" -gt 0 ]; then
  for r in "${ONLY[@]}"; do
    t="$(git -C "$r" rev-parse --show-toplevel 2>/dev/null)" || continue
    REPOS[${#REPOS[@]}]="$t"
  done
else
  seen=" "
  for r in "${ROOTS[@]}"; do
    [ -d "$r" ] || continue
    while IFS= read -r gitdir; do
      top="$(cd "$(dirname "$gitdir")" && git rev-parse --show-toplevel 2>/dev/null)" || continue
      case "$seen" in *" $top "*) continue ;; esac
      seen="$seen$top "
      REPOS[${#REPOS[@]}]="$top"
    done < <(find "$r" -maxdepth 2 -name .git -type d 2>/dev/null)
  done
fi

n_ok=0; n_changed=0; n_skip=0
for repo in "${REPOS[@]}"; do
  name="${repo/#$HOME/~}"
  cur="$(git -C "$repo" config --get core.hooksPath 2>/dev/null)" || cur=""
  prev_rec="$(git -C "$repo" config --get estatehooks.prev 2>/dev/null)" || prev_rec=""
  has_prev_key=0
  git -C "$repo" config --get estatehooks.prev >/dev/null 2>&1 && has_prev_key=1

  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -z "$cur" ] || [ ! -d "$cur" ] || [ ! "$cur" -ef "$HOOKS_DIR" ]; then n_skip=$((n_skip+1)); continue; fi
    if [ "$DRY" -eq 1 ]; then
      say "  would RESTORE $name -> ${prev_rec:-(.git/hooks)}"; n_changed=$((n_changed+1)); continue
    fi
    if [ "$has_prev_key" -eq 1 ] && [ -n "$prev_rec" ]; then
      git -C "$repo" config core.hooksPath "$prev_rec"
    else
      git -C "$repo" config --unset core.hooksPath 2>/dev/null || true
    fi
    git -C "$repo" config --unset estatehooks.prev 2>/dev/null || true
    git -C "$repo" config --unset estatehooks.installed 2>/dev/null || true
    say "  restored  $name -> ${prev_rec:-(.git/hooks)}"
    n_changed=$((n_changed+1)); continue
  fi

  # Same-dir test by INODE, not string: $HOME/code and $HOME/Code are the same directory
  # on a case-insensitive volume, and a symlinked alias is the same directory too. A string
  # compare would silently re-wire (and re-record prev) every run from an aliased path.
  if [ -n "$cur" ] && [ -d "$cur" ] && [ "$cur" -ef "$HOOKS_DIR" ]; then n_ok=$((n_ok+1)); continue; fi

  # THE self-chain trap: if estatehooks.prev is already recorded, NEVER overwrite it.
  # Re-running the installer after a partial state would otherwise record HOOKS_DIR as
  # "prev", and _chain.sh would exec itself forever. Drilled by hooks-drill.sh #7.
  if [ "$DRY" -eq 1 ]; then
    say "  would SET   $name  (prev: ${cur:-.git/hooks})"; n_changed=$((n_changed+1)); continue
  fi
  if [ "$has_prev_key" -eq 0 ] && [ -n "$cur" ]; then
    git -C "$repo" config estatehooks.prev "$cur"
  fi
  git -C "$repo" config core.hooksPath "$HOOKS_DIR"
  git -C "$repo" config estatehooks.installed "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  say "  wired     $name  (prev: ${cur:-.git/hooks})"
  n_changed=$((n_changed+1))
done

verb="wired"; [ "$UNINSTALL" -eq 1 ] && verb="restored"
[ "$DRY" -eq 1 ] && verb="would-$verb"
printf 'estate-hooks: %s=%s already-ok=%s skipped=%s  (of %s repos, hooks dir %s)\n' \
  "$verb" "$n_changed" "$n_ok" "$n_skip" "${#REPOS[@]}" "${HOOKS_DIR/#$HOME/~}"
