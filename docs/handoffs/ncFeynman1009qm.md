---
project: "ncFeynman1009qm"
session_n: 0
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: ""
updated: "2026-10-09"
definition_of_done: "Every one of the 1 card(s) in the frozen manifest lane-ncFeynman1009qm.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncFeynman1009qm` exits 0."
verify_cmd: "bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncFeynman1009qm"
ruler_files: ["$HOME/repos/claude-blackbook/state/smdrain/lane-ncFeynman1009qm.json", "$HOME/repos/claude-blackbook/scripts/verify-smdrain.sh"]
engine_sha: "23507861ee8917c40f52a7033d1a69611603c36a"
lessons_consulted: []
live_theme: "session 0: lane armed by the CEO desk from the 2026-10-10 freeze; no work yet."
phase: "0/1 closed. RULER RED (expected before any work)."
gate_passed: false
next_at_bat: "Run the verify_cmd; take the first OPEN gid in the table below; read the card on Asana (the body carries prior sessions' measurements), fix it reversibly, verify it yourself, bb-close.py with a receipt. One card per inning is fine; two is better; a card you cannot close is a finding: a big_worker/Fable lane RULES its own reversible park (THE PROPERTY RULE, see the handoff body); only ruler amends, prod/TNT and Jason-values calls wait on someone else."
blockers: []
drift_flags: []
parking_lot: []
---

# ncFeynman1009qm — LIVING HANDOFF

## Read first
Run the `verify_cmd` in the frontmatter above FIRST. Its OPEN lines are the at-bat and its
closed lines are the guard rails. Then `docs/NORTH-STAR.md` if this repo has one.

## What this lane is

Jason asked the CEO desk to attack the State Machine backlog (target: 95% of the frozen workable
board). The board was FROZEN at **2026-10-10T02:35:16+00:00** (rule 1 of the `backlog.work` bat: never
count against a live board — an honest session FILES cards, so a live denominator makes good work
look like failure). 32 cards were workable at the freeze (NOW+NEXT; SOMEDAY is memory, not debt).

This lane is ONE CLUSTER of that freeze — **darwin-mac-ops: smBones QUALITY PASS (Jason 2026-10-09 'Go for it'). PROPERTY RULE + WWJD. Rule your own reversible calls --by estate; ruler amends need a DIFFERENT session; never touch a repo a LIVE session claims. Live systems are READ-ONLY unless a fix is reversible and proven: no n8n hub restart before 2026-10-10T09:00Z unless purely additive; never the live ledger db (copy it). Every red is fixed at the root or carded through sm-file -- never silenced.** — because a cluster is
one system, which is one repo, which is one claim. The cards were scoped by the repo they are
CLOSED IN, not the topic they share.

## The ruler is DECLARED, not shimmed

`verify_cmd` is the blackbook verifier and `ruler_files:` in the frontmatter names the manifest
and the verifier. rail.py (ff86a5b, `ruler_files:` DECLARED never inferred) digests both at
rail-on, so narrowing the manifest is a LOUD `RULER MOVED` (exit 2), not a silent pass — the
smDrainWisdom false complete (48327fb1) cannot recur here. The ENGINE (`smdrain-lane.py`) is
PINNED, not frozen: `engine_sha:` is its blob sha at arming (smDrainDesk-05 — a frozen engine
made every grader bugfix a RULER MOVED on every live lane).

**You may not edit the manifest.** A card you cannot close is a FINDING, not a failure.
**THE PROPERTY RULE (Jason, 2026-10-08): no other CEO is coming.** Rulings are made by any Fable or Opus >= 5.5,
naively, after reading the relevant spec. So WHO decides the park depends on what it touches:
  - **Reversible scope call** (park a card that needs another repo / a deploy / a design / a human login): if this lane
    runs on big_worker (Opus >= 5.5) or Fable, RULE IT YOURSELF -- `decision open --proj ncFeynman1009qm -q "..."` then
    `decision rule --id N --by estate --ruling "..." --rationale "<the measurement> ROLLBACK: drop the park row"` -- and
    park. Do NOT open `--needs-ceo` and stop: measured 2026-10-09, five lanes idled on exactly these questions.
    A mid_worker lane opens it `--needs-ceo --no-provisional` (a big-tier session rules it) and moves to the next card.
    `--no-provisional` matters: a PROVISIONAL row does not hold the rail, so a mid lane whose ONLY card waits on it
    re-confirms the same fact every inning (measured 2026-10-09, ncCurie1009cl: 10 innings on ruling #912). OPEN holds it.
  - **A ruler amendment** (any edit to a frozen ruler input): never your own -- propose the diff in a write-ruling;
    a DIFFERENT Fable/Opus session amends (`ruler amend --by estate-ceo:<who>`), rulings #871/#876.
  - **Prod data / deploys / money / a call Jason routed to someone by name**: open `--needs-ceo`, say so on the card,
    move on. The estate desk rules those with belts (dump first, test tenant only, his routing respected).
Then park: `python3 /Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py park --lane ncFeynman1009qm --gid G --why "<cite the ruling>"`
— it appends to a sibling file and never touches the ruler. Commit `state/smdrain/parked-ncFeynman1009qm.json`
in claude-blackbook by pathspec (that repo is NOT this lane's claim — commit only that file, say so in the message).

## The cards (FROZEN — do not add, do not remove)

BRIEF is the CEO desk's measured fix surface from the campfire (read on 2026-09-05 with the repo open).
It is a head start, not an order: if the card or the repo disagree with the brief, the repo wins — say so.

| gid | bin | card | BRIEF (fix surface · Q1 done? · who) |
|---|---|---|---|
| `1219367612917959` | NEXT | [process] quality pass: darwin-mac-ops gate-selfcheck + hooks-drill green on darwin | — |

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
Every one of the 1 card(s) in the frozen manifest lane-ncFeynman1009qm.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncFeynman1009qm` exits 0.

_Reconcile (local-feynman-9034-d 2026-10-10T02:56:39Z): cites 1219367612917959 "[process] quality pass: darwin-mac-ops gate-selfcheck + hooks-drill green on dar" — now CLOSED: NO-AAR: Quality pass on feynman 2026-10-09 (ncFeynman1009qm). hooks/hooks-drill.sh 42/0. gate-selfcheck has no --selftest flag; read as its self-drills, which are ALL green now. Full gate went 8->5 is_
