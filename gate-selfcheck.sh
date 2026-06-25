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

# --- G-S · orphan code-island sweep (born 2026-06-22: cogs-mover was gitignored in
#     ~/Scripts AND never made its own repo -> live-bearing code lived in NO git repo,
#     invisible to the sweep above. The .gitignore even CLAIMED it was "its own repo".
#     Force function: any dir a repo's .gitignore excludes that CONTAINS code MUST
#     actually be its own git repo with a remote, or it is an unbacked island = FAIL.) ---
bold "=== G-S · orphan code-island sweep (gitignored code dirs must be their own backed repo) ==="
ORPHANS=0
for repo in "${REPOS[@]}"; do
  gi="$repo/.gitignore"
  [ -f "$gi" ] || continue
  while IFS= read -r raw; do
    line="${raw%%#*}"; line="$(echo "$line" | xargs 2>/dev/null)"     # strip comments + surrounding space
    case "$line" in ""|"!"*|*"*"*) continue ;; esac                    # skip blank / negation / glob lines
    case "$line" in */) sub="${line%/}" ;; *) continue ;; esac         # only directory excludes (trailing /)
    base="$(basename "$sub")"                                          # skip build/cache/vendor artifacts (not source we'd back)
    case "$base" in node_modules|.venv|venv|env|dist|build|out|target|__pycache__|.pytest_cache|.cache|.next|.nuxt|coverage|vendor|.git|.idea|.vscode|tmp|temp|.mypy_cache|.ruff_cache) continue ;; esac
    d="$repo/$sub"
    [ -d "$d" ] || continue
    hascode="$(find "$d" -maxdepth 2 \( -name '*.js' -o -name '*.py' -o -name '*.sh' -o -name '*.ts' -o -name 'package.json' \) -not -path '*/node_modules/*' 2>/dev/null | head -1)"
    [ -z "$hascode" ] && continue                                      # only care about dirs that actually hold code
    top="$(cd "$d" && git rev-parse --show-toplevel 2>/dev/null)"
    rem=""; [ "$top" = "$d" ] && rem="$(cd "$d" && git remote get-url origin 2>/dev/null)"
    if [ "$top" != "$d" ] || [ -z "$rem" ]; then
      printf '  ORPHAN %-45s%s\n' "${d/#$HOME/~}" "gitignored code, NOT a backed repo"
      FAILS+=("${d/#$HOME/~}: gitignored code island with no git remote (per .gitignore it should be its own repo) -> git init + gh repo create + push")
      ORPHANS=$((ORPHANS+1))
    else
      [ "$QUIET" -eq 1 ] || printf '  ok     %-45s%s\n' "${d/#$HOME/~}" "-> own repo ($rem)"
    fi
  done < "$gi"
done
[ "$ORPHANS" -eq 0 ] && { [ "$QUIET" -eq 1 ] || echo "  (no orphan code-islands — every gitignored code dir is its own backed repo)"; }
echo

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

# --- G-T#43 remote-runtime parity + scheduler presence (parity v2.13; scheduler-presence v2.16 2026-06-23) ---
# The box self-reconciles via a read-only gh deploy key AND a */15 cron (sz-box-pull.sh). We check BOTH: that
# the box IS current (HEAD==gh), AND that the MECHANISM keeping it current is still installed. A reflatten that
# restored the checkout but dropped the cron would leave HEAD momentarily == gh yet silently stop all future
# deploys — parity alone can't catch that; the scheduler-presence probe does. WARN-level + graceful skip so an
# offline box or a phone/web session (no ssh) NEVER blocks a wrap. Override host/paths via env if topology moves.
SZ_BOX_HOST="${SZ_BOX_HOST:-n8n}"
SZ_BOX_REPO="${SZ_BOX_REPO:-~/virtual-darwin/spine/repos/strike-zone}"
SZ_GH_LOCAL="${SZ_GH_LOCAL:-$HOME/repos/strike-zone}"
SZ_BOX_SCHED="${SZ_BOX_SCHED:-sz-box-pull.sh}"   # the cron line that keeps the box converged to gh
if [ -d "$SZ_GH_LOCAL/.git" ] && command -v ssh >/dev/null 2>&1; then
  GH_HEAD="$(git -C "$SZ_GH_LOCAL" rev-parse HEAD 2>/dev/null)"
  # ONE round-trip: line1 = box HEAD, line2 = count of the scheduler line in the box crontab.
  BOX_PROBE="$(timeout 14 ssh -o BatchMode=yes -o ConnectTimeout=8 "$SZ_BOX_HOST" "git -C $SZ_BOX_REPO rev-parse HEAD 2>/dev/null; crontab -l 2>/dev/null | grep -cF -- $SZ_BOX_SCHED" 2>/dev/null)"
  BOX_HEAD="$(printf '%s\n' "$BOX_PROBE" | sed -n '1p' | tr -d '\r\n ')"
  BOX_SCHED_N="$(printf '%s\n' "$BOX_PROBE" | sed -n '2p' | tr -d '\r\n ')"
  if [ -z "$BOX_HEAD" ]; then
    : # box unreachable (offline / no-ssh session) — skip silently, never a wrap blocker
  else
    if [ -n "$GH_HEAD" ] && [ "$BOX_HEAD" != "$GH_HEAD" ]; then
      WARNS+=("G-T#43: sz-tick runtime box ($SZ_BOX_HOST) HEAD ${BOX_HEAD:0:7} != gh ${GH_HEAD:0:7} — deploy: ssh $SZ_BOX_HOST 'git -C $SZ_BOX_REPO pull --ff-only'")
    fi
    if [ "${BOX_SCHED_N:-0}" = "0" ]; then
      WARNS+=("G-T#43b: box auto-pull SCHEDULER MISSING ($SZ_BOX_SCHED not in $SZ_BOX_HOST crontab) — box will NOT self-converge to gh; restore the */15 line from $SZ_BOX_REPO/provision/n8n/spine-crontab.txt")
    fi
  fi
fi

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

# --- G-L#35b · gate range-ref drift (born 2026-06-25 P0 audit: "G-A..R/P" range statements rot in
#     front doors after new steps (G-S/G-T) get added, because the range is COPIED not DERIVED.
#     Derive the live max G-step from the canonical gate, WARN any stale front-door range ref.
#     The gate's OWN changelog is excluded (it cites historical ranges by design). ---
if [ -f "$CANON_GATE" ]; then
  MAXG=$(grep -oE '^## G-[A-Z]' "$CANON_GATE" | sed 's/.*G-//' | sort | tail -1)
  if [ -n "$MAXG" ]; then
    for RF in "$CANON_GATE" "$HOME/repos/claude-blackbook/lessons.py" "$HOME/Desktop/downloads/CLAUDE.md" "$HOME/repos/strike-zone/docs/HANDOFF-PROMPT.md"; do
      [ -f "$RF" ] || continue
      if [ "$RF" = "$CANON_GATE" ]; then CONTENT=$(awk '/^## Changelog/{exit} {print}' "$RF"); else CONTENT=$(cat "$RF"); fi
      while IFS= read -r m; do
        endp=$(printf '%s' "$m" | grep -oE '[A-Z]' | tail -1)
        if [ -n "$endp" ] && [[ "$endp" < "$MAXG" ]]; then
          WARNS+=("gate range-ref drift: ${RF/#$HOME/~} cites 'G-A..$endp' but the gate documents through G-$MAXG — update the live range statement")
        fi
      done < <(printf '%s\n' "$CONTENT" | grep -hoE 'G-A *(\.\.|->|→|through)+ *(G-)?[A-Z]')
    done
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
  Any "not yet" is a BLOCKER: fix the doc gap before handing off. Full gate: ~/Desktop/downloads/HANDOFF-GATE.md (G-A->G-T).
TRIAD
  exit 0
else
  bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s) — fix before writing the handoff)"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
