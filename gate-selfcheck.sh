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

# CAPTURED AT LAUNCH, ON PURPOSE. The DoD block near the triad (search: "What this repo says
# DONE looks like") originally asked git for the repo at the moment it printed -- and by then
# this script has walked the whole estate and cwd is somewhere else entirely, so it silently
# printed nothing. A force function that does not fire is decoration; this one failed its own
# lesson on its first live run. The answer to "which repo did the human mean" is fixed the
# instant they typed the command, so capture it then.
GATE_START_REPO="$(git rev-parse --show-toplevel 2>/dev/null || true)"

ROOTS=("$HOME/repos" "$HOME/code" "$HOME/Desktop/downloads" "$HOME/Scripts" \
       "$HOME/Desktop/downloads/model-name-recon/repos")   # nest at depth 3 — past the maxdepth-2 walk (S44)
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

# -- A CHECK THAT NEVER RAN IS NOT A CHECK THAT PASSED ----------------------------------
# wealthTensor-109, AAR green-suite-hid-two-ship-blockers action A2.
#
# G-AI already refuses a step that vanishes with its INSTRUMENT. This is the sibling class
# it cannot see: a step that vanishes because an UPSTREAM BRANCH took another path, with
# every guard properly else-ed. The measured case: at -108 this gate ran without
# GATE_ROSTER_WHO, so G-AL printed `WARN CANNOT VERIFY: no current session tag` and
# returned -- and G-AL#board, which lives INSIDE G-AL's success branch and is a hard
# blocker, never ran at all. Nothing said so. The gate reported PASS while
# docs/CHECKLIST.md was stale over two ship-blocking defects, both of which the board
# surfaced four minutes later when the gate was re-run with the variable set.
#
# So an upstream CANNOT VERIFY now has to NAME the downstream checks it just silenced, and
# the verdict cannot read PASS while any of them is unrun. This is deliberately NOT a FAIL
# of the downstream check: nobody knows what that check would have said, and asserting it
# failed would be the same lie pointing the other way. It is a refusal to certify a run
# that did not happen -- which is what a gate is for.
SKIPPED=()
gate_skipped() {   # gate_skipped <downstream step> <why it could not run, and the remedy>
  SKIPPED+=("$1 NEVER RAN: $2")
  printf '  !      %s did not run -- %s\n' "$1" "$2"
}

# THE VERDICT PREDICATE IS A NAMED FUNCTION so that gate-skipped-drill.sh can extract and
# execute THIS text rather than a copy of it. A drill that reimplements the rule it checks
# goes on passing forever on the day the rule changes -- the copied-not-derived family,
# which this file has already caught in itself twice.
gate_verdict_is_pass() { [ "${#FAILS[@]}" -eq 0 ] && [ "${#SKIPPED[@]}" -eq 0 ]; }

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

# -- G-H concurrency: a sibling session's work-in-flight is not YOUR dirty repo ---------
# Multi-session on darwin has been supported since S35, and G-H was written before it: it FAILs
# on ANY dirty repo under the roots, including one a CONCURRENT session claimed ten minutes ago
# and is still editing. That is a blocker a wrapping session cannot legitimately clear -- and the
# only ways to clear it are to commit somebody else's half-finished work or to lie. A control
# whose only exits are vandalism or dishonesty gets ignored, which costs more than it saves.
#
# So: a DIRTY repo covered by a LIVE roster claim belonging to SOMEONE ELSE becomes a WARN that
# names the claimant. UNPUSHED stays a FAIL -- pushing a sibling's finished commit is safe (git
# refuses non-ff), and unpushed work sitting for weeks is the failure Jason actually got bitten by.
#
# Fail-closed by design -- but READ THE FUNCTION, NOT THIS PARAGRAPH, because this paragraph
# described the opposite behaviour for three days. It used to say "without GATE_ROSTER_WHO
# nothing is ever downgraded, so the default is byte-identical to before". That stopped being
# true on 2026-08-12 (1979d80, floristAlix-1): an unknown identity now makes the check MORE
# cautious, reporting EVERY live claim, because with no identity we cannot prove a claim is
# someone else's. The comment was not updated, and neither was gate-roster-drill.sh, whose
# assertion #1 asserted this stale sentence and had been failing ever since -- unnoticed,
# because nothing ran the drill. Corrected 2026-08-15 by opus-acmeLedger-21, along with the
# drill, which the gate now RUNS (see the G-H#drill step below) so the next such divergence
# announces itself instead of waiting for someone to run it by hand.
# A claim by your OWN name never downgrades anything -- otherwise a session could exempt
# itself by claiming its own repo -- but that self-exemption needs an identity to apply.
# ROSTER_DB is honoured (same env var roster itself uses) so this is drillable, not production-only.
_ROSTER_DB="${ROSTER_DB:-$HOME/.local/state/darlish/roster.sqlite3}"
_roster_other_claimant() {   # <repo-path> -> claimant name, or empty
  # FAIL SAFE, NOT OPEN (fixed 2026-08-12, floristAlix-1).
  #
  # This used to begin `[ -n "${GATE_ROSTER_WHO:-}" ] || return 0` -- i.e. the entire
  # sibling-protection silently DISABLED itself whenever the caller had not exported
  # GATE_ROSTER_WHO. Which is exactly the session that needs it: one that has not been
  # careful about roster hygiene. Hit live on 2026-08-12 -- wealth-tensor came back a
  # hard FAIL while big-wealthTensor-12 held a live claim and had written the file 60
  # SECONDS earlier. The remedy a FAIL prescribes is "commit it before writing the
  # handoff", so the gate was one obedient step away from committing another session's
  # half-written paragraph.
  #
  # Now: an UNKNOWN identity makes this MORE cautious, never less. With no identity we
  # cannot prove a claim is someone else's -- so we report every live claim and let the
  # human decide, rather than pretending there are none.
  [ -f "$_ROSTER_DB" ] || return 0
  command -v sqlite3 >/dev/null 2>&1 || return 0
  _rc_base="$(basename "$1")"
  _rc_selfclause=""
  if [ -n "${GATE_ROSTER_WHO:-}" ]; then
    _rc_selfclause="AND who <> '$(printf '%s' "$GATE_ROSTER_WHO" | sed "s/'/''/g")'"
  fi
  sqlite3 "$_ROSTER_DB" \
    "SELECT who FROM roster WHERE kind='claim' AND expires > strftime('%s','now')
       $_rc_selfclause
       AND (resource='$(printf '%s' "$_rc_base" | sed "s/'/''/g")'
            OR resource='$(printf '%s' "$1" | sed "s/'/''/g")')
     LIMIT 1;" 2>/dev/null
}

# ── G-H#drill · the sibling-downgrade control must still be a control (2026-08-15) ──
# _roster_other_claimant() turns a FAIL into a WARN -- the most dangerous direction a check
# can move -- and it cannot be exercised in production, so gate-roster-drill.sh exists to
# exercise it offline. Nothing ran it. Its assertion #1 was invalidated by the 2026-08-12
# fail-open fix and it sat red for three days in total silence, which is the same defect as
# a green light that never goes red: an instrument nobody reads. Now the gate reads it.
# The drill EXTRACTS the function from this file at run time, so it also catches the function
# being renamed or moved out from under it.
_RD="$HOME/code/darwin-mac-ops/gate-roster-drill.sh"
if [ -x "$_RD" ]; then
  bold "=== G-H#drill · roster downgrade control (offline drill) ==="
  _RD_OUT="$("$_RD" 2>&1)"; _RD_RC=$?
  printf '%s\n' "$_RD_OUT" | tail -3
  case "$_RD_RC" in
    0) : ;;
    2) FAILS+=("G-H#drill CANNOT VERIFY: gate-roster-drill.sh could not run (sqlite3 missing?). Exit 2 is NOT a pass") ;;
    *) FAILS+=("G-H#drill: the sibling-downgrade control FAILED its own drill -- G-H's DIRTY->WARN downgrade is not behaving as specified. Run: bash $_RD") ;;
  esac
else
  WARNS+=("G-H#drill: $_RD missing or not executable -- the sibling-downgrade control is unproven this run")
fi

# ── G-H#roster · the OTHER two roster drills, which were also notes (2026-08-15, acmeLedger-22) ──
# acmeLedger-21's finding was "a drill that is not in a gate is a note, not a control", and it
# wired the one drill it had just repaired. Reading the same sentence against the rest of the
# estate: roster-ghost-drill.sh and roster-identity-drill.sh were never wired either, so the
# board's ghost and identity behaviour was proven only by whoever remembered to type it -- and
# the handoff's verify block IS that remembering, which means the proof lived in a document
# rather than in a run. Both are hermetic (scratch ROSTER_DB, live board never opened) and take
# well under a second, so there was never a cost argument for leaving them out.
for _rdrill in "$HOME/Scripts/roster-ghost-drill.sh" "$HOME/Scripts/roster-identity-drill.sh"; do
  _rdname="$(basename "$_rdrill")"
  if [ -x "$_rdrill" ]; then
    bold "=== G-H#roster · $_rdname (offline, scratch db) ==="
    _RG_OUT="$(bash "$_rdrill" 2>&1)"; _RG_RC=$?
    printf '%s\n' "$_RG_OUT" | tail -1 | sed 's/^/  /'
    case "$_RG_RC" in
      0) : ;;
      9) WARNS+=("G-H#roster: $_rdname could not find its subject (exit 9) -- unproven this run") ;;
      *) FAILS+=("G-H#roster: $_rdname FAILED (rc=$_RG_RC) -- the roster's ghost/identity behaviour is not what the board's readers assume. Run: bash $_rdrill") ;;
    esac
  else
    WARNS+=("G-H#roster: $_rdrill missing or not executable -- that roster control is unproven this run")
  fi
done

# G-H #22c (acmeLedger-25, 2026-08-15) — ATTRIBUTION BY NAME, when no repo claim covers it.
# #22b attributes dirt by roster CLAIM on the repo. That misses the commonest multi-session
# case there is: a sibling drops HANDOFF-<theirSlug>-N.md into the everything folder, which
# nobody claims because nobody edits "the downloads repo" as a unit. Measured 2026-08-15:
# opus-pitchingMachine-2's untracked HANDOFF-pitchingMachine-2.md was the ONLY thing standing
# between a clean estate and a PASS, and the two exits G-H's own header warns about were back:
# commit a sibling's unfinished handoff, or lie. So: if EVERY dirty path in a repo carries a
# LIVE sibling's session slug in its basename, downgrade to WARN naming them.
# Deliberately narrow, and fail-closed in both directions -- ONE unattributable path and the
# whole repo stays a FAIL, so this can never launder your own mess in with theirs.
_paths_owned_by_sibling() {   # <repo-path> <porcelain> -> claimant name, or empty
  [ -f "$_ROSTER_DB" ] || return 0
  command -v sqlite3 >/dev/null 2>&1 || return 0
  local _slugs _who _p _st _hit _found="" _line
  # session rows only: a slug is 'opus-pitchingMachine-2' and the file says 'pitchingMachine-2',
  # so strip the tier prefix. Skip our own identity and slugs too short to be evidence.
  _slugs="$(sqlite3 "$_ROSTER_DB" \
     "SELECT who FROM roster WHERE kind='session' AND expires > strftime('%s','now');" 2>/dev/null)"
  [ -n "$_slugs" ] || return 0
  while IFS= read -r _line; do
    [ -n "$_line" ] || continue
    _p="${_line:3}"; _p="${_p##* -> }"; _p="${_p%\"}"; _p="${_p#\"}"
    _p="$(basename "$_p")"
    _hit=""
    while IFS= read -r _who; do
      [ -n "$_who" ] || continue
      [ "$_who" = "${GATE_ROSTER_WHO:-}" ] && continue
      _slug="${_who#*-}"                      # opus-pitchingMachine-2 -> pitchingMachine-2
      [ "${#_slug}" -ge 8 ] || continue        # too short to be evidence of anything
      case "$_p" in *"$_slug"*) _hit="$_who"; break ;; esac
    done <<EOF_SLUGS
$_slugs
EOF_SLUGS
    [ -n "$_hit" ] || return 0                 # one unattributable path => attribute nothing
    _found="$_hit"
  done <<EOF_DIRT
$2
EOF_DIRT
  printf '%s' "$_found"
}

bold "=== G-H #22 · repo hygiene sweep (${#REPOS[@]} repos across ${#ROOTS[@]} roots) ==="
for repo in "${REPOS[@]}"; do
  cd "$repo" || continue
  name="${repo/#$HOME/~}"
  [ "$DO_FETCH" -eq 1 ] && git fetch --quiet 2>/dev/null
  # G-H#stat (carded by acmeLedger-28, landed by acmeLedger-30). `git status` decides a file
  # is modified from STAT DATA -- mtime, size, inode -- before it ever compares content, so a
  # file that was merely TOUCHED reports ` M` while `git diff` finds nothing at all. This gate
  # runs scripts out of these very repos, so it touches its own. Refreshing the index first
  # reconciles the two. The `|| true` is load-bearing: update-index --refresh exits NON-ZERO
  # when it finds genuinely modified files, which is the normal case for a repo with real work
  # in it, and letting that escape would turn this fix into a worse bug than the one it repairs.
  # Why bother over a phantom: a control that cries wolf gets waved through, and a gate that
  # fails on a file nobody edited trains the next session to wave through a real failure.
  git update-index --refresh >/dev/null 2>&1 || true
  dirty="$(git status --porcelain 2>/dev/null)"
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
  has_remote=0; [ -n "$(git remote 2>/dev/null)" ] && has_remote=1
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    ahead="$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)"; tracking="ok"
  else
    ahead=0; tracking="none"
  fi

  flags=""; level="ok"
  # Hoisted out of the DIRTY branch by acmeLedger-30: the UNPUSHED branch below needs the
  # same answer, and a repo can be perfectly clean while a sibling holds unpushed commits.
  _claimant="$(_roster_other_claimant "$repo")"
  if [ -n "$dirty" ]; then
    nd="$(printf '%s\n' "$dirty" | grep -c .)"
    if [ -n "$_claimant" ]; then
      flags="$flags DIRTY($nd,claimed:$_claimant)"
      if [ -n "${GATE_ROSTER_WHO:-}" ]; then
        WARNS+=("$name: $nd uncommitted change(s) — LIVE roster claim by '$_claimant', i.e. ANOTHER session's work in flight. Do NOT commit it. Verify: ~/Scripts/roster who")
      else
        WARNS+=("$name: $nd uncommitted change(s) — LIVE roster claim by '$_claimant', and THIS session did not export GATE_ROSTER_WHO so I cannot tell whether that is you. If it is you, commit it; if it is not, DO NOT — it is another session's work in flight. Verify: ~/Scripts/roster who")
      fi
      [ "$level" = ok ] && level="WARN"
    else
      _owner="$(_paths_owned_by_sibling "$repo" "$dirty")"
      if [ -n "$_owner" ]; then
        flags="$flags DIRTY($nd,named:$_owner)"
        WARNS+=("$name: $nd uncommitted change(s) — every path names LIVE session '$_owner' (G-H#22c attribution by filename, no repo claim covers it). Do NOT commit it. Verify: ~/Scripts/roster who")
        [ "$level" = ok ] && level="WARN"
      else
        _paths="$(printf '%s\n' "$dirty" | head -6 | sed 's/^/    /')"
        [ "$nd" -gt 6 ] && _paths="$_paths
    ... and $((nd - 6)) more"
        flags="$flags DIRTY($nd)"
        FAILS+=("$name: $nd uncommitted change(s) — no live roster claim covers this repo and G-H#22c could not attribute every path by filename, so it is being reported as YOURS. If it is not, the sibling owes a \`roster claim\`:
$_paths")
        level="FAIL"
      fi
    fi
  fi
  if [ "$ahead" -gt 0 ]; then
    # G-H#22d (acmeLedger-30) — the SAME reasoning the DIRTY branch has carried since S40,
    # applied to UNPUSHED commits, where it never was. Since S35 several sessions routinely
    # share darwin, and a sibling mid-flight normally HAS local commits it has not pushed:
    # it pushes at ITS wrap, not at mine. So every parallel session's gate failed on a
    # sibling's work in progress, and a gate that fails on something you must not touch is a
    # gate that gets waved through. The downgrade is safe for exactly one reason: a roster
    # claim is LEASED and expires, so a LIVE claim means minutes -- not the weeks of unpushed
    # work Jason actually got bitten by, which is what this check exists for. Same predicate
    # as the dirty branch, so gate-roster-drill.sh's control already covers the lookup; that
    # drill now also asserts that BOTH branches consult it, which is the part a unit test of
    # the function alone can never see.
    if [ -n "$_claimant" ]; then
      flags="$flags UNPUSHED($ahead,claimed:$_claimant)"
      if [ -n "${GATE_ROSTER_WHO:-}" ]; then
        WARNS+=("$name: $ahead unpushed commit(s) on $branch — LIVE roster claim by '$_claimant', i.e. ANOTHER session's work in flight. It pushes at ITS wrap, not at yours. Do NOT push it. Verify: ~/Scripts/roster who")
      else
        WARNS+=("$name: $ahead unpushed commit(s) on $branch — LIVE roster claim by '$_claimant', and THIS session did not export GATE_ROSTER_WHO so I cannot tell whether that is you. If it is you, push it; if it is not, DO NOT. Verify: ~/Scripts/roster who")
      fi
      [ "$level" = ok ] && level="WARN"
    else
      flags="$flags UNPUSHED($ahead)"; FAILS+=("$name: $ahead unpushed commit(s) on $branch"); level="FAIL"
    fi
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

  # G-H #22b (S40) - ATTRIBUTION, not absolution. A dirty repo is still a BLOCKER; this
  # only says WHOSE. Since S35 several sessions routinely share darwin, and "1 uncommitted
  # change" reads identically whether you left it or a sibling is mid-edit -- and the right
  # response is opposite (commit it / hands off, never commit someone's untested WIP).
  if [ -n "$dirty" ]; then
    _now="$(date +%s)"
    while IFS= read -r _line; do
      [ -n "$_line" ] || continue
      _st="${_line:0:2}"; _p="${_line:3}"
      _p="${_p##* -> }"                       # renames: report the destination
      _p="${_p%\"}"; _p="${_p#\"}"             # git quotes paths with odd characters
      _mt="$(stat -f %m "$_p" 2>/dev/null || echo 0)"
      _when="$(stat -f '%Sm' -t '%H:%M' "$_p" 2>/dev/null || echo '--:--')"
      _tag=""
      [ "$_mt" -gt 0 ] && [ $((_now - _mt)) -lt 1200 ] \
        && _tag="   <-- touched <20min ago: a SIBLING session may own this (~/Scripts/roster who)"
      printf '          %s %s  (mtime %s)%s\n' "$_st" "$_p" "$_when" "$_tag"
    done < <(printf '%s\n' "$dirty")
  fi
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

# --- G-Z · TODO-rider sweep (born 2026-08-03, backstop ADR-004, RATIFIED by Jason: the
#     darlish deployment-shape item rode THREE handoffs; TODO-drift-check.md rode two.
#     Every ride re-derives context and defers again — pure carrying cost. THE RULE:
#     a TODO may ride at most ONE handoff.
#
#     THE COMPUTATION: this gate runs at wrap time, i.e. just before handoff N. The most
#     recent commit touching a HANDOFF* doc in the repo IS handoff N-1. A tracked
#     TODO-*.md whose last commit predates that has already ridden once and is about to
#     ride AGAIN -> BLOCKER. Untracked TODOs are the dirty sweep's problem; repos with no
#     handoff tradition are out of scope.
#
#     THE ESCAPE HATCH is mechanical and self-documenting: to legitimately ride again,
#     write WHY into the TODO file and commit it — the touch resets its ride clock, and
#     the justification lives in the file where the next session reads it. (Ratified as
#     "G-W" in ADR-004; ships as G-Z because G-W already names FOUR other things — see
#     the G-W#2 rename scar above. Fifth collision declined.) ---
bold "=== G-Z · TODO-rider sweep (a TODO may ride at most ONE handoff — ADR-004) ==="
RIDERS=0
for repo in "${REPOS[@]}"; do
  cd "$repo" 2>/dev/null || continue
  HOFF_TS="$(git log -1 --format=%ct -- 'HANDOFF*.md' '*/HANDOFF*.md' 2>/dev/null)"
  [ -n "$HOFF_TS" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    TODO_TS="$(git log -1 --format=%ct -- "$f" 2>/dev/null)"
    [ -n "$TODO_TS" ] || continue                                   # tracked-but-never-committed: dirty sweep owns it
    if [ "$TODO_TS" -lt "$HOFF_TS" ]; then
      printf '  RIDER  %-52s%s\n' "${repo/#$HOME/~}/$f" "untouched since before the last handoff"
      FAILS+=("G-Z: ${repo/#$HOME/~}/$f is RIDING — resolve as (a) DONE (delete it), (b) scheduled work (n8n / Batter's Box card, then delete it), or (c) a RULING that kills it; to ride ONE more time, write WHY into the file and commit (the touch resets its clock)")
      RIDERS=$((RIDERS+1))
    fi
  done < <(git ls-files 'TODO-*.md' '*/TODO-*.md' 2>/dev/null)
done
[ "$RIDERS" -eq 0 ] && { [ "$QUIET" -eq 1 ] || echo "  (no riding TODOs — every TODO-*.md is younger than its repo's last handoff)"; }
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
# The needle itself now lives in ONE place, shared with the pre-commit hook that
# REFUSES these strings at commit time (S45 2026-08-08). Before the split, G-E was
# the estate's only secret control and it ran at WRAP -- by which point the object
# is already in the repo, and in every clone of it. Two readers, one regex, so
# detect-at-wrap and refuse-at-commit can never disagree about what a secret is.
SECRET_LIB="${ESTATE_SECRET_LIB:-$HOME/code/darwin-mac-ops/hooks/secret-re.sh}"
if [ ! -f "$SECRET_LIB" ]; then
  echo "gate-selfcheck: FATAL — secret regex SSOT missing: $SECRET_LIB" >&2
  echo "  Failing CLOSED: a gate that cannot load its own needle must not report PASS." >&2
  echo "  Fix: git -C ~/code/darwin-mac-ops checkout -- hooks/secret-re.sh" >&2
  exit 2
fi
. "$SECRET_LIB"          # -> SECRET_RE, GE_ALLOW, ge_load_allow, ge_allowed, ge_mask
ge_load_allow
SECCOUNT=0
i=0
while [ "$i" -lt "$GE_NOREASON" ]; do
  WARNS+=("G-E: ALLOW-NOREASON '${GE_NOREASON_PATS[$i]}' in $GE_ALLOW — an exemption nobody justified is indistinguishable from an oversight; add '# why' or delete the line")
  i=$((i+1))
done
for repo in "${REPOS[@]}"; do
  cd "$repo" || continue
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ge_allowed "$(basename "$repo")/$(printf '%s' "$line" | cut -d: -f1)"; then
      GE_SUPPRESSED=$((GE_SUPPRESSED+1)); continue
    fi
    [ "$SECCOUNT" -eq 0 ] && bold "=== G-E · secret sweep (tracked files) ==="
    # Show file:line + the ACTUAL matched token (prefix kept, high-entropy tail MASKED) — NOT
    # cut -c1-90 of the raw line: that truncation can DISPLAY a leading jsCode // comment while
    # HIDING the real secret deeper on the same line. On 2026-07-07 it disguised real hardcoded
    # shpat_ tokens in COGS jsCode as benign "// 7:30" comments, and a teed-up "just skip jsCode
    # comment lines" would have MASKED live secrets. Masking the tail keeps the sweep from leaking
    # the credential into logs while still proving it IS a token, not a comment.
    floc=$(printf '%s' "$line" | cut -d: -f1-2)
    tok="$(ge_mask "$line")"
    printf '    %s: %s  [match: %s]\n' "${repo/#$HOME/~}" "$floc" "$tok"; SECCOUNT=$((SECCOUNT+1))
  done < <(git grep -nIE "$SECRET_RE" 2>/dev/null)
done
[ "$SECCOUNT" -gt 0 ] && WARNS+=("G-E: $SECCOUNT possible SECRET(s) in tracked files (see list above) — if real, scrub from HEAD, ROTATE the credential, and never commit it")
# Suppression is never silent — a reader has to be able to see what the allowlist ate.
[ "$GE_SUPPRESSED" -gt 0 ] && printf '    G-E: %s hit(s) suppressed by %s allowlist rule(s) in %s (review it when a repo changes hands)\n' "$GE_SUPPRESSED" "${#GE_PATS[@]}" "${GE_ALLOW/#$HOME/~}"

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
  # --- G-L#35c · the header version must have a changelog entry (born 2026-08-15,
  #     stateMachineRename-1). The gate's own standing rule is "header version and this entry
  #     bumped in the SAME edit", and the file that states it keeps breaking it: v2.29's entry
  #     fixed it once, v2.31 backfilled two more, v2.34 counted FOUR, v2.43 was backfilled by
  #     S39 (found only while writing v2.44), and v2.55 shipped 06ba490 with a header bump and
  #     a whole new G-AI.2 section and no entry at all (backfilled today). That is six.
  #
  #     The part that matters more than the count: v2.34's own changelog entry, on 2026-07-30,
  #     diagnosed this exactly right -- "by the estate's own N>2 rule the instrument is wrong;
  #     it already derives the max G-step letter for G-L#35b, so it is ONE GREP AWAY from also
  #     asserting the header version has a changelog line" -- and then EJECTED IT AS A CARD.
  #     The card sat for sixteen days and the sixth instance happened anyway. When the fix is
  #     smaller than the card that describes it, carding it is the slower path. This is that
  #     one grep, finally written, and it is DERIVED from the file so it cannot itself rot.
  #     Deliberately only the CURRENT version: checking every historical version would need
  #     the header's git history and would fire on pre-rule entries, which is how a check
  #     earns itself a mute.
  _hv="$(grep -m1 -oE 'Version [0-9]+\.[0-9]+' "$CANON_GATE" 2>/dev/null | sed 's/Version //')"
  if [ -z "$_hv" ]; then
    FAILS+=("G-L#35c CANNOT VERIFY: could not read a 'Version X.YY' line from ${CANON_GATE/#$HOME/~} header, so the changelog-entry check ran against nothing.")
  elif ! grep -qE "^- v${_hv//./\\.} " "$CANON_GATE"; then
    FAILS+=("G-L#35c: HANDOFF-GATE header says v$_hv but the Changelog has no '- v$_hv' entry — the 'header version and this entry bumped in the SAME edit' rule slipped — it has slipped six times before (v2.29, v2.31 x2, v2.43, v2.55), which is why this check exists. Write the entry NOW, while you still remember what changed; a backfilled entry is always thinner than the one you'd have written today.")
  fi

  # G-L#35c#drill · the control for the four lines above. Wired, not left to be remembered:
  # gate-roster-drill.sh had been failing since 2026-08-12 with nobody noticing precisely
  # because no gate ran it (v2.52). And this drill's FIRST cut stopped controlling ninety
  # seconds after it was written -- it hardcoded the version into its sed, the next bump made
  # the sed a no-op, and its "positive control" cheerfully passed an unmodified file. Every
  # control in it now DERIVES the version, and C5 asserts gate-selfcheck.sh still contains the
  # block the drill claims to be controlling.
  CL_DRILL="${CL_DRILL:-$HOME/code/darwin-mac-ops/gate-changelog-drill.sh}"
  if [ -x "$CL_DRILL" ]; then
    _cl_out="$(bash "$CL_DRILL" 2>&1)"; _cl_rc=$?
    case "$_cl_rc" in
      0) : ;;  # silent on success, house style -- G-L#35c itself speaks if the gate doc is wrong
      1) printf '%s\n' "$_cl_out" | sed 's/^/         /'
         FAILS+=("G-L#35c#drill: a control failed, so the header/changelog check cannot be trusted this run. Run: bash ~/code/darwin-mac-ops/gate-changelog-drill.sh") ;;
      2) printf '%s\n' "$_cl_out" | sed 's/^/         /'
         FAILS+=("G-L#35c#drill CANNOT VERIFY: the drill could not read the gate doc. Exit 2 is NOT a pass.") ;;
      *) FAILS+=("G-L#35c#drill: exited unexpectedly ($_cl_rc) -- treat as CANNOT VERIFY") ;;
    esac
  else
    bold "=== G-L#35c#drill · control for the header/changelog check ==="
    printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- the changelog check ran uncontrolled\n' "${CL_DRILL/#$HOME/~}"
    FAILS+=("G-L#35c#drill CANNOT VERIFY: $CL_DRILL is missing or not executable, so nothing proved the header/changelog check can still go red. Restore it: git -C ~/code/darwin-mac-ops checkout -- gate-changelog-drill.sh")
  fi
else
  # acmeLedger-24: this guard had no else, so a MISSING canonical gate doc — the strictly
  # worse state than a stale mirror — was the one condition this block stayed silent for.
  # It is also the input to MAXG, the version derivation and the range-drift detector
  # below, all of which then quietly degrade. Loud, once, here.
  bold "=== HANDOFF-GATE canonical doc ==="
  printf '  FAIL   CANNOT VERIFY: %s is missing -- no mirror-freshness, version or range check ran\n' "${CANON_GATE/#$HOME/~}"
  FAILS+=("HANDOFF-GATE CANNOT VERIFY: the canonical gate doc $CANON_GATE is missing, so the mirror-freshness check, the gate-version derivation and the G-L#35b range-drift detector all had nothing to read. Restore it: git -C ~/Desktop/downloads checkout -- HANDOFF-GATE.md")
fi

# --- G-L#35b · gate range-ref drift (born 2026-06-25 P0 audit: "G-A..R/P" range statements rot in
#     front doors after new steps (G-S/G-T) get added, because the range is COPIED not DERIVED.
#     Derive the live max G-step from the canonical gate, WARN any stale front-door range ref.
#     The gate's OWN changelog is excluded (it cites historical ranges by design). ---
# TWO-LETTER STEPS BROKE THIS BOTH WAYS (fixed 2026-08-05, S2 wealth-tensor). When G-AA and
# G-AB were added in v2.38/v2.40 the detector kept comparing SINGLE letters: `^## G-[A-Z]`
# matched "G-AB" as "G-A", so MAXG came out Z instead of AB and the gate's true ceiling was
# understated; and `endp` took the last uppercase letter of a range string, so a CORRECT
# reference to "G-A→G-AA" scored endp=A and fired a warning reading "cites 'G-A..A'". The
# check that exists to stop range statements rotting was itself rotting, and crying wolf while
# it did -- and a warning that cries wolf is a warning everyone learns to scroll past.
# Both ends now use gstep_rank(): letters -> a number, so AB(28) > Z(26) orders correctly.
gstep_rank() {  # G-step id (A..Z, AA..ZZ) -> ordinal. Empty input -> 0.
  local id="$1" n=0 i c
  [ -n "$id" ] || { echo 0; return; }
  for (( i=0; i<${#id}; i++ )); do
    c="${id:$i:1}"
    n=$(( n * 26 + $(LC_ALL=C printf '%d' "'$c") - 64 ))
  done
  echo "$n"
}
# VANISH-OK: the identical `-f $CANON_GATE` condition now FAILs loudly ~30 lines above, and
# a missing MAXG is reported again at the triad ("G-A->? (could not read ...)"). A second
# CANNOT VERIFY here would be the same news told three times.
if [ -f "$CANON_GATE" ]; then
  MAXG=""; MAXR=0
  while IFS= read -r g; do
    r=$(gstep_rank "$g"); [ "$r" -gt "$MAXR" ] && { MAXR=$r; MAXG=$g; }
  done < <(grep -oE '^## G-[A-Z]{1,2}\b' "$CANON_GATE" | sed 's/.*G-//')
  if [ -n "$MAXG" ]; then
    # Scope grew from four to SIX on 2026-08-15 (stateMachineRename-1). AGENTS.md -- the
    # Codex-facing twin of CLAUDE.md, same doctrine, different reader -- was never in the list
    # and had rotted to "G-A→G-U", TWENTY-FOUR letters stale, while its sibling one file over
    # was kept current by this very check. It was invisible to the drift detector for the same
    # reason it was invisible to git (no allowlist line, fixed in the same pass): nobody had
    # written its name down anywhere. STANDING-BRIEF-CURRENT.md joins for the same reason, and
    # it is the harder case to argue away -- it hedges with "the version moves; trust the file,
    # not this line", and it was still four letters stale. A hedge is not a detector.
    for RF in "$CANON_GATE" "$HOME/repos/claude-blackbook/lessons.py" "$HOME/Desktop/downloads/CLAUDE.md" "$HOME/Desktop/downloads/AGENTS.md" "$HOME/Desktop/downloads/STANDING-BRIEF-CURRENT.md" "$HOME/repos/strike-zone/docs/HANDOFF-PROMPT.md"; do
      # A named front door that is GONE used to `continue` in silence -- the vanishing-instrument
      # class (G-AI) applied to the subject rather than the tool. Say so instead.
      if [ ! -f "$RF" ]; then
        FAILS+=("gate range-ref drift CANNOT VERIFY: named front door ${RF/#$HOME/~} is missing, so its range statement was not checked. A door that is not there cannot be certified honest.")
        continue
      fi
      if [ "$RF" = "$CANON_GATE" ]; then CONTENT=$(awk '/^## Changelog/{exit} {print}' "$RF"); else CONTENT=$(cat "$RF"); fi
      while IFS= read -r m; do
        # The END of the range is whatever follows the SEPARATOR -- not the last letter (which
        # broke on two-letter steps) and not the last "G-xx" token either, because the common
        # written form "G-A..Z" leaves the endpoint unprefixed, so a G--anchored search finds
        # "G-A" and reports the START as the end. Strip through the separator instead.
        endp=$(printf '%s' "$m" | sed -E 's/.*(\.\.|->|→|through)+ *(G-)?//' | tr -d ' ')
        if [ -n "$endp" ] && [ "$(gstep_rank "$endp")" -lt "$MAXR" ]; then
          # BLOCKER, not a warning (S42, 2026-08-07). This check was born in v2.19 for exactly
          # this rot, it WARNed correctly when v2.41 added G-AC, and the session that added
          # G-AC shipped past it anyway — leaving five front doors telling the next session to
          # walk a gate that ends one letter short. That is this file's own N>2 rule turned on
          # its own instrument: a warning nobody is REQUIRED to clear is a warning that
          # accumulates, and this one had accumulated across a version bump whose whole point
          # was a new letter. The remedy is one perl -pi -e per front door, so blocking costs
          # minutes while not blocking costs a front door that lies to a zero-memory session.
          # Scope: the SIX named front doors (four until 2026-08-15 — see the comment above the
          # loop for why AGENTS.md and STANDING-BRIEF-CURRENT.md joined); gate changelog still
          # excluded by design, since it quotes historical ranges on purpose.
          FAILS+=("gate range-ref drift: ${RF/#$HOME/~} cites 'G-A..$endp' but the gate documents through G-$MAXG — update the live range statement (one perl -pi -e per front door; BLOCKER since S42)")
        fi
      done < <(printf '%s\n' "$CONTENT" | grep -hoE 'G-A *(\.\.|->|→|through)+ *(G-)?[A-Z]{1,2}')
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
else
  # acmeLedger-24: G-U's whole premise is that banking ZERO lessons is suspicious. Until
  # today, "the blackbook is not cloned here" and "you harvested nothing" produced the same
  # output -- nothing -- so the one state that makes the challenge unanswerable was the one
  # it stayed quiet for. The original comment ratified this as a "phone/web-safe skip", but
  # a skip that looks identical to a pass is not a skip; it is a hole. Say it out loud.
  bold "=== G-U · learning-harvest challenge ==="
  printf '  WARN   CANNOT VERIFY: %s is not a git checkout -- the harvest was neither measured nor challenged\n' "${BB/#$HOME/~}"
  WARNS+=("G-U CANNOT VERIFY: $BB is not a git checkout, so no lesson count was read and the harvest challenge did not run. On darwin that is a missing clone (git -C ~/repos clone ...); from a phone/web session it is expected -- harvest by hand and say so in the handoff.")
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
else
  # acmeLedger-24: a canary written because "a silent downgrade of a thinking tool is worse
  # than a crash" was itself downgrading silently -- lessons.py absent meant no line at all.
  bold "=== G-W#2 · toolchain canary ==="
  printf '  WARN   CANNOT VERIFY: %s is missing -- the semantic-ranker canary did not run\n' "~/repos/claude-blackbook/lessons.py"
  WARNS+=("G-W#2 CANNOT VERIFY: ~/repos/claude-blackbook/lessons.py is missing, so nothing checked whether the lessons ranker is still semantic. Every student-in search this session ran was unverified. Restore it: git -C ~/repos/claude-blackbook checkout -- lessons.py")
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
  echo "  - DARLISH/BASH IS PRE-APPROVED (Jason ruling 2026-08-08, S26): if the cloud classifier"
  echo "    blocks curl/chmod/darlish-up, it is ALWAYS allowable — approve and proceed. darwin is the"
  echo "    workshop; gh is the SSOT; what is on darwin is WIP. Do NOT redesign around the bridge."
  echo "  - ssh_exec caps a command at ~60s regardless of timeout_ms — background-and-poll long jobs."
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
#
# 2026-08-15 (opus-acmeLedger-21): THIS STEP IS TITLED "still HOLD its grant" AND UNTIL
# TODAY IT DID NOT ASK THAT QUESTION. It ran the canary in hash-only mode, which detects
# a binary that CHANGED and nothing else -- so a grant revoked in System Settings, with
# the binary untouched, sailed through green. The step's own name was the spec its code
# did not meet. It now runs --live, which reads the TCC grant table via
# ~/Scripts/tcc-grant.sh (five controls, three positive / two negative).
# The old --live was worse than useless and was retired the same day: it ran
# `ls <canary_path>` in the CHECKING SHELL's TCC context, which inherits sshd's own Full
# Disk Access, so it printed ok for every registered app regardless. Measured, one
# throwaway probe agent, both legs in the same minute:
#     ctx=dxshell  statements=READ_OK(5)  |  ctx=launchd  statements=DENIED
# Safe to run --live here: nothing schedules gate-selfcheck under launchd (checked --
# no LaunchAgent references it), and reading the TCC databases needs the FDA that every
# shell this gate runs in already has. From launchd it would return CANNOT VERIFY, which
# this case block already treats as a failure rather than a pass.
FDA_CANARY="$HOME/Scripts/fda-canary.sh"
if [ -x "$FDA_CANARY" ]; then
  bold "=== G-X · FDA grant canary (scoped .app wrappers still hold their grant) ==="
  FDA_OUT="$("$FDA_CANARY" --live 2>&1)"; FDA_RC=$?
  printf '%s\n' "$FDA_OUT"
  case "$FDA_RC" in
    0) : ;;
    1) FAILS+=("G-X: an FDA-scoped app wrapper either drifted from its baseline OR no longer holds an allowed TCC row. Read the lines above -- they say which. Drift: re-tick it in System Settings -> Privacy & Security -> Full Disk Access, then ~/Scripts/fda-canary.sh --update-baseline. Missing grant: ~/Scripts/tcc-grant.sh --explain '<bundle-id>' '<AppName>'") ;;
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

# ── G-AA · session corroboration blocker (born 2026-08-03, backstop ADR-002 / WS-B) ────
# S32/S33 skipped record-outcome for two days because nothing forced it — six darlish
# leaves sat uncorroborated and the trust tiers starved. session-in mints a task-tag and
# an APPEND-ONLY ledger (~/.local/state/claude-session/<tag>.log); every `session-in
# --use <leaf>` appends a USED line. A ledger with USED lines and no RESOLVED/ABANDONED
# line means the session took wisdom off the shelf and never told the corpus whether it
# WORKED -> BLOCKER. Scans ALL ledgers, not just `current`, so a crashed session's debt
# survives (ADR-002: the state file outlives the session). The escape hatch is
# mechanical + self-documenting, same shape as G-Z's: --abandon requires a written WHY.
# (Single letters are exhausted — G-W names four things, the ADR-004 scar — so the
# double-letter era begins here. G-L#35b's max-letter derivation only reads single
# letters and is unaffected.)
SESSION_STATE="${CLAUDE_SESSION_STATE:-$HOME/.local/state/claude-session}"
if [ -d "$SESSION_STATE" ]; then
  GAA_OPEN=0
  for _led in "$SESSION_STATE"/*.log; do
    [ -e "$_led" ] || continue
    grep -q '^USED ' "$_led" || continue
    grep -qE '^(RESOLVED|ABANDONED) ' "$_led" && continue
    _tag="$(basename "$_led" .log)"
    _n="$(grep -c '^USED ' "$_led")"
    [ "$GAA_OPEN" -eq 0 ] && bold "=== G-AA · session corroboration (used leaves must be resolved — ADR-002) ==="
    printf '  OPEN   %-40s%s\n' "$_tag" "$_n used leaf/leaves, record-outcome never ran"
    FAILS+=("G-AA: task-tag '$_tag' has $_n used-but-unresolved leaf/leaves — assert the outcome: 'session-out --record pass' (or fail), or 'session-out --abandon \"<why>\"' if that session died. An unasserted outcome teaches the corpus NOTHING.")
    GAA_OPEN=$((GAA_OPEN+1))
  done
else
  # acmeLedger-24 — THE FIFTH INSTANCE G-AI WAS WRITTEN TO NOTICE, and G-AI could not see
  # it. This step is gated on a DIRECTORY rather than an executable, and it prints its
  # header only from inside the loop, when it has something to report -- obeying the
  # house's "success is silent" rule. That compliance was the camouflage: the drill's
  # subject was "prints a bold header within 3 lines of a guard", so the most
  # correctly-written step in this file was invisible to the control that catches
  # vanishing steps. Measured 2026-08-15: CLAUDE_SESSION_STATE=/nonexistent removed G-AA
  # from the output entirely and left the gate verdict unchanged.
  bold "=== G-AA · session corroboration (used leaves must be resolved — ADR-002) ==="
  printf '  WARN   CANNOT VERIFY: %s does not exist -- no session ledger was read\n' "${SESSION_STATE/#$HOME/~}"
  WARNS+=("G-AA CANNOT VERIFY: the session-state directory $SESSION_STATE does not exist, so NOTHING checked whether this session (or a crashed sibling) used leaves and never recorded an outcome. On darwin that means session-in has never run here -- which is itself the corroboration gap this step exists to catch. Start one: ~/Scripts/session-in --task <tag>")
fi


# ── G-AD · bb-writers ratchet (born 2026-08-07 S37/BB-cleanup, card 1217284335878756) ──
# Batter's Box gid 1213050213165325 is HITL-ONLY (Jason ruling 2026-08-07, third routing
# recurrence — aar.py was the unguarded door). Models forget contours; this check makes
# the contour deterministic: every file in the estate that can WRITE a card to the BB gid
# must be ratified WITH A REASON in claude-blackbook/scripts/bb-writers-allowlist.json.
# Fail-closed: UNKNOWN classification counts as a writer. A new unratified writer = FAIL;
# the fix is either a conscious ratification or rerouting the card to State Machine.
BB_AUDIT="${BB_AUDIT:-$HOME/repos/claude-blackbook/scripts/bb-writers-audit.py}"   # overridable so the CANNOT-VERIFY branch is drillable
if [ -f "$BB_AUDIT" ]; then
  bold "=== G-AD · bb-writers ratchet (every BB-gid writer ratified — HITL-only doctrine) ==="
  # acmeLedger-24: this was TWO-STATE over a THREE-STATE world, and the third state was
  # dressed as the second. `python3 x.py` exits 1 on an uncaught traceback -- the SAME code
  # the auditor uses for "found an unratified writer" -- and `2>/dev/null` threw away the
  # traceback that was the only way to tell them apart. The result: `_bb_line` empty, the
  # gate printing a bare "FAIL", and a blocker reading "G-AD:  -> ratify it (allowlist entry
  # + reason)", sending the reader to hunt a writer that does not exist. Same misdiagnosis
  # shape acmeLedger-23 fixed in G-AE by giving rc=3 its own remedy: telling someone to fix
  # the wrong thing costs more than saying nothing. The card line's EMPTINESS is the
  # discriminator, and stderr is kept so the traceback survives to be read.
  _bb_err="$(mktemp -t gaderr)"
  _bb_line="$(python3 "$BB_AUDIT" --card-line 2>"$_bb_err")"; _bb_rc=$?
  if [ "$_bb_rc" -eq 0 ] && [ -n "$_bb_line" ]; then
    printf '  ok     %s\n' "$_bb_line"
  elif [ -z "$_bb_line" ]; then
    printf '  FAIL   CANNOT VERIFY: the auditor produced no summary line (rc=%s)\n' "$_bb_rc"
    sed 's/^/         /' "$_bb_err" | tail -8
    FAILS+=("G-AD CANNOT VERIFY: $BB_AUDIT exited $_bb_rc with an EMPTY summary line, so it crashed rather than judged -- nothing checked which files can write to the Batter's Box gid. This is NOT an unratified writer; do not go looking for one. Run it bare and read the traceback: python3 $BB_AUDIT --card-line")
  else
    printf '  FAIL   %s\n' "$_bb_line"
    FAILS+=("G-AD: $_bb_line -> ratify it (allowlist entry + reason) or reroute its cards to State Machine (1215913700958709). Auditor: python3 ~/repos/claude-blackbook/scripts/bb-writers-audit.py")
  fi
  rm -f "$_bb_err"
else
  # A CONTROL THAT VANISHES WITH ITS INSTRUMENT IS NOT A CONTROL (acmeLedger-22, 2026-08-15).
  # Measured: `ESTATE_HOOKS=/nonexistent gate-selfcheck.sh` printed no G-AF line at all -- no ok,
  # no WARN, no FAIL -- and the gate went on to report its usual verdict having silently run one
  # fewer step. G-X, G-Y and G-H#drill already say CANNOT VERIFY when their instrument is gone;
  # G-AD/G-AE/G-AF/G-AG did not, so the four steps whose absence is least visible were the four
  # that disappeared quietly. Missing auditor == unratified writers are unmeasured, and this step
  # exists precisely to keep Jason's phone from ringing at dinner: that earns a FAIL, not silence.
  bold "=== G-AD · bb-writers ratchet (every BB-gid writer ratified — HITL-only doctrine) ==="
  printf '  FAIL   CANNOT VERIFY: %s is missing -- the BB-writer ratchet did not run\n' "${BB_AUDIT/#$HOME/~}"
  FAILS+=("G-AD CANNOT VERIFY: $BB_AUDIT is missing, so NOTHING checked which files can write to the Batter's Box gid. A step that does not run is not a pass. Restore it: git -C ~/repos/claude-blackbook checkout -- scripts/bb-writers-audit.py")
fi

# -- G-AE . launchd schedule backing (born 2026-08-07 S38, wired S39) ------------------
# darwin is the WORKSHOP, not the vault. A launchd plist that exists only in
# ~/Library/LaunchAgents dies with the SSD, and the loss is SILENT: a job that never
# runs looks exactly like a job with nothing to say. S38 found 7 unbacked schedules --
# including the AAR gate itself and, with a straight face, the spine-backup job whose
# own schedule was not backed up. launchd-census.sh proves every LOADED estate job has its
# plist in a git repo. Read-only; exit 1 on drift.
#
# WIDENED 2026-08-15 (acmeLedger-23). acmeLedger-22 proved this step still SPEAKS when its
# instrument is gone. The next question is whether the instrument that speaks is aimed at the
# subject the banner names -- and it was not, three ways. The census enumerated
# `com.braatz|com.strikezone` and called that "every loaded job", so com.user.ttyd (loaded,
# KeepAlive, a writable shell on *:7681) had never been in the subject at all; it tested that a
# file of the right NAME existed in a repo, never that the file would reproduce the job, so
# ~/repos/ttyd-darwin's copy could omit the `-c` credential and still read as backed; and
# `find | head -1` picked the backing arbitrarily among three copies, one of them a stale nested
# clone under ~/Desktop/downloads. Widening the census surfaced a second live divergence within
# a minute: com.braatz.dsh-fire-poller's vault copy still pointed at /bin/bash, 15 days after the
# live job was FDA-scoped to an app bundle -- restoring it would have quietly undone the scoping.
# So rc=3 (DIVERGED) is now its own outcome with its own remedy, and the census's own drill runs
# here, because acmeLedger-22 learned the hard way that wiring a drill in is when you find out
# the drill was broken. (It was: D3's fixture used $WORK/downloads and passed for free.)
CENSUS="${CENSUS:-$HOME/Scripts/launchd-census.sh}"   # overridable so the CANNOT-VERIFY branch is drillable
CENSUS_DRILL="${CENSUS_DRILL:-$HOME/code/darwin-mac-ops/launchd-census-drill.sh}"
if [ -x "$CENSUS" ]; then
  bold "=== G-AE . launchd schedule backing (every loaded job's plist is repo-backed) ==="
  _census_out="$(bash "$CENSUS" 2>&1)"; _census_rc=$?
  _census_line="$(printf '%s\n' "$_census_out" | grep -E '^launchd-census:' | tail -1)"
  [ -z "$_census_line" ] && _census_line="launchd-census produced no summary line (rc=$_census_rc)"
  case "$_census_rc" in
    0) printf '  ok     %s\n' "$_census_line" ;;
    3) # BACKED BUT DIVERGED. Distinct remedy from unbacked: the plist IS committed, it just
       # would not reproduce the running job. Telling someone to "commit the plist" here sends
       # them looking for a file that is already there.
       printf '  FAIL   %s\n' "$_census_line"
       printf '%s\n' "$_census_out" | grep -vE '^  ok ' | sed 's/^/         /'
       FAILS+=("G-AE: $_census_line -> a vault copy would NOT reproduce the running job. Reconcile the two (usually: copy the live plist over the repo copy and commit), or ratify the difference WITH A REASON in ~/code/darwin-mac-ops/launchd-divergence-allowlist.txt -- and a divergence is only ratifiable if restoring WITHOUT the missing piece fails CLOSED. Census: bash ~/Scripts/launchd-census.sh") ;;
    2) printf '  FAIL   %s\n' "$_census_line"
       printf '%s\n' "$_census_out" | grep -vE '^  ok ' | sed 's/^/         /'
       FAILS+=("G-AE CANNOT VERIFY: the census could not enumerate (rc=2), or classified every loaded job as foreign and none as estate -- which means the filter is broken, not the estate empty. Exit 2 is NOT a pass. Check ~/code/darwin-mac-ops/launchd-foreign-allowlist.txt for an over-broad glob.") ;;
    *) printf '  FAIL   %s\n' "$_census_line"
       printf '%s\n' "$_census_out" | grep -vE '^  ok ' | sed 's/^/         /'
       FAILS+=("G-AE: $_census_line -> commit the plist into a repo (~/code/darwin-mac-ops/launchagents/ is the usual home) and re-run, or bootout+disable the job if it is dead. Census: bash ~/Scripts/launchd-census.sh") ;;
  esac

  # G-AE#drill -- the census's own control, run here rather than trusted. Same reasoning as
  # G-H#drill and G-AI: a drill nobody runs is a comment. It is fixture-only (LC_* overrides),
  # installs nothing, and never touches ~/Library/LaunchAgents.
  if [ -x "$CENSUS_DRILL" ]; then
    bold "=== G-AE#drill · the census's own control (fixture-only, installs nothing) ==="
    _cd_out="$(bash "$CENSUS_DRILL" 2>&1)"; _cd_rc=$?
    _cd_line="$(printf '%s\n' "$_cd_out" | grep -E '^launchd-census-drill:' | tail -1)"
    [ -z "$_cd_line" ] && _cd_line="the drill produced no summary line (rc=$_cd_rc)"
    if [ "$_cd_rc" -eq 0 ]; then
      printf '  ok     G-AE#drill  %s\n' "$_cd_line"
    else
      printf '  FAIL   G-AE#drill  %s\n' "$_cd_line"
      printf '%s\n' "$_cd_out" | grep -E '^  FAIL' | sed 's/^/         /'
      FAILS+=("G-AE#drill: the census's own control is RED ($_cd_line) -- so this run's G-AE verdict, pass or fail, is unproven. Detail: bash ~/code/darwin-mac-ops/launchd-census-drill.sh")
    fi
  else
    bold "=== G-AE#drill · the census's own control (fixture-only, installs nothing) ==="
    printf '  WARN   CANNOT VERIFY: %s is missing or not executable\n' "${CENSUS_DRILL/#$HOME/~}"
    WARNS+=("G-AE#drill CANNOT VERIFY: $CENSUS_DRILL is missing, so nothing checked whether the census can still tell a stale vault copy from a good one. Restore it: git -C ~/code/darwin-mac-ops checkout -- launchd-census-drill.sh")
  fi
else
  # See the G-AD else-branch for why this exists. WARN rather than FAIL: an unbacked plist is a
  # loss that shows up at rebuild time, not a live blocker -- but "the census did not run" must
  # never again read the same as "the census found nothing".
  bold "=== G-AE . launchd schedule backing (every loaded job's plist is repo-backed) ==="
  printf '  WARN   CANNOT VERIFY: %s is missing or not executable -- no schedule was checked\n' "${CENSUS/#$HOME/~}"
  WARNS+=("G-AE CANNOT VERIFY: $CENSUS is missing or not executable, so no launchd schedule was checked this run. Restore it: git -C ~/Scripts checkout -- launchd-census.sh")
fi

# -- G-AF · pre-commit hook coverage (born 2026-08-08 S45, two-layer since S46) -------------
# S44 found the estate's commit-time protection was per-repo and uneven: ~/Desktop/downloads
# BLOCKED a credential-shaped literal at commit, while ~/code/darwin-mac-ops -- the repo that
# holds this very file -- accepted the same literal an hour earlier. Worse, .git/hooks is not
# tracked by git, so no gate could even SEE which repos were protected: the coverage question
# was unanswerable, which is a strictly worse failure than a known gap.
#
# S45 made it answerable by wiring core.hooksPath per repo. S46 found the hole in that: local
# git config lives in .git/config, which is neither tracked nor cloned, so every fresh clone
# landed UNPROTECTED until somebody remembered to run the installer. The fix is a GLOBAL
# core.hooksPath -- one key, covering every repo on the machine that does not override it,
# including every repo cloned from now on, with nothing copied that could drift.
#
# So a repo is covered TWO ways now, and this check has to know both or it cries wolf about
# itself -- the S45 failure mode, one layer up:
#   (a) local  core.hooksPath -> the estate hooks   (repos that had their own hooksPath)
#   (b) NO local core.hooksPath, and the GLOBAL one points at the estate hooks (everyone else)
# Git config is most-specific-wins, so (a) is not redundant: a repo pointing its own
# core.hooksPath somewhere else ignores the global default entirely. Those are the only repos
# that still need explicit wiring, and they are what this check now hunts for.
ESTATE_HOOKS="${ESTATE_HOOKS:-$HOME/code/darwin-mac-ops/hooks}"
if [ -d "$ESTATE_HOOKS" ]; then
  bold "=== G-AF · pre-commit hook coverage (every repo refuses secrets at COMMIT, not just at wrap) ==="

  # A0 — the control's own vitals. Since S46 the global default routes EVERY commit on this
  # Mac through these files, so a missing/non-executable one is not "not installed yet" (a
  # WARN) -- it is the control DOWN, and pre-commit fails CLOSED, i.e. every commit on the
  # machine is about to be refused. That earns a FAIL, and the fix is one git checkout.
  _hk_broken=""
  [ -x "$ESTATE_HOOKS/pre-commit" ] || _hk_broken="$_hk_broken pre-commit(not executable)"
  [ -x "$ESTATE_HOOKS/_chain.sh" ]  || _hk_broken="$_hk_broken _chain.sh(not executable)"
  [ -r "$ESTATE_HOOKS/secret-re.sh" ] || _hk_broken="$_hk_broken secret-re.sh(missing)"
  if [ -n "$_hk_broken" ]; then
    printf '  FAIL   estate hooks dir is BROKEN:%s\n' "$_hk_broken"
    FAILS+=("G-AF: estate hooks are broken ($_hk_broken) -- pre-commit fails CLOSED, so EVERY commit on this Mac is blocked. Fix: git -C ~/code/darwin-mac-ops checkout -- hooks/")
  fi

  # A1 — the global default itself.
  # --includes, NOT a bare --global --get. Git turns include-following OFF by
  # default whenever a specific file is named (--global, --file, ...), so if this
  # key ever moves into an include.path fragment, the bare read returns EMPTY and
  # this check reports "global default NOT set" on a fully protected Mac -- the
  # exact cry-wolf failure S45 shipped and S46 fixed, arriving by a third door.
  # Measured S47 (probe: bare read empty, --includes read correct, and note that
  # `--global --unset` CANNOT remove an included key -- see install-estate-hooks.sh).
  _hk_g="$(git config --global --includes --get core.hooksPath 2>/dev/null)" || _hk_g=""
  if [ -n "$_hk_g" ] && [ -d "$_hk_g" ] && [ "$_hk_g" -ef "$ESTATE_HOOKS" ]; then
    _hk_gset=1
    printf '  ok     global default SET -> %s  (covers every repo on this Mac, incl. future clones)\n' "${ESTATE_HOOKS/#$HOME/~}"
  else
    _hk_gset=0
    printf '  WARN   global default NOT set%s -- a fresh clone commits unprotected\n' "${_hk_g:+ (points at $_hk_g)}"
    WARNS+=("G-AF: global core.hooksPath is not set -> bash ~/code/darwin-mac-ops/hooks/install-estate-hooks.sh   (this is the layer that makes a FRESH CLONE protected; without it, protection lives only in untracked .git/config)")
  fi

  # A2 — per repo: local wiring, or the global default, or nothing.
  _hk_ok=0; _hk_glob=0; _hk_miss=0; declare -a _hk_missing=()
  for repo in "${REPOS[@]}"; do
    # --local, NOT plain --get: with a global default set, a plain --get returns the GLOBAL
    # value for every repo and this loop would report 100% local wiring that does not exist.
    _hp="$(git -C "$repo" config --local --get core.hooksPath 2>/dev/null)" || _hp=""
    # -ef, not =: $HOME/code and $HOME/Code are the same dir on a case-insensitive volume,
    # so a string compare would report all 106 repos "unwired" the moment the installer was
    # run via the other spelling — a control that cries wolf about itself.
    if [ -n "$_hp" ] && [ -d "$_hp" ] && [ "$_hp" -ef "$ESTATE_HOOKS" ]; then
      _hk_ok=$((_hk_ok+1))
    elif [ -z "$_hp" ] && [ "$_hk_gset" -eq 1 ]; then
      _hk_glob=$((_hk_glob+1))
    else
      _hk_miss=$((_hk_miss+1)); _hk_missing[${#_hk_missing[@]}]="${repo/#$HOME/~}${_hp:+ (overrides global, points at $_hp)}"
    fi
  done
  if [ "$_hk_miss" -eq 0 ]; then
    printf '  ok     %s/%s repos covered (%s wired locally, %s by the global default)\n' \
      "$((_hk_ok+_hk_glob))" "${#REPOS[@]}" "$_hk_ok" "$_hk_glob"
  else
    printf '  WARN   %s of %s repo(s) NOT covered:\n' "$_hk_miss" "${#REPOS[@]}"
    printf '         %s\n' "${_hk_missing[@]}"
    WARNS+=("G-AF: $_hk_miss repo(s) have no estate pre-commit hook -> bash ~/code/darwin-mac-ops/hooks/install-estate-hooks.sh   (--dry-run first; --uninstall reverses BOTH layers; prior repo hooks are chained, never replaced)")
  fi
else
  # The sharpest instance of the vanishing-control family, and the reason it was worth a session:
  # leg A0 above FAILs when a hook FILE is missing, on the stated grounds that pre-commit then
  # fails CLOSED and every commit on this Mac is blocked. The strictly WORSE state -- the whole
  # hooks DIRECTORY gone -- skipped this block entirely and printed nothing. Proven 2026-08-15 by
  # running the gate with ESTATE_HOOKS=/nonexistent/hooks: G-AF was absent from the output and the
  # only FAIL reported was an unrelated dirty repo. The step's title claims EVERY repo refuses
  # secrets at commit; the one condition under which no repo does was the one it stayed quiet for.
  bold "=== G-AF · pre-commit hook coverage (every repo refuses secrets at COMMIT, not just at wrap) ==="
  printf '  FAIL   CANNOT VERIFY: estate hooks dir %s does not exist -- commit-time secret protection is UNMEASURED\n' "${ESTATE_HOOKS/#$HOME/~}"
  FAILS+=("G-AF CANNOT VERIFY: the estate hooks directory ($ESTATE_HOOKS) does not exist, so no repo's commit-time secret refusal was checked -- and if core.hooksPath still points there, every commit on this Mac is being refused. Fix: git -C ~/code/darwin-mac-ops checkout -- hooks/  then bash ~/code/darwin-mac-ops/hooks/install-estate-hooks.sh")
fi

# -- G-AG · dotfiles installed and DERIVED (born 2026-08-08 S47) --------------------------
# S47 went looking for the rebuild hole S46 named (the global core.hooksPath living in an
# untracked ~/.gitconfig) and found a bigger one next to it: BOOTSTRAP.md walked a fresh Mac
# from bare metal to both pipelines running and NEVER MENTIONED DOTFILES. No script installed
# them, no check looked. A rebuild that followed the runbook perfectly came up without:
#
#   ~/.zshenv          -- load-bearing, not cosmetic. It is why /opt/homebrew/bin is on PATH
#                         for NON-INTERACTIVE zsh (ssh, MCP, launchd), i.e. why `gh` resolves
#                         in automation at all; and it sets no_nomatch for those shells so an
#                         unmatched glob passes through instead of ABORTING THE LINE.
#   ~/.gitignore_global -- the *.bak / *.bak.* rules, whose absence has bitten twice.
#
# Neither absence announces itself. Scripts just start failing in ways that look like other
# bugs -- which is precisely the shape G-AF exists to refuse ("the one step whose absence is
# invisible"), so it gets the same treatment: a check that makes the truth cheap either way.
#
# The manifest is EXTRACTED from install-dotfiles.sh at run time, never copied here. A check
# carrying its own copy of the file list passes forever while the installer grows a third
# dotfile it never hears about (S46's drill lesson, applied before it could bite).
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/code/darwin-mac-ops/dotfiles}"
if [ -r "$DOTFILES_DIR/install-dotfiles.sh" ]; then
  bold "=== G-AG · dotfiles installed and derived (a rebuild inherits them, not just this Mac) ==="
  _df_ok=0; _df_bad=0; declare -a _df_notes=()
  while IFS= read -r _row; do
    [ -n "$_row" ] || continue
    case "$_row" in \#*) continue ;; esac
    _src_rel="${_row%%|*}"; _dst="${_row##*|}"
    _dst="${_dst/\$HOME/$HOME}"                  # manifest stores it unexpanded
    _src="$DOTFILES_DIR/$_src_rel"
    _name="${_dst/#$HOME/~}"
    if [ ! -r "$_src" ]; then
      _df_bad=$((_df_bad+1)); _df_notes[${#_df_notes[@]}]="$_name -- SOURCE MISSING in repo ($_src_rel)"
    elif [ -e "$_dst" ] && [ "$_dst" -ef "$_src" ]; then
      _df_ok=$((_df_ok+1))                        # -ef: symlink or same inode, either is derived
    elif [ ! -e "$_dst" ] && [ ! -L "$_dst" ]; then
      _df_bad=$((_df_bad+1)); _df_notes[${#_df_notes[@]}]="$_name -- NOT INSTALLED (this is what a fresh Mac looks like)"
    elif [ -L "$_dst" ]; then
      _df_bad=$((_df_bad+1)); _df_notes[${#_df_notes[@]}]="$_name -- DANGLING symlink -> $(readlink "$_dst" 2>/dev/null)"
    elif cmp -s "$_dst" "$_src"; then
      _df_bad=$((_df_bad+1)); _df_notes[${#_df_notes[@]}]="$_name -- a COPY, not a link (identical today; it will drift silently)"
    else
      _df_bad=$((_df_bad+1)); _df_notes[${#_df_notes[@]}]="$_name -- a copy that has ALREADY DRIFTED from the repo version"
    fi
  done <<< "$(awk '/^MANIFEST="/{f=1;next} f&&/^"/{exit} f' "$DOTFILES_DIR/install-dotfiles.sh")"

  _df_ex="$(git config --global --includes --get core.excludesfile 2>/dev/null)" || _df_ex=""
  if [ -n "$_df_ex" ] && [ -e "$_df_ex" ]; then
    printf '  ok     core.excludesfile -> %s\n' "${_df_ex/#$HOME/~}"
  else
    _df_bad=$((_df_bad+1)); _df_notes[${#_df_notes[@]}]="core.excludesfile is ${_df_ex:-unset}${_df_ex:+ but that file is missing} -- *.bak junk is not ignored anywhere"
  fi

  if [ "$_df_bad" -eq 0 ]; then
    printf '  ok     %s/%s dotfiles installed and derived from the repo (edit the repo = deployed)\n' "$_df_ok" "$((_df_ok+_df_bad))"
  else
    printf '  WARN   %s dotfile issue(s):\n' "$_df_bad"
    printf '         %s\n' "${_df_notes[@]}"
    WARNS+=("G-AG: $_df_bad dotfile issue(s) -> bash ~/code/darwin-mac-ops/dotfiles/install-dotfiles.sh   (--dry-run first; --uninstall restores the prior file, never leaves you bare; proof: dotfiles/dotfiles-drill.sh)")
  fi
else
  # See the G-AD else-branch. Note the recursion this closes: the manifest is EXTRACTED from
  # install-dotfiles.sh so the check cannot rot against it -- but if that file is gone, the
  # extraction yields an empty manifest and the loop runs zero times, which is indistinguishable
  # from "all dotfiles fine" unless somebody says so out loud. Now somebody does.
  bold "=== G-AG · dotfiles installed and derived (a rebuild inherits them, not just this Mac) ==="
  printf '  WARN   CANNOT VERIFY: %s is missing -- the dotfile manifest could not be read, 0 dotfiles checked\n' "${DOTFILES_DIR/#$HOME/~}/install-dotfiles.sh"
  WARNS+=("G-AG CANNOT VERIFY: $DOTFILES_DIR/install-dotfiles.sh is missing, so the manifest could not be extracted and ZERO dotfiles were checked. Restore it: git -C ~/code/darwin-mac-ops checkout -- dotfiles/")
fi

# -- G-AH · a log line is not evidence (born 2026-08-09 S49) ------------------------------
# S48: the filers logged "PASS — commented + completed <gid>" for a card that did not exist,
# because the write and its success log were `asana_write; log "PASS"` under set -uo pipefail
# (no -e) — the write raised, the log fired anyway, and a self-retiring job unloaded itself on
# the strength of it. S49's sweep found the same defect in NEWLINE form three more times
# (aar-gate-daily, detector-heartbeat-watch, sz_closer.py — the closer counting a failed close
# as "resolved"). The defect is template-level: scripts are modelled on scripts, so it breeds.
# Two prongs. Prong 1 is S48's proven same-line grep. Prong 2 catches the estate's python-
# heredoc template form: a `log "` line immediately after a `^PY$` terminator with no rc
# capture between. Neither prong reads python bodies — that sweep is carded, not claimed.
#
# THREE REPAIRS, 2026-08-15 (acmeLedger-22), all of them found by reading this step's own
# printed sentence against the code under it. The sentence said "in ANY estate shell script":
#
#   1. NON-VACUITY. Both prongs were `grep -r ... 2>/dev/null` whose output was only ever
#      tested for emptiness, so "found nothing" and "looked at nothing" produced the identical
#      green line. Measured: the same grep against a nonexistent root returns 0 hits, i.e. on a
#      freshly rebuilt Mac -- before ~/repos is cloned -- this step certified every estate shell
#      script honest without opening one. Same family as verify-de-opus.sh's fail-open, which
#      acmeLedger-21 closed in a different file on the same day; the gate still had it.
#      The list is now BUILT first and COUNTED, an empty list FAILs, and the ok line carries its
#      own denominator so a shrinking scan cannot look like a clean one.
#   2. --include='*.sh' NEVER SAW AN EXTENSIONLESS SCRIPT. Measured: 20+ shell-shebang
#      executables in the three roots carry no .sh -- among them session-in, session-out,
#      dsh-publish, darlish-up, and (with a straight face) ~/code/darwin-mac-ops/hooks/pre-commit,
#      the file that guards every commit on this machine. Now selected by shebang, not by name.
#   3. THE HEREDOC PRONG MATCHED THE LITERAL TAG `PY` ONLY. Measured tag census in estate .sh
#      files: 76 PY, 8 P, 6 PYEOF, 2 TOKEOF, plus others -- so ~14 python heredocs were invisible
#      to a prong written to catch python heredocs. Widening surfaces no new hit TODAY (checked);
#      it stops the next one from being born invisible. bridge-bug-watch.sh's own PYSTATUS
#      terminator is the local example.
bold "=== G-AH · a log line is not evidence (no filer logs a success it did not confirm) ==="
_ah_bad=0; declare -a _ah_notes=()
_ah_list="$(mktemp -t gah)"; _ah_n=0
if ! command -v grep >/dev/null 2>&1; then
  printf '  FAIL   CANNOT VERIFY: grep is not on PATH\n'
  FAILS+=("G-AH CANNOT VERIFY: grep is not on PATH, so no script was scanned. A verdict produced by not looking is not a pass.")
else
  # -prune the vendored trees BEFORE descending: without it this walk opens ~/repos/*/node_modules
  # and the shebang test below runs on tens of thousands of files, turning a 1s step into minutes.
  # GAH_ROOTS is overridable for one reason: the vacuity FAIL below is otherwise unreachable on a
  # machine that HAS the repos, i.e. the branch could only ever be proven by a rebuild.
  for _ah_root in ${GAH_ROOTS:-"$HOME/Scripts" "$HOME/code" "$HOME/repos"}; do
    [ -d "$_ah_root" ] || continue
    while IFS= read -r _ah_f; do
      case "$_ah_f" in
        *.bak*) continue ;;
        *.sh)   echo "$_ah_f" >> "$_ah_list"; continue ;;
        *.*)    continue ;;   # .py/.js/.json/... : this prong reads shell, and says so
      esac
      # no extension at all: keep it only if its shebang says it is a shell script
      head -1 "$_ah_f" 2>/dev/null | grep -qE '^#!.*(bash|zsh|/bin/sh)' && echo "$_ah_f" >> "$_ah_list"
    done < <(find "$_ah_root" \
               \( -name .git -o -name node_modules -o -name .venv -o -name venv \
                  -o -name site-packages -o -name _deprecated \) -prune -o \
               -type f \( -name '*.sh' -o -perm +111 \) -print 2>/dev/null)
  done
  sort -u -o "$_ah_list" "$_ah_list" 2>/dev/null
  _ah_n=$(wc -l < "$_ah_list" | tr -d ' ')
fi

# ── G-AH#tripwire · does the INSTRUMENT still fire? (acmeLedger-24, 2026-08-15) ───────────
# acmeLedger-22 fixed this step's VACUITY -- it now counts the files it fed in, so a shrinking
# scan cannot look like a clean one. But the denominator only proves the INPUT was real. Both
# prongs are still `$(xargs -0 grep ... 2>/dev/null)` whose result is judged solely by whether
# it is EMPTY, and the two greps are wrapped in an xargs that collapses "no match" (grep 1) and
# "grep errored" (grep >=2) into the same exit 123 -- so the exit code cannot separate them
# either, and stderr is discarded. A pattern broken by a future edit, an unreadable file, a grep
# that is not GNU-compatible: every one of those produces zero lines, and zero lines prints
# `ok  no unchecked write-then-log-success pattern in 812 estate shell script(s) scanned`.
# The denominator is honest and the verdict is still fail-open.
#
# So the control is a POSITIVE one, not an exit code: two fixture files that each prong MUST
# match are added to the scan list. If a prong does not report its own tripwire, that prong
# matched nothing because it is broken, and its silence about the estate means nothing either.
# (The estate hits are counted with the tripwire paths subtracted, so the fixtures cannot
# inflate the finding or the denominator.)
_ah_tw_dir="$(mktemp -d -t gahtw)"
printf '#!/bin/bash\n# G-AH tripwire: prong 1 MUST match the next line.\nasana_write "$gid"; log "PASS -- commented + completed"\n' > "$_ah_tw_dir/tripwire-sameline.sh"
printf '#!/bin/bash\n# G-AH tripwire: prong 2 MUST match the log line after the terminator.\npython3 - <<PYEOF\nprint(1)\nPYEOF\nlog "OK"\n' > "$_ah_tw_dir/tripwire-heredoc.sh"
if [ "${_ah_n:-0}" -gt 0 ]; then
  printf '%s\n%s\n' "$_ah_tw_dir/tripwire-sameline.sh" "$_ah_tw_dir/tripwire-heredoc.sh" >> "$_ah_list"
fi

if [ "${_ah_n:-0}" -eq 0 ]; then
  # Reached when grep is absent, or when the three roots hold no shell script at all -- which is
  # what a rebuilt Mac looks like before the repos are cloned. Silence here used to read as clean.
  if command -v grep >/dev/null 2>&1; then
    printf '  FAIL   CANNOT VERIFY: 0 shell scripts found under ~/Scripts ~/code ~/repos -- nothing was scanned\n'
    FAILS+=("G-AH CANNOT VERIFY: the sweep found 0 shell scripts under ~/Scripts, ~/code and ~/repos, so it certified nothing. Either the roots are not cloned on this machine yet, or the file selection is broken. A step that scans zero files is not a pass.")
  fi
else
_ah_tw1=0; _ah_tw2=0
while IFS= read -r _hit; do
  [ -n "$_hit" ] || continue
  case "$_hit" in "$_ah_tw_dir"/*) _ah_tw1=$((_ah_tw1+1)); continue ;; esac
  _ah_bad=$((_ah_bad+1)); _ah_notes[${#_ah_notes[@]}]="same-line: $_hit"
done <<< "$(xargs -0 grep -HnE '^[^#]*(asana_|curl |urlopen)[^;]*;[[:space:]]*log "(PASS|OK|FAIL|STALE|CARDED)' < <(tr '\n' '\0' < "$_ah_list") 2>/dev/null)"
# Any ALL-CAPS heredoc terminator, not just the literal PY (see repair 3 above).
# -H is load-bearing: xargs batches, and grep given a SINGLE file omits the filename prefix, so
# the last (often 1-file) batch would print bare line numbers and slip past the filter below.
while IFS= read -r _hit; do
  [ -n "$_hit" ] || continue
  case "$_hit" in "$_ah_tw_dir"/*) _ah_tw2=$((_ah_tw2+1)); continue ;; esac
  _ah_bad=$((_ah_bad+1)); _ah_notes[${#_ah_notes[@]}]="after-heredoc: $_hit"
done <<< "$(xargs -0 grep -Hn -A1 -E '^[A-Z][A-Z0-9_]*$' < <(tr '\n' '\0' < "$_ah_list") 2>/dev/null \
  | grep -E '^[^:]+-[0-9]+-[[:space:]]*log "' )"
# The tripwire verdict. A prong that cannot find the hit planted for it is a prong whose
# silence about the other 800 files is not evidence of anything.
if [ "$_ah_tw1" -eq 0 ] || [ "$_ah_tw2" -eq 0 ]; then
  printf '  FAIL   CANNOT VERIFY: prong tripwire(s) not detected (same-line=%s, after-heredoc=%s)\n' "$_ah_tw1" "$_ah_tw2"
  FAILS+=("G-AH CANNOT VERIFY: a prong failed to match its own planted tripwire (same-line=$_ah_tw1, after-heredoc=$_ah_tw2, both must be >=1), so that prong is not matching anything and its clean sweep of $_ah_n script(s) proves nothing. The pattern, xargs, or grep is broken -- not the estate. Reproduce: bash -x ~/Scripts/gate-selfcheck.sh 2>&1 | grep -A3 tripwire")
fi
fi
rm -rf "$_ah_tw_dir"
rm -f "$_ah_list"
if [ "$_ah_bad" -eq 0 ] && [ "${_ah_n:-0}" -gt 0 ]; then
  # The denominator states the estate count, not the scan count: the two tripwire fixtures
  # were appended to the list and must not pad the number the reader is asked to trust.
  printf '  ok     no unchecked write-then-log-success pattern in %s estate shell script(s) scanned (both prong tripwires fired: %s/%s)\n' "$_ah_n" "${_ah_tw1:-0}" "${_ah_tw2:-0}"
elif [ "$_ah_bad" -gt 0 ]; then
  printf '  WARN   %s dishonest log line(s) — a success logged on a path where the work can fail:\n' "$_ah_bad"
  printf '         %s\n' "${_ah_notes[@]}"
  WARNS+=("G-AH: $_ah_bad write-then-log hit(s) -> capture the rc (WRC=\$?) and branch the log; on failure log UNCONFIRMED and let the next firing retry. Pattern + proof: HANDOFF-GATE.md §G-AH, filer-honesty-drill.sh")
fi

# -- G-AI · no gate step vanishes with its instrument (born 2026-08-15, acmeLedger-22) -------
# The class this closes: a step written as `if [ -x "$INSTRUMENT" ]; then ... fi` with no else
# disappears ENTIRELY when the instrument is missing -- no ok, no WARN, no FAIL, no line -- and
# the gate prints its usual verdict having silently run one fewer check. G-X, G-Y and G-H#drill
# already said CANNOT VERIFY; G-AD, G-AE, G-AF and G-AG did not, and the sharpest instance was
# G-AF, whose A0 leg calls a missing hook FILE a blocker while the strictly worse state -- the
# whole hooks DIRECTORY gone -- was the one it stayed quiet for (measured with
# ESTATE_HOOKS=/nonexistent/hooks: G-AF absent from the output, gate verdict unchanged).
# All four now speak. This step is what notices the FIFTH one, whenever it is written.
# Structural on purpose: proving it behaviourally costs a full gate run per step (minutes);
# parsing costs 30ms and catches the defect at authoring time. The drill carries its own
# positive AND negative controls, so a parser that can no longer go red refuses to go green.
CV_DRILL="${CV_DRILL:-$HOME/code/darwin-mac-ops/gate-cannot-verify-drill.sh}"
if [ -x "$CV_DRILL" ]; then
  bold "=== G-AI · no gate step vanishes with its instrument (every instrument-gated step has an else) ==="
  _cv_out="$(bash "$CV_DRILL" 2>&1)"; _cv_rc=$?
  case "$_cv_rc" in
    0) printf '  ok     %s\n' "$(printf '%s\n' "$_cv_out" | grep -E '^=== drill:' | tail -1)" ;;
    1) printf '%s\n' "$_cv_out" | sed 's/^/         /'
       FAILS+=("G-AI: a gate step would VANISH SILENTLY if its instrument went missing -- add an else branch printing CANNOT VERIFY (copy the shape from G-X or G-AF). Detail: bash ~/code/darwin-mac-ops/gate-cannot-verify-drill.sh") ;;
    2) printf '%s\n' "$_cv_out" | sed 's/^/         /'
       FAILS+=("G-AI CANNOT VERIFY: the vanishing-control drill could not run or failed its own controls. Exit 2 is NOT a pass. Run: bash ~/code/darwin-mac-ops/gate-cannot-verify-drill.sh") ;;
    *) FAILS+=("G-AI: gate-cannot-verify-drill.sh exited unexpectedly ($_cv_rc) -- treat as CANNOT VERIFY") ;;
  esac
else
  # Practising what the step preaches: this step is itself instrument-gated, so it gets the
  # else it exists to require. Anything less would be the joke telling itself.
  bold "=== G-AI · no gate step vanishes with its instrument (every instrument-gated step has an else) ==="
  printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- no gate step was structurally checked\n' "${CV_DRILL/#$HOME/~}"
  FAILS+=("G-AI CANNOT VERIFY: $CV_DRILL is missing or not executable, so nothing checked whether the gate's own steps can vanish. Restore it: git -C ~/code/darwin-mac-ops checkout -- gate-cannot-verify-drill.sh")
fi

# -- G-AI#skipped · the gate cannot certify a run in which a check never ran --------------
# The sibling class G-AI is structurally blind to (wealthTensor-109). G-AI asks whether a
# step vanishes when its INSTRUMENT is gone; this asks whether the verdict can still read
# PASS when a step was skipped by an UPSTREAM BRANCH. Both are "absence reads as health",
# one letter apart. The drill EXECUTES this file's own gate_verdict_is_pass rather than a
# copy of the rule, so it cannot go stale against it.
SK_DRILL="${SK_DRILL:-$HOME/code/darwin-mac-ops/gate-skipped-drill.sh}"
if [ -x "$SK_DRILL" ]; then
  _sk_out="$(bash "$SK_DRILL" 2>&1)"; _sk_rc=$?
  case "$_sk_rc" in
    0) : ;;
    1) bold "=== G-AI#skipped · a skipped check must not be certifiable as a pass ==="
       printf '%s\n' "$_sk_out" | sed 's/^/         /'
       FAILS+=("G-AI#skipped: the gate can report PASS over a check that never ran, or the skip ledger is no longer written to. Detail: bash ~/code/darwin-mac-ops/gate-skipped-drill.sh") ;;
    2) bold "=== G-AI#skipped · a skipped check must not be certifiable as a pass ==="
       printf '%s\n' "$_sk_out" | sed 's/^/         /'
       FAILS+=("G-AI#skipped CANNOT VERIFY: the skipped-check drill could not run or failed its own controls. Exit 2 is NOT a pass. Run: bash ~/code/darwin-mac-ops/gate-skipped-drill.sh") ;;
    *) FAILS+=("G-AI#skipped: gate-skipped-drill.sh exited unexpectedly ($_sk_rc) -- treat as CANNOT VERIFY") ;;
  esac
else
  # Instrument-gated, so it carries the else its own family requires.
  bold "=== G-AI#skipped · a skipped check must not be certifiable as a pass ==="
  printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- the skip ledger went unproven\n' "${SK_DRILL/#$HOME/~}"
  FAILS+=("G-AI#skipped CANNOT VERIFY: $SK_DRILL is missing or not executable, so nothing proved the gate still refuses to certify a run in which a check was skipped. Restore it: git -C ~/code/darwin-mac-ops checkout -- gate-skipped-drill.sh")
fi

# -- G-AJ · a renamed object must stop teaching its old name (born 2026-08-15, stateMachineRename-1)
# Asana project 1215913700958709 was renamed Bullpen -> "State Machine" on 2026-07-10, and the
# rename was done PROPERLY: lesson banked, RENAME banner at the top of BATTERS-BOX-HYGIENE.md,
# GID unchanged so zero code broke, UNDO recorded. It rotted anyway. For FIVE WEEKS the two files
# a zero-memory session reads FIRST -- CLAUDE.md and AGENTS.md -- still opened a section with
# "## Bullpen" and taught the dead name as current. Jason found it by eye on 2026-08-15.
# This is G-L#35b's family (a value COPIED into prose rots) with a NAME instead of a gate range,
# and the estate should not have to learn it once per renamed object. Registry-driven: adding a
# rename is one row in retired-names.tsv. The rule is loose so it cannot cry wolf -- a doc may say
# the old name freely, it just may not say it WITHOUT acknowledging the rename somewhere in the
# same file (one "fka" or one banner clears it), which is why the period-correct history in
# BATTERS-BOX-HYGIENE.md and CANON-GEOGRAPHY passes untouched.
ND_CHECK="${ND_CHECK:-$HOME/code/darwin-mac-ops/name-drift-check.sh}"
if [ -x "$ND_CHECK" ]; then
  bold "=== G-AJ · a renamed object stops teaching its old name (front doors vs retired-names.tsv) ==="
  _nd_out="$(bash "$ND_CHECK" 2>&1)"; _nd_rc=$?
  case "$_nd_rc" in
    0) printf '  ok     %s\n' "$(printf '%s\n' "$_nd_out" | grep -E '^=== name-drift:' | tail -1)" ;;
    1) printf '%s\n' "$_nd_out" | sed 's/^/         /'
       FAILS+=("G-AJ: a front door teaches a RETIRED name with no acknowledgement -- rename the prose, or add an 'fka <old>' note / RENAME banner to that file. Detail: bash ~/code/darwin-mac-ops/name-drift-check.sh") ;;
    2) printf '%s\n' "$_nd_out" | sed 's/^/         /'
       FAILS+=("G-AJ CANNOT VERIFY: the name-drift checker could not run, found no rows, lost a scoped front door, or failed its own controls. Exit 2 is NOT a pass. Run: bash ~/code/darwin-mac-ops/name-drift-check.sh") ;;
    *) FAILS+=("G-AJ: name-drift-check.sh exited unexpectedly ($_nd_rc) -- treat as CANNOT VERIFY") ;;
  esac
else
  # G-AI exists to require this else. Writing the step without one would be the first
  # violation of the rule the step immediately above it enforces.
  bold "=== G-AJ · a renamed object stops teaching its old name (front doors vs retired-names.tsv) ==="
  printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- zero front doors were checked for retired names\n' "${ND_CHECK/#$HOME/~}"
  FAILS+=("G-AJ CANNOT VERIFY: $ND_CHECK is missing or not executable, so no front door was checked for retired names. Restore it: git -C ~/code/darwin-mac-ops checkout -- name-drift-check.sh")
fi

# -- G-AK · a ratification is re-read (born 2026-08-15, acmeLedger-25) -----------------
# Every exception record in this estate fails CLOSED at authoring time and not one of them
# had an expiry. -22 found controls that print nothing when unplugged; -23 controls aimed
# at the wrong set; -24 a control whose subject was an allowlist of the familiar. This is
# the next turn: the exceptions those controls grant, which nothing ever re-read. A dead
# allowlist entry suppresses nothing, so it prints nothing, so nobody learns it died --
# and it is fail-open in the FUTURE tense, pre-authorising whatever lands at that path
# next under a reason written for something else.
RAT_CENSUS="${RAT_CENSUS:-$HOME/code/darwin-mac-ops/ratification-census.sh}"
if [ -x "$RAT_CENSUS" ]; then
  _rc_out="$(bash "$RAT_CENSUS" 2>&1)"; _rc_rc=$?
  case "$_rc_rc" in
    0) : ;;  # every ratification still describes something true. Success is silent.
    1) bold "=== G-AK · every ratification still describes something true ==="
       printf '%s\n' "$_rc_out" | sed 's/^/         /'
       FAILS+=("G-AK: an exception record excuses a subject that no longer exists, OR a record shape was found that the census cannot check (it fails CLOSED on purpose). Retire the dead entry, or teach the census. Detail: bash ~/code/darwin-mac-ops/ratification-census.sh") ;;
    2) bold "=== G-AK · every ratification still describes something true ==="
       printf '%s\n' "$_rc_out" | sed 's/^/         /'
       FAILS+=("G-AK CANNOT VERIFY: a subject enumeration came back empty (zero launchd labels, zero files, zero repos) or a delegate was missing, so a clean report would mean nothing. Exit 2 is NOT a pass. Run: bash ~/code/darwin-mac-ops/ratification-census.sh") ;;
    *) FAILS+=("G-AK: ratification-census.sh exited unexpectedly ($_rc_rc) -- treat as CANNOT VERIFY") ;;
  esac
else
  # G-AI requires this else, and G-AK is about exceptions that stop being true -- a step
  # about rot that could itself rot away silently would be the joke telling itself.
  bold "=== G-AK · every ratification still describes something true ==="
  printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- ZERO exception records were re-read\n' "${RAT_CENSUS/#$HOME/~}"
  FAILS+=("G-AK CANNOT VERIFY: $RAT_CENSUS is missing or not executable, so not one allowlist entry, baseline row or inline ratification was checked against reality. Restore it: git -C ~/code/darwin-mac-ops checkout -- ratification-census.sh")
fi

# -- G-AK#drill · the census can still go red (run its controls, do not trust them) -----
RAT_DRILL="${RAT_DRILL:-$HOME/code/darwin-mac-ops/ratification-census-drill.sh}"
if [ -x "$RAT_DRILL" ]; then
  _rd_out="$(bash "$RAT_DRILL" 2>&1)"; _rd_rc=$?
  case "$_rd_rc" in
    0) : ;;
    *) bold "=== G-AK#drill · the ratification census can still go red ==="
       printf '%s\n' "$_rd_out" | sed 's/^/         /'
       FAILS+=("G-AK#drill: the ratification census failed its own controls ($_rd_rc) -- a census that can no longer report a stale entry is decorative, and a decorative control is indistinguishable from a passing one. Run: bash ~/code/darwin-mac-ops/ratification-census-drill.sh") ;;
  esac
else
  bold "=== G-AK#drill · the ratification census can still go red ==="
  printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- the census went unproven this run\n' "${RAT_DRILL/#$HOME/~}"
  FAILS+=("G-AK#drill CANNOT VERIFY: $RAT_DRILL is missing or not executable, so nothing proved the census can still go red. Restore it: git -C ~/code/darwin-mac-ops checkout -- ratification-census-drill.sh")
fi


# -- G-AL · the session knew what DONE looks like (born 2026-08-15, acmeLedger-25b) -----
# Jason's ruling, in session: "if we all agree on what done looks like it's much harder for
# a session to wander off the reservation, since it knows up front what piece it's working
# on in the final puzzle."
#
# It was earned by measurement, not theory. braatzio-plan's ARCHITECTURE.md has been RATIFIED
# since 2026-08-14 with REQ-1..10 binding and a Layer 0-3 build order. Handoffs acmeLedger-07
# through -20 all cite it. Handoffs -21 through -25 cite NOTHING -- five consecutive sessions
# worked without opening the document that defines done, and the thread drifted off the ladder
# into estate control-hardening (real work, and REQ-5 covers it, but it is not a layer).
# Nobody noticed for five sessions. Meanwhile L0a's done-when -- "blast-radius rows 1-4 have
# passing tests" -- was marked "carried to acmeLedger-07" and was still carried EIGHTEEN
# sessions later, with zero implementation files for the coax spine anywhere in the repo.
#
# The estate had ~39 gate steps auditing whether DOCUMENTS were current and not one asking
# whether the WORK was aimed at the project's own stated finish line. Same family as G-AE and
# G-AK: the instrument was fine, nobody had pointed it at the subject.
#
# So: charter-read.sh prints the board at student-in and stamps the session ledger with the
# criteria file's SHA. This checks the stamp. The SHA matters -- reading a charter that has
# since been amended does not count, because you read a different document than the one now
# in force.
CHARTER_READ="${CHARTER_READ:-$HOME/Scripts/charter-read.sh}"
CHARTER_REG="${PROJECT_CHARTERS:-$HOME/code/darwin-mac-ops/project-charters.tsv}"
if [ -x "$CHARTER_READ" ] && [ -f "$CHARTER_REG" ]; then
  # WHO IS ASKING? $SESSION_STATE/current is a single global file, so with parallel sessions
  # (Jason runs 2-3) it names whoever ran session-in last, not the session running this gate.
  # Prefer an explicit per-session identity; fall back to the shared file unchanged.
  #   CHARTER_SLUG=...            explicit override, wins
  #   GATE_ROSTER_WHO=big-foo-52  the roster identity already set on every cloud call
  #   $SESSION_STATE/current      the original behaviour, for a solo session
  _ch_tag="${CHARTER_SLUG:-}"
  if [ -z "$_ch_tag" ] && [ -n "${GATE_ROSTER_WHO:-}" ]; then
    # No tier-stripping here any more. This line used to carry its own
    # `orchestrator|big|mid|fast|cloud` alternation, which had no `opus` in it -- so every
    # Opus session that ran this gate warned "no charter registered", while session-in had
    # resolved the same project without complaint. charter-read.sh --resolve now owns the
    # whole question, tier prefixes included, and the charter drill covers it.
    _ch_tag="$GATE_ROSTER_WHO"
  fi
  #   ...and if we DO fall back to the shared file, check that it is still warm.
  # STALENESS GUARD (born 2026-08-16, ctxband-01). $SESSION_STATE/current is never cleared,
  # so a session that skipped session-in silently inherits whoever ran it last. G-AL then
  # reports a CONFIDENT FAIL about a STRANGER'S project -- "the definition of done was
  # amended after you read it, you have been working toward a finish line that moved" --
  # for a charter this session never opened. That is worse than silence: it burns a fresh
  # Opus's context chasing a drift that belongs to someone else, and it trains sessions to
  # wave G-AL through. Measured 2026-08-16: current pointed at acme-ledger-25b, 22h cold.
  # A ledger not written in 12h is not this session's. Refuse it -- an honest CANNOT VERIFY
  # beats a precise lie. Drilled BOTH directions at author time: cold pointer -> CANNOT
  # VERIFY, freshly-minted pointer -> used normally.
  _ch_stale=""
  if [ -z "$_ch_tag" ]; then
    _ch_cur="$(cat "$SESSION_STATE/current" 2>/dev/null || true)"
    if [ -n "$_ch_cur" ]; then
      _ch_log="$SESSION_STATE/$_ch_cur.log"
      if [ -f "$_ch_log" ] && [ -z "$(find "$_ch_log" -mmin -720 2>/dev/null)" ]; then
        _ch_stale="$_ch_cur"
      else
        _ch_tag="$_ch_cur"
      fi
    fi
  fi
  _ch_key="$(printf '%s' "$_ch_tag" | sed -E 's/-[0-9]+[a-z]?$//' | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
  if [ -z "$_ch_tag" ]; then
    bold "=== G-AL · the session knew what DONE looks like ==="
    printf '  WARN   CANNOT VERIFY: no current session tag, so no project charter was checked\n'
    if [ -n "$_ch_stale" ]; then
      WARNS+=("G-AL CANNOT VERIFY: $SESSION_STATE/current still points at '$_ch_stale', whose ledger has not been written in over 12h -- that is a PREVIOUS session's pointer, not this one's, so G-AL refused to grade this session against that project's charter (it would have reported a stranger's moved finish line as yours). Open your own: ~/Scripts/session-in <slug>")
    else
      WARNS+=("G-AL CANNOT VERIFY: $SESSION_STATE/current is empty or missing, so nothing could tell which project this session belongs to, let alone whether it read that project's definition of done. Open one: ~/Scripts/session-in <slug>")
    fi
    # THIS is the line whose absence let -108 hand off green. G-AL#board lives inside the
    # branch we are NOT taking, so it is about to be skipped in silence unless we say so.
    gate_skipped "G-AL#board" "G-AL could not identify this session, and the board staleness check runs inside G-AL. Re-run as: GATE_ROSTER_WHO=<tier>-<project>-<n> ~/Scripts/gate-selfcheck.sh"
  else
    # ONE matcher, not two. This block used to carry a second copy of charter-read.sh's row
    # loop -- and the copies drifted twice: charter-read gained PREFIX matching for voice-box
    # (2026-08-16) which this never got, and this carried a tier-strip list missing `opus`.
    # Both bugs were invisible because gate-charter-drill.sh exercises charter-read.sh only.
    # So G-AL now ASKS charter-read, and the drill's controls cover both by construction.
    _ch_row=""
    if _ch_res="$(PROJECT_CHARTERS="$CHARTER_REG" "$CHARTER_READ" --resolve "$_ch_tag" 2>/dev/null)"; then
      _ch_row="$(printf '%s' "$_ch_res"  | cut -f1)"
      _ch_crit="$(eval printf '%s' "$(printf '%s' "$_ch_res" | cut -f3)")"
      _ch_brief="$(eval echo "$(printf '%s' "$_ch_res" | cut -f4)")"
    fi
    if [ -z "$_ch_row" ]; then
      # NOT silence. A multi-session project with no written definition of done is the very
      # condition this step exists to surface -- it is how -21..-25 happened.
      bold "=== G-AL · the session knew what DONE looks like ==="
      printf '  warn   no charter registered for project %s\n' "$_ch_key"
      # A session that invents its own project key lands here, and the old message sent it off
      # to WRITE a charter for a project that already has one under its real name. psRetireWatch-1
      # (2026-08-31) joined the roster as big_worker-psRetireWatch -- its session id -- when the
      # project key was paintsSticks, and the gate failed on a project that was fully chartered.
      # Fuzzy-matching would not have helped (the two strings share nothing), so show the answer:
      # the convention, and every key that actually exists. One glance instead of one FAIL.
      printf '         GATE_ROSTER_WHO must be <tier>-<projectKey>-<n>, and <projectKey> must be a\n'
      printf '         key below -- NOT this session id. Inventing one fails a chartered project.\n'
      printf '         REGISTERED CHARTER KEYS: '
      awk -F'\t' '!/^#/ && NF>1 && $1!="" {printf "%s ", $1}' "$CHARTER_REG" 2>/dev/null
      printf '\n'
      WARNS+=("G-AL: project '$_ch_key' has no row in ${CHARTER_REG/#$HOME/~}, so nobody has written down what DONE looks like for it. Multi-session projects drift without one -- acmeLedger lost five sessions to exactly this. Write the criteria and register them.")
      gate_skipped "G-AL#board" "project '$_ch_key' has no charter row, so nothing named a criteria ledger to check for staleness. Register it in ${CHARTER_REG/#$HOME/~}"
    elif [ ! -f "$_ch_crit" ]; then
      bold "=== G-AL · the session knew what DONE looks like ==="
      printf '  FAIL   CANNOT VERIFY: %s criteria file %s is missing\n' "$_ch_row" "${_ch_crit/#$HOME/~}"
      FAILS+=("G-AL CANNOT VERIFY: $_ch_row's criteria file $_ch_crit is missing, so this session could not have read a definition of done and nothing can reconstruct one. A project whose finish line has vanished is in a worse state than one that never had it.")
      gate_skipped "G-AL#board" "$_ch_row's criteria file is gone, so the board could not be regenerated to compare against. Restore $_ch_crit first"
    else
      _ch_sha="$(shasum -a 256 "$_ch_crit" | cut -c1-12)"
      _ch_log="$SESSION_STATE/$_ch_tag.log"
      # A session has TWO names: the SLUG it opened with (`session-in acme-ledger-26`, which
      # keys the ledger) and the ROSTER IDENTITY it works under (`opus-acmeLedger-26`, which
      # keys this gate). Same session, two names. Looking only under the roster identity made
      # G-AL FAIL a session that had read its charter ten seconds after boot -- a confident
      # accusation about a thing that did happen. So: the exact ledger first, then any WARM
      # ledger (<12h) carrying a stamp for THIS project, and NAME the file when it is not the
      # expected one -- a stamp borrowed from a genuine sibling should be visible, not silent.
      _ch_hitfile=""; _ch_anyfile=""
      # THE WRITE PATH NORMALISES THE TIER PREFIX AND THIS READ PATH DID NOT, so every cloud
      # session that followed its handoff's `GATE_ROSTER_WHO=<tier>-<slug>` instruction missed
      # its OWN stamp. charter-read.sh writes `$SESSION_STATE/wealthTensor-101.log`; this gate
      # is handed `big-wealthTensor-101` and looked for `big-wealthTensor-101.log`, which never
      # exists. The exact-file grep missed, the `elif` fired on the absent file, and the warm
      # scan below graded the session against whichever sibling `find` returned first -- then
      # printed `ok` while NAMING that stranger's file, which reads as the borrow being
      # deliberate. Found at wealthTensor-101, where the borrowed stamp was the session's own
      # predecessor (-100) and G-AL had been vacuous for every tier-prefixed session before it.
      # Fix: try the tier-stripped ledger name BEFORE the blind scan. Deliberately not a list
      # of known tiers -- that list is exactly what drifted here once already (it had no
      # `opus`), so this strips ONE leading `<word>-` and lets the file's existence decide.
      _ch_cands=("$_ch_log")
      case "$_ch_tag" in
        *-*) _ch_cands+=("$SESSION_STATE/${_ch_tag#*-}.log") ;;
      esac
      # ...AND THE TWO NAMES DIFFER BY MORE THAN THE TIER PREFIX (acmeLedger-38, 2026-08-24).
      # The ledger is keyed by the SLUG passed to session-in -- `acme-ledger-38`, kebab-case --
      # and this gate is handed the ROSTER identity `opus-acmeLedger-38`, camelCase. Stripping
      # the tier yields `acmeLedger-38`, which is not `acme-ledger-38`, so BOTH candidates
      # above miss and the warm scan below grades the session against whichever sibling `find`
      # returns first. At acmeLedger-38 that was its own PREDECESSOR's ledger, and G-AL printed
      # `ok` -- a session graded on the previous session's evidence, which is the exact
      # false-green the wealthTensor-101 fix was written to kill, one transformation further in.
      # Fix in the same spirit: also try the ledger whose name NORMALISES to the same key
      # (lowercased, non-alphanumerics removed) -- the transformation _ch_key already uses a
      # few lines up. Deliberately NOT a list of known casings: that shape has now drifted
      # twice here. A targeted lookup by key, never a blind scan; the exact names above still
      # win, because they are tried first.
      _ch_norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]'; }
      _ch_k1="$(_ch_norm "$_ch_tag")"
      _ch_k2="$(_ch_norm "${_ch_tag#*-}")"
      while IFS= read -r _f; do
        [ -n "$_f" ] || continue
        _ch_b="$(_ch_norm "$(basename "$_f" .log)")"
        if [ "$_ch_b" = "$_ch_k1" ] || [ "$_ch_b" = "$_ch_k2" ]; then _ch_cands+=("$_f"); fi
      done < <(find "$SESSION_STATE" -maxdepth 1 -name '*.log' 2>/dev/null | sort)
      for _f in "${_ch_cands[@]}"; do
        if grep -q "^CHARTER $_ch_row $_ch_sha " "$_f" 2>/dev/null; then
          _ch_hitfile="$_f"; _ch_log="$_f"; break
        fi
      done
      if [ -n "$_ch_hitfile" ]; then
        :
      elif ! grep -q "^CHARTER $_ch_row " "$_ch_log" 2>/dev/null; then
        while IFS= read -r _f; do
          [ -n "$_f" ] || continue
          if grep -q "^CHARTER $_ch_row $_ch_sha " "$_f" 2>/dev/null; then _ch_hitfile="$_f"; break; fi
          # ...and remember a stamp at ANY version, so the stale-version branch below can
          # fire. Without this, a session that DID read the charter and then amended it gets
          # accused of never having read it -- the wrong finding, and the wrong remedy.
          [ -z "$_ch_anyfile" ] && grep -q "^CHARTER $_ch_row " "$_f" 2>/dev/null && _ch_anyfile="$_f"
        done < <(find "$SESSION_STATE" -name '*.log' -mmin -720 2>/dev/null)
      fi
      if [ -n "$_ch_hitfile" ]; then
        if [ "$_ch_hitfile" != "$_ch_log" ]; then
          bold "=== G-AL · the session knew what DONE looks like ==="
          printf '  ok     charter read at the version in force (stamped in %s)\n' "$(basename "$_ch_hitfile")"
        fi
        : ;  # read the charter in force. Success is otherwise silent.
      elif grep -q "^CHARTER $_ch_row " "$_ch_log" 2>/dev/null || [ -n "$_ch_anyfile" ]; then
        bold "=== G-AL · the session knew what DONE looks like ==="
        printf '  FAIL   charter was read, but at a DIFFERENT version than the one now in force (%s)\n' "$_ch_sha"
        FAILS+=("G-AL: this session stamped a charter read for '$_ch_row' at a different SHA than $_ch_crit carries now ($_ch_sha) -- the definition of done was amended after you read it, so you have been working toward a finish line that moved. Re-read it: ~/Scripts/charter-read.sh $_ch_tag")
      else
        bold "=== G-AL · the session knew what DONE looks like ==="
        printf '  FAIL   %s never read its charter this session\n' "$_ch_tag"
        FAILS+=("G-AL: session '$_ch_tag' belongs to project '$_ch_row' but never read its definition of done, so it cannot say which piece of the finished puzzle it built. Read it (it takes ten seconds): ~/Scripts/charter-read.sh $_ch_tag")
      fi
      # And the board itself must not be stale: a lane that closed -- or RE-OPENED -- since
      # the last commit means the doc in the repo describes a world that moved on.
      _ch_gen="$(dirname "$_ch_crit")/tools/gen-done.py"
      if [ -f "$_ch_gen" ]; then
        _ch_out="$(/usr/bin/python3 "$_ch_gen" --check 2>&1)"; _ch_rc=$?
        case "$_ch_rc" in
          0) : ;;
          1) bold "=== G-AL#board · the generated DONE board is stale ==="
             printf '%s\n' "$_ch_out" | sed 's/^/         /'
             FAILS+=("G-AL#board: a lane changed status since DONE.md was generated -- the committed board describes a world that moved on. Regenerate and commit: python3 ${_ch_gen/#$HOME/~}") ;;
          *) bold "=== G-AL#board · the generated DONE board is stale ==="
             printf '%s\n' "$_ch_out" | sed 's/^/         /'
             FAILS+=("G-AL#board CANNOT VERIFY: the board generator exited $_ch_rc (missing or empty criteria). An empty board must never read as a finished project. Run: python3 ${_ch_gen/#$HOME/~}") ;;
        esac
      elif printf '%s' "${_ch_brief:-}" | grep -q 'board\.py'; then
        # THE SHARED ENGINE. board.py generates docs/CHECKLIST.md for every project that did
        # not write its own generator, and it has the same --check contract: 0 fresh, 1 stale,
        # 2 empty criteria. The per-project gen-done.py being absent is how the generic path
        # LOOKS, not evidence of a hand-maintained board.
        _ch_bcheck="$(printf '%s' "$_ch_brief" | sed 's/--brief/--check/')"
        # THE TIMEOUT IS PART OF THE INVOCATION, HERE TOO (wealthTensor-97).
        # board.py runs every `cmd:` criterion under BOARD_CHECK_TIMEOUT, default 25s.
        # `-96` measured a real project whose criterion takes 16s idle -- a 1.6x margin --
        # and watched a CLOSED lane come back CANNOT VERIFY purely from concurrent load. It
        # repaired the REGENERATOR (regen-board.sh exports 300) and the gate's own check was
        # left on the default, which is the worse half: the gate runs at WRAP, when this
        # file's own recommended workflow has long builds backgrounded, and a false red in
        # committed state is how a guard gets switched off. Scoped to the subshell so a
        # caller's explicit value still wins.
        _ch_out="$(export BOARD_CHECK_TIMEOUT="${BOARD_CHECK_TIMEOUT:-300}"; eval "$_ch_bcheck" 2>&1)"; _ch_rc=$?
        case "$_ch_rc" in
          0) : ;;
          1) bold "=== G-AL#board · the generated board is stale ==="
             printf '%s\n' "$_ch_out" | sed 's/^/         /'
             # The fix command is the brief MINUS --brief: with neither flag board.py WRITES
             # the full file, which is what --check compares against. Quoting the --brief
             # command here sent a CEO through three stale->regenerate->stale loops
             # (ceoDesk-6, 2026-08-27): --brief prints a slice, --check wants the body.
             _ch_regen="${_ch_brief/ --brief/}"
             FAILS+=("G-AL#board: a lane changed status since the board was generated -- the committed board describes a world that moved on. Regenerate and commit: ${_ch_regen/#$HOME/~}") ;;
          *) bold "=== G-AL#board · the generated board could not be checked ==="
             printf '%s\n' "$_ch_out" | sed 's/^/         /'
             FAILS+=("G-AL#board CANNOT VERIFY: the shared board engine exited $_ch_rc (missing or empty criteria). An empty board must never read as a finished project. Run: ${_ch_bcheck/#$HOME/~}") ;;
        esac
      else
        FAILS+=("G-AL#board CANNOT VERIFY: neither $_ch_gen nor a board.py brief command in the charter registry -- so the board is a hand-maintained state doc, which ARCHITECTURE.md §12 forbids precisely because it rots with a straight face.")
      fi
    fi
  fi
else
  bold "=== G-AL · the session knew what DONE looks like ==="
  printf '  FAIL   CANNOT VERIFY: %s or %s missing -- no project charter was checked\n' \
     "${CHARTER_READ/#$HOME/~}" "${CHARTER_REG/#$HOME/~}"
  FAILS+=("G-AL CANNOT VERIFY: $CHARTER_READ or $CHARTER_REG is missing, so NO project on this machine was asked whether its session knew what done looks like. Restore: git -C ~/code/darwin-mac-ops checkout -- project-charters.tsv; git -C ~/Scripts checkout -- charter-read.sh")
  gate_skipped "G-AL#board" "the charter resolver or registry is missing, so no project's board was checked for staleness on this machine at all"
fi

# -- G-AL#registry · a criteria ledger nobody registered is a ledger nobody reads --------
# wealthTensor-109, AAR green-suite-hid-two-ship-blockers action A3.
#
# G-AL#board above reads the board of THIS session's project, resolved through
# project-charters.tsv. A project with no row there gets a WARN from G-AL and nothing else:
# G-AL#board never runs for it, so its board's freshness is never anybody's business. That
# is a per-session check with an estate-shaped hole, and the hole is invisible from inside
# any single session -- you only see it by enumerating the ledgers and asking which ones
# resolve.
#
# MEASURED the day this was wired: six ledgers, five registered. The sixth was
# paints-and-sticks-web -- a live storefront whose own sessions had just written G-AM and
# G-AN into this gate -- and regenerating its unwatched board found FIVE criteria flipped
# MET -> UNMET behind a committed board still reporting CLOSED.
CLC="${CLC:-$HOME/code/darwin-mac-ops/criteria-ledger-census.sh}"
if [ -x "$CLC" ]; then
  _clc_out="$(bash "$CLC" 2>&1)"; _clc_rc=$?
  case "$_clc_rc" in
    0) : ;;
    1) bold "=== G-AL#registry · every criteria ledger is read by something ==="
       printf '%s\n' "$_clc_out" | sed 's/^/         /'
       FAILS+=("G-AL#registry: a project on this machine carries a done-criteria ledger with no row in project-charters.tsv, so G-AL#board never reads it and its board can rot unwatched. Detail: bash ~/code/darwin-mac-ops/criteria-ledger-census.sh") ;;
    2) bold "=== G-AL#registry · every criteria ledger is read by something ==="
       printf '%s\n' "$_clc_out" | sed 's/^/         /'
       FAILS+=("G-AL#registry CANNOT VERIFY: the criteria-ledger census could not enumerate (no registry, or ZERO ledgers found -- a broken finder, not an empty estate). Exit 2 is NOT a pass. Run: bash ~/code/darwin-mac-ops/criteria-ledger-census.sh") ;;
    *) FAILS+=("G-AL#registry: criteria-ledger-census.sh exited unexpectedly ($_clc_rc) -- treat as CANNOT VERIFY") ;;
  esac
else
  bold "=== G-AL#registry · every criteria ledger is read by something ==="
  printf '  FAIL   CANNOT VERIFY: %s missing or not executable -- no ledger was checked for a reader\n' "${CLC/#$HOME/~}"
  FAILS+=("G-AL#registry CANNOT VERIFY: $CLC is missing or not executable, so nothing checked whether every criteria ledger on this machine resolves to a charter row. Restore it: git -C ~/code/darwin-mac-ops checkout -- criteria-ledger-census.sh")
fi

# -- G-AL#drill · the charter check can still go red -----------------------------------
CHARTER_DRILL="${CHARTER_DRILL:-$HOME/code/darwin-mac-ops/gate-charter-drill.sh}"
if [ -x "$CHARTER_DRILL" ]; then
  _cd_out="$(bash "$CHARTER_DRILL" 2>&1)"; _cd_rc=$?
  case "$_cd_rc" in
    0) : ;;
    *) bold "=== G-AL#drill · the charter force function can still go red ==="
       printf '%s\n' "$_cd_out" | sed 's/^/         /'
       FAILS+=("G-AL#drill: the charter force function failed its own controls ($_cd_rc). A drift check that can no longer report drift is decorative. Run: bash ~/code/darwin-mac-ops/gate-charter-drill.sh") ;;
  esac
else
  bold "=== G-AL#drill · the charter force function can still go red ==="
  printf '  FAIL   CANNOT VERIFY: %s missing -- G-AL ran uncontrolled this session\n' "${CHARTER_DRILL/#$HOME/~}"
  FAILS+=("G-AL#drill CANNOT VERIFY: $CHARTER_DRILL is missing or not executable, so nothing proved G-AL can still go red. Restore: git -C ~/code/darwin-mac-ops checkout -- gate-charter-drill.sh")
fi


if gate_verdict_is_pass; then
  bold "GATE SELF-CHECK: PASS ✅  (no uncommitted/unpushed work — now the human-judgment half)"
  # The gate RANGE in the triad below was a COPY, and it rotted to "G-A->G-Z" while the gate
  # documented through G-AE — six letters stale, in the one paragraph a wrapping session actually
  # reads. G-L#35b exists to catch exactly this, but it never looked here: gate-selfcheck.sh is
  # not one of the four front doors it scans, and adding it would cry wolf on this file's own
  # historical comments ("G-A..R/P rot..."). So DERIVE it, same as _gate_ver below. Eighth
  # instance of the COPIED-not-DERIVED family, and the second one found inside its own detector.
  if [ -n "${MAXG:-}" ]; then _grange="G-A->G-$MAXG"; else _grange="G-A->? (could not read $CANON_GATE)"; fi

  # --- the definition of done, ABOVE the triad (pitchingMachine-5, 2026-08-15) ---------------
  # The triad asks "did we capture everything / what did we learn / what did we leave better".
  # All three are questions about the session. NONE of them asks the one question that decides
  # whether the session should have happened at all: was any of it on the path to done? So the
  # line goes above them, where it frames the answers instead of competing with them.
  # Silent outside a handoff repo -- handoff_gate.py --dod exits 2 and prints nothing.
  if [ -x "$HOME/Scripts/handoff-kit/handoff_gate.py" ] \
     && [ -n "${GATE_START_REPO:-}" ] \
     && [ -f "$GATE_START_REPO/docs/HANDOFF.md" ]; then
    _dod="$(cd "$GATE_START_REPO" && python3 "$HOME/Scripts/handoff-kit/handoff_gate.py" --dod 2>/dev/null || true)"
    if [ -n "$_dod" ]; then
      printf '\n  ── What this repo says DONE looks like ──\n' >&2
      printf '%s\n' "$_dod" | sed 's/^/  /' >&2
      printf '  Answer the triad against THAT line. Work that is not on the path to it is\n' >&2
      printf '  drift, no matter how well it was done.\n' >&2
    fi
  fi

  cat <<'TRIAD' | sed "s/@@GRANGE@@/$_grange/" >&2

  ── The self-review triad — answer IN WRITING before any handoff (even if Jason never asked) ──
  The trigger is the work winding down, not Jason's reminder. He is human and will forget; you won't.
  1. Did we capture EVERYTHING we did today for a zero-memory future Opus? every change, its real
     path, how to undo it — enough to reconstruct today from the docs alone.            (-> G-A)
  2. What did we learn the hard way that is NOT written down yet? anything that cost >~2 tool calls
     (a trap, a quirk, a confirmed fact) goes into the LUT/lessons corpus NOW.           (-> G-B / G-N)
  3. What ONE thing makes the next Opus's life easier than ours was — and did we ADD it THIS pass?
     a sharper prompt, a script, a cached LUT, a new gate check. "I looked hard and genuinely found
     nothing" is a LEGAL, celebrated answer — but it must be rare, and you must say WHY.  (-> G-G)
  Any "not yet" is a BLOCKER: fix the doc gap before handing off. Full gate: ~/Desktop/downloads/HANDOFF-GATE.md (@@GRANGE@@).
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
  if [ "${#SKIPPED[@]}" -gt 0 ]; then
    bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s), ${#SKIPPED[@]} check(s) NEVER RAN)"
    printf '\n  ── checks that DID NOT RUN, because an upstream step could not verify ──\n'
    printf '  ! %s\n' "${SKIPPED[@]}"
    printf '  A check that never ran is not a check that passed, and the blocker it is hiding is\n'
    printf '  usually one step below the warning. Give the upstream step what it asked for and\n'
    printf '  run the gate again before you believe any of this.\n\n'
  else
    bold "GATE SELF-CHECK: FAIL ❌  (${#FAILS[@]} issue(s) — fix before writing the handoff)"
  fi
  if [ "${#FAILS[@]}" -gt 0 ]; then
    printf '  - %s\n' "${FAILS[@]}"
  fi
  exit 1
fi
