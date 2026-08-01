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

# --- G-W · untracked-keeper sweep (born 2026-07-28: an audit found 105 of 117
#     HANDOFF-*/SESSION-*/BUGREPORT-*/EVIDENCE-* docs in the everything folder were
#     UNTRACKED -- a 90% miss rate on exactly the documents the suspension-bridge method
#     depends on, spanning six weeks. FIVE lessons had already been banked about the trap
#     and none stopped the sixth occurrence, because it fires at WRAP TIME when nobody is
#     searching the corpus for git advice.
#
#     WHY NO EXISTING CHECK CATCHES IT: the dirty/unpushed sweep above reasons about
#     TRACKED files. An IGNORED file is not "uncommitted work", so the gate says PASS --
#     correctly, and uselessly. G-S covers the same blind spot for gitignored CODE dirs;
#     this is its sibling for gitignored DOCS. A file that is gitignored is not a file
#     that is safe. ---
bold "=== G-W · untracked-keeper sweep (a keeper doc that git ignores is NOT backed) ==="
KEEPER_MISS=0
for repo in "${REPOS[@]}"; do
  [ -d "$repo/.git" ] || continue
  cd "$repo" 2>/dev/null || continue
  while IFS= read -r f; do
    [ -e "$f" ] || continue
    git ls-files --error-unmatch "$f" >/dev/null 2>&1 && continue     # tracked -> fine
    git check-ignore -q "$f" || continue                              # untracked+unignored -> the dirty sweep owns it
    # Deliberately ignored keepers are legal, but they must SAY SO: an allowlist-style
    # .gitignore should carry a comment naming the exclusion (e.g. a superseded chain).
    base="$(basename "$f")"
    if grep -qiE "superseded|deliberately|not vaulted|noise in a vault" .gitignore 2>/dev/null \
       && git check-ignore -v "$f" 2>/dev/null | grep -q '\*'; then
      [ "$QUIET" -eq 1 ] || printf '  ok     %-52s%s\n' "$base" "ignored by an explained glob"
      continue
    fi
    printf '  MISS   %-52s%s\n' "$base" "keeper doc is GITIGNORED -> never reaches the vault"
    FAILS+=("${repo/#$HOME/~}/$base: keeper doc is gitignored and unbacked -> allowlist it, then VERIFY with 'git ls-files --error-unmatch'")
    KEEPER_MISS=$((KEEPER_MISS+1))
  done < <(ls -1 HANDOFF-*.md SESSION-*.md BUGREPORT-*.md EVIDENCE-*.md 2>/dev/null)
done
[ "$KEEPER_MISS" -eq 0 ] && { [ "$QUIET" -eq 1 ] || echo "  (no unbacked keeper docs — every handoff/session note is in the vault)"; }
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
    if [ -n "$GH_LEDGER_HEAD" ] && [ -n "$BOX_LEDGER_HEAD" ] && [ "$BOX_LEDGER_HEAD" != "$GH_LEDGER_HEAD" ] && [ "$BOX_LEDGER_HEAD" != "MISSING" ]; then
      # v2.27 lag-aware (2026-07-24 root-cause of card 1216752373472909): the box ledger mirror is
      # an eventually-consistent CONSUMER — darwin pushes the vault hourly (:0x), the box pulls
      # */15 — so bare inequality has an inherent <=15-min false-positive window every single hour
      # ("reconverged by timing" IS the mechanism working). Only two failure modes are real:
      #   (a) DIVERGENCE — box HEAD is not an ancestor of gh HEAD (someone committed on the mirror);
      #   (b) WEDGED PULL — box is >2 vault commits (~>2h) behind (pull cron dead or ff-only stuck).
      if ! git -C "$SZ_GH_LEDGER_LOCAL" merge-base --is-ancestor "$BOX_LEDGER_HEAD" "$GH_LEDGER_HEAD" 2>/dev/null; then
        WARNS+=("G-T#43c: ledger runtime box ($SZ_BOX_HOST) HEAD ${BOX_LEDGER_HEAD:0:7} DIVERGED from gh ${GH_LEDGER_HEAD:0:7} (not an ancestor — a commit landed on the read-only mirror) — inspect: ssh $SZ_BOX_HOST 'git -C $SZ_BOX_LEDGER_REPO log --oneline -3; git -C $SZ_BOX_LEDGER_REPO status' then converge via sz-box-pull.sh (exit 8 = drift-orphan; see the DAY-1H leaf)")
      else
        LEDGER_BEHIND_N="$(git -C "$SZ_GH_LEDGER_LOCAL" rev-list --count "$BOX_LEDGER_HEAD".."$GH_LEDGER_HEAD" 2>/dev/null | tr -d '[:space:]')"
        if [ "${LEDGER_BEHIND_N:-999}" -gt 2 ] 2>/dev/null; then
          WARNS+=("G-T#43c: ledger runtime box ($SZ_BOX_HOST) WEDGED ${LEDGER_BEHIND_N} vault commits behind gh (>2 = pull not landing) — converge: ssh $SZ_BOX_HOST '$SZ_BOX_REPO/scripts/sz-box-pull.sh --quiet' (exit 8 = drift-orphan; see the DAY-1H leaf) and check the */15 cron log")
        fi
      fi
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


# ── G-W#2: toolchain canary (added 2026-07-27; RENAMED from G-W 2026-07-30) ─────
# The label was a COLLISION: "G-W" already names the untracked-keeper sweep ~290 lines
# above, so a failure message reading "G-W: ..." was ambiguous about which check fired --
# in a script whose entire job is telling a human precisely what is wrong. Renamed rather
# than renumbered so the untracked-keeper sweep keeps the label it has been printing.
# The lessons.py semantic ranker sat SILENTLY degraded to pure BM25 for weeks: it
# still "worked", just dumber, so nobody noticed. Root cause was interpreter drift —
# `python3 lessons.py` bypasses the shebang, and on darwin bash resolves python3 to
# Xcode's 3.9 (a stub that follows `xcode-select -p`, so it moves whenever Xcode
# updates) while zsh resolves it to Homebrew 3.14. lessons.py now re-execs into its
# own pinned venv; this check makes any future regression LOUD instead of quiet.
# A silent downgrade of a thinking tool is worse than a crash — you keep trusting it.
if [ -f "$HOME/repos/claude-blackbook/lessons.py" ]; then
  if ! python3 "$HOME/repos/claude-blackbook/lessons.py" --doctor >/dev/null 2>&1; then
    WARNS+=("G-W#2: lessons.py ranker is DEGRADED to pure BM25 (semantic backend down) — run: python3 ~/repos/claude-blackbook/lessons.py --doctor  (it prints the venv rebuild recipe)")
  fi
fi

# ── BRIDGE-BUG PLASTER (temporary, NOT a G-step — relabelled 2026-07-29 when the
#    canonical G-V was assigned to the AAR/RCA obligation) (added 2026-07-25, Jason ruling — cost ~8-10h misdiagnosed) ──
# The Cowork device bridge rotates its websocket ~every 27-33 min (anthropics/claude-code#81248);
# sessions see "MCP server disconnected" and have QUIT over it. While the bug is alive (rotating
# lines present in the app log), EVERY handoff must open with a step-0 BRIDGE-BUG ACK so no
# future session can miss it. Self-retiring: the block goes silent once a fresh main.log has no
# 'rotating' lines (bug fixed upstream) — then delete this section.
CLAUDE_APP_LOG="$HOME/Library/Logs/Claude/main.log"
if [ -f "$CLAUDE_APP_LOG" ] && grep -q '\[remote-tools-device\] rotating' "$CLAUDE_APP_LOG" 2>/dev/null; then
  bold "BRIDGE-BUG PLASTER: BRIDGE-ROTATION BUG STILL ALIVE (claude-code#81248) — plaster the handoff:"
  echo "  - the handoff prompt you emit MUST open with step-0 BRIDGE-BUG ACK: inheritor runs"
  echo "    ~/Scripts/bridge-status.sh and says in chat it is briefed (tools vanish ~every 27-33 min,"
  echo "    self-heals ~1s, NOT darwin, retry next turn; NEVER declare 'can't continue' over it)."
  echo "  - template: ~/repos/flowers-sms-concierge/HANDOFF.md step 0 · doctrine: lessons.py doctrine"
  echo "  - retire this check when 'rotating' vanishes from a fresh main.log."
  echo "  - (this block is NOT gate G-V; G-V is the AAR/RCA obligation below.)"
  echo ""
fi


# ── G-V · AAR/RCA obligation on completed Batter's Box cards (added 2026-07-29) ──
# HANDOFF-GATE.md §G-V. No card completes carrying an unmet AAR obligation: either
# "AAR: <slug>" (and it validates) or "NO-AAR: <20+ chars of reason>".
# TRI-STATE — exit 2 is CANNOT VERIFY and is NOT a pass. A check that cannot fail out
# loud is decoration; that is the entire lesson of the incident this gate commemorates.
AAR_PY="$HOME/repos/claude-blackbook/aar.py"
if [ ! -x "$AAR_PY" ]; then
  FAILS+=("G-V CANNOT VERIFY: $AAR_PY missing or not executable -- NOT a pass")
else
  AAR_OUT="$(python3 "$AAR_PY" gate --days 7 2>&1)"; AAR_RC=$?
  case "$AAR_RC" in
    0) : ;;  # pass, stay quiet
    1) bold "=== G-V · AAR/RCA obligation ==="
       echo "$AAR_OUT" | sed 's/^/  /'
       FAILS+=("G-V: a Batter's Box card was completed with no AAR link and no NO-AAR reason -- see above") ;;
    2) bold "=== G-V · AAR/RCA obligation ==="
       echo "$AAR_OUT" | sed 's/^/  /'
       FAILS+=("G-V CANNOT VERIFY: the AAR gate could not run (token/network). Exit 2 is NOT a pass") ;;
    *) FAILS+=("G-V: aar.py gate exited unexpectedly ($AAR_RC) -- treat as CANNOT VERIFY") ;;
  esac
  # anti-silence: the gate itself must have run recently. Only meaningful to report
  # separately when the run above did not already fail -- otherwise it just echoes it.
  if [ "$AAR_RC" -eq 0 ] && ! python3 "$AAR_PY" heartbeat --max-age-hours 36 >/dev/null 2>&1; then
    FAILS+=("G-V heartbeat stale: the AAR gate stopped running and nobody noticed")
  fi
fi

# ── G-V#2 · Asana single-page collection-read ratchet (added 2026-07-30) ─────────
# Enforces action A3 of AAR aar-gate-single-page-read (card 1217004329363570).
#
# WHY IT IS A GATE AND NOT JUST A LIBRARY: ~/Scripts/asana_client.py pages Asana to
# exhaustion, but a library is an OFFER. Nothing about its existence stops the next
# session from hand-rolling a fresh single-page urllib loop -- which is how this cause
# class recurred FIVE times, twice in code written by sessions that had already fixed it
# elsewhere. The AAR's actual complaint was "the readers that were right could not stop
# the one that was wrong." This is the thing that can stop it.
#
# WHY A RATCHET: 15 single-page reads exist today (all strike-zone). Wiring a red check
# over a debt nobody agreed to pay tonight would either fail every wrap or get the check
# disabled -- and a disabled gate is indistinguishable from a passing one. So the baseline
# pins what is known and the gate fails ONLY on a new offender. The baseline may only
# shrink; --update-baseline locks in each win.
#
# TRI-STATE, same contract as G-V above: a missing tool is CANNOT VERIFY, never a pass.
ASANA_LINT="$HOME/Scripts/asana-read-lint.py"
if [ ! -x "$ASANA_LINT" ]; then
  FAILS+=("G-V#2 CANNOT VERIFY: $ASANA_LINT missing or not executable -- NOT a pass")
else
  AL_OUT="$(/usr/bin/python3 "$ASANA_LINT" --ratchet 2>&1)"; AL_RC=$?
  case "$AL_RC" in
    0) : ;;  # no NEW single-page reads. Stay quiet; success is silent.
    1) bold "=== G-V#2 · Asana single-page collection-read ratchet ==="
       echo "$AL_OUT" | sed 's/^/  /'
       FAILS+=("G-V#2: a NEW single-page Asana collection read was added -- route it through ~/Scripts/asana_client.py or declare it '# ASANA-READ-OK: <reason>'") ;;
    2) bold "=== G-V#2 · Asana single-page collection-read ratchet ==="
       echo "$AL_OUT" | sed 's/^/  /'
       FAILS+=("G-V#2 CANNOT VERIFY: the read-lint walked ZERO files. Exit 2 is NOT a pass") ;;
    *) FAILS+=("G-V#2: asana-read-lint exited unexpectedly ($AL_RC) -- treat as CANNOT VERIFY") ;;
  esac
fi

# ── G-V#3 · card-lint stale-summary ratchet (added 2026-07-30, S27) ─────────────
# Builds step (b) of card 1216983787594801.
#
# THE RULE, AS A COMPUTATION: if artifact A references card B and B.completed_at is
# later than A's last modification, A has not been reconciled since B closed. A is
# describing a world that no longer exists and says so nowhere.
#
# WHY IT IS A GATE: FOUR consecutive sessions were handed a stale artifact (S23 sent
# after its work finished; S24 told to redo a card done the day before; S25 given a
# wrong seed.ts claim; S26 given a call-site count that hid a second fetch and shipped
# a live regression behind it). Every one was two timestamps nobody compared. It lints
# the HANDOFF DOCUMENTS as well as the cards, because the handoff is the artifact every
# session reads FIRST and its mtime is a stat(2) rather than an API call.
#
# WHY A RATCHET: 10 offenders existed the day it was written. A checker that goes red on
# day one gets disabled, and a disabled gate is indistinguishable from a passing one --
# this card said so itself. The baseline pins what is known and may only SHRINK; it also
# fails when a baseline entry is NO LONGER an offender, so a fix cannot quietly leave its
# excuse behind.
#
# TRI-STATE, same contract as G-V and G-V#2: a missing tool, an empty corpus, or a
# resolver that resolved nothing is CANNOT VERIFY -- never a pass.
CARD_LINT="$HOME/Scripts/card-lint.py"
if [ ! -x "$CARD_LINT" ]; then
  FAILS+=("G-V#3 CANNOT VERIFY: $CARD_LINT missing or not executable -- NOT a pass")
else
  CL_OUT="$(/usr/bin/python3 "$CARD_LINT" --ratchet 2>&1)"; CL_RC=$?
  case "$CL_RC" in
    0) : ;;  # no NEW stale references, nothing to retire. Success is silent.
    1) bold "=== G-V#3 · card-lint stale-summary ratchet ==="
       echo "$CL_OUT" | sed 's/^/  /'
       FAILS+=("G-V#3: a NEW stale reference appeared, or a baselined one is fixed and must be retired -- reconcile the artifact, or run card-lint.py --update-baseline") ;;
    2) bold "=== G-V#3 · card-lint stale-summary ratchet ==="
       echo "$CL_OUT" | sed 's/^/  /'
       FAILS+=("G-V#3 CANNOT VERIFY: card-lint inspected an empty corpus or resolved zero gids (no Asana token?). Exit 2 is NOT a pass") ;;
    *) FAILS+=("G-V#3: card-lint exited unexpectedly ($CL_RC) -- treat as CANNOT VERIFY") ;;
  esac
fi

[ "${#WARNS[@]}" -gt 0 ] && { bold "WARNINGS (${#WARNS[@]}) — not blocking, but worth a glance:"; printf '  - %s\n' "${WARNS[@]}"; }
# ── G-X · FDA grant canary (added 2026-07-31) ───────────────────────────────────
# A LaunchAgent wrapped in a scoped .app holds its Full Disk Access grant against the
# binary's CODE HASH. Rebuild/re-sign/move that app and macOS drops the grant with NO
# error: reads under ~/Desktop start returning "Operation not permitted", and because
# stat() still succeeds an `ls` prints a bare "total 0" -- indistinguishable from an
# EMPTY FOLDER. On 2026-07-31 a session nearly reported the Shopify statements as
# missing on exactly this. Silent-failure class -> it gets a gate.
FDA_CANARY="$HOME/Scripts/fda-canary.sh"
if [ -x "$FDA_CANARY" ]; then
  bold "=== G-X · FDA grant canary (scoped .app wrappers still hold their grant) ==="
  FDA_OUT="$("$FDA_CANARY" 2>&1)"; FDA_RC=$?
  printf '%s\n' "$FDA_OUT"
  case "$FDA_RC" in
    0) : ;;
    1) FAILS+=("G-X: an FDA-scoped app wrapper drifted from its baseline -- macOS has SILENTLY dropped Full Disk Access. Re-tick it in System Settings -> Privacy & Security -> Full Disk Access, then run ~/Scripts/fda-canary.sh --update-baseline") ;;
    2) FAILS+=("G-X CANNOT VERIFY: the FDA canary could not run (missing or empty registry). Exit 2 is NOT a pass") ;;
    *) FAILS+=("G-X: fda-canary.sh exited unexpectedly ($FDA_RC) -- treat as CANNOT VERIFY") ;;
  esac
else
  FAILS+=("G-X CANNOT VERIFY: $FDA_CANARY missing or not executable -- NOT a pass")
fi

# ── G-Y · relay bootstrap freshness (added 2026-08-01) ──────────────────────────
# Every handoff tells the next cloud session to bootstrap its off-bridge kit with
#   curl -s https://system.europeanflorist.com/dsh/dsh-fire -o /tmp/dsh-fire
# which serves a HAND-PLACED copy under /var/www/dsh-relay on the flowers box. Nothing
# kept it in step with ~/Scripts. On 2026-08-01 the `dsh -C` fix landed on darwin and
# the relay went on serving the OLD script -- so a fresh session would have bootstrapped
# the very bug we had just fixed, with no way to know. Same silent-drift class as G-X:
# the thing keeps answering, it just answers with yesterday.
DSH_PUBLISH="$HOME/Scripts/dsh-publish"
if [ -x "$DSH_PUBLISH" ]; then
  bold "=== G-Y · relay bootstrap freshness (the cloud curl serves what darwin has) ==="
  DP_OUT="$("$DSH_PUBLISH" --check 2>&1)"; DP_RC=$?
  printf '%s\n' "$DP_OUT"
  case "$DP_RC" in
    0) : ;;
    1) FAILS+=("G-Y: the dsh relay is STALE -- a fresh cloud session would bootstrap an OLD dsh-fire/dwait. Fix with ~/Scripts/dsh-publish") ;;
    2) FAILS+=("G-Y CANNOT VERIFY: the relay was unreachable or a local script is missing. Exit 2 is NOT a pass") ;;
    *) FAILS+=("G-Y: dsh-publish --check exited unexpectedly ($DP_RC) -- treat as CANNOT VERIFY") ;;
  esac
else
  FAILS+=("G-Y CANNOT VERIFY: $DSH_PUBLISH missing or not executable -- NOT a pass")
fi

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
  Any "not yet" is a BLOCKER: fix the doc gap before handing off. Full gate: ~/Desktop/downloads/HANDOFF-GATE.md (G-A->G-V).
  COWORK ONLY (interactive Jason session): if THIS session's milestone is CLEARED, emit NO handoff -- say 'cleared for takeoff' (the ABSENCE is the done-signal; a handoff means real work remains). HANDOFF-GATE §G-F (version printed below). Autonomous DJ sessions: always hand off.
TRIAD
  # Version is DERIVED from the canonical doc header, never hardcoded -- see
  # global lesson "a number copied into prose rots". Fourth instance was this very line.
  _gate_ver="$(grep -m1 -oE 'Version [0-9]+\.[0-9]+' "$CANON_GATE" 2>/dev/null || true)"
  echo "  gate version in force: ${_gate_ver:-UNKNOWN (could not read $CANON_GATE header)}"
  echo ""
  echo "  ── handoff-lint (write-side, report-only — added 2026-07-14) ──"
  "$HOME/Scripts/handoff-lint.sh" 2>/dev/null | sed 's/^/  /'
  echo "  (public-reachability of any cloud-facing endpoint: ~/Scripts/probe-public.sh <url>)"
  exit 0
else
  bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s) — fix before writing the handoff)"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
