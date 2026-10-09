---
project: "ncCurie1009dm"
session_n: 1
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "3b99ab8df03d7221a59d46b228b2b8bc086f0a48"
updated: "2026-10-09"
definition_of_done: "Every one of the 2 card(s) in the frozen manifest lane-ncCurie1009dm.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm` exits 0."
verify_cmd: "bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm"
ruler_files: ["$HOME/repos/claude-blackbook/state/smdrain/lane-ncCurie1009dm.json", "$HOME/repos/claude-blackbook/scripts/verify-smdrain.sh"]
engine_sha: "858f4697dc887570b6f1500588f7e1b78b15ff97"
lessons_consulted: []
live_theme: "session 1: both frozen cards were already CLOSED on Asana before this lane's first inning began -- by nightCrew (fence 235, local-feynman-8822-m), which drains the same shared backlog without a per-lane manifest and reached these two gids first. RULER GREEN on claim."
phase: "2/2 closed (both pre-closed by nightCrew i234, with receipts, before this lane claimed). RULER GREEN."
gate_passed: true
next_at_bat: "DONE. Nothing left to fix: `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm` exits 0 (ssh darwin -- it is the board host; the manifest lane-ncCurie1009dm.json and bb-close receipts live there, not on this box). Both gids carry marked_complete + a receipt-shaped comment: 1218799021417865 'CLOSED -- nightCrew i234 ... fixed by darwin-mac-ops commit 6618385' and 1219234903451799 'NO-AAR: FIXED (pitching-machine/Scripts commit 552f806, not darwin-mac-ops)'. Next worker: confirm with rail.py status that ncCurie1009dm reads complete; if a sibling somehow reopened it, re-run the verify and re-check before doing any card work."
blockers: []
drift_flags: ["session 0's 'no work yet / RULER RED' line was written at arming time without a verify_cmd run -- it was wrong the moment nightCrew closed these two gids minutes later. Lesson banked: always run verify_cmd before trusting a freshly-armed lane's boilerplate phase line."]
parking_lot: []
---

# ncCurie1009dm — LIVING HANDOFF

## Read first
Run the `verify_cmd` in the frontmatter above FIRST. Its OPEN lines are the at-bat and its
closed lines are the guard rails. Then `docs/NORTH-STAR.md` if this repo has one.

## What this lane is

Jason asked the CEO desk to attack the State Machine backlog (target: 95% of the frozen workable
board). The board was FROZEN at **2026-10-08T10:57:25+00:00** (rule 1 of the `backlog.work` bat: never
count against a live board — an honest session FILES cards, so a live denominator makes good work
look like failure). 115 cards were workable at the freeze (NOW+NEXT; SOMEDAY is memory, not debt).

This lane is ONE CLUSTER of that freeze — **darwin-mac-ops: smBones estate lane (PROPERTY RULE 2026-10-08), carved from the night crew queue (an armed lane owns its cards). Judge first (STRATEGIC NO with receipt if moot/already done); fix S/M with a rollback; big_worker/Fable: RULE your own reversible scope calls --by estate (never --needs-ceo and stop); ruler amends need a DIFFERENT session (#871/#876); prod deploys/data/money/Jason-routed calls: --needs-ceo and move on; skip anything a LIVE session holds and name it.** — because a cluster is
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
    runs on big_worker (Opus >= 5.5) or Fable, RULE IT YOURSELF -- `decision open --proj ncCurie1009dm -q "..."` then
    `decision rule --id N --by estate --ruling "..." --rationale "<the measurement> ROLLBACK: drop the park row"` -- and
    park. Do NOT open `--needs-ceo` and stop: measured 2026-10-09, five lanes idled on exactly these questions.
    A mid_worker lane opens it `--needs-ceo` (a big-tier session rules it) and moves to the next card.
  - **A ruler amendment** (any edit to a frozen ruler input): never your own -- propose the diff in a write-ruling;
    a DIFFERENT Fable/Opus session amends (`ruler amend --by estate-ceo:<who>`), rulings #871/#876.
  - **Prod data / deploys / money / a call Jason routed to someone by name**: open `--needs-ceo`, say so on the card,
    move on. The estate desk rules those with belts (dump first, test tenant only, his routing respected).
Then park: `python3 /Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py park --lane ncCurie1009dm --gid G --why "<cite the ruling>"`
— it appends to a sibling file and never touches the ruler. Commit `state/smdrain/parked-ncCurie1009dm.json`
in claude-blackbook by pathspec (that repo is NOT this lane's claim — commit only that file, say so in the message).

## The cards (FROZEN — do not add, do not remove)

BRIEF is the CEO desk's measured fix surface from the campfire (read on 2026-09-05 with the repo open).
It is a head start, not an order: if the card or the repo disagree with the brief, the repo wins — say so.

| gid | bin | card | BRIEF (fix surface · Q1 done? · who) |
|---|---|---|---|
| `1219234903451799` | NEXT | [defect] reference-guard refuses every builder commit to braatzio-plan serve.py: it guards | — |
| `1218799021417865` | NEXT | [defect] wrap gate blames the wrapping session for a dirty file older than its own join (D | — |

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

## Session 1 — found already green

Ran the verify_cmd FIRST (per "Read first" above), over `ssh darwin` since curie is a twin and
the lane manifest + bb-close receipts live on the board host, not this box's filesystem. Result:

```
LANE ncCurie1009dm (darwin-mac-ops) — 2/2 done (2 closed, 0 handed)
RULER GREEN — every playable card in the lane is closed or handed
```

Both gids were marked `completed` on Asana (1218799021417865 at 2026-10-08T22:21:38Z,
1219234903451799 at 2026-10-08T20:58:46Z) with receipt-shaped comments, by `nightCrew` (fence 235,
local-feynman-8822-m) — a sibling lane that drains the same shared backlog without a per-card
manifest, and reached both of these gids before ncCurie1009dm's own claim/arming finished. Checked
via the live Asana API (`asana_client.AsanaClient`, run on darwin): both tasks' story feed shows
`comment_added` with a receipt immediately followed by `marked_complete`, same shape as a
`bb-close.py` run. Nothing left to fix; no card work needed this inning.

## Definition of done
Every one of the 2 card(s) in the frozen manifest lane-ncCurie1009dm.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm` exits 0.
