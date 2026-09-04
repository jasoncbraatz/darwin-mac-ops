# HANDOFF — smDrain/handoff  (darwin-mac-ops)

**Project:** `smDrainHandoff` on the rail · **CEO:** opus-smDrainDesk-01 (desk 7)
**Ruler (FROZEN):** `bash ~/repos/claude-blackbook/scripts/verify-smdrain.sh handoff`
**Manifest (FROZEN):** `~/repos/claude-blackbook/state/smdrain/lane-handoff.json`

## What this lane is

Jason asked the CEO desk to drain one third of the State Machine backlog. The board was
FROZEN at 2026-09-03T20:48:03+00:00 (rule 1 of `backlog.work`: never count against a live
board — an honest session FILES cards, so a live denominator makes good work look like
failure; measured 201 -> 203, ADR-state-machine-divide §10).

This lane is one **cluster** of that freeze — everything whose fix surface is gate-selfcheck.sh / the gate drills / the handoff kit in darwin-mac-ops (seven inherited from gateAttrib by rulings #128 and #130) — and clusters are the unit
because a cluster is one system, which is one repo, which is one claim.

## Definition of done — one sentence someone can mark right or wrong

> Every one of the 17 cards below is closed on the State Machine with a
> `bb-close.py` receipt, and `verify-smdrain.sh handoff` exits 0.

## The cards (frozen — do NOT add to this list; a moved ruler refuses to grade)

| gid | bin | card |
|---|---|---|
| `1218152478656223` | NOW | [process] anti-string-of-pearls (HANDOFF-GATE v2.23) has no teeth — three inherited threads died silently between smBacklog-11 and -12 |
| `1217560480809492` | NEXT | handoff-kit · make PASTE THE HANDOFF a forcing function, not a note-to-self |
| `1218142549980676` | NEXT | Handoff feedback gap: cold sessions can't see a prior incarnation's progress before re-running |
| `1217654200494124` | NEXT | HANDOFF-GATE.md G-AM: a handoff that ASSERTS an exit code must have it re-run |
| `1217805451663111` | NEXT | [gate] session-out --record DESTROYS the tag G-AL needs, so the documented wrap order mutes the charter check every session |
| `1218149975342086` | NEXT | [process] G-AP orphan: flowers-sms-sender-watch.sh declares a verdict its own drill FAILS (exit 1) |
| `1217564707330383` | NEXT | [process] Gate check: a §N range named in HANDOFF.md must exist in the paper it names |
| `1217561601836055` | NEXT | Pre-commit secret hook does not detect PANs — G-AF is green at 114/114 and a live Visa number went through |
| `1217527164868214` | NEXT | G-AK follow-on: a ratification can still MATCH and no longer be RIGHT |
| `1217904193313336` | NEXT | [near-miss] Registered is not measured: voice-box and mcpMirror boards are stale too, and G-AL#board only ever checks the CURRENT session's project |
| `1218126486445244` | NOW | [process] gate-selfcheck blamed roster-ghost-drill.sh for roster-identity-drill.sh's failure — the summary names the wrong drill |
| `1218054982400791` | NOW | [process] gate-selfcheck can never go green for a scheduled/unchartered session (G-AL + G-AL#board) |
| `1217341652482828` | NEXT | [process] gate-selfcheck.sh FLAPS: PASS/FAIL/PASS on identical clean state (network-dependent ssh probes) |
| `1218125780430801` | NEXT | [process] gate-selfcheck blames the WRAPPING session for an unrostered sibling's dirty repo — G-H#22c/e/f all miss, and the fallback is "reported as Y |
| `1218147386804343` | NEXT | [process] gate-selfcheck orphan reds: repo:auto-bridge and repo:strike-zone aren't registered as "live reds" so red-owner.py transfer refuses them |
| `1218153310094177` | NEXT | [process] Gate G-V + G-AE red on 2026-09-03 — both items belong to live sibling lanes (shellac AAR, restore-drill plist) |
| `1217721634749933` | NEXT | [process] G-AL accepts a SIBLING's charter stamp and passes — should it fail closed? |

## How to close one

1. **Read the card first** (`python3 ~/Scripts/asana_client.py get --gid G`, or the Asana
   MCP). Several of these carry a prior session's measurements in the body — that is free
   context you would otherwise pay to rediscover.
2. **The undo comes FIRST.** `.bak`, a commit, or a tag, before the edit. Every one of these
   is reversible or it does not ship.
3. Fix it, then **verify it yourself** — run the thing, read the log, hit the route. A green
   claim you did not witness is the exact failure `MANAGEMENT BY WALKING AROUND` exists for.
4. Close with a receipt a stranger can audit:
   `python3 ~/Scripts/bb-close.py --gid G --reason "<what you did, what proves it, how to undo>"`
   (≥20 chars; it writes the AAR marker, completes the card, ledgers the undo, and
   reconciles citing cards.)
5. **A card you CANNOT close is not a failure — it is a finding.** Say so on the card, open
   a decision (`python3 ~/repos/auto-bridge/abridge.py decision open --proj smDrainHandoff …`,
   add `--needs-ceo` if it needs the desk), and move to the next one. Do NOT grind.

## Standing constraints

- **Never make a live third-party write** (Shopify admin, DNS, a production mailbox, a
  customer-facing send) without opening a `--needs-ceo` decision first. Reading is free;
  writing to something Jason's customers touch is not.
- **You share darwin with siblings.** `~/Scripts/roster who` before you edit; claim what you
  touch; commit with a **pathspec** (`git commit -- <paths>`), never `git add -A` — the
  roster brake will stop you and it is right to.
- **Student-in / teacher-out is not optional.** Search before you build; bank a leaf the
  moment something hurts, not at wrap.
- Cheap kills count as real work: ADR-state-machine-divide's Q1 ("is this already taken care
  of?") and Q2 ("is this still necessary?") close cards on *measured* evidence. Killing
  freely and reopening freely is the policy, stolen from Debian on purpose.

## Next at-bat

Take the topmost still-open card in the table, close it end-to-end per the five steps above,
and re-run the ruler. One card, start to finish, with its receipt on the board.

lessons consulted: run `python3 ~/repos/claude-blackbook/lessons.py search "handoff backlog"
--scope global,darwin-mac-ops` at student-in and record the ids you leaned on here.
