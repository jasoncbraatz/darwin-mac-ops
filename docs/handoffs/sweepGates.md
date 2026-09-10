---
project: "sweepGates"
session_n: 1
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "c227f9a942296d6f34142e1d6715fe0694912ac6"
updated: "2026-09-10"
definition_of_done: "Every one of the 2 card(s) in the frozen manifest lane-sweepGates.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh sweepGates` exits 0."
verify_cmd: "bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh sweepGates"
ruler_files: ["/Users/jasoncbraatz/repos/claude-blackbook/state/smdrain/lane-sweepGates.json", "/Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh"]
engine_sha: "8775c04ece0cf9f367a4a017bf26a03d51e708fc"
lessons_consulted: ["2026-09-09-known-broken-darwin-mac-ops-state", "2026-09-08-build-census-ask-declines-count-answer", "2026-08-19-readme-names-escape-hatch-evidence-escape"]
live_theme: "session 1: both cards CLOSED with receipts, RULER GREEN 2/2. The lane is DONE."
phase: "2/2 closed. RULER GREEN. DoD MET — `complete` run this inning."
gate_passed: false
next_at_bat: "NOTHING — the phase is DONE. Do not continue this lane. If a heartbeat still hands you sweepGates, that is a rail bug worth reporting, not an at-bat. The two findings in 'Teed up, NOT absorbed' below belong to OTHER lanes and must not be dragged in here."
blockers: []
drift_flags: []
parking_lot: []
---

# sweepGates — LIVING HANDOFF

## THE PHASE IS DONE. Ask no further at-bats of this lane.

`bash scripts/verify-smdrain.sh sweepGates` → **`RULER GREEN — 2/2 done (2 closed, 0 handed)`, exit 0**,
run 2026-09-10 after both closes. Both cards carry a bb-close.py receipt naming the sha and the undo.
Nothing is parked; nothing was handed; the manifest was never touched.

## What session 1 did

**Card `1218281434871161` (G-AW / G-AI + G-AK) — CHEAP KILL, already fixed.**
darwin-mac-ops **366a80b** (2026-09-08 18:43Z) fixed both halves *eight minutes after the card
was filed* at 18:34Z — the filer (`fable-braatz911-06`) could not claim the repos and so could
not see it land. Re-verified on 2026-09-10 against main @53a204e:
- `bash gate-cannot-verify-drill.sh` → `49 instrument guard(s): 47 speak, 2 ratified-quiet, **0 would VANISH**`, exit 0.
  The card's premise was itself wrong in an interesting way: guard@3556 always spoke. The *drill's*
  case-arm depth walk miscounted it (a missing `)` in the opener alternation), so the fix was to the
  COUNTER, not to the guard. A false VANISH, not a real one.
- `bash ratification-census.sh` → zero `UNKNOWN EXCEPTION RECORD`; both baselines are registered AND
  checked by delegation to their owning tools.

**Card `1218323812563047` (G-AL#board errand hatch) — FIXED, darwin-mac-ops `1834277`.**
The card asked for a new "errand signal". It did not need one. The gate already HAS an explicit
errand signal — `gate_charter_is_na` + `GATE_UNCHARTERED`, routing G-AL and G-AL#board to `gate_na`.
The entire defect was that **the hatch the roster join banner documents is spelled differently**:
`ROSTER_FOUNDING_CHECK=0` reached `roster:361`'s founding check and stopped, and nothing anywhere
said the gate wanted a different word. So `gate_charter_is_na` now accepts either spelling of the
same assertion. **The measured half is untouched and is the whole guarantee** — the key must still
resolve to NO charter row, so a chartered project that merely forgot to register still goes red
under both names.

Witnessed with the card's own repro, not just at the predicate:
```
GATE_ROSTER_WHO=opus-boxUnlock-01 ROSTER_FOUNDING_CHECK=0 bash gate-selfcheck.sh
  n/a    G-AL#board does not apply here -- no charter, so no generated DONE board exists to be stale
  GATE SELF-CHECK: FAIL ❌  (3 issue(s) — fix before writing the handoff)
```
Zero checks NEVER RAN. Before: `FAIL (0 issue(s), 1 check(s) NEVER RAN)` — the unclearable red.
Force function: `gate-charter-drill.sh` 40 → **43 controls (18 negative)**, both directions of the
new spelling plus "`ROSTER_FOUNDING_CHECK=1` buys nothing"; the two pre-existing negative controls
now `unset` BOTH names inside their subshell, because a control that inherits a declaration from
the runner's shell measures that shell and not the predicate.

## The one thing that cost this inning 12 minutes — READ THIS

**The rail lane runs on `feynman` (Linux), and `rail.py` FORWARDS every verb to the darwin board
host over ssh.** So `rail.py ruler show --project sweepGates` answered — truthfully — `status:
frozen, file_inputs: 2` about *darwin's* bytes, while on the box I was standing on
`state/smdrain/lane-sweepGates.json` did not exist at all and the verify_cmd died with a
`FileNotFoundError` traceback. That looks exactly like a ruler defect and is not one: the local
checkouts were simply behind. `git -C ~/code/darwin-mac-ops pull --ff-only` and
`git -C ~/repos/claude-blackbook pull --ff-only` produced the handoff and the manifest.
**Pull BOTH repos before you conclude anything about the ruler.** Banked as a lesson.

## Teed up, NOT absorbed (these belong to OTHER lanes — do not drag them in here)

Noticed in passing while witnessing card 2. Both are outside this lane's repo, so the Rule of One
sends them elsewhere rather than into this claim:

1. **`ratification-census.sh` now reds on a stale `bb-writers-allowlist.json` entry** — the pattern
   `~/repos/claude-blackbook/state/sm-intake/intake.jsonl` matches no file since that path was
   deleted in claude-blackbook (visible in this morning's pull). The census's own remedy is
   "Delete it." One line, in **claude-blackbook**, not darwin-mac-ops.
2. **3 dead `REF-OK:` declarations** excuse a reference that now resolves, or that the handoff no
   longer cites. Retire with
   `/usr/bin/python3 ~/code/darwin-mac-ops/handoff-reference-integrity.py --handoff <handoff>`.
   This one IS in darwin-mac-ops but is not in either card's fix surface and would have widened a
   green lane's diff on its last inning.

Also standing and pre-existing, surfaced by the errand repro: **`G-R#drill` fails its own selftest
(1 control)** — `handoff-reference-integrity.py --selftest`. A check that can no longer tell a 404
from a 403 is worth someone's inning; it is not worth this one's.

## The ruler (unchanged, never touched)

`verify_cmd` is the blackbook verifier; `ruler_files:` names the manifest and the verifier and
rail.py digests both at rail-on. The manifest was not edited, amended, or narrowed. No park was
needed — `park` requires a CEO ruling and neither card needed one.

## Definition of done
Every one of the 2 card(s) in the frozen manifest lane-sweepGates.json is closed on the State Machine with a bb-close.py receipt (or PARKED by a CEO ruling via smdrain-lane.py park), and `bash /Users/jasoncbraatz/repos/claude-blackbook/scripts/verify-smdrain.sh sweepGates` exits 0.

**MET.** 2/2 closed with receipts; ruler exits 0.
