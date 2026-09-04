---
project: smDrainHandoff
session_n: 2
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "7017b830b57eb7616d4e5c382dbae691429085f0"
updated: "2026-09-04"
definition_of_done: "Every card in state/smdrain/lane-handoff.json is closed on the State Machine with a bb-close receipt, i.e. verify-smdrain.sh handoff exits 0"
verify_cmd: "bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff"
lessons_consulted: ["2026-09-03-handoff-written-from-session-memory-loses", "2026-09-03-run-gate-selfcheck-sh-before-roster", "2026-08-07-before-wiring-new-gate-selfcheck-section"]
live_theme: "the gate is right that something is wrong and wrong about WHOSE it is — seven of the seventeen cards are that one sentence"
phase: "DRAINING. 17 cards frozen, session 1 closed 2. Not done — ask again every inning."
gate_passed: false
next_at_bat: "1218125780430801 — gate-selfcheck blames the WRAPPING session for an unrostered sibling's dirty repo. Same family as the two closed in session 1 (misattribution), and 8b543f4 already built the machinery it needs: G-H#22c-content asks the LEAF who signed a file via attribute.py. Read _paths_owned_by_sibling() at gate-selfcheck.sh:~236 — it fails closed on ONE unattributable path, which is correct for laundering and wrong for an UNROSTERED sibling (a sibling that never joined the board has no slug to match, so every one of its files is unattributable and the whole repo is 'reported as YOURS'). The card names G-H#22c/e/f as all missing it."
blockers: []
drift_flags: []
parking_lot: ["The lane manifest lives at ~/repos/claude-blackbook/state/smdrain/lane-handoff.json, NOT in darwin-mac-ops — the DoD sentence reads as if it were repo-relative and it is not. Do not go looking for state/ in this repo.", "SM card 1218163994701439 (clobber-tripwire) says lane-handoff.json was OVERWRITTEN in a shared checkout by local-mbp2024-55818-b. The manifest read fine this inning (17 cards, digest intact, ruler graded), but if a future inning finds the card list changed, that is the ruler moving underneath the lane — open a decision, do NOT edit the manifest."]
---

# smDrainHandoff — LIVING HANDOFF

## Read first
`docs/NORTH-STAR.md` does not exist in this repo (checked, session 1). `README.md` is the
nearest thing: darwin-mac-ops is the runbook that rebuilds Jason's Mac in an hour, and
`gate-selfcheck.sh` — the mechanical half of HANDOFF-GATE.md — lives here and is **symlinked
into `~/Scripts`**. That symlink is why the merge in §6 is not tidying: the moment
`rail/smDrainHandoff` lands on `main`, every session on the machine is running your edit.

Then run the ruler:

    bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff

## The lane
17 frozen cards, `~/repos/claude-blackbook/state/smdrain/lane-handoff.json`, everything whose
fix surface is `gate-selfcheck.sh` / the gate drills / the handoff kit. **2 of 17 closed.**

## Session 1 (2026-09-03, local-mbp2024-18253) — what moved

Closed, both with bb-close receipts:

- **1218054982400791** — *gate-selfcheck can never go green for a scheduled/unchartered session.*
  Implemented the card's own sketch (a). `GATE_UNCHARTERED="<reason>"` makes G-AL print
  **N/A** instead of a warn, and G-AL#board take an **explicit else** that is NOT counted in
  SKIPPED. New `gate_na()` + `NA[]` ledger sit beside `gate_skipped()`; the N/A block prints
  above BOTH verdicts so a reader can tell *did not apply* from *did not run*.
  The anti-abuse property is structural, not a check: the opt-out branch is only reachable
  when `charter-read.sh --resolve` finds **no** row, so a chartered project that exports the
  variable is still graded and can still FAIL. `gate_charter_is_na()` is a named predicate
  precisely so the drill executes the real text (same trick as `gate_verdict_is_pass`).
- **1218126486445244** — *gate-selfcheck blamed roster-ghost-drill.sh for roster-identity-drill.sh's failure.*
  MEASURED FIRST, and the finding is not what the card assumed: the loop's `$_rdname` has been
  correct since e506639 (2026-08-15), and both drills now use `mktemp` (Scripts@6a00ebc fixed
  identity; ghost was fixed by smBacklog-7). The 2026-09-03 red was ghost genuinely exiting 2
  as collateral from the shared fixed `/tmp` path. So the misattribution *report* was real and
  its stated root cause was not. What survives is the card's own second ask, and it is the
  durable half: **nothing anywhere asserted the reported name matches the drill that failed.**
  Extracted the name-and-remedy into `gate_roster_line()` and drilled it against fixtures.

Both landed as controls in `gate-charter-drill.sh` (already wired into the gate), which now
runs **34 controls, 16 of them negative**, up from 28/10. New negatives worth keeping:
a chartered project cannot opt out; silence is not consent; an empty reason buys nothing;
the finding must name the failing drill **and must not name the innocent one** (that second
column is the whole card — the message doubles as the command the reader will run).

EVIDENCE, run, not asserted:

    # before (reproduces the card exactly)
    GATE_ROSTER_WHO=cloud-atxFanoutConfirm bash gate-selfcheck.sh --quiet
    -> FAIL (5 issue(s), 1 check(s) NEVER RAN)
       ! G-AL#board NEVER RAN: project 'cloudatxfanoutconfirm' has no charter row

    # after
    GATE_ROSTER_WHO=cloud-atxFanoutConfirm \
    GATE_UNCHARTERED="9am ATX fan-out confirmation (scheduled routine, not a chartered project)" \
      bash gate-selfcheck.sh --quiet
    -> FAIL (5 issue(s))  -- note: NO "check(s) NEVER RAN" clause any more
       n/a  G-AL does not apply here -- unchartered by design (...)
       n/a  G-AL#board does not apply here -- no charter, so no generated DONE board
       the same 5 issues as before, none of them G-AL's: which IS the card's own
       done-when ("exits non-zero for reasons OTHER than G-AL/G-AL#board, and says
       out loud that the charter check was N/A rather than failed").

    GATE_SELFCHECK=$PWD/gate-selfcheck.sh bash gate-charter-drill.sh
    -> drill: PASS — 34 controls

Undo: `gate-selfcheck.sh.bak-smDrainHandoff1-20260903`,
`gate-charter-drill.sh.bak-smDrainHandoff1-20260903`, both committed alongside.

## Is the phase DONE?
**No. 2 of 17.** Ask this question explicitly every inning — a milestone that is met but never
declared keeps getting continued.

## The shape of what is left (read this before picking)
Seven of the fifteen remaining cards are one sentence: **the gate is right that something is
wrong and wrong about whose it is.** 1218125780430801 (dirty repo blamed on the wrapper),
1218147386804343 (orphan reds not registered so `red-owner.py transfer` refuses them),
1218153310094177 (G-V + G-AE red over live sibling lanes' work), 1217721634749933 (G-AL
accepts a SIBLING's charter stamp). Session 1 closed two more of the same family. Whoever
picks one should read all four: the fix surface is the same attribution machinery
(`_paths_owned_by_sibling`, `attribute.py`, the roster) and doing them one at a time is how
you write the same helper four times.

Three are about the handoff itself and are the reason this lane exists at all:
1218152478656223 (anti-string-of-pearls has no teeth — a carried thread needs a one-line
`verify:` or it dies silently), 1218142549980676 (cold sessions can't see a prior
incarnation's progress), 1217654200494124 (G-AM: a handoff that ASSERTS an exit code must
have it re-run). Note the irony available to whoever takes 1218152478656223: **this file**
is the artefact under test.

## Gotchas paid for in session 1
- **`grep` needs `-a` on `gate-selfcheck.sh`.** The file is UTF-8 with 554-char lines and
  plain `grep -n roster gate-selfcheck.sh` returns NOTHING, exit 1 — indistinguishable from
  "the code isn't there". It cost this session a wrong conclusion before `file(1)` caught it.
- **The gate takes minutes to run.** A control that shells out to the whole gate is not a
  control you can iterate on; extract the predicate BY NAME and execute that instead. There is
  house precedent in `gate-skipped-drill.sh`.
- **`env -u FOO shellfunc` does not test a shell function** — `env` execs a program, so the
  control "passes" by failing to run its own subject. Use `( unset FOO; shellfunc )`.
