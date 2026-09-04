---
project: smDrainGate2
session_n: 1
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: ""
updated: "2026-09-04"
definition_of_done: "Every one of the 2 cards in the frozen manifest lane-gate2.json is closed on the State Machine with a bb-close.py receipt, and `bash docs/verify-smDrainGate2.sh` exits 0."
verify_cmd: "bash docs/verify-smDrainGate2.sh"
lessons_consulted: ["2026-09-04-freezing-acceptance-command-freezing-acceptance-criteria", "2026-09-04-smdrainmail-4-rail-py-s-ruler", "2026-09-03-fraction-target-work-board-unreachable-only", "2026-09-04-rewriting-handoff-every-inning-can-silently"]
live_theme: "session 0 — this skeleton was written by `rail.py handoff-init` and nobody has played an inning yet"
phase: "SESSION 0. No inning has been played. The next worker's first act is to replace next_at_bat below with a real one."
gate_passed: false
next_at_bat: "Take the TOPMOST still-open card in the table below, close it end to end (read it, build the undo FIRST, fix, verify it yourself, then bb-close.py with a receipt), and re-run the ruler. ONE card, start to finish."
blockers: []
drift_flags: []
parking_lot: []
---

# smDrainGate2 — LIVING HANDOFF

## Read first
`docs/NORTH-STAR.md` (the invariants and the destination), then run the `verify_cmd` in the
frontmatter above. Its RED lines are the at-bat and its GREEN lines are the guard rails.

## Where this came from
`rail.py handoff-init --project smDrainGate2` wrote this file as a SKELETON so an unattended
worker would not arrive at a repo with no at-bat. Everything below the frontmatter is a
placeholder. The first worker to play an inning here rewrites all of it.

## Is the phase DONE?
No — no inning has been played. Ask this question explicitly in every handoff from here on:
a milestone that is met but never declared keeps getting continued.


## What this lane is

Jason asked the CEO desk to drain **one third** of the State Machine backlog. The board was
FROZEN at **2026-09-04T16:07:24Z** (rule 1 of the `backlog.work` bat: never count against a live board —
an honest session FILES cards, so a live denominator makes good work look like failure).
98 cards were workable at the freeze (NOW+NEXT; SOMEDAY is memory, not debt).

This lane is ONE CLUSTER of that freeze — **gate-selfcheck.sh: two checks the gate ships but does not know about itself** — because a cluster is one system, which
is one repo, which is one claim.

## The ruler, and why it is a shim in THIS repo

`docs/verify-smDrainGate2.sh` is the frozen ruler. It does not just call the blackbook verifier; it
**pins the manifest's sha256 first**. Measured by opus-smDrainDesk-02 on 2026-09-04: rail.py's
`ruler_digest()` hashes only files the verify_cmd NAMES *and* that resolve under this repo, so
all eleven ruler rows from the 09-03 drain froze with `files={}` — the manifest, which IS the
acceptance criteria in data form, was never covered. Narrowing a manifest is how smDrainWisdom
recorded a false `complete` (48327fb1). The shim makes that a LOUD `RULER MOVED` (exit 2), and
the negative control was run before arming: narrowing this lane's manifest 5→2 produced exit 2.

**You may not edit the manifest.** A card you cannot close is a FINDING, not a failure:
`python3 /Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py park --lane gate2 --gid G --why "<cite the ruling>"`
after the CEO rules it — `park` appends to a sibling file and never touches the ruler.

## The cards (FROZEN — do not add, do not remove)

| gid | bin | card |
|---|---|---|
| `1218165043650153` | NEXT | [process] G-AQ shipped in gate-selfcheck.sh with NO S-G-AQ section and NO changelog entry — G-L#35b/ |
| `1218099226884459` | NEXT | [ipc → fable-luxuryDesk-18] your G-AL#done guard turns G-AI red for every session |

## How to close one

1. **Read the card first** — several carry a prior session's measurements in the body. That is
   free context you would otherwise pay to rediscover.
2. **The undo comes FIRST.** `.bak`, a commit, or a tag, before the edit.
3. Fix it, then **verify it yourself** — run the thing, read the log, hit the route. A green
   claim you did not witness is what MANAGEMENT BY WALKING AROUND exists for.
4. `python3 ~/Scripts/bb-close.py --gid G --reason "<what you did, what proves it, how to undo>"`
5. **A card you cannot close is a finding.** Open a decision
   (`python3 ~/repos/auto-bridge/abridge.py decision open --proj smDrainGate2 … [--needs-ceo]`),
   say so on the card, move on. Do NOT grind.
6. **If a card is MISFILED — the fix surface is not this repo — say so and open a decision.**
   The CEO scoped these by the repo the card is CLOSED IN, not the topic it shares. If a lane
   says a card is misfiled it is probably right; the desk will rule it promptly.

## Standing constraints

- Never make a live third-party write (Shopify admin, DNS, a production mailbox, a
  customer-facing send) without opening a `--needs-ceo` decision first. Reading is free.
- You share darwin with siblings. `~/Scripts/roster who` before you edit; commit with a
  **pathspec** (`git commit -- <paths>`), never `git add -A`.
- Cheap kills are real work: "is this already taken care of?" and "is this still necessary?"
  close cards on MEASURED evidence.
- Student-in / teacher-out is not optional. Bank a leaf the moment something hurts.

lessons consulted: 2026-09-04-freezing-acceptance-command-freezing-acceptance-criteria, 2026-09-04-smdrainmail-4-rail-py-s-ruler, 2026-09-03-fraction-target-work-board-unreachable-only, 2026-09-04-rewriting-handoff-every-inning-can-silently
