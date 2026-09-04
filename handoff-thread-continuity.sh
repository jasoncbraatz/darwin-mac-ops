#!/usr/bin/env bash
# handoff-thread-continuity.sh — a thread you inherited and never mention again is DROPPED,
# and prose cannot notice its own omission.
#
# WHY THIS EXISTS (2026-09-03, smDrainHandoff-7, card 1218152478656223)
# HANDOFF-GATE.md v2.23 (2026-06-29) carries the anti-string-of-pearls rule: "every
# carried-over OPEN / 'actionable now' item MUST ship its own one-line verify: liveness
# check". It was PROSE ONLY for 66 days -- `command grep -niE "pearls|carried.over"
# gate-selfcheck.sh` returned nothing, and the gate's ~40 checks audited whether DOCUMENTS
# were current without ever asking whether INHERITED THREADS survived the handoff.
#
# Measured cost, from real history and not a hypothetical: smBacklog-11 handed -12 three
# live threads plus the project's own drain scoreboard. -12's handoff to -13 carried exactly
# ONE of them. Every claim -12 MADE was true -- three real pushed commits, one genuinely
# closed card, honest that Book L was unsolved. It was not a quality failure. It was an
# OMISSION, and omission is the one defect a narrative cannot self-detect: the session writes
# the handoff from its own memory, so every item it never personally touched falls out.
#
# THE UNIT IS THE GID, NOT THE SENTENCE. Prose matching would need to decide whether "the
# dedupe ratchet" and "A1 ratchet" are the same worry. A 16-digit State Machine gid is the
# estate's own machine-checkable noun and is already how every card is cited. Per the card:
# start at gid coverage; extend to headed threads only if gid coverage proves insufficient.
#
# ANTI-GAMING, and it is the whole reason for the prose filter. If pasting the inbound
# handoff verbatim into a fenced block satisfied the check, this control would enforce
# copy-paste and nothing else. So gids are read ONLY from prose: fenced code blocks and
# blockquoted lines are stripped from BOTH sides before any gid is extracted, on the same
# predicate, because "a thread this document actually carries" means the same thing whether
# the document is the one handing over or the one being handed.
#
# WHAT IT DOES NOT DO. It does not judge whether a carried thread is carried WELL, and it
# does not read the verify: line's command. A dropped gid is a FAIL because an inherited
# thread that appears nowhere was decided by accident. A carried gid with no verify: line
# nearby is a NOVERIFY advisory (the caller decides its severity) -- because the v2.23 rule
# asks for a liveness check and a session that carries the thread has at least made the
# decision on purpose. Dropping a thread AFTER a one-command liveness check is a WIN, and
# this script cannot tell that apart from carrying it, which is exactly why the drop must be
# WRITTEN DOWN in the outbound: the gid stays, the receipt says DROPPED.
#
# EXIT CODES (this script's own contract):
# @verdict-contract
# @verdict 0  every gid the inbound handoff carries is accounted for in the outbound
# @verdict 1  a finding: at least one inbound gid appears NOWHERE in the outbound prose
# @verdict 2  CANNOT VERIFY: a handoff is missing/unreadable, or the inbound parsed to ZERO
#             gids (an empty parse is a broken parser, never a clean bill of health)
# @drill ~/code/darwin-mac-ops/handoff-thread-continuity-drill.sh
#
# bash 3.2 (stock macOS, 3.2.57) is the only bash on darwin: NO mapfile/readarray, and
# `set -u` explodes on an empty array expansion. name-drift-check.sh learned this first.
set -o pipefail

INBOUND=""; OUTBOUND=""
# How far below a gid's first prose mention a verify: line still counts as ITS liveness
# check. A carried item in this estate's handoffs is a short block, not a chapter.
VERIFY_WINDOW="${HTC_VERIFY_WINDOW:-12}"

while [ $# -gt 0 ]; do
  case "$1" in
    --inbound)  INBOUND="$2";  shift 2 ;;
    --outbound) OUTBOUND="$2"; shift 2 ;;
    -h|--help)
      echo "usage: handoff-thread-continuity.sh --inbound <handoff.md> --outbound <handoff.md>"
      exit 0 ;;
    *) echo "  CANNOT VERIFY: unknown argument '$1'"; exit 2 ;;
  esac
done

if [ -z "$INBOUND" ] || [ -z "$OUTBOUND" ]; then
  echo "  CANNOT VERIFY: both --inbound and --outbound are required."
  echo "  usage: handoff-thread-continuity.sh --inbound <handoff.md> --outbound <handoff.md>"
  exit 2
fi
for f in "$INBOUND" "$OUTBOUND"; do
  if [ ! -r "$f" ]; then
    echo "  CANNOT VERIFY: cannot read '$f'."
    echo "  A missing handoff is not a clean one. Nothing was compared."
    exit 2
  fi
done

# --- prose(): the document minus everything a session could paste without deciding -------
# Fenced blocks (``` or ~~~) and blockquote lines are NOT prose. Note the fence toggle is
# a plain state machine, not a regex over the file: an unterminated fence therefore swallows
# the rest of the document, which fails toward reporting a gid as ABSENT -- the loud
# direction, and the right one for a control whose whole job is to notice absence.
prose() {
  awk '
    /^[[:space:]]*(```|~~~)/ { infence = !infence; next }
    infence                  { next }
    /^[[:space:]]*>/         { next }
    { print }
  ' "$1"
}

gids_of() { prose "$1" | grep -oE '[0-9]{16}' | sort -u; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
gids_of "$INBOUND"  > "$WORK/in"
gids_of "$OUTBOUND" > "$WORK/out"
prose "$OUTBOUND"   > "$WORK/outprose"

nin=$(wc -l < "$WORK/in" | tr -d ' ')
if [ "$nin" -eq 0 ]; then
  echo "  CANNOT VERIFY: the inbound handoff '$INBOUND' yielded ZERO State Machine gids in prose."
  echo "  Either it cites no cards (nothing to inherit, so nothing this check can grade) or the"
  echo "  parse is broken. Both are unknowns, and an unknown is not a pass. Check by hand:"
  echo "    command grep -oE '[0-9]{16}' '$INBOUND' | sort -u"
  exit 2
fi

dropped=0; noverify=0
while IFS= read -r g; do
  [ -n "$g" ] || continue
  if ! grep -q "$g" "$WORK/out"; then
    echo "DROPPED $g"
    dropped=$((dropped+1))
    continue
  fi
  # Carried. Does it ship the v2.23 liveness check within its own block?
  if ! awk -v g="$g" -v w="$VERIFY_WINDOW" '
        index($0, g) { hit = NR }
        hit && NR >= hit && NR <= hit + w && /verify:/ { found = 1; exit }
        END { exit(found ? 0 : 1) }
      ' "$WORK/outprose"; then
    echo "NOVERIFY $g"
    noverify=$((noverify+1))
  fi
done < "$WORK/in"

nout=$(wc -l < "$WORK/out" | tr -d ' ')
echo "EVIDENCE inbound=$INBOUND gids=$nin  outbound=$OUTBOUND gids=$nout  dropped=$dropped  noverify=$noverify"

if [ "$dropped" -gt 0 ]; then
  echo "  FINDING: $dropped inherited thread(s) appear NOWHERE in the outbound handoff."
  echo "  An inbound gid must land in the outbound in one of three states -- CARRIED (with a"
  echo "  verify: line), CLOSED (with a receipt), or DROPPED (with the liveness check that"
  echo "  justified dropping it). Absent is not one of them: it is a decision nobody made."
  exit 1
fi
exit 0
