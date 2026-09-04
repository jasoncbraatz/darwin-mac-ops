---
project: smDrainGate2
session_n: 1
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "08e5786"
updated: "2026-09-04"
definition_of_done: "Every one of the 2 cards in the frozen manifest lane-gate2.json is closed on the State Machine with a bb-close.py receipt, and `bash docs/verify-smDrainGate2.sh` exits 0."
verify_cmd: "bash docs/verify-smDrainGate2.sh"
lessons_consulted: ["2026-09-04-freezing-acceptance-command-freezing-acceptance-criteria", "2026-09-04-smdrainmail-4-rail-py-s-ruler", "2026-09-03-fraction-target-work-board-unreachable-only", "2026-09-04-rewriting-handoff-every-inning-can-silently", "2026-09-04-pick-new-gate-letter-measuring-both"]
live_theme: "session 1 — both frozen cards closed, ruler GREEN, DoD met"
phase: "DONE. Both cards in lane-gate2.json are closed with bb-close.py receipts and the frozen ruler exits 0."
gate_passed: true
next_at_bat: "None — this lane is done. If a future session lands here anyway: re-run `bash docs/verify-smDrainGate2.sh` first; if it is still GREEN there is nothing to do, and landing on a finished charter without saying so is exactly the G-AL#done failure mode this session's own card-2 fix guards against."
blockers: []
drift_flags: []
parking_lot: []
---

# smDrainGate2 — LIVING HANDOFF

## Is the phase DONE?
**Yes.** Both cards below are closed with `bb-close.py` receipts, and
`bash docs/verify-smDrainGate2.sh` exits 0 (`RULER GREEN — every playable card in the lane is
closed`, 2/2). `rail.py complete` was run this session after this handoff was pushed — see
`rail_log` for the receipt rather than trusting this sentence (this file itself once warned the
project against exactly that trust failure — see "DoD revised" below).

## What this lane was
Jason asked the CEO desk to drain **one third** of the State Machine backlog (frozen
2026-09-04T16:07:24Z). This lane was ONE CLUSTER of that freeze — **gate-selfcheck.sh: two
checks the gate ships but does not know about itself** — scoped by the repo the cards are
CLOSED IN (`darwin-mac-ops`), per the CEO's routing rule.

## DoD revised mid-flight (read this if you inherited confusion)
Before this session started, `handoff_gate.py --stamp` overwrote this brand-new lane's
`definition_of_done` with an unrelated project's (root cause: `ledger_dod()` given `--project`
finds no row for it because `project-init` runs AFTER `--stamp` in `lane-open.sh`, and falls
through to a repo-name query that returns the repo's one *older* project). A CEO restored the
DoD before this session's inning began (`dod_revisions` row 15, `opus-smDrainDesk-02`). This
session's `dod-echo` matched it exactly (fence 1, `match=yes`) after one retry — the first
attempt dropped the backticks around `` `bash docs/verify-smDrainGate2.sh` ``, which is a good
reminder that the echo is graded on the LITERAL frozen string, not its paraphrase.

## The two cards — both closed this session

| gid | card | what happened |
|---|---|---|
| `1218099226884459` | G-AL#done guard turns G-AI red for every session | **Cheap kill.** Already fixed *before the card was even filed* — commit `30e67fc` (2026-09-02) had already added the missing `else` branch to the guard at `gate-selfcheck.sh` (the card's own inbound message references this exact commit range but the card survived the drain-freeze anyway). Verified: `bash gate-cannot-verify-drill.sh` reports `36 instrument guard(s): 35 speak, 1 ratified-quiet, 0 would VANISH` — 0 vanish is the pass condition the card names. Closed with a receipt citing the commit and the drill output, not just "looks fixed." |
| `1218165043650153` | G-AQ shipped in gate-selfcheck.sh with NO §G-AQ section and NO changelog entry | **Real fix.** `gate-selfcheck.sh` shipped `G-AQ` (an inherited thread survives the handoff, `handoff-thread-continuity.sh`) on 2026-09-03, and `~/Desktop/downloads/HANDOFF-GATE.md` never carried a `## G-AQ` section — v2.68 (shipped the next day) *named* the hole rather than closing it, which is the same G-L#35b/#35c drift class this file exists to catch, turned on itself. Backfilled: `## G-AQ` section inserted between `§G-AP` and `§G-AR`, v2.69 changelog entry, header version bump. **No range-ref bump needed** — v2.68 already carries `G-A→G-AR`, which numerically covers `G-AQ`, so the front-door range refs in the other 5 files are untouched (verified: still correct, not merely assumed). Undo: `HANDOFF-GATE.md.bak-smDrainGate2-session1` in `~/Desktop/downloads/`, or `git revert e518317` in `darwin-everything-meta`. Mirrored to `claude-blackbook` (v2.69) and pushed. Verified: `command grep -c 'G-AQ' HANDOFF-GATE.md` went 0→8; `gate-changelog-drill.sh` reports `C1 real file (v2.69) passes`; a full `gate-selfcheck.sh` run (59/59 internal drill checks passed) shows no G-L#35b/#35c or G-AQ failure/warning anywhere in its output. |

Neither fix touched this repo's own tree (`darwin-mac-ops`) — both edits landed in
`darwin-everything-meta` (`~/Desktop/downloads/HANDOFF-GATE.md`, commit `e518317`, pushed) and
its `claude-blackbook` mirror. `darwin-mac-ops` itself has no uncommitted changes from this
session other than this handoff file.

## Found in passing, NOT fixed (teed up, not smuggled)
Running the full `gate-selfcheck.sh` for verification surfaced pre-existing findings that are
**out of this lane's scope** (not gate/handoff cluster cards, not in the frozen manifest):
- `bb-writers-audit`: 6 unratified writers touching BB gid `1213050213165325` across
  `braatzio-plan` and `~/Scripts/cogs-mover` — not this repo, not this cluster.
- A ratchet-fail (6 baseline entries no longer offend and should retire) and a `G-L#35d` drift
  warning (`scripts/handoff_gate.py` copy vs `~/Scripts/handoff-kit/handoff_gate.py`) — both
  pre-existing, neither named in `lane-gate2.json`.
None of these are mine to fix under this DoD (the manifest is frozen at 2 cards and I may not
add to it); noting them here rather than silently walking past, per "find it, fix it" — the
fix here is naming it, since the manifest itself is not editable.

**Also noticed, separately real:** `gate-selfcheck.sh` carries a stray NUL byte (already a
banked TAX/FIX-ME leaf, `2026-09-04-tax-fix-me-code-darwin-mac`, unfixed ≥14d). It is sharper
than the leaf states: `grep` without `-a` treats the whole file as binary and returns **zero**
matches for a live search term (confirmed live: `grep -n "G-AQ" gate-selfcheck.sh` → 0 hits;
`grep -a -n "G-AQ" gate-selfcheck.sh` → the real hits). Any future session that greps this file
without `-a` gets a false "not found" — including, almost, this session, until `sed`
contradicted the `grep`. Worth retiring the tax rather than re-discovering this the hard way a
third time.

## Lesson used
`2026-09-04-pick-new-gate-letter-measuring-both` — corroborated: G-AQ's doc-parity hole was
exactly what that leaf predicted (a letter shipped in code with the doc never told).

## Standing constraints (unchanged, still true)
- Never make a live third-party write without opening a `--needs-ceo` decision first.
- You share darwin with siblings. `~/Scripts/roster who` before you edit; commit with a
  **pathspec**, never `git add -A`.
- Cheap kills are real work: card `1218099226884459` above is exactly that.
