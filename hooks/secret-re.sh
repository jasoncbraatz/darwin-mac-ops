#!/bin/bash
# =============================================================================
# secret-re.sh — the ONE secret-shape regex for the whole estate (SSOT).
#
# Born 2026-08-08 (S45). Before this file, the credential regex lived inline in
# gate-selfcheck.sh (G-E) only, and the estate's pre-commit protection was
# per-repo and uneven: ~/Desktop/downloads blocked a credential-shaped literal at
# commit time while ~/code/darwin-mac-ops -- the repo that HOLDS gate-selfcheck.sh
# -- accepted the same literal without a murmur an hour earlier (S44 finding).
#
# Two readers, one needle, so detect-at-wrap and refuse-at-commit can never
# disagree about what a secret looks like:
#   * ~/Scripts/gate-selfcheck.sh  G-E   (WARN at wrap, whole tracked tree)
#   * ~/code/darwin-mac-ops/hooks/pre-commit (BLOCK at commit, staged index)
#
# Sourced, never executed. Defines: SECRET_RE, GE_ALLOW, ge_load_allow, ge_allowed.
#
# ⚠ SELF-INDICT RULE (global lesson 2026-07-07): a tracked file that NAMES the
# needle matches itself. The patterns below are safe because each one's literal
# text fails its own match (e.g. "shpat_[a-f0-9]{32}" has no 32 hex chars, and
# "[A-Z ]*" is not itself in [A-Z ]). Verify that property before adding a
# pattern, or this file becomes its own first false positive. Do NOT paste a
# real-shaped example key into this file or the allowlist -- S44 spelled out
# AWS's documentation example key in a comment and G-E bit the very file
# written to quiet it.
# =============================================================================

# Tight patterns: each requires the real high-entropy tail, so prose mentions of
# "shpat_" or a regex literal in a doc do not trip it.
SECRET_RE='shpat_[a-f0-9]{32}|sk-[A-Za-z0-9]{32,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|xox[baprs]-[0-9A-Za-z-]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'

# Repo-backed home. A ~/Scripts copy is SILENTLY swallowed by that repo's '*secret*'
# ignore rule -- a control file git ignores is not backed, and it took a `git status`
# that showed nothing to notice (S44). ~/Scripts/gate-secret-sweep.allow is a symlink here.
GE_ALLOW="${GE_ALLOW:-$HOME/code/darwin-mac-ops/gate-secret-sweep.allow}"

declare -a GE_PATS=(); declare -a GE_NOREASON_PATS=()
GE_NOREASON=0; GE_SUPPRESSED=0

# ge_load_allow -- parse GE_ALLOW into GE_PATS. The reason after '#' is MANDATORY:
# an exemption nobody justified is indistinguishable from an oversight six weeks later.
ge_load_allow() {
  GE_PATS=(); GE_NOREASON_PATS=(); GE_NOREASON=0; GE_SUPPRESSED=0
  [ -f "$GE_ALLOW" ] || return 0
  local al pat reason
  while IFS= read -r al; do
    al="${al%%$'\r'}"
    case "$al" in ''|'#'*) continue ;; esac
    pat="${al%%#*}"; reason="${al#*#}"
    pat="$(printf '%s' "$pat" | sed -E 's/[[:space:]]+$//')"
    [ -z "$pat" ] && continue
    if [ "$reason" = "$al" ] || [ -z "$(printf '%s' "$reason" | tr -d '[:space:]')" ]; then
      GE_NOREASON=$((GE_NOREASON+1))
      GE_NOREASON_PATS[${#GE_NOREASON_PATS[@]}]="$pat"
    fi
    GE_PATS[${#GE_PATS[@]}]="$pat"
  done < "$GE_ALLOW"
  return 0
}

# ge_allowed <repo-basename>/<path> -- 0 if suppressed by an allowlist glob.
ge_allowed() {
  local k="$1" p
  [ "${#GE_PATS[@]}" -eq 0 ] && return 1
  for p in "${GE_PATS[@]}"; do
    case "$k" in $p) return 0 ;; esac
  done
  return 1
}

# ge_mask <line> -- print the matched token with its high-entropy tail masked.
# Never print the raw line: truncation can DISPLAY a leading jsCode comment while
# HIDING the real secret deeper on the same line (2026-07-07, COGS workflows).
ge_mask() {
  printf '%s' "$1" | grep -oE "$SECRET_RE" | head -1 | sed -E 's/(.{10}).*/\1…MASKED/'
}
