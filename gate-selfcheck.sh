#!/bin/bash
# =============================================================================
# gate-selfcheck.sh
# -----------------------------------------------------------------------------
# The MECHANICAL half of HANDOFF-GATE.md. The gate has two kinds of checks:
#   - human-judgment ones (G-C "is the next step clear?", G-G "what did we learn?")
#     -> only a thinking session can answer those; this script does NOT touch them.
#   - mechanical ones (G-H #22 every touched repo committed+pushed; G-I dead-value
#     sweep) -> a script does these faster and more reliably than a tired human.
#
# So: run this FIRST when wrapping a session. It clears the boring checks so the
# session can spend its attention on the judgment calls. SILENT-ish on pass,
# LOUD on fail, in the house style.
#
#   exit 0 = repo hygiene clean (PASS)
#   exit 1 = at least one repo dirty or unpushed (FAIL) — fix before you hand off
#
# Usage:
#   gate-selfcheck.sh                      # repo hygiene sweep across all roots
#   gate-selfcheck.sh --fetch              # git fetch first (slower, more accurate)
#   gate-selfcheck.sh --dead-value VAL     # also hunt VAL (repeatable) — G-I
#   gate-selfcheck.sh --root ~/foo         # add an extra root to scan (repeatable)
#
# Source of truth: git repo ~/code/darwin-mac-ops (this file). Live copy
# ~/Scripts/gate-selfcheck.sh is a SYMLINK into that repo. Referenced by
# ~/Desktop/downloads/HANDOFF-GATE.md (G-H / G-I).
# =============================================================================
set -uo pipefail

ROOTS=("$HOME/repos" "$HOME/code" "$HOME/Desktop/downloads" "$HOME/Scripts")
DEAD_VALUES=()
DO_FETCH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --fetch) DO_FETCH=1; shift ;;
    --dead-value) DEAD_VALUES+=("$2"); shift 2 ;;
    --root) ROOTS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
FAILS=()

# --- discover unique git working-tree toplevels under the roots ---
declare -a REPOS=()
seen=" "
for r in "${ROOTS[@]}"; do
  [ -d "$r" ] || continue
  while IFS= read -r gitdir; do
    top="$(cd "$(dirname "$gitdir")" && git rev-parse --show-toplevel 2>/dev/null)" || continue
    case "$seen" in *" $top "*) continue ;; esac
    seen="$seen$top "
    REPOS+=("$top")
  done < <(find "$r" -maxdepth 2 -name .git -type d 2>/dev/null)
done

bold "=== G-H #22 · repo hygiene sweep (${#REPOS[@]} repos across ${#ROOTS[@]} roots) ==="
for repo in "${REPOS[@]}"; do
  cd "$repo" || continue
  name="${repo/#$HOME/~}"
  [ "$DO_FETCH" -eq 1 ] && git fetch --quiet 2>/dev/null
  dirty="$(git status --porcelain 2>/dev/null)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    ahead="$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"
    upstream="ok"
  else
    ahead=0; upstream="NONE"
  fi
  nd="$(printf '%s' "$dirty" | grep -c . || true)"
  status="clean"
  if [ -n "$dirty" ]; then status="DIRTY($nd)"; FAILS+=("$name: $nd uncommitted change(s)"); fi
  if [ "$ahead" -gt 0 ]; then status="$status UNPUSHED($ahead)"; FAILS+=("$name: $ahead unpushed commit(s) on $branch"); fi
  if [ "$upstream" = "NONE" ]; then status="$status no-upstream"; fi
  case "$status" in clean) printf '  ok    %s\n' "$name" ;; *) printf '  FAIL  %-45s %s\n' "$name" "$status" ;; esac
done

# --- G-I optional dead-value sweep (report-only; human judges intent) ---
if [ "${#DEAD_VALUES[@]}" -gt 0 ]; then
  echo
  bold "=== G-I · dead-value sweep (report-only — confirm survivors are intentional) ==="
  for val in "${DEAD_VALUES[@]}"; do
    echo "  hunting: $val"
    hits=0
    for repo in "${REPOS[@]}"; do
      cd "$repo" || continue
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf '    %s: %s\n' "${repo/#$HOME/~}" "$line"; hits=$((hits+1))
      done < <(git grep -n -F -- "$val" 2>/dev/null)
    done
    [ "$hits" -eq 0 ] && echo "    none found (fully eradicated)" || echo "    -> $hits hit(s) — verify each is a changelog/backup/intentional ref, not a live use"
  done
fi

echo
if [ "${#FAILS[@]}" -eq 0 ]; then
  bold "GATE SELF-CHECK: PASS ✅  (repo hygiene clean — now answer the human-judgment checks)"
  exit 0
else
  bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s) — fix before writing the handoff)"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
