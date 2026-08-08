#!/bin/bash
# =============================================================================
# install-estate-hooks.sh — make every repo on this Mac refuse credentials at
# COMMIT, without killing any hook a repo already had.
#
#   install-estate-hooks.sh                # install (idempotent)
#   install-estate-hooks.sh --dry-run      # say what it WOULD do, change nothing
#   install-estate-hooks.sh --uninstall    # restore prior state exactly (global + per-repo)
#   install-estate-hooks.sh --root ~/foo   # extra root (repeatable)
#   install-estate-hooks.sh --repo ~/bar   # just this one repo (repeatable; never touches global)
#   install-estate-hooks.sh --no-global    # per-repo wiring only, leave ~/.gitconfig alone
#
# TWO LAYERS, on purpose (S46):
#
#   1. THE GLOBAL DEFAULT — `git config --global core.hooksPath <here>`.
#      This is the load-bearing one. It covers every repo on the machine that has
#      no core.hooksPath of its own: the ones under the roots below, the ones that
#      are not, and — the whole point — every repo CLONED OR `git init`'d FROM NOW
#      ON. No per-repo state, nothing to remember, and nothing COPIED that could
#      drift out of date. S45 shipped per-repo wiring only, so protection lived in
#      .git/config — untracked, uncloned — and a fresh clone was unprotected until
#      somebody remembered this script.
#
#      NOT init.templateDir, which is the obvious-looking answer. Measured (S46):
#      a template that COPIES the hooks freezes them at install-day forever (the
#      COPIED-not-DERIVED family, ninth instance), and a template that SYMLINKS
#      them makes the hook resolve $0 inside .git/hooks, where secret-re.sh and
#      _chain.sh are not — so it fails CLOSED on every commit in every new clone.
#      Both shapes were run end-to-end before this one was chosen.
#
#   2. THE PER-REPO WIRING — the loop below. Git config is most-specific-wins, so
#      a repo with its OWN local core.hooksPath (e.g. ~/Desktop/downloads pointing
#      at .githooks) IGNORES the global default entirely. Those repos are exactly
#      the ones that still need explicit wiring, and G-AF names any that lack it.
#
# ROOTS are kept identical to gate-selfcheck.sh's, on purpose: the installer and
# the G-AF check must walk the SAME estate or "all repos protected" is a lie about
# a smaller estate than the one you have. (S44's whole finding was a gate that
# could not see 18 of 83 repos.) ESTATE_HOOK_ROOTS overrides them, colon-separated,
# so hooks-drill.sh can exercise a full-estate run against scratch dirs.
#
# Reversibility, first: the ONLY mutations are git-config keys — core.hooksPath
# globally, plus core.hooksPath + estatehooks.prev/installed per repo. --uninstall
# puts every one of them back, which is why the global key is set HERE and not by
# hand: one documented undo command has to stay true.
# =============================================================================
set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd -P)"
if [ -n "${ESTATE_HOOK_ROOTS:-}" ]; then
  declare -a ROOTS=()
  # bash 3.2 (darwin ships 2007's): no mapfile, no readarray.
  _oldifs="$IFS"; IFS=':'
  for _r in $ESTATE_HOOK_ROOTS; do [ -n "$_r" ] && ROOTS[${#ROOTS[@]}]="$_r"; done
  IFS="$_oldifs"
else
  ROOTS=("$HOME/repos" "$HOME/code" "$HOME/Desktop/downloads" "$HOME/Scripts" \
         "$HOME/Desktop/downloads/model-name-recon/repos")   # keep in sync with gate-selfcheck.sh
fi
declare -a ONLY=()
DRY=0; UNINSTALL=0; QUIET=0; NO_GLOBAL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --root) ROOTS[${#ROOTS[@]}]="$2"; shift 2 ;;
    --repo) ONLY[${#ONLY[@]}]="$2"; shift 2 ;;
    --no-global) NO_GLOBAL=1; shift ;;
    --quiet) QUIET=1; shift ;;
    # DERIVED, not a copied line range: the header grows and a hardcoded "2,45p"
    # silently starts truncating the help text (the COPIED-not-DERIVED family again).
    -h|--help) awk 'NR>1 && /^# ={10,}/{n++; next} n==1' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# --repo is the surgical mode (it is what hooks-drill.sh uses). Surgical stays
# surgical: it never reaches into ~/.gitconfig.
TOUCH_GLOBAL=1
[ "${#ONLY[@]}" -gt 0 ] && TOUCH_GLOBAL=0
[ "$NO_GLOBAL" -eq 1 ] && TOUCH_GLOBAL=0

# -----------------------------------------------------------------------------
# Layer 1 — the global default
# -----------------------------------------------------------------------------
g_state="untouched"
if [ "$TOUCH_GLOBAL" -eq 1 ]; then
  gcur="$(git config --global --get core.hooksPath 2>/dev/null)" || gcur=""
  if [ "$UNINSTALL" -eq 1 ]; then
    # Only ever unset OUR value. If Jason (or some other tool) pointed the global
    # key somewhere else, that is not ours to remove.
    if [ -n "$gcur" ] && [ -d "$gcur" ] && [ "$gcur" -ef "$HOOKS_DIR" ]; then
      if [ "$DRY" -eq 1 ]; then g_state="would-unset"
      else git config --global --unset core.hooksPath 2>/dev/null && g_state="unset" || g_state="unset-FAILED"; fi
    elif [ -n "$gcur" ]; then g_state="left-alone (points at $gcur, not ours)"
    else g_state="already-absent"; fi
  else
    # Inode compare, not string: $HOME/code and $HOME/Code are the same directory on a
    # case-insensitive volume, so a string compare would rewrite the key on every run
    # from the other spelling — a control that churns is a control nobody reads.
    if [ -n "$gcur" ] && [ -d "$gcur" ] && [ "$gcur" -ef "$HOOKS_DIR" ]; then
      g_state="already-set"
    elif [ -n "$gcur" ]; then
      # Someone else owns this key. Refuse to clobber it; say so loudly.
      g_state="CONFLICT (global core.hooksPath=$gcur — not overwritten)"
      say "  ⚠ global core.hooksPath already points at $gcur (not the estate hooks)."
      say "    Left as-is. Resolve by hand, then re-run; per-repo wiring below still applies."
    else
      if [ "$DRY" -eq 1 ]; then g_state="would-set"
      else git config --global core.hooksPath "$HOOKS_DIR" && g_state="set" || g_state="set-FAILED"; fi
    fi
  fi
fi

# -----------------------------------------------------------------------------
# Layer 2 — per-repo wiring (the repos that override the global default)
# -----------------------------------------------------------------------------
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
  cur="$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null)" || cur=""
  prev_rec="$(git -C "$repo" config --local --get estatehooks.prev 2>/dev/null)" || prev_rec=""
  has_prev_key=0
  git -C "$repo" config --local --get estatehooks.prev >/dev/null 2>&1 && has_prev_key=1

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
printf 'estate-hooks: global-default=%s  %s=%s already-ok=%s skipped=%s  (of %s repos, hooks dir %s)\n' \
  "$g_state" "$verb" "$n_changed" "$n_ok" "$n_skip" "${#REPOS[@]}" "${HOOKS_DIR/#$HOME/~}"
