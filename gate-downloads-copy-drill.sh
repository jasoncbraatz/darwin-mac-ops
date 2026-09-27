#!/usr/bin/env bash
# gate-downloads-copy-drill.sh — controls for gate-selfcheck's G-BA, "the wrap Jason can SEE".
#
# SM 1218649246436186. A session whose handoff is committed to a project repo but never copied
# into ~/Desktop/downloads passed every mechanical check the gate had. Jason reads that folder
# in Finder; on 2026-09-19 he saw only a kickoff file, concluded the job was not done, and
# re-seated a fresh Fable onto ~40 minutes of already-finished work. G-BA is the row that goes
# red on exactly that state — and the reason it needs a drill of its own is that its FAILING
# case and its N/A case look identical from outside: both are "no handoff in downloads". One is
# a blocker, the other is every rail lane on the estate. A row that cannot tell them apart is
# either useless or a permanent red.
#
# The block is EXTRACTED from gate-selfcheck.sh and eval'd, never copied here: a drill that
# grades a duplicate proves the duplicate (htc-number-drill.sh:16).
#
# rc 0 = every control holds.  rc 1 = at least one did not.  rc 2 = could not extract.
set -uo pipefail
GATE="${GATE_FILE:-$HOME/code/darwin-mac-ops/gate-selfcheck.sh}"
# A RELATIVE $GATE is resolved HERE, before anything cds away — this drill runs from a temp
# dir, so a relative path handed in by a caller would resolve to nothing and the drill would
# report "could not extract", a true statement with a false cause (feynmanSync-09).
case "$GATE" in
  /*) : ;;
   *) GATE="$(cd "$(dirname "$GATE")" 2>/dev/null && pwd)/$(basename "$GATE")" ;;
esac

PASS=0; FAIL=0
bold(){ printf '\033[1m%s\033[0m\n' "$*"; }
check(){ # check <name> <expected> <got>
  if [ "$3" = "$2" ]; then printf '  ok    %-58s %s\n' "$1" "${3:-（empty）}"; PASS=$((PASS+1))
  else printf '  FAIL  %-58s got "%s", wanted "%s"\n' "$1" "$3" "$2"; FAIL=$((FAIL+1)); fi
}

[ -f "$GATE" ] || { echo "drill: CANNOT VERIFY — gate not found at $GATE"; exit 2; }
# the whole row, from its reach marker to the sentinel comment that closes it
_blk="$(awk '/^gate_ran "G-BA"$/,/^# G-BA-END/' "$GATE" | sed '$d')"
[ -n "$_blk" ] || { echo "drill: CANNOT VERIFY — could not extract the G-BA block from $GATE"; exit 2; }
case "$_blk" in *_dlc_hit*) : ;; *) echo "drill: CANNOT VERIFY — extracted text carries no _dlc_hit; the row was renamed or reshaped"; exit 2 ;; esac

T="$(mktemp -d "${TMPDIR:-/tmp}/gate-dlc-drill.XXXXXX")" || exit 2
trap 'rm -rf "$T"' EXIT

# --- the harness the block expects, stubbed so a verdict is READABLE as data ---------------
# gate_ran / bold are noise here; gate_na and FAILS are the two things being measured.
_stub() {
  gate_ran(){ :; }
  bold(){ :; }
  FAILS=(); NA=()
  gate_na(){ NA+=("$1 N/A: $2"); }
}

# ==========================================================================================
bold "=== part 1 · the boundary rule (_dlc_hit), extracted and run directly ==="
_stub; eval "$_blk" >/dev/null 2>&1 || true   # defines _dlc_hit (the searches find nothing here)

_hit(){ if _dlc_hit "$1" "$2"; then echo hit; else echo miss; fi; }

# THE SHIPPED CASE. A ceo-desk session calls itself `freshcanary-hardening` and writes
# HANDOFF-ceoFreshCanary-hardening-2026-09-19.md. The slug is an INFIX, and the only thing
# marking the seam is the capital F.
check "1  upper-case seam: ceoFreshCanary-hardening finds freshcanary-hardening" hit \
  "$(_hit 'ceoFreshCanary-hardening-2026-09-19' 'freshcanary-hardening')"
# ...and the negative control for that same permissiveness: a suffix of a WORD is not a word.
check "2  mid-word infix is NOT a hit (a slug 'anary' cannot claim it)" miss \
  "$(_hit 'ceoFreshCanary-13' 'anary')"
check "3  position 0 is a boundary" hit "$(_hit 'nightCrew-31' 'nightcrew')"
check "4  a dash before the seam is a boundary" hit "$(_hit 'fable-freshCanary-13' 'freshcanary')"
check "5  a key that is simply absent is a miss" miss "$(_hit 'ceoFreshCanary-13' 'ledgerprimitive')"

# ==========================================================================================
bold "=== part 2 · the verdict, end to end, against fixtures ==="
# a real git repo, because the row asks git (not the filesystem) what is committed: an
# UNTRACKED handoff lying in a repo is not "safe in git" and must not read as one.
mkdir -p "$T/repo" "$T/downloads"
git -C "$T/repo" init -q 2>/dev/null
git -C "$T/repo" config user.email d@d; git -C "$T/repo" config user.name d
mkdir -p "$T/repo/docs/handoffs"
printf 'x\n' > "$T/repo/docs/handoffs/HANDOFF-ceoFreshCanary-hardening-2026-09-19.md"
git -C "$T/repo" add -A >/dev/null 2>&1
git -C "$T/repo" commit -qm seed >/dev/null 2>&1

_verdict(){ # _verdict <tag> <downloads-dir>  -> "FAIL|NA|SILENT"
  _stub
  _ch_tag="$1"; HTC_DIR="$2"; REPOS=("$T/repo")
  eval "$_blk" >/dev/null 2>&1
  if   [ "${#FAILS[@]}" -gt 0 ]; then echo FAIL
  elif [ "${#NA[@]}"    -gt 0 ]; then echo NA
  else echo SILENT; fi
}
_failtext(){
  _stub; _ch_tag="$1"; HTC_DIR="$2"; REPOS=("$T/repo")
  eval "$_blk" >/dev/null 2>&1
  printf '%s' "${FAILS[0]:-}"
}

# 6. THE CASE THAT FILED THE CARD: committed in the repo, absent from downloads.
check "6  handoff in git only -> FAIL (the card's specimen)" FAIL \
  "$(_verdict 'fable-freshCanary-hardening' "$T/downloads")"
# and the blocker must NAME the file, or the reader cannot act on it
case "$(_failtext 'fable-freshCanary-hardening' "$T/downloads")" in
  *"HANDOFF-ceoFreshCanary-hardening-2026-09-19.md"*) check "7  the blocker NAMES the git file" yes yes ;;
  *) check "7  the blocker NAMES the git file" yes no ;;
esac
# ...and prints the copy command, which is the difference between a finding and a chore
case "$(_failtext 'fable-freshCanary-hardening' "$T/downloads")" in
  *"cp "*"git -C"*"push"*) check "8  the blocker ships the cp+vault command" yes yes ;;
  *) check "8  the blocker ships the cp+vault command" yes no ;;
esac

# 9. AFTER THE COPY -> GREEN. This is the card's own VERIFY line, second half.
cp "$T/repo/docs/handoffs/HANDOFF-ceoFreshCanary-hardening-2026-09-19.md" "$T/downloads/"
check "9  after cp into downloads -> silent pass (card's VERIFY line)" SILENT \
  "$(_verdict 'fable-freshCanary-hardening' "$T/downloads")"
rm -f "$T/downloads/HANDOFF-ceoFreshCanary-hardening-2026-09-19.md"

# 10. THE RAIL LANE. No HANDOFF-<slug>.md anywhere -> N/A, never FAIL. If this control ever
#     goes red, G-BA has become a permanent blocker for every rail lane and scheduled run on
#     the estate — the G-AI failure (a check that can never pass).
check "10 a slug with no handoff document anywhere -> N/A, not FAIL" NA \
  "$(_verdict 'nightCrew-31' "$T/downloads")"
# 11. No slug at all -> N/A, and for its own stated reason.
check "11 no slug at all -> N/A" NA "$(_verdict '' "$T/downloads")"

# 12. UNTRACKED IS NOT IN GIT. The same file, uncommitted, is not evidence of a safe wrap.
mkdir -p "$T/repo2/docs"; git -C "$T/repo2" init -q 2>/dev/null
git -C "$T/repo2" config user.email d@d; git -C "$T/repo2" config user.name d
printf 'x\n' > "$T/repo2/docs/HANDOFF-ceoFreshCanary-hardening-2026-09-19.md"
_stub; _ch_tag='fable-freshCanary-hardening'; HTC_DIR="$T/downloads"; REPOS=("$T/repo2")
eval "$_blk" >/dev/null 2>&1
check "12 an UNTRACKED handoff does not read as 'in git'" 0 "${#FAILS[@]}"

# ==========================================================================================
bold "=== part 3 · mutant · the verdict is driven by the matcher, not by the fixture ==="
# Control 6 would also pass if the block FAILED on every slug it was handed. Neuter the
# boundary test so nothing can ever match, and 6 must move while 10 (already N/A) must not.
_mut="$(printf '%s\n' "$_blk" | sed 's/^  case "\$_l" in \*"\$_k"\*) : ;; \*) return 1 ;; esac$/  return 1/')"
case "$_mut" in
  "$_blk") check "13 MUTANT A applied (boundary test neutered)" yes no ;;
  *)       check "13 MUTANT A applied (boundary test neutered)" yes yes ;;
esac
_mverdict(){ _stub; _ch_tag="$1"; HTC_DIR="$2"; REPOS=("$T/repo"); eval "$_mut" >/dev/null 2>&1
  if [ "${#FAILS[@]}" -gt 0 ]; then echo FAIL; elif [ "${#NA[@]}" -gt 0 ]; then echo NA; else echo SILENT; fi; }
check "14 MUTANT A: control 6 MOVES (FAIL -> N/A) -- 6 was really measuring" NA \
  "$(_mverdict 'fable-freshCanary-hardening' "$T/downloads")"
check "15 MUTANT A: control 10 does NOT move -- the N/A case was not the mutant's doing" NA \
  "$(_mverdict 'nightCrew-31' "$T/downloads")"

printf '\n'
if [ "$FAIL" -eq 0 ]; then bold "gate-downloads-copy-drill: $PASS passed, 0 failed"; exit 0; fi
bold "gate-downloads-copy-drill: $PASS passed, $FAIL failed"; exit 1
