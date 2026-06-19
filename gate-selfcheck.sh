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
# LOUD on real drift, in the house style.
#
#   exit 0 = no real drift (PASS)         FAIL = uncommitted or unpushed work
#   exit 1 = real drift found (FAIL)      WARN = no remote / tracking unset (noted)
#
# Usage:
#   gate-selfcheck.sh                      # repo hygiene sweep across all roots
#   gate-selfcheck.sh --fetch              # git fetch first (slower, more accurate)
#   gate-selfcheck.sh --dead-value VAL     # also hunt VAL (repeatable) — G-I
#   gate-selfcheck.sh --root ~/foo         # add an extra root to scan (repeatable)
#   gate-selfcheck.sh --quiet              # only print WARN/FAIL lines + summary
#
# Source of truth: git repo ~/code/darwin-mac-ops (this file). Live copy
# ~/Scripts/gate-selfcheck.sh is a SYMLINK into that repo. Referenced by
# ~/Desktop/downloads/HANDOFF-GATE.md (G-H / G-I).
# =============================================================================
set -uo pipefail

ROOTS=("$HOME/repos" "$HOME/code" "$HOME/Desktop/downloads" "$HOME/Scripts")
DEAD_VALUES=()
DO_FETCH=0
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --fetch) DO_FETCH=1; shift ;;
    --dead-value) DEAD_VALUES+=("$2"); shift 2 ;;
    --root) ROOTS+=("$2"); shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
FAILS=(); WARNS=()

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
  has_remote=0; [ -n "$(git remote 2>/dev/null)" ] && has_remote=1
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    ahead="$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"; tracking="ok"
  else
    ahead=0; tracking="none"
  fi

  flags=""; level="ok"
  if [ -n "$dirty" ]; then
    nd="$(printf '%s\n' "$dirty" | grep -c .)"
    flags="$flags DIRTY($nd)"; FAILS+=("$name: $nd uncommitted change(s)"); level="FAIL"
  fi
  if [ "$ahead" -gt 0 ]; then
    flags="$flags UNPUSHED($ahead)"; FAILS+=("$name: $ahead unpushed commit(s) on $branch"); level="FAIL"
  fi
  if [ "$has_remote" -eq 0 ]; then
    flags="$flags NO-REMOTE"; WARNS+=("$name: no git remote (work is unbacked)"); [ "$level" = ok ] && level="WARN"
  elif [ "$tracking" = "none" ]; then
    flags="$flags no-tracking"; WARNS+=("$name: remote exists but branch '$branch' has no upstream tracking"); [ "$level" = ok ] && level="WARN"
  fi

  case "$level" in
    ok)   [ "$QUIET" -eq 1 ] || printf '  ok    %s\n' "$name" ;;
    WARN) printf '  warn  %-45s%s\n' "$name" "$flags" ;;
    FAIL) printf '  FAIL  %-45s%s\n' "$name" "$flags" ;;
  esac
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

# --- G-E mechanical secret sweep (born 2026-06-17: a worker committed a live Shopify token) ---
# Tight patterns (require the real high-entropy tail) so doc mentions of "shpat_"/regex literals don't trip it.
# Loud WARN (not FAIL) to keep momentum; if a hit is a REAL secret, treat it as a blocker + rotate.
# NOTE: only sweeps maxdepth-2 repos (same as the hygiene sweep); deeply-nested vendored clones are not covered.
SECRET_RE='shpat_[a-f0-9]{32}|sk-[A-Za-z0-9]{32,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|xox[baprs]-[0-9A-Za-z-]{20,}|AIza[0-9A-Za-z_-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
SECCOUNT=0
for repo in "${REPOS[@]}"; do
  cd "$repo" || continue
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$SECCOUNT" -eq 0 ] && bold "=== G-E · secret sweep (tracked files) ==="
    printf '    %s: %s\n' "${repo/#$HOME/~}" "$(echo "$line" | cut -c1-90)"; SECCOUNT=$((SECCOUNT+1))
  done < <(git grep -nIE "$SECRET_RE" 2>/dev/null)
done
[ "$SECCOUNT" -gt 0 ] && WARNS+=("G-E: $SECCOUNT possible SECRET(s) in tracked files (see list above) — if real, scrub from HEAD, ROTATE the credential, and never commit it")

# --- HANDOFF-GATE secondary-mirror freshness (G-L#35: one canonical home, synced not forked) ---
CANON_GATE="$HOME/Desktop/downloads/HANDOFF-GATE.md"
MIRROR_GATE="$HOME/repos/claude-blackbook/HANDOFF-GATE.md"
if [ -f "$CANON_GATE" ]; then
  if [ ! -f "$MIRROR_GATE" ]; then
    WARNS+=("HANDOFF-GATE claude-blackbook mirror missing — clone it, then run ~/Scripts/mirror-handoff-gate.sh")
  elif ! cmp -s "$CANON_GATE" "$MIRROR_GATE"; then
    WARNS+=("HANDOFF-GATE claude-blackbook mirror is STALE — run ~/Scripts/mirror-handoff-gate.sh")
  fi
fi

echo
[ "${#WARNS[@]}" -gt 0 ] && { bold "WARNINGS (${#WARNS[@]}) — not blocking, but worth a glance:"; printf '  - %s\n' "${WARNS[@]}"; }
if [ "${#FAILS[@]}" -eq 0 ]; then
  bold "GATE SELF-CHECK: PASS ✅  (no uncommitted/unpushed work — now the human-judgment half)"
  cat >&2 <<'TRIAD'

  ── The self-review triad — answer IN WRITING before any handoff (even if Jason never asked) ──
  The trigger is the work winding down, not Jason's reminder. He is human and will forget; you won't.
  1. Did we capture EVERYTHING we did today for a zero-memory future Opus? every change, its real
     path, how to undo it — enough to reconstruct today from the docs alone.            (-> G-A)
  2. What did we learn the hard way that is NOT written down yet? anything that cost >~2 tool calls
     (a trap, a quirk, a confirmed fact) goes into the LUT/lessons corpus NOW.           (-> G-B / G-N)
  3. What ONE thing makes the next Opus's life easier than ours was — and did we ADD it THIS pass?
     a sharper prompt, a script, a cached LUT, a new gate check. "I looked hard and genuinely found
     nothing" is a LEGAL, celebrated answer — but it must be rare, and you must say WHY.  (-> G-G)
  Any "not yet" is a BLOCKER: fix the doc gap before handing off. Full gate: ~/Desktop/downloads/HANDOFF-GATE.md (G-A->G-R).
TRIAD
  exit 0
else
  bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s) — fix before writing the handoff)"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
