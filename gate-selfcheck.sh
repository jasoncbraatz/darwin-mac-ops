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
    # Show file:line + the ACTUAL matched token (prefix kept, high-entropy tail MASKED) — NOT
    # cut -c1-90 of the raw line: that truncation can DISPLAY a leading jsCode // comment while
    # HIDING the real secret deeper on the same line. On 2026-07-07 it disguised real hardcoded
    # shpat_ tokens in COGS jsCode as benign "// 7:30" comments, and a teed-up "just skip jsCode
    # comment lines" would have MASKED live secrets. Masking the tail keeps the sweep from leaking
    # the credential into logs while still proving it IS a token, not a comment.
    floc=$(printf '%s' "$line" | cut -d: -f1-2)
    tok=$(printf '%s' "$line" | grep -oE "$SECRET_RE" | head -1 | sed -E 's/(.{10}).*/\1…MASKED/')
    printf '    %s: %s  [match: %s]\n' "${repo/#$HOME/~}" "$floc" "$tok"; SECCOUNT=$((SECCOUNT+1))
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
# v2.26 (G-T#43c): sz-box-pull v2 made the box a TWO-repo runtime (strike-zone + the
# sz-exhaust-ledger sibling) — parity must name them both or a wedged ledger checkout
# passes the gate silently while box jobs consume stale calibration/craft data.
SZ_BOX_LEDGER_REPO="${SZ_BOX_LEDGER_REPO:-~/virtual-darwin/spine/repos/sz-exhaust-ledger}"
SZ_GH_LEDGER_LOCAL="${SZ_GH_LEDGER_LOCAL:-$HOME/repos/sz-exhaust-ledger}"
SZ_BOX_SCHED="${SZ_BOX_SCHED:-sz-box-pull.sh}"   # the cron line that keeps the box converged to gh
if [ -d "$SZ_GH_LOCAL/.git" ] && command -v ssh >/dev/null 2>&1; then
  GH_HEAD="$(git -C "$SZ_GH_LOCAL" rev-parse HEAD 2>/dev/null)"
  GH_LEDGER_HEAD="$(git -C "$SZ_GH_LEDGER_LOCAL" rev-parse HEAD 2>/dev/null)"
  # ONE round-trip: line1 = box strike-zone HEAD, line2 = box ledger HEAD, line3 = scheduler count.
  # `|| echo MISSING` keeps line positions DETERMINISTIC (a failed rev-parse used to shift the
  # scheduler count up a line and silently mis-parse).
  BOX_PROBE="$(timeout 14 ssh -o BatchMode=yes -o ConnectTimeout=8 "$SZ_BOX_HOST" "git -C $SZ_BOX_REPO rev-parse HEAD 2>/dev/null || echo MISSING; git -C $SZ_BOX_LEDGER_REPO rev-parse HEAD 2>/dev/null || echo MISSING; crontab -l 2>/dev/null | grep -cF -- $SZ_BOX_SCHED" 2>/dev/null)"
  BOX_HEAD="$(printf '%s\n' "$BOX_PROBE" | sed -n '1p' | tr -d '\r\n ')"
  BOX_LEDGER_HEAD="$(printf '%s\n' "$BOX_PROBE" | sed -n '2p' | tr -d '\r\n ')"
  BOX_SCHED_N="$(printf '%s\n' "$BOX_PROBE" | sed -n '3p' | tr -d '\r\n ')"
  if [ -z "$BOX_HEAD" ]; then
    : # box unreachable (offline / no-ssh session) — skip silently, never a wrap blocker
  else
    if [ -n "$GH_HEAD" ] && [ "$BOX_HEAD" != "$GH_HEAD" ]; then
      WARNS+=("G-T#43: sz-tick runtime box ($SZ_BOX_HOST) HEAD ${BOX_HEAD:0:7} != gh ${GH_HEAD:0:7} — deploy: ssh $SZ_BOX_HOST 'git -C $SZ_BOX_REPO pull --ff-only'")
    fi
    if [ -n "$GH_LEDGER_HEAD" ] && [ -n "$BOX_LEDGER_HEAD" ] && [ "$BOX_LEDGER_HEAD" != "$GH_LEDGER_HEAD" ]; then
      WARNS+=("G-T#43c: ledger runtime box ($SZ_BOX_HOST) HEAD ${BOX_LEDGER_HEAD:0:7} != gh ${GH_LEDGER_HEAD:0:7} — converge: ssh $SZ_BOX_HOST '$SZ_BOX_REPO/scripts/sz-box-pull.sh --quiet' (exit 8 = drift-orphan; see the DAY-1H leaf)")
    fi
    if [ "${BOX_SCHED_N:-0}" = "0" ]; then
      WARNS+=("G-T#43b: box auto-pull SCHEDULER MISSING ($SZ_BOX_SCHED not in $SZ_BOX_HOST crontab) — box will NOT self-converge to gh; restore the */15 line from $SZ_BOX_REPO/provision/n8n/spine-crontab.txt")
    fi
  fi
fi

# --- G-T#44 · crontab-vault drift (born 2026-06-26: the n8n-spine crontab is box-LOCAL state a
#     rebuild loses; provision/n8n/spine-crontab.txt is the gh ark, but it drifted 3x when refreshed
#     by hand. sz-crontab-snapshot.sh --check is a READ-ONLY probe (exit 2 = drift, 0 = in sync, and
#     it NEVER writes — so the gate can't dirty the vault) wired here so a wrap notices divergence
#     automatically. WARN-level + graceful skip so an offline box or a phone/web session (no ssh)
#     NEVER blocks a wrap. Closes the loop the vault opened (drift caught by tool, not by memory).) ---
SZ_CRON_SNAP="${SZ_CRON_SNAP:-$SZ_GH_LOCAL/scripts/sz-crontab-snapshot.sh}"
if [ -x "$SZ_CRON_SNAP" ] && command -v ssh >/dev/null 2>&1; then
  if SZ_BOX_SSH="$SZ_BOX_HOST" timeout 20 bash "$SZ_CRON_SNAP" --check >/dev/null 2>&1; then
    : # exit 0 = vault in sync — silent
  else
    rc=$?
    if [ "$rc" -eq 2 ]; then
      WARNS+=("G-T#44: n8n-spine crontab DRIFT — live box crontab != vaulted provision/n8n/spine-crontab.txt; refresh: (cd $SZ_GH_LOCAL && SZ_BOX_SSH=$SZ_BOX_HOST scripts/sz-crontab-snapshot.sh --commit)")
    fi
    # rc 3 (empty crontab) / 124 (timeout) / ssh-unreachable / any other -> skip silently (phone-safe, never a wrap blocker)
  fi
fi

# --- G-T#45 · n8n-provision box-repo parity (born 2026-07-04: /opt/n8n became a gh-backed repo
#     (jasoncbraatz/n8n-provision) that the BOX authors + pushes via a deploy key. It lives on the
#     n8n box, OUTSIDE darwin's ROOTS, so the G-H sweep can't see it — a live compose/Caddyfile edit
#     left uncommitted/unpushed would drift invisibly (the exact "prod config on one uninsured SSD"
#     risk this repo was created to kill). READ-ONLY probe: working tree clean AND HEAD pushed to
#     origin. sudo because /opt/n8n is root-owned (claudeApp has NOPASSWD). WARN-level + graceful skip
#     so an offline box / phone-web session never blocks a wrap. Override host/path via env.) ---
N8N_PROV_HOST="${N8N_PROV_HOST:-n8n}"
N8N_PROV_REPO="${N8N_PROV_REPO:-/opt/n8n}"
if command -v ssh >/dev/null 2>&1; then
  PROV_PROBE="$(timeout 14 ssh -o BatchMode=yes -o ConnectTimeout=8 "$N8N_PROV_HOST" "sudo git -C $N8N_PROV_REPO status --porcelain 2>/dev/null | wc -l | tr -d ' '; sudo git -C $N8N_PROV_REPO rev-list --count @{u}..HEAD 2>/dev/null || echo MISSING" 2>/dev/null)"
  PROV_DIRTY="$(printf '%s\n' "$PROV_PROBE" | sed -n '1p' | tr -d '\r\n ')"
  PROV_AHEAD="$(printf '%s\n' "$PROV_PROBE" | sed -n '2p' | tr -d '\r\n ')"
  if [ -z "$PROV_PROBE" ] || [ "$PROV_AHEAD" = "MISSING" ]; then
    : # box unreachable OR no upstream set — skip silently (phone-safe, never a wrap blocker)
  else
    if [ "${PROV_DIRTY:-0}" != "0" ]; then
      WARNS+=("G-T#45: n8n-provision box repo ($N8N_PROV_HOST:$N8N_PROV_REPO) has UNCOMMITTED change(s) [$PROV_DIRTY] — commit+push on the box (sudo git add -A && sudo git commit && sudo git push)")
    fi
    if [ -n "$PROV_AHEAD" ] && [ "$PROV_AHEAD" != "0" ]; then
      WARNS+=("G-T#45b: n8n-provision box repo ($N8N_PROV_HOST:$N8N_PROV_REPO) has $PROV_AHEAD UNPUSHED commit(s) — ssh $N8N_PROV_HOST 'sudo git -C $N8N_PROV_REPO push'")
    fi
  fi
fi

# --- G-T#46 · flowers box-repo parity (born 2026-07-14, order-flow sentinel session: /var/www/flowers
#     is a gh-backed repo (jasoncbraatz/flowers) that the BOX authors + pushes (root-owned; sudo git).
#     It lives on the flowers Linode, OUTSIDE darwin's ROOTS, so the G-H sweep can't see it — live
#     server.ts / health-module / OPUS-README edits left uncommitted or unpushed would drift invisibly
#     (this exact repo silently drifted for weeks once, pre-gate). Same recipe as G-T#45: READ-ONLY
#     probe, worktree clean AND HEAD pushed; WARN-level + graceful skip (offline box / phone-web never
#     blocks a wrap). darwin's ~/.ssh/config has a direct `flowers` alias (public IP, key auth,
#     claudeApp NOPASSWD sudo). Override host/path via env. ---
FLOWERS_BOX_HOST="${FLOWERS_BOX_HOST:-flowers}"
FLOWERS_BOX_REPO="${FLOWERS_BOX_REPO:-/var/www/flowers}"
if command -v ssh >/dev/null 2>&1; then
  FLW_PROBE="$(timeout 14 ssh -o BatchMode=yes -o ConnectTimeout=8 "$FLOWERS_BOX_HOST" "sudo git -C $FLOWERS_BOX_REPO status --porcelain 2>/dev/null | wc -l | tr -d ' '; sudo git -C $FLOWERS_BOX_REPO rev-list --count @{u}..HEAD 2>/dev/null || echo MISSING" 2>/dev/null)"
  FLW_DIRTY="$(printf '%s\n' "$FLW_PROBE" | sed -n '1p' | tr -d '\r\n ')"
  FLW_AHEAD="$(printf '%s\n' "$FLW_PROBE" | sed -n '2p' | tr -d '\r\n ')"
  if [ -z "$FLW_PROBE" ] || [ "$FLW_AHEAD" = "MISSING" ]; then
    : # box unreachable OR no upstream set — skip silently (phone-safe, never a wrap blocker)
  else
    if [ "${FLW_DIRTY:-0}" != "0" ]; then
      WARNS+=("G-T#46: flowers box repo ($FLOWERS_BOX_HOST:$FLOWERS_BOX_REPO) has UNCOMMITTED change(s) [$FLW_DIRTY] — commit+push on the box (sudo git add -A && sudo git commit && sudo git push)")
    fi
    if [ -n "$FLW_AHEAD" ] && [ "$FLW_AHEAD" != "0" ]; then
      WARNS+=("G-T#46b: flowers box repo ($FLOWERS_BOX_HOST:$FLOWERS_BOX_REPO) has $FLW_AHEAD UNPUSHED commit(s) — ssh $FLOWERS_BOX_HOST 'sudo git -C $FLOWERS_BOX_REPO push'")
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
# --- G-U · learning-harvest challenge (born 2026-06-25, Jason ruling: across 500+ handoffs, ZERO
#     ever truly found "nothing to add" -> a session that banks 0 lessons is almost certainly
#     UN-harvested, not clean. The empirical prior FLIPS the POV: finding nothing is near-impossible
#     and must be justified in writing. Deterministic nudge so the harvest stops depending on Jason
#     remembering to ask -- failure-now is cheaper than failure in a real project; learnings compound.
#     WARN-level (never blocks a hygiene-clean wrap); phone/web-safe skip if no blackbook.) ---
BB="$HOME/repos/claude-blackbook"
if [ -d "$BB/.git" ]; then
  # DJ-4.1 fix: the 6h window FALSE-0s a long (>6h) session whose lessons were committed early. Make
  # the window configurable (export SZ_GATE_HARVEST_WINDOW='12 hours ago' or your session-start) and add
  # a 24h secondary signal so a long, midnight-crossing session is not falsely told it harvested nothing.
  WINDOW="${SZ_GATE_HARVEST_WINDOW:-6 hours ago}"
  LCOUNT="$(git -C "$BB" log --since="$WINDOW" --oneline -- lessons/ 2>/dev/null | grep -c .)"
  LWIDE="$(git -C "$BB" log --since='24 hours ago' --oneline -- lessons/ 2>/dev/null | grep -c .)"
  bold "=== G-U · learning-harvest challenge (lessons banked: ${LCOUNT:-0} in [$WINDOW], ${LWIDE:-0} in 24h) ==="

  # --- G-U.2 · CONCURRENT-SESSION LEAF CHECK (born 2026-07-13, learned the hard way) ---
  # Jason runs PARALLEL cowork sessions and they all bank into the SAME tree. On 2026-07-13 a
  # session banked a leaf on "cheap models aren't worth it" while a CONCURRENT session had that
  # same day banked a far better one (5-day live A/B with hard data) — a FORKED TWIN, the exact
  # thing lessons.py warns against. Worse, the two DISAGREED on detail, and the wrong version had
  # already leaked into a live config. Two overlapping leaves drift, and the next Claude believes
  # whichever it greps first. So: SHOW today's leaves. If you didn't write one, READ IT before
  # you add yours — then defer + cross-link, or curate the ONE leaf.
  TODAY_LEAVES="$(ls -1 "$BB"/lessons/*/"$(date +%F)"-*.md 2>/dev/null)"
  if [ -n "$TODAY_LEAVES" ]; then
    printf '  \033[1mLeaves banked TODAY (yours AND any concurrent session'"'"'s):\033[0m\n'
    printf '%s\n' "$TODAY_LEAVES" | while read -r L; do
      CB=$(grep -m1 '^contributor:' "$L" 2>/dev/null | sed 's/contributor: *//')
      printf '    • %s  [by %s]\n' "$(basename "$L")" "${CB:-unknown}"
    done
    printf '  \033[1m^ Did you WRITE all of those?\033[0m If not, a concurrent session banked it — READ it.\n'
    printf '    Overlaps yours? DEFER to it + cross-link, or curate the ONE leaf. Never fork a twin.\n'
  fi
  if [ "${LCOUNT:-0}" -eq 0 ] && [ "${LWIDE:-0}" -eq 0 ]; then
    printf '  \033[1mZERO lessons banked this session.\033[0m Across 500+ handoffs, NOT ONE truly had nothing.\n'
    printf '  A 0 here is almost always an UN-harvested session, not a clean one. Harvest BEFORE you wrap:\n'
    WARNS+=("G-U: 0 lessons banked -- run the harvest; a genuine 'nothing' has never happened in 500+ handoffs and must be justified IN WRITING")
  elif [ "${LCOUNT:-0}" -eq 0 ]; then
    printf '  0 in [%s] but %s lesson(s) in the last 24h -- likely a LONG session (the 6h window false-0s). VERIFY the harvest landed (git -C ~/repos/claude-blackbook log -- lessons/); silence by exporting SZ_GATE_HARVEST_WINDOW to your session-start.\n' "$WINDOW" "$LWIDE"
  else
    printf '  %s lesson(s) banked recently -- harvest evidence present. Push further before you call it:\n' "$LCOUNT"
  fi
  cat <<'HARVEST'
    - >2 tool calls to learn a fact/trap/quirk?      -> a leaf NOW (atomic, verified, ground-truth).
    - a FAILURE MODE surfaced (even a small one)?    -> a leaf (failure-now is the cheap kind).
    - a META-lesson about the PROCESS or TOOLING?    -> the most valuable kind; bank it.
    - did you ADD a force-function/script/gate THIS pass (not just NOTE it)? that is the JOB.
    - CURATE: grep a unique phrase from EACH of today's leaves -- two adds with the same lead word
      SILENTLY clobber via lessons.py id-collision (see global leaf lessonspy-slug-collision).
HARVEST
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
  Any "not yet" is a BLOCKER: fix the doc gap before handing off. Full gate: ~/Desktop/downloads/HANDOFF-GATE.md (G-A->G-U).
  COWORK ONLY (interactive Jason session): if THIS session's milestone is CLEARED, emit NO handoff -- say 'cleared for takeoff' (the ABSENCE is the done-signal; a handoff means real work remains). HANDOFF-GATE G-F v2.23. Autonomous DJ sessions: always hand off.
TRIAD
  exit 0
else
  bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s) — fix before writing the handoff)"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
