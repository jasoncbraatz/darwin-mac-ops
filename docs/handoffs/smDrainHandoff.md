---
project: smDrainHandoff
session_n: 3
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "PENDING"
updated: "2026-09-03"
definition_of_done: "Every card in state/smdrain/lane-handoff.json is closed on the State Machine with a bb-close receipt, i.e. verify-smdrain.sh handoff exits 0"
lessons_consulted: ["2026-09-03-contract-built-fix-class-problem-check", "2026-08-15-attribution-shared-machine-s-dirty-files"]
live_theme: "the gate is right that something is wrong and wrong about WHOSE it is — six of the fourteen remaining cards are that one sentence"
phase: "DRAINING. 17 cards frozen, 3 closed (2 in session 1, 1 in session 2). Not done — ask again every inning."
gate_passed: false
next_at_bat: "1218147386804343 — gate-selfcheck orphan reds: repo:auto-bridge and repo:strike-zone are not registered, so `red-owner.py transfer` REFUSES them. Same attribution family as the three now closed, and session 2 just added the fifth rung (G-H#22g-unrostered) beside the four it will read. Take 1218153310094177 (G-V + G-AE red over live siblings' work) in the same at-bat if it fits: both are about a red whose OWNER exists but cannot be named to the tool that would move it, and the fix surface is the same red-owner/attribute.py pair."
blockers: []
drift_flags: []
parking_lot: ["The lane manifest lives at ~/repos/claude-blackbook/state/smdrain/lane-handoff.json, NOT in darwin-mac-ops — the DoD sentence reads as if it were repo-relative and it is not. Do not go looking for state/ in this repo.", "SM card 1218163994701439 (clobber-tripwire) says lane-handoff.json was OVERWRITTEN in a shared checkout by local-mbp2024-55818-b. The manifest read fine in sessions 1 and 2 (17 cards, digest intact, ruler graded), but if a future inning finds the card list changed, that is the ruler moving underneath the lane — open a decision, do NOT edit the manifest.", "CARD FIX 3 OF 1218125780430801, deliberately not built: the roster should NOTICE an unrostered author. Session 2 taught the GATE to stop guessing, which is the reader-facing half; the estate-facing half is that a session doing consequential work on darwin without `roster join` is invisible to the attribution SSOT by construction, and nothing anywhere complains. That is a roster change (~/Scripts/roster), not a gate-selfcheck.sh change, so it is out of this lane's fix surface — card it against the roster if you agree, do not smuggle it in here.", "The UNPUSHED branch of the G-H#22 sweep keeps its unconditional FAIL and session 2 left it alone on purpose (reason in the code comment and the bb-close receipt): its message never asserts ownership, so it is not telling the lie 1218125780430801 is about, and freshly-unpushed work is exactly what that check exists to catch."]
---

# smDrainHandoff — LIVING HANDOFF

## Read first
`docs/NORTH-STAR.md` does not exist in this repo (checked, sessions 1 and 2). `README.md` is
the nearest thing: darwin-mac-ops is the runbook that rebuilds Jason's Mac in an hour, and
`gate-selfcheck.sh` — the mechanical half of HANDOFF-GATE.md — lives here and is **symlinked
into `~/Scripts`**. That symlink is why the merge in §6 is not tidying: the moment
`rail/smDrainHandoff` lands on `main`, every session on the machine is running your edit.

Sharper, measured in session 2: `gate-selfcheck.sh` invokes the drill by the **hard-coded path
`$HOME/code/darwin-mac-ops/gate-roster-drill.sh`** (line ~229), i.e. the `repo:` checkout, never
your worktree. So a drill you add on `rail/smDrainHandoff` is **not a control until it merges** —
the gate run from your lane will happily report the OLD control count. Session 2 saw exactly
that: the worktree drill said 56 and the gate's own G-H#drill line said 45, in the same run.

Then run the ruler:

    bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff

## The lane
17 frozen cards, `~/repos/claude-blackbook/state/smdrain/lane-handoff.json`, everything whose
fix surface is `gate-selfcheck.sh` / the gate drills / the handoff kit. **3 of 17 closed.**

## Is the phase DONE?
**No. 3 of 17.** Ask this question explicitly every inning — a milestone that is met but never
declared keeps getting continued.

## Session 2 (2026-09-03, local-mbp2024-18253) — what moved

Closed, with a bb-close receipt: **1218125780430801** — *gate-selfcheck blames the WRAPPING
session for an unrostered sibling's dirty repo; G-H#22c/e/f all miss and the fallback is
"reported as YOURS".*

The finding, restated the way the fix takes it: **#22c (filename), #22c-content (signature),
#22e (claim journal) and #22f (live sibling's mtime window) are four voices asking ONE source —
the roster — and all four are blind to the same actor by construction:** a session doing
consequential work without `roster join`. When all four decline, the fallback beneath them
asserted *"so it is being reported as YOURS"*, which is not a weaker answer than the four above
it, it is a **wrong** one — and the only remedy it leaves a doctrine-blocked session is to commit
and push a sibling's in-flight work. The gate's remedy was more dangerous than the condition.

Built (card fix 1 + fix 2): a fifth rung, `_dirt_recent_unrostered()`, asked **after** #22f
(which NAMES a live sibling) and immediately **before** the anonymous FAIL, at **both** sites
that carried it — the ORPHAN-with-no-author branch and the no-verdict default. It looks at the
one thing none of the four do: **a repo does not commit itself.** If HEAD landed inside the live
window (`QUIET_H`, asked of `roster constants`, never copied) then somebody was working here
minutes ago, and every roster rung above has just said it knows of nobody who holds this repo
*including you*. Verdict: **UNATTRIBUTED** — a WARN naming the commit as evidence and handing the
reader BOTH branches (do not commit it blind; if it IS yours you owe a `roster claim` and a commit
before you wrap). It declines to guess; it does not grant an amnesty.

**Narrow on purpose**, because FAIL→WARN is the most dangerous direction a control can move: a
HEAD **older** than QUIET_H attributes NOTHING and the anonymous FAIL stands unchanged. Weeks of
uncommitted work in a repo nobody has touched is the bite this check was BUILT for (Jason's), and
it has no recent actor to point at. The downgrade buys exactly the carded case and nothing else.

EVIDENCE, run, not asserted:

    # the drill, before (the .bak) and after
    GATE_SELFCHECK=$PWD/gate-selfcheck.sh.bak-smDrainHandoff2-20260903 \
      bash gate-roster-drill.sh.bak-smDrainHandoff2-20260903
    -> === drill: 45 passed, 0 failed ===

    GATE_SELFCHECK=$PWD/gate-selfcheck.sh bash gate-roster-drill.sh
    -> === drill: 56 passed, 0 failed ===

    # the whole gate, from the worktree
    bash gate-selfcheck.sh --quiet
    -> GATE SELF-CHECK: FAIL (4 issue(s), 1 check(s) NEVER RAN)
       G-V, G-X CANNOT VERIFY, G-AD (6 unratified BB writers), G-AK — all pre-existing
       estate reds, NONE of them in G-H. G-AL#board NEVER RAN because this rail session
       exported no GATE_ROSTER_WHO (see "unfinished business" below).

    bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff   # the frozen ruler
    -> LANE handoff (darwin-mac-ops) — 3/17 closed

The 11 new controls, and why each is there: **#23a/a2** the card's own case (a fresh HEAD in an
unclaimed repo names the actor the roster cannot, and the note says it cannot name *you* either);
**#23b** the load-bearing negative — a stale HEAD attributes nothing, so the weeks-of-dirt bite is
intact and a future "simplification" that drops the recency test trips a named assertion;
**#23c** a clock-skewed future commit is not evidence; **#23d/e** fail-closed on a repo with no
commits and on a non-repo; **#24** *both* anonymous-FAIL sites are wired (a grep count of 2, not
a boolean — the first cut of this fix could easily have patched one); **#24b/c** the WARN still
says UNATTRIBUTED and still carries both branches; **#24d** an ordering control — #22f is asked
before #22g so an answer that NAMES a sibling is never pre-empted by an anonymous one;
**#24e** both FAILs survive beneath it (attribution, not absolution).

Undo: `git revert` the commit below, plus on-disk `.bak`s made **before** the edit —
`gate-selfcheck.sh.bak-smDrainHandoff2-20260903`,
`gate-roster-drill.sh.bak-smDrainHandoff2-20260903`. **Note for the next inning:** unlike
session 1's, these are NOT committed — `.bak-*` is now in `.gitignore` and session 2 declined to
`git add -f` past a repo policy to keep a habit. Session 1's handoff says "both committed
alongside", which was true when it was written and is not the rule any more.

## The shape of what is left (read this before picking)
**Six of the fourteen remaining are still one sentence: the gate is right that something is
wrong and wrong about whose it is.** 1218147386804343 (orphan reds not registered, so
`red-owner.py transfer` refuses them), 1218153310094177 (G-V + G-AE red over live sibling lanes'
work), 1217721634749933 (G-AL accepts a SIBLING's charter stamp), 1217341652482828
(gate-selfcheck FLAPS PASS/FAIL/PASS on identical clean state — read it as an attribution card,
because a flap between two runs is usually a sibling moving underneath you). Sessions 1 and 2
closed three of this family. **Whoever picks one should read all four**: the fix surface is the
same attribution machinery — the five rungs in the G-H#22 sweep, `attribute.py`, `red-owner.py`,
the roster — and doing them one at a time is how you write the same helper four times.

Three are about the handoff itself and are the reason this lane exists at all:
1218152478656223 (anti-string-of-pearls has no teeth — a carried thread needs a one-line
`verify:` or it dies silently), 1218142549980676 (cold sessions can't see a prior incarnation's
progress), 1217654200494124 (G-AM: a handoff that ASSERTS an exit code must have it re-run).
The irony available to whoever takes 1218152478656223 is unchanged: **this file** is the artefact
under test.

## Unfinished business a next inning can pick up cheaply
- **This rail session exports no `GATE_ROSTER_WHO`**, so every gate run from a lane reports
  `G-AL#board NEVER RAN: project 'localmbp2024' has no charter row`. Session 1 built the honest
  answer for exactly this shape (`GATE_UNCHARTERED="<reason>"` → N/A, not a warn) and **the
  runner does not set it**. That is a one-line change in `runner/rail-runner.sh`, in a different
  repo, so it is teed up rather than done: a rail inning is unchartered BY DESIGN and should say
  so mechanically instead of every inning re-deriving it.
- The four pre-existing estate reds above (G-V, G-X, G-AD, G-AK) are not this lane's cards, but
  two of them (G-V, G-AD) name *this* worktree's files. If you are here anyway, look.

## Gotchas paid for in sessions 1-2
- **`grep` needs `-a` on `gate-selfcheck.sh`.** The file is UTF-8 with 554-char lines and plain
  `grep -n roster gate-selfcheck.sh` returns NOTHING, exit 1 — indistinguishable from "the code
  isn't there". It cost session 1 a wrong conclusion before `file(1)` caught it.
- **The gate takes minutes to run.** A control that shells out to the whole gate is not a control
  you can iterate on; extract the predicate BY NAME and execute that instead. House precedent:
  `gate-skipped-drill.sh`, and every rung control in `gate-roster-drill.sh`.
- **`env -u FOO shellfunc` does not test a shell function** — `env` execs a program, so the
  control "passes" by failing to run its own subject. Use `( unset FOO; shellfunc )`.
- **A wiring control that greps the sweep for a SENTENCE will count the sweep's own comments.**
  Session 2's #24e wanted "both anonymous FAILs survive" and got 3, because the new rung's comment
  block quotes the sentence it replaces. Anchor the grep on the CODE (`FAILS+=.*<sentence>`), or
  the control goes green on a rung that has been reduced to prose about itself.
