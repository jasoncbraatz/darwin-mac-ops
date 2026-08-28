#!/bin/bash
# criteria-ledger-census.sh — every criteria ledger on this estate must be REGISTERED, so
# that some gate step actually reads it.  (born 2026-08-27, wealthTensor-109; AAR
# green-suite-hid-two-ship-blockers action A3)
#
# THE CLASS THIS CLOSES
# A project's done-criteria ledger is only ever read by two things: the project's own test
# suite (if it has one, and if anybody wired it — wealth-tensor's A1 row), and `G-AL#board`
# at the handoff gate. G-AL#board resolves the project through
# `~/code/darwin-mac-ops/project-charters.tsv`. **A ledger with no row in that registry is
# therefore read by nothing, ever** — G-AL prints `no charter registered` as a WARN and
# returns, and the board's freshness is never anybody's business.
#
# MEASURED THE DAY THIS WAS WRITTEN. Six ledgers on the estate; five registered. The sixth
# was `paints-and-sticks-web` — a live customer-facing storefront, 48 criteria, a generated
# board, and the project whose sessions had just written G-AM and G-AN INTO the handoff gate.
# Regenerating its board found **five criteria flipped MET -> UNMET** and two lanes fallen
# from PENDING-HUMAN back to OPEN, against a committed board that still said otherwise. The
# project doing the most to improve the gate was the one project the gate could not see.
#
# WHY A CENSUS AND NOT A NOTE. The AAR that produced this action already said the sweep had
# "not been done" and named it rather than assuming it — which is how it got done today.
# Doing it once more only moves the discovery to the next unregistered project. The subject
# is DERIVED (every done-criteria*.tsv under the roots), never a list of the projects we
# happen to know about: an allowlist of the familiar fails open on whatever is added next,
# which this estate has now recorded in gate-cannot-verify-drill.sh, launchd-census.sh and
# name-drift-check.sh. Unknown counts as ours.
#
#   exit 0 = every ledger found is registered (and the count is printed, never implied)
#   exit 1 = at least one ledger is read by nothing
#   exit 2 = CANNOT VERIFY — no registry, or ZERO ledgers found, which means the finder is
#            broken rather than the estate empty. A clean report over an empty subject is
#            the failure this file exists to prevent, so it refuses to produce one.
set -uo pipefail

REG="${PROJECT_CHARTERS:-$HOME/code/darwin-mac-ops/project-charters.tsv}"
ROOTS_RAW="${CLC_ROOTS:-$HOME/repos $HOME/code $HOME/Scripts $HOME/Desktop/downloads}"
read -r -a ROOTS <<< "$ROOTS_RAW"

say()  { printf '%s\n' "$*"; }
cant() { printf '  CANNOT VERIFY  %s\n' "$*"; exit 2; }

[ -f "$REG" ] || cant "the charter registry $REG does not exist, so nothing could be
      resolved and every ledger on this machine is unread. Restore it:
      git -C ~/code/darwin-mac-ops checkout -- project-charters.tsv"

# -- the subject: every criteria ledger under the roots, derived ------------------------------
LEDGERS=()
for r in "${ROOTS[@]}"; do
  [ -d "$r" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] && LEDGERS+=("$f")
  done < <(find "$r" -maxdepth 5 -name 'done-criteria*.tsv' \
             -not -path '*/node_modules/*' -not -path '*/.git/*' -not -name '*.bak*' \
             2>/dev/null | sort)
done

if [ "${#LEDGERS[@]}" -eq 0 ]; then
  cant "ZERO done-criteria*.tsv found under: ${ROOTS[*]}. On darwin that is a broken finder
      or an unmounted home, not an estate with no projects. A census that certifies an empty
      subject is the defect, not the report."
fi

# -- the registry's third column, with $HOME expanded ------------------------------------------
REGISTERED=""
while IFS=$'\t' read -r _key _repo _crit _brief; do
  case "$_key" in ''|'#'*) continue ;; esac
  [ -n "${_crit:-}" ] || continue
  _crit="${_crit//\$HOME/$HOME}"
  _crit="${_crit/#\~/$HOME}"
  REGISTERED="$REGISTERED
$_crit"
done < "$REG"

if [ -z "$(printf '%s' "$REGISTERED" | tr -d '[:space:]')" ]; then
  cant "$REG parsed to ZERO criteria paths. Either the column order changed or the file is
      empty -- and an empty registry would make every ledger below look unregistered, which
      is a parser finding, not an estate finding."
fi

# -- a ledger inside a LINKED GIT WORKTREE is not a second project -----------------------------
# The rail runs its lanes in git worktrees (claude-blackbook-lane-c etc). A worktree contains
# the same COMMITTED files as its canonical repo, so a `find` across the roots sees one
# registered ledger twice and reports the second copy as an unregistered project. That is a
# false positive that fires for every lane that will ever exist -- and a check that cries wolf
# on the estate's own tooling is one people learn to scroll past, which costs more than the
# check was ever worth (the L3 OAuth criterion states the same rule: a row that reddens on
# something nobody controls is a row nobody reads).
#
# Skipped ONLY when both are true: the file sits in a linked worktree, AND git already tracks
# it -- so a genuinely NEW ledger written inside a lane is still reported, which is the case
# that would actually matter. Skips are COUNTED AND NAMED below, never silent.
in_linked_worktree() {
  local d gd
  d="$(dirname "$1")"
  gd="$(git -C "$d" rev-parse --git-dir 2>/dev/null)" || return 1
  case "$gd" in */worktrees/*) return 0 ;; *) return 1 ;; esac
}
ledger_is_tracked() {
  git -C "$(dirname "$1")" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

FOUND=0
ORPHANS=()
WORKTREE_DUPES=()
for f in "${LEDGERS[@]}"; do
  if printf '%s\n' "$REGISTERED" | grep -qxF "$f"; then
    continue
  fi
  if in_linked_worktree "$f" && ledger_is_tracked "$f"; then
    WORKTREE_DUPES+=("$f")
    continue
  fi
  ORPHANS+=("$f")
  FOUND=1
done

# -- board-path collision: two charters whose boards resolve to ONE file (ceoDesk-4, 2026-08-27) ---
# board.py's default --out is <criteria dir>/CHECKLIST.md. claude-blackbook hosts TWO charters
# (floristDeputize, bbCleanup); until bbCleanup's row carried an explicit --out, G-AL#board compared
# bbCleanup's criteria against floristDeputize's board and reported STALE forever. The collision is
# invisible from inside either session, so the census -- the only thing that reads every row -- checks it.
# bash 3.2 on darwin: no associative arrays, so the seen-list is a newline-joined "out<TAB>key" string.
_OUTSEEN=""
_COLL=0
while IFS=$'\t' read -r _key _repo _crit _brief; do
  case "$_key" in ''|'#'*) continue ;; esac
  [ -n "${_crit:-}" ] || continue
  _crit="${_crit//\$HOME/$HOME}"; _crit="${_crit/#\~/$HOME}"
  _out=""
  if printf '%s' "${_brief:-}" | grep -q -- '--out '; then
    _out="$(printf '%s' "$_brief" | sed -E 's/.*--out[[:space:]]+([^[:space:]]+).*/\1/')"
    _out="${_out//\$HOME/$HOME}"; _out="${_out/#\~/$HOME}"
  else
    _out="$(dirname "$_crit")/CHECKLIST.md"
  fi
  _prev="$(printf '%s\n' "$_OUTSEEN" | awk -F'\t' -v o="$_out" '$1==o {print $2; exit}')"
  if [ -n "$_prev" ]; then
    printf '  RED   board-path collision: %s and %s both render to %s -- give one of them an explicit --out\n' \
      "$_prev" "$_key" "${_out/#$HOME/~}"
    _COLL=1
  else
    _OUTSEEN="$_OUTSEEN
$_out	$_key"
  fi
done < "$REG"
if [ "$_COLL" -eq 1 ]; then
  say "  Two charters writing one CHECKLIST.md means G-AL#board judges one project's board against"
  say "  the other project's criteria and reports STALE forever. Fix the registry row, not the gate."
  exit 1
fi

say "=== criteria-ledger census: ${#LEDGERS[@]} ledger(s) found, ${#ORPHANS[@]} unregistered"
if [ "${#WORKTREE_DUPES[@]}" -gt 0 ]; then
  say "  note  ${#WORKTREE_DUPES[@]} tracked copy/copies skipped inside linked git worktrees (the rail's lanes);"
  say "        each is the SAME committed file as its canonical repo, already registered there:"
  for _d in "${WORKTREE_DUPES[@]}"; do say "          $_d"; done
fi
if [ "$FOUND" -eq 0 ]; then
  say "  ok    every criteria ledger resolves to a charter row, so G-AL#board reads all of them"
  exit 0
fi

for f in "${ORPHANS[@]}"; do
  printf '  RED   %s has NO row in %s\n' "${f/#$HOME/~}" "${REG/#$HOME/~}"
done
say ""
say "  A ledger with no charter row is read by NOTHING. G-AL prints 'no charter registered'"
say "  as a WARN and returns, so G-AL#board never runs and the board's freshness is never"
say "  anybody's business. Add a TAB-separated row -- key, repo, criteria file, brief command:"
say ""
say "    <projectKey>\\t\$HOME/repos/<repo>\\t<the path above>\\t\\"
say "      python3 \$HOME/Scripts/handoff-kit/board.py --criteria <the path above> \\"
say "        --project <projectKey> --brief"
say ""
say "  Then REGENERATE that project's board before believing it -- an unwatched board is"
say "  usually a stale one, and the first thing this census ever found was five criteria"
say "  that had flipped MET -> UNMET behind a board still reporting CLOSED."
exit 1
