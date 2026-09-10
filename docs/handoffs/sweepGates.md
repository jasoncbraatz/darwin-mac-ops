---
project: "sweepGates"
session_n: 0
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "76ca2455d2f8ed6625defe8d83545ab2466e1154"
updated: "2026-09-10"
definition_of_done: "Every one of the 2 card(s) in the frozen manifest lane-sweepGates.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh sweepGates` exits 0."
verify_cmd: "bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh sweepGates"
ruler_files: ["/Users/jasoncbraatz/repos/claude-blackbook/state/smdrain/lane-sweepGates.json", "/Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh"]
engine_sha: "8775c04ece0cf9f367a4a017bf26a03d51e708fc"
lessons_consulted: ["2026-09-08-ratification-census-sh-fails-closed-ratification", "2026-09-06-put-shared-drill-script-surface-drill", "2026-09-07-start-scripts-session-slug-hand-rolled"]
live_theme: "session 0: lane armed by the CEO desk from the 2026-09-10 freeze; no work yet."
phase: "0/2 closed. RULER RED (expected before any work)."
gate_passed: false
next_at_bat: "Run the verify_cmd; take the first OPEN gid in the table below; read the card on Asana (the body carries prior sessions' measurements), fix it reversibly, verify it yourself, bb-close.py with a receipt. One card per inning is fine; two is better; a card you cannot close is a finding (park needs a ruling \u2014 open a decision)."
blockers: []
drift_flags: []
parking_lot: []
---

# sweepGates — LIVING HANDOFF

## Read first
Run the `verify_cmd` in the frontmatter above FIRST. Its OPEN lines are the at-bat and its
closed lines are the guard rails. Then `docs/NORTH-STAR.md` if this repo has one.

## What this lane is

Jason asked the CEO desk to attack the State Machine backlog (target: 95% of the frozen workable
board). The board was FROZEN at **2026-09-10T09:11:46+00:00** (rule 1 of the `backlog.work` bat: never
count against a live board — an honest session FILES cards, so a live denominator makes good work
look like failure). 29 cards were workable at the freeze (NOW+NEXT; SOMEDAY is memory, not debt).

This lane is ONE CLUSTER of that freeze — **darwin-mac-ops: an ERRAND session can green G-AL#board through its documented escape hatch, and G-AW's drill-census reds when guard@3556 vanishes and knows its two baselines — both proven by a drill in darwin-mac-ops, both cards closed with the sha** — because a cluster is
one system, which is one repo, which is one claim. The cards were scoped by the repo they are
CLOSED IN, not the topic they share.

## The ruler is DECLARED, not shimmed

`verify_cmd` is the blackbook verifier and `ruler_files:` in the frontmatter names the manifest
and the verifier. rail.py (ff86a5b, `ruler_files:` DECLARED never inferred) digests both at
rail-on, so narrowing the manifest is a LOUD `RULER MOVED` (exit 2), not a silent pass — the
smDrainWisdom false complete (48327fb1) cannot recur here. The ENGINE (`smdrain-lane.py`) is
PINNED, not frozen: `engine_sha:` is its blob sha at arming (smDrainDesk-05 — a frozen engine
made every grader bugfix a RULER MOVED on every live lane).

**You may not edit the manifest.** A card you cannot close is a FINDING, not a failure:
open a decision (`python3 ~/repos/auto-bridge/abridge.py decision open --proj sweepGates --needs-ceo -q "..."`),
say so on the card, move on. After the CEO rules, the park is
`python3 /Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py park --lane sweepGates --gid G --why "<cite the ruling>"`
— it appends to a sibling file and never touches the ruler. Commit `state/smdrain/parked-sweepGates.json`
in claude-blackbook by pathspec (that repo is NOT this lane's claim — commit only that file, say so in the message).

## The cards (FROZEN — do not add, do not remove)

BRIEF is the CEO desk's measured fix surface from the campfire (read on 2026-09-05 with the repo open).
It is a head start, not an order: if the card or the repo disagree with the brief, the repo wins — say so.

| gid | bin | card | BRIEF (fix surface · Q1 done? · who) |
|---|---|---|---|
| `1218323812563047` | NOW | [defect] G-AL#board: an ERRAND session can never green the gate — the documented escape ha | — |
| `1218281434871161` | NEXT | [defect] G-AW drill-census step: guard@3556 would VANISH SILENTLY (G-AI red) and its two b | — |

## How to close one

1. **Read the card first** — several carry a prior session's measurements in the body. That is
   free context you would otherwise pay to rediscover.
2. **The undo comes FIRST.** `.bak`, a commit, or a tag, before the edit.
3. Fix it, then **verify it yourself** — run the thing, read the log, hit the route. A green
   claim you did not witness is what MANAGEMENT BY WALKING AROUND exists for.
4. `python3 ~/Scripts/bb-close.py --gid G --reason "<what you did, what proves it, how to undo>"`
   — the reason is the receipt a stranger reads in a fortnight; ≥20 chars, name the commit sha.
5. **Cheap kills are legitimate work** (divide ADR Q1/Q2): a card that is already done, or no
   longer necessary, closes on MEASURED evidence — cite the sha / the grep / the date in the reason.
6. **THE DOOR (Rule of One):** a finding that is one repo + ≤3 files + no missing secret + a commit
   undoes it is FIXED THIS INNING, not carded. File a card ONLY via `~/Scripts/sm-file file --repo R --kind K --reason CODE`.
7. **A card you cannot close is a finding.** Open a decision (`--needs-ceo` if it needs the desk),
   say so on the card, move on. Do NOT grind. The desk rules promptly.
8. **If a card is MISFILED — the fix surface is not this repo — say so and open a decision.**
   If a lane says a card is misfiled it is probably right; the desk will rule it promptly.
9. **The card you route away from must say where the work went** (smDrainDesk-02, 2026-09-05):
   "routed" and "abandoned" look identical from the source gid. Comment on THIS gid before you leave it.
10. **Commit + push by pathspec every inning** (`git add <exact paths>`; never `-A`). If a fix lands
    in a SIBLING repo, claim it on the roster first (`~/Scripts/roster claim --who <you> --repo R --task "..."`; there is no --why).

## Lane-specific notes from the desk

(none)

## Definition of done
Every one of the 2 card(s) in the frozen manifest lane-sweepGates.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh sweepGates` exits 0.
