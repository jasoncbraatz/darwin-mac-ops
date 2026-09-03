---
project: smDrainHandoff
session_n: 1
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "ce21ccb390aaf9a3ae5138e007a27968c753e6c8"
updated: "2026-09-03"
definition_of_done: "Every card in state/smdrain/lane-handoff.json is closed on the State Machine with a bb-close receipt, i.e. verify-smdrain.sh handoff exits 0"
verify_cmd: "bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff"
lessons_consulted: ["2026-09-03-estate-has-recurring-defect-shape", "2026-08-29-never-close-card-have-opened-card", "2026-09-03-classifying-estate-s-own-cards-match"]
live_theme: "session 0 — this skeleton was written by `rail.py handoff-init` and nobody has played an inning yet"
phase: "SESSION 0. No inning has been played. The next worker's first act is to replace next_at_bat below with a real one."
gate_passed: false
next_at_bat: "PLACEHOLDER — `rail.py handoff-init` wrote this, not a worker. Nobody has decided what the first at-bat is. Read docs/NORTH-STAR.md (write one if it is missing), then replace this line with ONE numbered at-bat that a stranger could start on, and set verify_cmd above to a command that decides the definition_of_done."
blockers: []
drift_flags: []
parking_lot: []
---

# smDrainHandoff — LIVING HANDOFF

## Read first
`docs/NORTH-STAR.md` (the invariants and the destination), then run the `verify_cmd` in the
frontmatter above. Its RED lines are the at-bat and its GREEN lines are the guard rails.

## Where this came from
`rail.py handoff-init --project smDrainHandoff` wrote this file as a SKELETON so an unattended
worker would not arrive at a repo with no at-bat. Everything below the frontmatter is a
placeholder. The first worker to play an inning here rewrites all of it.

## Is the phase DONE?
No — no inning has been played. Ask this question explicitly in every handoff from here on:
a milestone that is met but never declared keeps getting continued.
