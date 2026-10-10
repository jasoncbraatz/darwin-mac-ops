---
project: "ncCurie1009dm2"
session_n: 1
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "e0ac4c1f9a69b7fd206cefe9ff789ace289ebba0"
updated: "2026-10-09"
definition_of_done: "Every one of the 1 card(s) in the frozen manifest lane-ncCurie1009dm2.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm2` exits 0."
verify_cmd: "bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm2"
ruler_files: ["$HOME/repos/claude-blackbook/state/smdrain/lane-ncCurie1009dm2.json", "$HOME/repos/claude-blackbook/scripts/verify-smdrain.sh"]
engine_sha: "23507861ee8917c40f52a7033d1a69611603c36a"
lessons_consulted: ["2026-10-09-estate-audit-2026-10-09-sm"]
live_theme: "session 1: closed the only card (1219355290378801) by writing docs/host/REMOTE-ACCESS.md -- darwin's own SSH/sshd, pmset, and firewall state, read-only, cross-linked from README.md."
phase: "1/1 closed. RULER GREEN."
gate_passed: true
next_at_bat: "DONE. All 1 card(s) in the frozen manifest are closed and verify_cmd is RULER GREEN. The next session should confirm the ruler is still green (nobody can add cards to a frozen manifest) and run rail.py complete for this project/fence. No further card work exists for this lane."
blockers: []
drift_flags: []
parking_lot: []
---

# ncCurie1009dm2 — LIVING HANDOFF

## Read first
Run the `verify_cmd` in the frontmatter above FIRST. Its OPEN lines are the at-bat and its
closed lines are the guard rails. Then `docs/NORTH-STAR.md` if this repo has one.

## What this lane is

Jason asked the CEO desk to attack the State Machine backlog (target: 95% of the frozen workable
board). The board was FROZEN at **2026-10-09T16:45:07+00:00** (rule 1 of the `backlog.work` bat: never
count against a live board — an honest session FILES cards, so a live denominator makes good work
look like failure). 37 cards were workable at the freeze (NOW+NEXT; SOMEDAY is memory, not debt).

This lane is ONE CLUSTER of that freeze — **darwin-mac-ops: smBones estate lane (PROPERTY RULE + WWJD 2026-10-09). Judge first; fix with a rollback; never touch a repo a LIVE session claims; write every tool for every box. mid_worker: open any scope call --needs-ceo --no-provisional and move on. BOX AS A SUBJECT: DOCUMENT ONLY. Read the box state (read-only commands), write it into the repo, and commit. Do NOT change sshd, users, keys, firewall, or packages. Anything that SHOULD change becomes its own sm-file card with the evidence.** — because a cluster is
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
    runs on big_worker (Opus >= 5.5) or Fable, RULE IT YOURSELF -- `decision open --proj ncCurie1009dm2 -q "..."` then
    `decision rule --id N --by estate --ruling "..." --rationale "<the measurement> ROLLBACK: drop the park row"` -- and
    park. Do NOT open `--needs-ceo` and stop: measured 2026-10-09, five lanes idled on exactly these questions.
    A mid_worker lane opens it `--needs-ceo --no-provisional` (a big-tier session rules it) and moves to the next card.
    `--no-provisional` matters: a PROVISIONAL row does not hold the rail, so a mid lane whose ONLY card waits on it
    re-confirms the same fact every inning (measured 2026-10-09, ncCurie1009cl: 10 innings on ruling #912). OPEN holds it.
  - **A ruler amendment** (any edit to a frozen ruler input): never your own -- propose the diff in a write-ruling;
    a DIFFERENT Fable/Opus session amends (`ruler amend --by estate-ceo:<who>`), rulings #871/#876.
  - **Prod data / deploys / money / a call Jason routed to someone by name**: open `--needs-ceo`, say so on the card,
    move on. The estate desk rules those with belts (dump first, test tenant only, his routing respected).
Then park: `python3 /Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py park --lane ncCurie1009dm2 --gid G --why "<cite the ruling>"`
— it appends to a sibling file and never touches the ruler. Commit `state/smdrain/parked-ncCurie1009dm2.json`
in claude-blackbook by pathspec (that repo is NOT this lane's claim — commit only that file, say so in the message).

## The cards (FROZEN — do not add, do not remove)

BRIEF is the CEO desk's measured fix surface from the campfire (read on 2026-09-05 with the repo open).
It is a head start, not an order: if the card or the repo disagree with the brief, the repo wins — say so.

| gid | bin | card | BRIEF (fix surface · Q1 done? · who) |
|---|---|---|---|
| `1219355290378801` | SOMEDAY | [process] darwin as a SUBJECT: record its own remote access + credential model, re-assert  | **CLOSED session 1** (3d8c44c) |

## Session 1 (2026-10-09) — closed the lane

Found that `darwin-remote-access` (a separate repo) already documents VNC/ttyd/WireGuard for
darwin-as-subject reasonably well, but was missing from this repo's "Related repos" table and
didn't cover the three things the 2026-10-09 estate audit (SM 1218729017558178) flagged as
undocumented anywhere: SSH/sshd's own config + `authorized_keys`, `pmset`, and the Application
Firewall. Gathered all of it read-only over SSH to darwin (no box config touched) and wrote
`docs/host/REMOTE-ACCESS.md`, cross-linked from `README.md` alongside a new `darwin-remote-access`
row in Related repos. Closed `1219355290378801` with a receipt citing commit `3d8c44c`.
`verify-smdrain.sh ncCurie1009dm2` now reports **RULER GREEN**.

Two findings carried in the doc, not fixed (document-only lane, property rule): `pmset`'s
always-on settings (`SleepDisabled`, `womp`, etc.) and the Application Firewall's current
OFF state are both hand-set with no re-assertion script anywhere — neither is a 3-file/one-commit
fix, and firewall-on-or-off is a security-posture call for the estate desk, not this lane.

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
Every one of the 1 card(s) in the frozen manifest lane-ncCurie1009dm2.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash $HOME/repos/claude-blackbook/scripts/verify-smdrain.sh ncCurie1009dm2` exits 0.

_Reconcile (ncFeynman1010tl 2026-10-10T21:16:05Z): cites 1218729017558178 "[process] Audit: which boxes are documented only as the FLOOR, not as subjects w" — now CLOSED: closed earlier (reconcile-only)_
