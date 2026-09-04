---
project: smDrainHandoff
session_n: 6
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "PENDING — set by the merge in §6"
updated: "2026-09-03"
definition_of_done: "Every card in state/smdrain/lane-handoff.json is closed on the State Machine with a bb-close receipt, i.e. verify-smdrain.sh handoff exits 0"
verify_cmd: "bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff"
lessons_consulted: ["2026-09-04-flap-detector-must-compare-issue-set", "2026-08-16-stamp-charter-read-sh-immediately-before"]
live_theme: "the gate is right that something is wrong and wrong about WHOSE it is — and on 1217341652482828, wrong about WHAT: the probes it names are WARN-only and cannot move the exit code it flapped on"
phase: "DRAINING. 17 cards frozen, 4 closed. Session 5 closed NONE and says so: it played the BULK of 1217341652482828's at-bat (the tri-state probe fix + a 17/17 hermetic drill, both merged) and then found, by reading the exit-code branch, that the probes the card names are WARN-only and structurally cannot produce the PASS/FAIL/PASS it was filed on. Fixing them was worth doing and does not earn the close. Not done — ask again every inning."
gate_passed: false
next_at_bat: "1217341652482828 is now ONE precise question, and it is cheap. The gate's exit code branches on FAILS and SKIPPED only (gate-selfcheck.sh ~line 2624-2638) — WARNS never touch it. Session 5 fixed the three G-T#4x ssh probes the card names, but they only ever append to WARNS, so they CANNOT be the flap. Re-aim at what CAN enter FAILS/SKIPPED on a network stutter: `G-X CANNOT VERIFY` is in the issue set of every single probe run and is network-dependent, which makes it the standing suspect. Method: `bash ~/Scripts/gate-flap-probe.sh -n 5 --outdir /tmp/flap` (~190 s/run, ~16 min — START IT AS THE FIRST ACT OF THE INNING, in the background, then work while it runs; session 5 started it at minute 12 and still ran out of clock). Then grep the transcripts for which check moved between two runs. If it is stable again, that is 13+ clean runs and the honest close is `bb-close.py --gid 1217341652482828 --played` on the grounds that its named mechanism is fixed+drilled and its symptom has not reproduced in 13 attempts — say BOTH halves in the --reason. SECOND at-bat if that lands: 1217721634749933 (G-AL accepts a SIBLING's charter stamp), which session 5 did NOT start; lesson 2026-08-16-stamp-charter-read-sh-immediately-before is the relevant prior art and is already marked used."
blockers: []
drift_flags: []
parking_lot: ["THE G-T#44 crontab probe is still TWO-STATE and session 5 left it that way on purpose: it is parsed from an EXIT CODE (rc 2 = drift, anything else = skip), not from text, so a timeout (rc 124) is already distinguishable from an answer and the truncation bug cannot reach it. If you ever change it to parse output, it needs _probe_field() like the other three.", "gate-probe-tristate-drill.sh is NOT wired into gate-selfcheck.sh as a G-x#drill check, unlike gate-roster-drill.sh. It is hermetic and sub-second, so it is a good candidate and session 5 simply ran out of clock. A drill that is not in a gate is a note, not a control — that sentence is already in gate-roster-drill.sh's own header.", "A THIRD false-positive class in the AAR sweep, found by s4 and deliberately NOT fixed: commit n8n-stack@b8c39779 is flagged as an incident-marker only because its subject QUOTES a card title containing 'sev-2' (`handoff: smDrainN8n session 3 — closed ... (COGS sev-2)`). It is a handoff commit, not an incident. Clearing it honestly means CALIBRATING SWEEP_NARROW_RE (a control being LOOSENED, which is the dangerous direction and needs its own card and its own negative controls), NOT an `aar.py adopt`, which would make a real AAR falsely claim a commit. Card it; do not smuggle it into a drain inning.", "The two [[SMOKE TEST]] cards holding G-V red (1218162752959495, 1218162743000102) are machine noise whose filer, cogs_mover.js, is not emitting bb-card.py's --autofiled marker. Same bug class as 1218153310094177 but the fix surface is the COGS bridge, not this lane. Card it against the bridge.", "The lane manifest lives at ~/repos/claude-blackbook/state/smdrain/lane-handoff.json, NOT in darwin-mac-ops — the DoD sentence reads as if it were repo-relative and it is not. Do not go looking for state/ in this repo.", "SM card 1218163994701439 (clobber-tripwire) says lane-handoff.json was OVERWRITTEN in a shared checkout by local-mbp2024-55818-b. The manifest read fine in sessions 1 and 2 (17 cards, digest intact, ruler graded), but if a future inning finds the card list changed, that is the ruler moving underneath the lane — open a decision, do NOT edit the manifest.", "CARD FIX 3 OF 1218125780430801, deliberately not built: the roster should NOTICE an unrostered author. Session 2 taught the GATE to stop guessing, which is the reader-facing half; the estate-facing half is that a session doing consequential work on darwin without `roster join` is invisible to the attribution SSOT by construction, and nothing anywhere complains. That is a roster change (~/Scripts/roster), not a gate-selfcheck.sh change, so it is out of this lane's fix surface — card it against the roster if you agree, do not smuggle it in here.", "The UNPUSHED branch of the G-H#22 sweep keeps its unconditional FAIL and session 2 left it alone on purpose (reason in the code comment and the bb-close receipt): its message never asserts ownership, so it is not telling the lie 1218125780430801 is about, and freshly-unpushed work is exactly what that check exists to catch."]
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
fix surface is `gate-selfcheck.sh` / the gate drills / the handoff kit. **4 of 17 closed.**

## Is the phase DONE?
**No. 4 of 17**, unchanged by session 5 — the second inning running to close no card. Read the
session 5 section before you treat that as a stall: the inning played most of an at-bat and then
disqualified its own close on evidence it went looking for. Ask this question explicitly every
inning — a milestone that is met but never declared keeps getting continued.

**Two innings in a row have now left a card one move from closed** (s4: 1218153310094177; s5:
1217341652482828). That is a pattern, and the cause is the same both times: the last, cheap,
*confirming* step is the one that needs wall-clock, and it keeps getting started too late.
Both remaining moves are named precisely in `next_at_bat`. Start the slow one FIRST.

## READ THIS FIRST — session 3 found the ruler had been DELETED
`rail.py ruler show --project smDrainHandoff` reported **`moved` / "the handoff no longer
declares a verify_cmd but one was frozen at rail-on"**. Session 2's frontmatter rewrite dropped
the `verify_cmd:` line. `ruler_digest()` returns `None` with no such key, and **`complete`
REFUSES a moved ruler outright** — so this project could not have closed no matter how many
cards got drained. Two sessions ran the ruler by hand every inning and never saw it, because
running the script yourself is not the same question as asking rail whether it can grade you.

Session 3 restored the exact frozen line and *proved* it rather than asserting it:

    python3 -c "import sys; sys.path.insert(0,'$HOME/repos/pitching-machine'); import rail; \
      print(rail.ruler_digest('<your worktree>','smDrainHandoff'))"
    -> digest a1397a9b931ab2ffe927f734d524a4cd46b9a53edfa999f5f1455ab6640efb91  == the recorded one

**`ruler show` reads the `repo:` checkout, not your worktree**, so it kept saying `moved` until
the merge. If you read `moved` at the top of your inning, check whether the line is present in
YOUR tree before you believe the project is broken. **Do not amend the ruler. Never edit the
verify_cmd line to anything but the frozen string.**

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

## Session 3 (2026-09-03, local-mbp2024-18253) — what moved

Two things, and the first was not on anybody's at-bat list.

**1. The ruler, restored** (see the section above). One line, and without it the DoD was
unreachable. It is committed and merged; `ruler show` should read `ok` for you.

**2. Closed, with a bb-close receipt: 1218147386804343** — *gate-selfcheck orphan reds:
`repo:auto-bridge` and `repo:strike-zone` aren't registered as "live reds" so `red-owner.py
transfer` refuses them.*

The card read as a red-owner internals mystery. It is not. It is **a roots gap plus a message
that says one thing about two opposite states.**

- gate-selfcheck sweeps **5** roots (`ROOTS`, ~line 47). `red-owner.repo_dirs()` scanned **4** —
  it never learned the depth-3 nest `~/Desktop/downloads/model-name-recon/repos`, **30 repos** as
  of today. The gate FAILs an orphan there with "run `red-owner.py transfer --key repo:<name>`",
  and that command **can never succeed** for any of them. Not a race: a permanent dead end.
- The two repos the card names are under `~/repos` and are **clean today**, so their specific
  dirt cleared between the gate run and the transfer. That is the *other* state, and
  `"is not a live red right now (nothing to transfer)"` was the message for **both**.

Built:
- `GATE_ROOTS` in red-owner.py, and a selftest control that **parses gate-selfcheck.sh's own
  `ROOTS` array** rather than restating it. A control that quotes the value it checks cannot
  catch that value changing — this one reads the subject.
- the `repo:` refusal splits three ways: **SCOPE gap** (prints the roots scanned, says the
  remediation is a dead end, says fix `GATE_ROOTS`), **CLEAN** (says the red cleared since the
  gate run, re-run the gate, nothing is owed), and the gate-transcript case.
- gate-selfcheck's ORPHAN FAIL now tells the reader **which of the two refusals to look for**,
  which is the card's part (b) verbatim.

EVIDENCE, run, not asserted:

    cd ~/repos/ceo-desk && python3 red-owner.py selftest
    -> red-owner selftest: 44 ok, 0 red          (39 before)

    # the parity control BITES — a gate with a shorter ROOTS array turns it red
    GATE_SELFCHECK=/tmp/fake-gate.sh python3 red-owner.py selftest
    -> RED  ROOTS PARITY: ... red-owner-only: ['~/Desktop/downloads', '~/.../model-name-recon/repos', '~/Scripts']
    -> red-owner selftest: 43 ok, 1 red

    GATE_SELFCHECK=$PWD/gate-selfcheck.sh bash gate-roster-drill.sh
    -> === drill: 59 passed, 0 failed ===        (56 before, from the .bak pair)

    # and #25a bites against the pre-edit gate
    GATE_SELFCHECK=$PWD/gate-selfcheck.sh.bak-smDrainHandoff3-20260903 bash gate-roster-drill.sh
    -> === drill: 58 passed, 1 failed ===

    bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff
    -> LANE handoff (darwin-mac-ops) — 4/17 closed   (exit 1, correctly still red)

Commits: **ceo-desk `be95c5d`** (pushed — a different repo, so it does not ride this lane's
merge) and **darwin-mac-ops `be5fee1`**. Undo: `git revert` each, plus on-disk
`.bak-smDrainHandoff3-20260903` for `red-owner.py`, `gate-selfcheck.sh`, `gate-roster-drill.sh`.
Same as session 2: the `.bak`s are **not** committed (`.bak-*` is gitignored).

**Teed up, deliberately not built:** the gate keys repos by **basename** across roots, and the
nest contains a `claude-blackbook` that collides with `~/repos/claude-blackbook`. So
`repo:claude-blackbook` is **ambiguous** — two different repos, one key, and both the gate and
red-owner will answer about whichever the walk saw last. That is a real attribution bug of the
same family, it is bigger than a message fix, and smuggling it into this card's commit would
have hidden it. **Card it if you agree**; it is not on the frozen manifest, so it cannot be
drained here anyway.

## Session 4 (2026-09-03, local-mbp2024-18253) — what moved, and the card that did NOT close

At-bat was **1218153310094177** (G-V + G-AE red over live sibling lanes' work). **Both items
the card names are now green. The card is still OPEN, on purpose.** Read the last paragraph
of this section before you judge that.

**(2) G-AE — done by the sibling, exactly as the card predicted it would be.**

    bash ~/Scripts/launchd-census.sh
    -> launchd-census: 61 repo-backed (1 ratified-divergent), 0 unbacked, 0 loaded-but-missing,
       0 DIVERGED

`com.braatz.restore-drill` is repo-backed. Nothing owed. Cost: one command.

**(1) G-V — done here.** The lesson `2026-09-03-windows-product-key-decoded-out-registry`
(contributor `opus-shellacP2V-1`, live at filing time) had no AAR declaration. The sweep
offered `aar.py adopt voice-box-em-dashes-shipped-over-stated-preference`, matched by ±3d
**date alone** — and that is plainly the wrong AAR for a Windows licence near-miss. **Taking
the suggestion would have turned the gate green with a lie**, which is the one move a drain
lane must never make. Filed the AAR the signal actually needs instead:

    aars/2026-09-03-generic-key-decoded-as-recovered-licence.md   (validate: 1/1 valid)
    aar.py adopt generic-key-decoded-as-recovered-licence --lesson 2026-09-03-windows-...

Cause class `implicit-vendor-default`, **reused, not invented** (`aar.py classes` first — it
is the join key the monthly retro clusters on). The mechanism is worth carrying: the registry
`DigitalProductId` holds Microsoft's GENERIC edition key on a machine whose entitlement is a
digital licence, and the only available cross-check — `slmgr /dlv`'s partial key — **reads the
same blob**, so it can confirm the base24 decode ran and can never falsify the answer. Filed
on a live sibling's behalf with an explicit invitation to correct it; precedent for that shape
is `voice-box-em-dashes-shipped-over-stated-preference`, filed the same way.

**FOUND IN PASSING, FIXED — the sweep was counting one signal as two.**

`aar.py`'s `_sweep_repo_dirs()` identified a repo by its **literal path**, while its own
docstring claimed parity with `gate-selfcheck.sh`'s walk. It did not have parity: the gate
runs every hit through `git rev-parse --show-toplevel` and keeps a `seen` set (gate-selfcheck.sh
~line 138), so a repo reachable under two roots is walked ONCE. `SWEEP_ROOTS` overlap heavily
on this estate and `Path.is_dir()` follows symlinks. MEASURED, not assumed:

    111 walked, 104 distinct, 6 repos DOUBLE-counted, ~/Scripts counted THREE times
    (via ~/repos/Scripts, ~/repos/darwin-scripts, and itself)
    ~/repos/n8n-stack -> ~/code/n8n-stack   ~/repos/darwin-mac-ops -> ~/code/darwin-mac-ops

So every incident-marker commit in an aliased repo was emitted **once per alias**, including
in the `<!--BBFINDING:...-->` block that `CLOSE-ON-CLEAR.md` 7b tells a closer to verify
**one by one**. Deduped on the resolved toplevel; first-seen alias wins so output stays
deterministic; an unresolvable path keeps its literal identity, i.e. it fails toward
over-reporting, which is the safe direction for an evidence source.

EVIDENCE, run, not asserted:

    python3 ~/repos/claude-blackbook/aar.py selftest
    -> ALL GREEN, including the new control:
       "sweep walk dedupes aliased repos (one repo under two roots = one signal), keeps distinct ones"

    # and it BITES — the same control against the pre-fix walk (naive append, monkeypatched):
    -> FAIL: sweep walk did not dedupe aliased repos: [.../real/aliased, .../real/solo,
       .../alias/aliased]

    python3 ~/repos/claude-blackbook/aar.py gate --days 7
    -> findings 5 -> 3   (exit 1, correctly still red — see below)

The control is built against a **real symlink, not a mock**, and carries the load-bearing
negative: a genuinely distinct repo must survive the dedupe, so a future "simplification"
that collapses too much trips a named assertion rather than silently narrowing the evidence.

Commit: **claude-blackbook `557e61c2`** (pushed — a different repo, so it does not ride this
lane's merge). Undo: `git revert 557e61c2`, plus on-disk
`~/repos/claude-blackbook/aar.py.bak-smDrainHandoff4-20260903` and the backup `aar.py adopt`
leaves beside the lesson. As in sessions 2 and 3 the `.bak`s are **not** committed.

### WHY 1218153310094177 IS STILL OPEN — this is the finding, not an excuse

The card's own close line is *"Close this card when `~/Scripts/gate-selfcheck.sh` shows G-V
and G-AE green."* G-AE is green. G-V is **not**, on three findings that **did not exist when
the card was filed at 18:07Z** and are not its subject — all three belong to the smDrainN8n
lane:

    <!--BBFINDING:commit:n8n-stack@b8c39779-->    a HANDOFF commit, flagged only because its
                                                  subject quotes a card title containing "sev-2"
    <!--BBFINDING:card:1218162752959495-->        [SMOKE TEST] cogs_mover.js battersBox() live call
    <!--BBFINDING:card:1218162743000102-->        [SMOKE TEST] COGS BB Bridge — smDrainN8n inning 10

**Closing on a whole-gate colour that live siblings keep writing to is exactly the failure
1217341652482828 describes** — the gate FLAPS because someone moved underneath you. A drain
lane that closes a card on a ruler a third party is still editing has not drained anything;
it has just picked a lucky moment to look. So: cleared what the card names, wrote the state
onto the card itself (comment `1218164732730110`, with the three BBFINDINGs listed verbatim),
and left it one move from closed.

**If you are the next inning: re-run `aar.py gate --days 7` FIRST.** If a sibling cleared
those three, this card closes in one `bb-close.py` and you have banked a card before your
real at-bat starts. Neither residual is yours to force — see the parking lot for why the
commit one needs its own card (it is a control being LOOSENED) and why the smoke-test ones
belong against the COGS bridge.

**The through-line sessions 2, 3 and 4 have now each hit from a different side:** the gate
has no stable notion of WHOSE a red is. s2 found four rungs blind to the same actor; s3 found
a remediation that scanned less ground than the control; s4 found a control double-counting
one repo as two and then declined to close on a colour a sibling owns. That is 1217721634749933
+ 1217341652482828, and it is why they are the next at-bat.

## Session 5 (2026-09-03, local-mbp2024-18253) — the fix landed, the close did not

At-bat was **1217341652482828** — *gate-selfcheck.sh FLAPS: PASS/FAIL/PASS on identical clean
state (network-dependent ssh probes)*. **Most of its at-bat is now played and merged. The card is
still OPEN, and unlike session 4's card it is not one lucky moment away — it is one precise
question away.**

### First, the free card that was not free
`aar.py gate --days 7` re-run as session 4 instructed. **Unchanged** — the same three
smDrainN8n-owned findings still hold G-V red (`n8n-stack@b8c39779`, cards `1218162752959495`,
`1218162743000102`). So 1218153310094177 stays open for exactly session 4's reason. Cost: one
command, and it is the right first move every inning until it comes back clean.

### What was built, and why the card asked for it
The card's own at-bat named four things. Items **2 and 3** are now done, in this repo:

> *"Make every remote probe TRISTATE and say so out loud: reachable-and-answered / unreachable /
> ANSWERED-BUT-UNPARSEABLE. Today the third collapses into the first."*
> *"An unparseable probe should WARN with the raw value echoed, never FAIL, and never silently pass."*

Each `G-T#4x` check is one ssh round-trip under `timeout 14` whose multi-line answer is parsed
positionally with `sed -n 'Np'`. The code recognised **two** states — unreachable (empty) and
answered — and a timeout that cuts the stream **mid-answer** is neither. The shell's default
substitutions then collapsed that third state into whichever neighbour was silently wrong, and
**it went both directions in the same file**:

| site | old code | what a truncated line became |
|---|---|---|
| G-T#43b | `[ "${BOX_SCHED_N:-0}" = "0" ]` | a conjured **"SCHEDULER MISSING"** finding — a WARN out of a network hiccup |
| G-T#45 / #46 | `[ "${PROV_DIRTY:-0}" != "0" ]` | a conjured **all-clear** — the same bug, and the dangerous direction |
| G-T#43 | `[ "$BOX_HEAD" != "$GH_HEAD" ]` | a 20-char **truncated sha** is still hex, so it compared unequal and reported a parity drift **naming a commit that never existed** |

`_probe_field()` parses to three states and returns which: **rc 0** answered (the probe's own
`MISSING` sentinel passes through), **rc 1** absent, **rc 2** answered-but-unparseable **with the
raw value echoed**. Seven fields across three sites go through it. Per the card, every unparseable
branch is a **WARN** — a network stutter is not a finding about Jason's repos — and none is silent,
because a probe nobody could read has not cleared anything.

**FOUND IN PASSING, FIXED.** `BOX_HEAD="MISSING"` (no checkout on the box at all) was not handled
on the strike-zone branch, so an **absent deploy** rendered as a parity drift and the remedy line
told you to `pull --ff-only` a repo that does not exist. The *ledger* branch three lines below
already guarded `!= "MISSING"`; the strike-zone one never did. Now `G-T#43m`, with the right remedy.

EVIDENCE, run, not asserted:

    bash gate-probe-tristate-drill.sh
    -> === drill: 17 passed, 0 failed ===

    # and it BITES — the same drill against the OLD semantics (naive ${VAR:-0}, monkeypatched):
    -> 11 passed, 6 failed, including
       FAIL 5  a SHORT answer (line 3 never arrived) -> rc 1 ABSENT, not 0  (want='1|' got='0|0')
       FAIL 6  a TRUNCATED sha is rc 2 UNPARSEABLE, raw value echoed        <-- the flap's mechanism

`gate-probe-tristate-drill.sh` is **hermetic** — every subject is a string, it never runs the gate
and never touches the estate — and it **extracts `_probe_field()` from `gate-selfcheck.sh` at run
time** rather than copying it, the same contract `gate-roster-drill.sh` states in its header. The
six that go red are the mutation proof; the eleven that stay green are the load-bearing negatives,
asserting that a **genuine** zero scheduler count, dirty count and unpushed count still produce the
real findings. This is a WARN-*adding* change that re-gates three existing findings behind an rc
test, so "the real findings survive" is the assertion that matters most.

The wiring control (#14) is anchored on the **code** form, not the sentence — because the comment
block above `_probe_field` quotes `${BOX_SCHED_N:-0}` verbatim, and a naive grep reports **4 live
conflations that do not exist**. That is session 2's G-H#24e gotcha, reproduced exactly, one
inning after it was written down. It is in the gotchas list below for a reason; it will happen again.

### WHY THE CARD IS STILL OPEN — this is the finding

Having fixed the mechanism the card names, session 5 went to confirm it was *the* mechanism, and
it is not. **The gate's exit code branches on `FAILS` and `SKIPPED` only** (`gate-selfcheck.sh`
~2624-2638: `exit 0` above, `exit 1` below, both keyed on `${#FAILS[@]}` / `${#SKIPPED[@]}`).
**`WARNS` never touches it.** Every one of the three `G-T#4x` probes appends to `WARNS+=` and
nothing else — before this change and after it.

So the probes this card names **structurally cannot** produce the `PASS → FAIL → PASS` that was
observed on 2026-08-10. The fix is real and worth having; it is not this card's symptom. Session 5
of the sibling lane smDrainGateAttrib read this from the code and said so; session 5 here confirmed
it at the exit statement itself, which is the load-bearing line.

**Closing on the hypothesis while the symptom stands unexplained is the drain-lane failure mode**,
and it is the same one session 4 refused. So the card stays open — but its question is now small
and aimed: *which check that can enter `FAILS` or `SKIPPED` moves on a network stutter?*
**`G-X CANNOT VERIFY` is in the issue set of every probe run and is network-dependent.** That is
the suspect, and `SKIPPED` is the mechanism nobody has looked at — a check that NEVER RAN changes
the headline and the exit code, and "could not verify" is exactly what a network stutter produces.

### The reproduce attempt, and the honest state of it
`gate-flap-probe.sh -n 5` (the sibling lane's instrument) was started at minute 12 and **did not
finish inside the inning** — runs are ~185 s each, so five is ~16 min, and the tail of the inning
came first. What it did produce, both runs **byte-identical**, same 35 check ids, `rc=1`:

    run 1   188s  rc=1   run 2   182s  rc=1        (transcripts: /tmp/flap-s5, VOLATILE)

With the sibling's three earlier runs that is **5 consecutive non-reproductions**. Not a verdict —
`/tmp` will not survive, so re-run it rather than citing this. **Start it as the FIRST act of the
inning.** That is the whole scheduling lesson of both session 4 and session 5.

Commit: this lane, `05b2d9f`. Undo: `git revert 05b2d9f`, plus the on-disk
`gate-selfcheck.sh.bak-smDrainHandoff5-20260903` and
`gate-roster-drill.sh.bak-smDrainHandoff5-20260903` (made **before** the edit). As in sessions 2-4
the `.bak`s are **not** committed — `.bak-*` is in `.gitignore`.

Banked: `2026-09-04-remote-probe-has-three-states-two` (global). Used:
`2026-09-04-flap-detector-must-compare-issue-set` (its design rule — compare the issue set, not
the exit code — is what made "rc=1 both runs" readable as evidence rather than noise) and
`2026-08-16-stamp-charter-read-sh-immediately-before`.

## The shape of what is left (read this before picking)
**Five of the thirteen remaining are still one sentence: the gate is right that something is
wrong and wrong about whose it is.** 1218153310094177 (G-V + G-AE red over live sibling lanes'
work), 1217721634749933 (G-AL accepts a SIBLING's charter stamp), 1217341652482828
(gate-selfcheck FLAPS PASS/FAIL/PASS on identical clean state — read it as an attribution card,
because a flap between two runs is usually a sibling moving underneath you). Sessions 1-3 closed
four of this family. **Whoever picks one should read all three:** the fix surface is the
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

## Gotchas paid for in sessions 1-3
- **`grep` needs `-a` on `gate-selfcheck.sh`.** The file is UTF-8 with 554-char lines and plain
  `grep -n roster gate-selfcheck.sh` returns NOTHING, exit 1 — indistinguishable from "the code
  isn't there". It cost session 1 a wrong conclusion before `file(1)` caught it.
- **The gate takes minutes to run.** A control that shells out to the whole gate is not a control
  you can iterate on; extract the predicate BY NAME and execute that instead. House precedent:
  `gate-skipped-drill.sh`, and every rung control in `gate-roster-drill.sh`.
- **`env -u FOO shellfunc` does not test a shell function** — `env` execs a program, so the
  control "passes" by failing to run its own subject. Use `( unset FOO; shellfunc )`.
- **Check `rail.py ruler show` at the TOP of the inning.** It is the only thing that answers
  "can rail still grade me", and running the verify script by hand does not answer it. Session 3
  found two innings' worth of a project that could not have completed.
- **A wiring control that greps the sweep for a SENTENCE will count the sweep's own comments.**
  Session 2's #24e wanted "both anonymous FAILs survive" and got 3, because the new rung's comment
  block quotes the sentence it replaces. Anchor the grep on the CODE (`FAILS+=.*<sentence>`), or
  the control goes green on a rung that has been reduced to prose about itself.
