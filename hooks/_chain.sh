#!/bin/bash
# =============================================================================
# _chain.sh — delegate to whatever hook this repo had BEFORE the estate took over.
#
# core.hooksPath does not layer: the moment it is set, git stops looking in
# .git/hooks entirely. Without this shim, installing the estate hooks would have
# SILENTLY killed strike-zone's pre-push (scripts/hooks/pre-push, the offline
# net self-test) and n8n-stack's pre-commit (Workflow Guard) -- two live controls,
# gone, with nothing to notice. That is the single biggest risk of the whole
# change, which is why hooks-drill.sh asserts it every run.
#
# The installer records the prior location in `git config estatehooks.prev`
# (empty/unset => the repo's own .git/hooks). Every estate hook name that is not
# pre-commit is a symlink to this file.
# =============================================================================
set -uo pipefail
HOOK="${ESTATE_HOOK_NAME:-$(basename "$0")}"
TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
prev="$(git config --get estatehooks.prev 2>/dev/null)" || prev=""
if [ -n "$prev" ]; then
  case "$prev" in /*) d="$prev" ;; *) d="$TOP/$prev" ;; esac
else
  gd="$(git rev-parse --git-dir 2>/dev/null)" || exit 0
  case "$gd" in /*) ;; *) gd="$TOP/$gd" ;; esac
  d="$gd/hooks"
fi
# ESTATE_HOOK_DRYRUN=1 -> report what WOULD be chained and exit, without running it.
# Lets a human (or G-AF) answer "did installing core.hooksPath orphan anybody's hook?"
# across the whole estate without executing 106 repos' worth of side effects.
if [ -n "${ESTATE_HOOK_DRYRUN:-}" ]; then
  if [ -x "$d/$HOOK" ]; then echo "chain: $HOOK -> $d/$HOOK"; else echo "chain: $HOOK -> (none)"; fi
  exit 0
fi
[ -x "$d/$HOOK" ] || exit 0
# exec, not a call: preserves stdin (pre-push reads its refs there) and the exit code.
exec "$d/$HOOK" "$@"
