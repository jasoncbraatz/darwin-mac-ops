---
project: smDrainHandoff
session_n: 9
gh_repo: "jasoncbraatz/darwin-mac-ops"
branch: "main"
gh_sha: "0cb085d9b0b557867dc8b60a1bbe67f2c9c41a50"
updated: "2026-09-04"
definition_of_done: "Every card in state/smdrain/lane-handoff.json is closed on the State Machine with a bb-close receipt, i.e. verify-smdrain.sh handoff exits 0"
verify_cmd: "bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff"
lessons_consulted: ["2026-09-04-rail-lane-worker-claims-resources-never", "2026-09-04-there-innings-table-rail-rail-db", "2026-09-03-handoff-written-from-session-memory-loses"]
live_theme: "the gate is right that something is wrong and wrong about WHOSE it is — and G-AL was the purest case: it graded every darwin session on whichever SIBLING read the charter first, and said ok"
phase: "DRAINING. 17 cards frozen, **7 closed**. Session 8 CLOSED **1218142549980676** (cold sessions cannot see a prior incarnation's progress) — THREE closes in three innings, all obeying the same rule session 6 discovered and 7 confirmed: take the at-bat whose move is WORKING, never the one whose move is WAITING. Session 8 also found and fixed TWO defects in its own new code before shipping, both the lane's live theme. Not done — 10 open. Ask again every inning."
gate_passed: false
next_at_bat: "**1217560480809492** — *handoff-kit · make PASTE THE HANDOFF a forcing function, not a note-to-self*. It is the LAST of the three handoff-kit cards (sessions 7 and 8 took the other two), its fix surface is the handoff kit, and like both of those it needs NO network and NO gate run — which is exactly why sessions 6, 7 and 8 landed and 3-5 did not. Take it. Session 8 is a live model for the SHAPE: the fix that lands is a READ of facts that already exist, printed where the reader already looks, with negative controls run BEFORE the receipt. SECOND CHOICE if that card turns out to need a gate run: **1218149975342086** (G-AP orphan — flowers-sms-sender-watch.sh declares a verdict its own drill FAILS), hermetic, one script and one drill. DO NOT take **1217341652482828** (the flap) unless you are prepared to spend the inning waiting: sessions 4, 5 and 6 all shaped an inning around its ~182 s x5 probe and none of them got a verdict out of it. The G-AQ doc-parity item sessions 7 and 8 both teed up is now CARDED as **1218165043650153** — off the parking lot, on the board, and NOT in this lane's frozen manifest, so it cannot move the ruler."
blockers: []
drift_flags: []
parking_lot: ["DISCHARGED by session 8: the G-AQ doc-parity item is now SM card **1218165043650153** (verified still owed first — `command grep -c 'G-AQ' ~/Desktop/downloads/HANDOFF-GATE.md` -> 0). Carded, not smuggled: it raises MAXG AP->AQ and cascades into four documents' front-door range refs, in a file stale-claimed by a dead sibling. NOT in this lane's frozen manifest, so it cannot move the ruler.", "NEW (session 8), teed up not taken: claude-blackbook START-HERE.md STEP 0 / student-in does not point a cold session at `rail <project>`, so the WHO WAS HERE BEFORE YOU block shipped for 1218142549980676 is discoverable only by someone who already knows the verb — which is the exact NORTH-STAR 2.4 failure that made ~/Scripts/rail exist in the first place. Cross-repo doc edit. verify: `command grep -c 'rail <project>' ~/repos/claude-blackbook/START-HERE.md` -> 0 today.", "G-AQ resolves the handoff pair from ~/Desktop/downloads/HANDOFF-<project>-<n>.md, which is the COWORK naming convention. Rail lanes write docs/handoffs/<project>.md and get an honest N/A. Wiring the rail lane's own handoff pair into G-AQ needs a notion of the PREVIOUS revision of a file that is rewritten in place (git show HEAD~1:docs/handoffs/X.md), which is a different mechanism, not a bigger regex. verify: run a rail-lane gate and confirm the G-AQ line reads n/a, not ok.", "gate-charter-drill.sh hard-codes its own negative-control count in its summary line (\"18 of them negative\"). Session 6 corrected it 16 -> 18 by hand, and that is the second time a number nobody checks has rotted in a drill footer. Making it self-counting is a change to a drill's REPORTING and deserves its own card and its own control; do not smuggle it into a drain inning. verify: `command grep -n 'of them negative' gate-charter-drill.sh` and count the FAIL-direction controls by hand.", "gate-flap-probe.sh has NO per-run timeout. Session 6's run 3 of 5 overran its ~182 s budget by >6x and emitted nothing, which is what forced the probe to be killed. A probe that can hang is a probe you cannot start at minute 0 and trust, which is the whole reason it exists. verify: `command grep -n timeout ~/Scripts/gate-flap-probe.sh` returns nothing today.", "gate-flap-probe.sh runs ~/Scripts/gate-selfcheck.sh, i.e. THROUGH THE SYMLINK into the repo: checkout, never your worktree. Correct for a flap question, wrong for anything you are editing. And do NOT run a second gate concurrently with a live probe: a gate run mutates the estate the probe is measuring. verify: `readlink ~/Scripts/gate-selfcheck.sh`.", "THE G-T#44 crontab probe is still TWO-STATE and session 5 left it that way on purpose: it is parsed from an EXIT CODE (rc 2 = drift, anything else = skip), not from text, so a timeout (rc 124) is already distinguishable from an answer and the truncation bug cannot reach it. If you ever change it to parse output, it needs _probe_field() like the other three.", "gate-probe-tristate-drill.sh is NOT wired into gate-selfcheck.sh as a G-x#drill check, unlike gate-roster-drill.sh. It is hermetic and sub-second, so it is a good candidate and session 5 simply ran out of clock. A drill that is not in a gate is a note, not a control — that sentence is already in gate-roster-drill.sh's own header.", "A THIRD false-positive class in the AAR sweep, found by s4 and deliberately NOT fixed: commit n8n-stack@b8c39779 is flagged as an incident-marker only because its subject QUOTES a card title containing 'sev-2' (`handoff: smDrainN8n session 3 — closed ... (COGS sev-2)`). It is a handoff commit, not an incident. Clearing it honestly means CALIBRATING SWEEP_NARROW_RE (a control being LOOSENED, which is the dangerous direction and needs its own card and its own negative controls), NOT an `aar.py adopt`, which would make a real AAR falsely claim a commit. Card it; do not smuggle it into a drain inning.", "The two [[SMOKE TEST]] cards holding G-V red (1218162752959495, 1218162743000102) are machine noise whose filer, cogs_mover.js, is not emitting bb-card.py's --autofiled marker. Same bug class as 1218153310094177 but the fix surface is the COGS bridge, not this lane. Card it against the bridge.", "The lane manifest lives at ~/repos/claude-blackbook/state/smdrain/lane-handoff.json, NOT in darwin-mac-ops — the DoD sentence reads as if it were repo-relative and it is not. Do not go looking for state/ in this repo.", "SM card 1218163994701439 (clobber-tripwire) says lane-handoff.json was OVERWRITTEN in a shared checkout by local-mbp2024-55818-b. The manifest read fine in sessions 1 and 2 (17 cards, digest intact, ruler graded), but if a future inning finds the card list changed, that is the ruler moving underneath the lane — open a decision, do NOT edit the manifest.", "CARD FIX 3 OF 1218125780430801, deliberately not built: the roster should NOTICE an unrostered author. Session 2 taught the GATE to stop guessing, which is the reader-facing half; the estate-facing half is that a session doing consequential work on darwin without `roster join` is invisible to the attribution SSOT by construction, and nothing anywhere complains. That is a roster change (~/Scripts/roster), not a gate-selfcheck.sh change, so it is out of this lane's fix surface — card it against the roster if you agree, do not smuggle it in here.", "The UNPUSHED branch of the G-H#22 sweep keeps its unconditional FAIL and session 2 left it alone on purpose (reason in the code comment and the bb-close receipt): its message never asserts ownership, so it is not telling the lie 1218125780430801 is about, and freshly-unpushed work is exactly what that check exists to catch."]
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
fix surface is `gate-selfcheck.sh` / the gate drills / the handoff kit. **7 of 17 closed.**

Note on "fix surface", because session 8 hit it and lost a few minutes: **the lane is defined by
its CARDS, not by its repo.** 1218142549980676's fix surface was `~/Scripts/rail`, which lives in
the separate `darwin-scripts` repo — so that inning's code commit does NOT ride this lane's §6
merge and had to be committed and pushed in `~/Scripts` on its own. Sessions 2 and 3 did the same
thing with `ceo-desk`. The ruler grades CARDS CLOSED, so this is normal, not drift. Commit by
pathspec there too: `~/Scripts` is shared and was carrying a sibling's dirty `docs/HANDOFF.md`.

## Is the phase DONE?
**No. 7 of 17.** Session 8 closed **1218142549980676**; session 7 closed **1218152478656223**;
session 6 closed **1217721634749933** — three innings, three cards, after a two-inning streak of
innings that left a card one move from closed. Ask this question explicitly every inning — a
milestone that is met but never declared keeps getting continued.

**What actually broke the streak, because it is repeatable and it is not "worked harder".**
Sessions 4 and 5 both ran out of clock on a last, cheap, *confirming* step. Session 5 diagnosed
that correctly and told session 6 to start the slow thing first. Session 6 did — and then went
one step further: it noticed that its two candidate at-bats were **different kinds of work**. The
flap card's move is *waiting on a 15-minute probe*; the borrow card's move is *editing a drill and
a gate*. So it started the wait at minute 0 and spent the inning on the work, and when the probe
overran at minute ~19 it **killed the probe** rather than let it eat the landing. **Sort your
candidate at-bats by whether their move is WAITING or WORKING; background every wait; and never
let a wait you started own your last fifteen minutes.**

## Session 8 (2026-09-04, local-mbp2024-18253) — what moved

Closed, with a bb-close receipt: **1218142549980676** — *Handoff feedback gap: cold sessions
can't see a prior incarnation's progress before re-running.*

**The card, restated.** 2026-09-03 Anthropic had API errors; superCEODesk-04 died mid-session and
its handoff prompt got run **three times**, because nothing told a fresh incarnation that a prior
one had already joined the roster, written a design doc and landed three commits. -05 reconstructed
that by hand in ~15 tool calls of `roster who --all` + `rail` + `git log` + poking at the ledger
before it was safe to proceed. The ask: one command that answers *"has anyone worked on this
before me, and how did it go?"*

**Where the fix went, and why there.** `~/Scripts/rail` — the front door, whose own docstring says
it exists because a verb only findable by someone who already knows its path satisfies NORTH-STAR
§2.4 for exactly one person. `rail <project>` now LEADS with a **WHO WAS HERE BEFORE YOU** block.
Charter kept verbatim: *no new state and no new truth*, four reads of facts that already exist,
and it never raises.

The load-bearing choice is the source. **The roster BOARD is TTL'd**, so the incarnation that died
>QUIET_H ago is gone from `roster who` *entirely* — which is precisely the case this card was filed
about, and why -05 could not just look. The **CLAIM JOURNAL**
(`~/.local/state/darlish/claim-journal.jsonl`) is append-only and **never pruned**: it is the
roster's memory, and it is where the answer actually lives. The board is then asked only for the
present tense (is this actor still breathing). Plus the ledger for per-session `outcome` /
`verify_exit` and whether a `complete` row — the box score — was ever written, which is the
difference between *it died* and *it finished and never said so*; plus ruling #37's
landed-but-never-reported check **scoped to one project and printed ABOVE the estate board**,
because the cold reader of `rail <project>` was the one reader who could not see it.

**TWO DEFECTS FOUND IN MY OWN NEW CODE AND FIXED BEFORE THE RECEIPT — both this lane's live theme,
"right that something is unusual, wrong about WHOSE/WHAT":**

1. The first cut marked a worker that had claimed **three minutes ago** as `†` GONE. Cause: **a
   rail lane worker claims resources but never `roster join`s a session row**, so absence from the
   board is its NORMAL state, not its death. Fix: the journal timestamp OUTRANKS board absence
   below `QUIET_H` — and `QUIET_H` is **asked of `roster constants`, never copied**, the same
   discipline gate-selfcheck's roster rungs follow. Banked as a global lesson.
2. A project holding a **live claim** tripped `⚠ LANDED BUT NEVER REPORTED`. True but wrong: that
   alarm is for work that **stopped** without reporting, and firing it on a lane mid-drain trains
   the reader to skip the block — the same failure mode ruling #38's `🅰` and ceoDesk-6's `⏸`
   branches were added to prevent. A live claim now renders `▶ IN FLIGHT`.

**The card's BONUS, answered:** there is no `innings` table and no `~/.rail/rail.db`. The ledger is
`~/.local/state/auto-bridge/ledger.db` (`RAIL_STATE` defaults to `~/.local/state/auto-bridge`,
never `~/.local/state/pitching-machine`) and one inning is spread over **rail_log** (verbs, incl.
the `complete` row) + **sessions** (n/outcome/verify_exit) + **inning_telemetry** (rc/wall/cost).
The empty query was the wrong path, not a data gap. That is now a comment in the code where the
next reader will hit it, and a global lesson.

EVIDENCE, run, not asserted — four controls, including a negative and a regression:

    python3 ~/Scripts/rail shipToFeedback      # THE CARD'S OWN CASE
    -> † fable-superCEODesk-05   last touched it 10.9h ago [GONE from the board — journal only]
       † rail-shipToFeedback-... last touched it 11.1h ago [GONE from the board — journal only]
       † fable-superCEODesk-04   last touched it 12.7h ago [GONE from the board — journal only]
       ledger sessions (newest first): n5 done, n4 advanced, n3 error, n2 error, n1 error
       box score (`complete` row on the ledger): YES — 1
       work on disk: 7 commit(s) on main naming shipToFeedback, 0 unmerged
    # i.e. all three actors -05 dug out by hand, reprinted in one command.

    python3 ~/Scripts/rail smDrainHandoff      # LIVE LANE — must be • and ▶, not † and ⚠
    -> • local-mbp2024-18253 last touched it 4m ago [no session row (normal for a rail lane
         worker) but claimed <6h ago -- may be LIVE]
       ▶ IN FLIGHT — local-mbp2024-18253 holds a live claim...

    python3 ~/Scripts/rail zzzNoSuchProject    # NEGATIVE CONTROL
    -> (no claim-journal entries name zzzNoSuchProject ...)
       → nothing on record. You are most likely the first. Proceed.

    python3 ~/Scripts/rail | grep -c 'DID THE WORK LAND'      -> 1   # regression: estate intact
    python3 ~/Scripts/rail | grep -c 'WHO WAS HERE BEFORE YOU'-> 0   # and the block stays scoped

    bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff
    -> LANE handoff (darwin-mac-ops) — 7/17 closed   (exit 1, correctly still red)

**Commit: `darwin-scripts` `c2c48e4`, pushed.** A different repo, so it does not ride this lane's
§6 merge — see the note under "The lane" above. Undo: `git revert c2c48e4`, plus the on-disk
`~/Scripts/rail.bak-smDrainHandoff8-20260904` (made BEFORE the edit; not committed, same as
sessions 2 and 3).

**Also done this inning, so it is not on the dugout floor:** the G-AQ doc-parity item that sessions
7 and 8 both teed up is **carded as 1218165043650153** — verified still owed first (`grep -c 'G-AQ'
~/Desktop/downloads/HANDOFF-GATE.md` -> 0), then carded rather than smuggled, because bumping MAXG
AP->AQ cascades into four documents' front-door range refs in a file stale-claimed by a dead
sibling. Two global lessons banked (the roster-liveness one and the ledger-path one).

**What session 8 would tell session 9 in one line.** The three innings that closed a card all had
the same shape and it is repeatable: **take the card whose move is WORKING, not WAITING; build the
undo first; then run your own new code against the card's own case, a live case, a negative and a
regression BEFORE you write the receipt** — that last step is what caught both defects above, and
either one shipped would have been a control that lies.

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

## Session 6 (2026-09-03, local-mbp2024-18253) — 1217721634749933, played and closed

At-bat was NOT the one session 5 teed up first, and the reason is worth reading before you
repeat the choice. Session 5's `next_at_bat` put the **flap card 1217341652482828** first and the
**G-AL borrow card 1217721634749933** second. Session 6 started the flap probe as the literal
first act of the inning (minute 0, background, exactly as instructed) and then played the SECOND
at-bat while it ran — because the flap card's move is *waiting*, and the borrow card's move is
*work*. That ordering is what produced a close instead of a third consecutive near-miss.

### Closed, with a bb-close receipt: 1217721634749933
*G-AL accepts a SIBLING's charter stamp and passes — should it fail closed?*

The card offered three options and recommended **(b)**; CEO ruling **#130** had already moved the
card into this lane, on the finding that its fix surface is `gate-selfcheck.sh` + `gate-charter-drill.sh`
in darwin-mac-ops and not `~/Scripts` (the lesson `2026-09-04-ruling-130-...` carries the decisive
mechanical fact: `~/Scripts/gate-selfcheck.sh` is a **symlink**, mode 120000, so a Scripts-side fix
would be graded by a `complete` that structurally cannot see it). Option (b) is what was built.

**The defect, restated the way the fix takes it.** G-AL looks for the session's charter stamp
under every name the session answers to — the slug it opened with, the roster identity, the
tier-stripped form, the case/hyphen-normalised form. Sessions 1-5 of *other* lanes added each of
those in turn, each time because a real session missed its own stamp. Beneath all four sits a
**blind scan of every warm (<12 h) ledger** that accepts a stamp for the same project from **any**
of them — and it printed `ok`. On darwin, where Jason runs 2-3 sessions on one project at once,
that borrow **always succeeds**, so G-AL could not fail anybody. The card's live proof, reproduced
verbatim: `GATE_ROSTER_WHO=big-wealthTensor-999` — *a session id that does not exist* — passed by
borrowing `wealthTensor-100.log`.

**Why (b) and not (c) fail-closed, and why that is not timidity.** The borrow branch was added
deliberately and its reason is intact: looking only under the roster identity once made G-AL
**FAIL a session that HAD read its charter**. A confident accusation about a thing that did happen
is worse than silence. So the branch stays and the *silence* goes: a borrow is now a **WARN naming
the ledger it came from and the session it was credited to**, non-blocking, visible in the issue
list. That is the card's own recommendation, and the drill now **asserts the non-blocking half by
name** — so a future "let's tighten this up" that promotes it to `FAILS` trips a named control and
has to argue with the card rather than quietly with the exit code.

**Drill FIRST, in both directions, exactly as the card instructed.** The verdict is derived once in
a named producer `gate_charter_stamp_line()`, and `gate-charter-drill.sh` **extracts it by name and
executes the shipped text** (`awk '/^gate_charter_stamp_line\(\)/,/^}/'` + `eval`) — the file's own
established idiom, and the reason it exists: a drill carrying its own copy of the rule goes on
passing forever on the day the rule changes. Six controls, two of them the load-bearing negatives:

- a borrow is a `WARN|`, not a silent ok — the card itself;
- ...and NAMES the borrowed-from ledger (the pre-fix `ok` line already did; losing it in the
  rewrite would have traded one defect for another);
- ...and NAMES the session being graded, so the reader knows the finding is about them;
- **NEGATIVE** — a borrow does **not** block. This is option (b) pinned against (c);
- **NEGATIVE** — a session that found its OWN stamp stays **SILENT**. A producer that speaks on
  every run warns on every gate, and a warning every session sees is a warning no session reads;
  that would kill the exact signal this change exists to create;
- **SOURCE-LEVEL** — the warm scan actually raises `_ch_borrowed=1`. The producer is only half the
  fix: *a producer nobody ever calls with 1 can never fire, and it would pass all five behavioural
  controls above it.* Same failure shape as `gate-probe-tristate-drill.sh` not being wired into a
  gate — a drill that is not in a gate is a note, not a control.

EVIDENCE, run, not asserted:

    # RED-PROOF: the new controls against the PRE-EDIT gate (the .bak)
    GATE_SELFCHECK=$PWD/gate-selfcheck.sh.bak-smDrainHandoff6-20260903 bash gate-charter-drill.sh
    -> FAIL  gate-selfcheck.sh has no gate_charter_stamp_line producer
       FAIL  the borrow verdict is never produced by the gate
       === drill: FAIL — 2 of 36 controls did not hold ===

    # ...and against the fix
    GATE_SELFCHECK=$PWD/gate-selfcheck.sh bash gate-charter-drill.sh
    -> ok  a borrowed stamp is a WARN, not a silent ok
       ok  the borrowed-from ledger is named
       ok  the session being graded is named
       ok  a borrow stays non-blocking (option b, not c)
       ok  an own stamp is still silent success
       ok  the warm scan raises the borrow flag and is read
       === drill: PASS — 40 controls, 18 of them negative (G-AL can still go red) ===

    # LIVE, end-to-end, reproducing the card's own repro verbatim: a fixture project with ONE
    # warm sibling ledger, graded as a session id that does not exist.
    T=/tmp/gal-borrow6   # charters.tsv + crit.tsv + state/demoborrow-100.log carrying the stamp
    PROJECT_CHARTERS=$T/charters.tsv CLAUDE_SESSION_STATE=$T/state \
      GATE_ROSTER_WHO=big-demoborrow-999 bash gate-selfcheck.sh
    -> === G-AL · the session knew what DONE looks like ===
         WARN   charter stamp BORROWED from demoborrow-100.log -- not this session's own

    (pre-fix, that same run printed `ok  charter read at the version in force (stamped in
    demoborrow-100.log)` and filed nothing. The `.bak` half of this comparison was queued and
    was still running at wrap -- the drill's red-proof above already covers that direction, so
    it is confirmation, not evidence this close depends on. Fixture is left at /tmp/gal-borrow6
    if the next inning wants it.)


**FOUND IN PASSING, FIXED.** The drill's summary line hard-codes its own negative-control count
("16 of them negative") — a number that no control checks and that therefore rots on every edit.
Corrected to 18. Flagged rather than automated: making it self-counting is a real change to a
drill's reporting and belongs on its own card, not smuggled into this one.

Undo: `git revert` commit `57eabc3`, plus on-disk `.bak-smDrainHandoff6-20260903` for
`gate-selfcheck.sh` and `gate-charter-drill.sh`. As in sessions 2-5 the `.bak`s are **not**
committed (`.bak-*` is gitignored).

### The flap card 1217341652482828 — what the probe got through, and the honest state
Started at **minute 0** in the background per session 5's instruction. It got **2 of 5 runs done**
and then run 3 **overran its ~182 s budget by more than 6x** without producing a line. At minute
~19 session 6 **killed it** rather than let it eat the landing, which is the exact failure that
took innings 3, 4 and 5. That is a deliberate trade and it is a finding in itself.

What the two completed runs say — **they are byte-identical**, same rc, same issue set:

    run 1   182s  rc=1 issues=[G-H#drill G-H#roster x2 G-H G-S G-W G-Z G-E G-U G-V G-T G-X G-Y
                               G-AD G-AE G-AE#drill x2 G-AF G-AG G-AH G-AI G-AJ G-AK G-AD G-V
                               G-X G-AL G-AL#board G-V#ship G-AO G-AL#board G-V G-X G-AD G-AK]
    run 2   181s  (identical)

So the flap has now **not reproduced in 15 attempts** across sessions 4-6. **It is still not
closed, and session 6 declines to close it**, for the same reason session 5 declined: an absence
of reproduction is not the same evidence as a named mechanism, and the mechanism the card names
(the G-T#4x ssh probes) was proven by session 5 to be **WARN-only and structurally incapable of
moving the exit code the card flapped on**. Session 5's proposed `--played` close rests on
"mechanism fixed + not reproduced"; the half that is missing is *which* check actually moved, and
the probe died before it could say. **See the next at-bat: it is now cheaper than it looks.**

**A gotcha the next inning must not pay for twice:** `gate-flap-probe.sh` runs
`~/Scripts/gate-selfcheck.sh`, i.e. **through the symlink into the `repo:` checkout — never your
worktree**. So the probe measures the *pre-merge* gate, which is correct for a flap question and
wrong for anything you are currently editing. Session 6 also deliberately **did not run a second
gate concurrently** with the probe while it was alive, because a concurrent gate run mutates the
estate the probe is measuring and would have contaminated the very evidence being collected.

## Session 7 (2026-09-03, local-mbp2024-18253) — 1218152478656223, played and closed

At-bat was session 6's first-listed candidate, taken for session 6's own stated reason: **its
move is WORK, not WAITING.** No probe was started, nothing was backgrounded, and the inning
landed with ~10 minutes of slack. That is now two consecutive closes and both of them came from
the same rule, so it is worth stating as a rule rather than as a happy accident: **sort the
candidate at-bats by whether their move is waiting or working, and take a working one.**

### Closed, with a bb-close receipt: 1218152478656223
*anti-string-of-pearls (HANDOFF-GATE v2.23) has no teeth — three inherited threads died silently
between smBacklog-11 and -12.*

**The defect.** HANDOFF-GATE.md line ~243 has required, since 2026-06-29, that *every* carried-over
OPEN item ship a one-line `verify:` liveness check. It was **prose only for 66 days**. The estate
built G-AL to catch drift away from the definition of **DONE** and had nothing catching drift away
from the definition of **WHAT IS OPEN** — because nothing in `gate-selfcheck.sh` ever read the
*inbound* handoff at all. The measured cost, from the card: smBacklog-11 handed -12 three live
threads plus the project's own drain scoreboard; -12 carried exactly one. Every claim -12 *made*
was true. It was an **omission**, and omission is the one defect a narrative cannot self-detect.

**Built.** `handoff-thread-continuity.sh` diffs inbound against outbound by **16-digit State
Machine gid** — the estate's own machine-checkable noun, and the card's own instruction to start
there rather than at prose matching. Gids are read from **prose only**: fenced code blocks and
blockquoted lines are stripped from **both** sides. That filter is not tidiness, it is the whole
control: without it, pasting the inbound handoff verbatim into a fence satisfies the check, and
the rule would enforce copy-paste and nothing else.

    rc 0  every inbound gid is accounted for
    rc 1  a thread appears NOWHERE in the outbound prose
    rc 2  CANNOT VERIFY -- a handoff is unreadable, or the inbound parsed to ZERO gids

**The `verify:` half is a WARN, not the exit code**, and that is deliberate — option (b), the same
shape ruling #130 produced for G-AL#borrow one inning ago. A **dropped** thread is a decision
nobody made; a thread **carried without a liveness check** is a thread someone did decide to keep.
A drill control pins the non-blocking half **by name**, so a future "let us tighten this up" trips
a named assertion and has to argue with the card instead of quietly with `${#FAILS[@]}`.

EVIDENCE — the card's own DONE WHEN, run against **real history, not a fixture**:

    bash handoff-thread-continuity.sh --inbound ~/Desktop/downloads/HANDOFF-smBacklog-13.md \
                                     --outbound ~/Desktop/downloads/HANDOFF-smBacklog-12.md
    -> DROPPED 1217015004006698
       DROPPED 1218065539722208
       EVIDENCE ... dropped=2  noverify=4
       rc=1

Those are **exactly** the two gids the card names, and `noverify=4` mechanically confirms the
card's other observation ("smBacklog-12 also shipped ZERO `verify:` lines on the threads it DID
carry"). The reverse direction — inbound -12, outbound -13 — is `rc=0` and silent.

    bash handoff-thread-continuity-drill.sh
    -> === drill: PASS — 14 controls (0 skipped), 8 of them negative or anti-gaming ===
       VERDICTS-EXERCISED: 1,0,2

**RED-PROOF, three mutations of the checker** (a drill never seen to fail is decorative):

    prose filter removed          -> 3 controls fail (both anti-gaming + the symmetry one)
    missing file made a silent pass -> 2 controls fail
    per-gid coverage reduced to a count -> 1 control fails

**G-AQ**, wired the G-AP way (an external checker plus its drill, so the gate file grows a case
statement and not a rule). Its five branches were tested **individually in a harness that extracts
the block and stubs the gate's accumulators** — the gate itself takes ~182 s and is not something
you iterate on (a gotcha this handoff has carried since session 1, and it paid for itself here):

    drop case                            -> 1 FAIL, naming both files
    clean case                           -> silent
    carried-without-verify case          -> 1 WARN, 0 FAILs
    a rail lane with no numbered handoff -> n/a   (not a pass, and not a fail)
    outbound present, predecessor missing-> CANNOT VERIFY

That last pair is the load-bearing bit of the wiring. Almost no session writes a numbered
`HANDOFF-<project>-<n>.md`, so the common case had to be an honest **N/A** or G-AQ would have
been a warning every session learns to scroll past. But an outbound that exists with its
predecessor missing is **CANNOT VERIFY**, never silence — an unreadable inbound is precisely the
state in which a dropped thread is invisible.

**TEED UP, DELIBERATELY NOT SMUGGLED IN — and it is the next inning's first move.**
`HANDOFF-GATE.md` still has **no §G-AQ section and no changelog entry**. That is the G-L#35c
family the gate document has now broken six times *about itself*, so leaving it unnamed would be
the joke landing twice. It was not done here because it is a **cross-repo** edit
(`~/Desktop/downloads`) that raises `MAXG` from AP to AQ, which cascades into G-L#35b's front-door
range references in four documents — a doc-parity change with its own blast radius and its own
controls. Verifying that cascade needs a full gate run, i.e. ~182 s, i.e. the exact wall-clock
gamble that cost innings 3, 4 and 5. Carding it is honest; hiding it inside this commit was not.

Commits: `78b474e` (the checker + drill) and `927cb12` (the gate wiring). Undo: `git revert` each,
plus on-disk `gate-selfcheck.sh.bak-smDrainHandoff7-20260903` (made **before** the edit). As in
sessions 2-6 the `.bak` is **not** committed — `.bak-*` is in `.gitignore`.

**A note on the irony, since three handoffs have now promised it.** This file was the artefact
under test, and it does not pass its own new check by construction: rail-lane handoffs are
rewritten in place at a fixed path, so "the inbound handoff" is `git show HEAD~1:docs/handoffs/
smDrainHandoff.md`, not a sibling file. That is a different mechanism, not a bigger regex, and it
is in the parking lot. What this file *can* do it now does: every carried item below ships a
`verify:` line.


## The shape of what is left (read this before picking)
**Of the attribution family — "the gate is right that something is wrong and wrong about whose it
is" — sessions 1-6 have now closed five.** Two remain: **1218153310094177** (G-V + G-AE red over
live sibling lanes' work) and **1217341652482828** (gate-selfcheck FLAPS PASS/FAIL/PASS on
identical clean state; read it as an attribution card, because a flap between two runs is usually
a sibling moving underneath you). **1217721634749933** (G-AL accepts a sibling's charter stamp)
was the third and closed in session 6. Whoever picks one of the remaining two should read session
6's section first: the fix surface is the same attribution machinery — the five rungs in the
G-H#22 sweep, `attribute.py`, `red-owner.py`, the roster, and now `gate_charter_stamp_line()` —
and doing them one at a time is how you write the same helper five times.

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
- **Use `command grep` on `gate-selfcheck.sh`, and the cause is NOT what sessions 1-5 thought.**
  Plain `grep -n roster gate-selfcheck.sh` returns NOTHING, exit 1 — indistinguishable from "the
  code isn't there", and it cost session 1 a wrong conclusion and session 6 a cycle. Session 1
  blamed the file (UTF-8, 554-char lines) and prescribed `-a`. **Session 6 read the actual cause:
  in a Claude Code session `grep` is a SHELL FUNCTION shimmed to ugrep** (`type grep` shows it:
  `ARGV0=ugrep "$CLAUDE_CODE_EXECPATH" -G --ignore-files ...`). `command grep -n "G-AL"` found 7
  lines where the shim found 0, same file, same directory, no `-a` anywhere. The shim is inherited
  into `$( )` and heredocs too. **Any empty grep over a file you have just read is suspect —
  re-run it as `command grep` before you believe it.** Banked: `2026-09-04-claude-code-session-darwin-shell-function`.
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
