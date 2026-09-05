---
project: "smDrainGate4"
session_n: 0
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "0a4e46046478672f83b0c3c3ab3ef8896c7a4992"
updated: "2026-09-05"
definition_of_done: "Every one of the 3 card(s) in the frozen manifest lane-gate4.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh gate4` exits 0."
verify_cmd: "bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh gate4"
ruler_files: ["/Users/jasoncbraatz/repos/claude-blackbook/state/smdrain/lane-gate4.json", "/Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh", "/Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py"]
lessons_consulted: ["2026-09-03-g-ae-gate-selfcheck-sh-launchd", "2026-08-15-aggregate-suppression-count-cannot-reveal-rule", "2026-08-08-secret-sweep-whose-output-95-upstream", "2026-08-03-gate-g-letters-namespace-allocator-they"]
live_theme: "session 0: lane armed by the CEO desk from the 2026-09-05 freeze; no work yet."
phase: "0/3 closed. RULER RED (expected before any work)."
gate_passed: false
next_at_bat: "Run the verify_cmd; take the first OPEN gid in the table below; read the card on Asana (the body carries prior sessions' measurements), fix it reversibly, verify it yourself, bb-close.py with a receipt. One card per inning is fine; two is better; a card you cannot close is a finding (park needs a ruling \u2014 open a decision)."
blockers: []
drift_flags: []
parking_lot: []
---

# smDrainGate4 — LIVING HANDOFF

## Read first
Run the `verify_cmd` in the frontmatter above FIRST. Its OPEN lines are the at-bat and its
closed lines are the guard rails. Then `docs/NORTH-STAR.md` if this repo has one.

## What this lane is

Jason asked the CEO desk to attack the State Machine backlog (target: 95% of the frozen workable
board). The board was FROZEN at **2026-09-05T17:21:48+00:00** (rule 1 of the `backlog.work` bat: never
count against a live board — an honest session FILES cards, so a live denominator makes good work
look like failure). 33 cards were workable at the freeze (NOW+NEXT; SOMEDAY is memory, not debt).

This lane is ONE CLUSTER of that freeze — **darwin-mac-ops: three gate-selfcheck gaps: G-AE has no category for ephemeral agents, G-AK found an allow rule that suppresses nothing, G-V#3 is unwinnable mid-drain (ruled #181)** — because a cluster is
one system, which is one repo, which is one claim. The cards were scoped by the repo they are
CLOSED IN, not the topic they share.

## The ruler is DECLARED, not shimmed

`verify_cmd` is the blackbook verifier and `ruler_files:` in the frontmatter names the manifest,
the verifier and its engine. rail.py (ff86a5b, `ruler_files:` DECLARED never inferred) digests
every one of them at rail-on, so narrowing the manifest is a LOUD `RULER MOVED` (exit 2), not a
silent pass — the smDrainWisdom false complete (48327fb1) cannot recur here.

**You may not edit the manifest.** A card you cannot close is a FINDING, not a failure:
open a decision (`python3 ~/repos/auto-bridge/abridge.py decision open --proj smDrainGate4 --needs-ceo -q "..."`),
say so on the card, move on. After the CEO rules, the park is
`python3 /Users/jasoncbraatz/repos/claude-blackbook/scripts/smdrain-lane.py park --lane gate4 --gid G --why "<cite the ruling>"`
— it appends to a sibling file and never touches the ruler. Commit `state/smdrain/parked-gate4.json`
in claude-blackbook by pathspec (that repo is NOT this lane's claim — commit only that file, say so in the message).

## The cards (FROZEN — do not add, do not remove)

BRIEF is the CEO desk's measured fix surface from the campfire (read on 2026-09-05 with the repo open).
It is a head start, not an order: if the card or the repo disagree with the brief, the repo wins — say so.

| gid | bin | card | BRIEF (fix surface · Q1 done? · who) |
|---|---|---|---|
| `1218198174895655` | NEXT | [process] gate-selfcheck G-AE: third launchd allowlist category for deliberately-ephemeral | gate-selfcheck.sh G-AE launchd allowlist has two categories; travel-mode-rearm needs a third: 'deliberately ephemeral, no persistent form'. FIRST measure the fail direction: run gate-selfcheck G-AE against the live launchd list and record whether it false-positives (flags a legit ephemeral agent) or false-negatives (accepts a job that should persist). Then add the category with a RETIRE-WHEN clause, and a drill case. ALSO: two plists shipped today have NO repo copy in darwin-mac-ops — com.braatz.fuel-probe (pitching-machine/launchagents/, installed 17:20Z) and com.braatz.dated-gates (ceo-desk, 09-05) — check G-AE reads a repo copy from those repos; if it only knows darwin-mac-ops, that is the false-positive to fix. Q1 done? NO. Who: this lane. Repo: ~/code/darwin-mac-ops (gate-selfcheck.sh is symlinked from ~/Scripts; COMMIT in darwin-mac-ops). |
| `1218218730885002` | NEXT | [process] gate-secret-sweep.allow: the tenancy-scan.py suppression matches nothing (G-AK s | gate-secret-sweep.allow: the entry for braatzio-plan/v3/tools/tenancy-scan.py suppresses NOTHING in today's sweep (G-AK census). Measure: run the sweep's per-rule replay (G-E, lesson 2026-08-15) to see which literals in tenancy-scan.py match now; either re-point the entry at the current literals or retire it if nothing matches; add a RETIRE-WHEN:/REVIEWED: clause. The allow file exists in TWO places (~/code/darwin-mac-ops/ and its deployed copy) — fix the repo copy, confirm the deployed one follows. braatzio-plan is claimed by a live sibling (parity-34): READ it, do not edit it. Q1 done? NO. Who: this lane. |
| `1218196762459024` | NEXT | [process] card-lint ratchet (G-V#3) is unwinnable during a live State-Machine drain — it m | RULED #181: a+b, b FIRST. (b) bb-close.py already reconciles citing CARDS; extend the same breath to citing HANDOFF DOCS: grep the closed gid across ~/Desktop/downloads/HANDOFF-*.md and every repo's docs/handoffs/*.md, append ONE dated reconcile line, pathspec-commit it (bb-close.py lives in ~/Scripts — claim that repo on the roster before editing; say so in the message). (a) then scope gate-selfcheck G-V#3 to docs the wrapping session touched/authored (the session ledger knows) and leave estate-wide staleness to the daily card-lint launchd job. Selftest both. Q1 done? NO. Who: this lane (dmo + a Scripts commit). |

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

- `~/Scripts/gate-selfcheck.sh` is a SYMLINK into `~/code/darwin-mac-ops/` — edit through it, COMMIT in darwin-mac-ops (`git -C ~/Scripts commit` reports nothing with a straight face).
- `bb-close.py` and `sm-file` live in `~/Scripts` (repo darwin-scripts) — for card 1218196762459024 part (b) you will touch that repo: `~/Scripts/roster claim --who <you> --repo Scripts --task "..."` FIRST, then a pathspec commit that names the sibling repo in its message.
- Rulings #180/#181 are on the ledger (`abridge.py decision show 181`). Cite them; do not re-derive.
- G-AE fail-direction measurement is the deliverable's first line — write the measured direction into the card comment before the fix.

## Definition of done
Every one of the 3 card(s) in the frozen manifest lane-gate4.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh gate4` exits 0.
