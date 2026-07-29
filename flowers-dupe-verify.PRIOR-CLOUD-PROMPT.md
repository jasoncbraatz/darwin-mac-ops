# ARCHIVE — the prior CLOUD prompt for "Flowers double-send: 24h post-fix verification"

**Trigger id:** `trig_01GK8X6JQ72L5Rgr6DSPSyU3` · one-shot `2026-07-30T01:30:00Z` · fresh-session cloud task
**Status:** DELETED 2026-07-29 by the AAR phase-3 session, superseded by the LOCAL launchd job
`com.braatz.flowers-dupe-verify` (`~/Scripts/flowers-dupe-verify.sh`).

## Why it was retired

It was a **fresh-session** cloud scheduled task (`persist_session: false`), so it ran in an isolated cloud
container with no device bridge and no ssh MCP. Every `~/...` path below was dead on arrival, and the probe
reaches the flowers Linode *through* darwin via `tools/flowers-remote.sh` — so unlike the geo check it could
not be made cloud-native. See AAR `2026-07-29-geo-detector-blind-spot` §5, action A1.

Separately, a **one-shot was the wrong shape** even setting the location aside: `dupe-scan.py` refuses to
say PASS below a sample floor, and at 2026-07-29T22:05Z there were 9 post-fix messages against a floor of
29. This job would have returned exit 2, and nothing would ever have re-asked.

## Why this archive exists

The prompt below is genuinely good content — particularly the step-2 exit-code branching and the
"a verification whose denominator is zero is decoration" reasoning, both carried forward into the
replacement script. Deleting the trigger without keeping the text would have thrown that away.
**This file IS the undo path:** to restore, re-create a scheduled task whose body is everything below
the rule. (You almost certainly should not — read "Why it was retired" first.)

---

One-shot verification of the 2026-07-28 ship-blocker fix. You are a fresh session — everything you need is here. (Hardened by S19, S20, and again by S21 on 2026-07-29: step 2 no longer lets you pass on a quiet day. That was a real hole — read WHY below, because the reasoning matters more than the command.)

FIRST: run `~/Scripts/bridge-status.sh` and say in chat you are briefed on the bridge-rotation bug (mcp__remote-devices__* tools vanish every ~27-33 min and self-heal in ~1s; that is NOT darwin; retry next turn; NEVER restart the Claude app; ops >55s go through `~/Scripts/bg`).

HOW TO RUN SHELL COMMANDS: every `~/...` path below is on darwin (the MacBook), NOT in your cloud container. Reach darwin with `mcp__remote-devices__Desktop_Commander__start_process`. Your own `Bash` tool runs in a cloud container that has none of these repos.

STEP 0 — CAPABILITY CHECK, DO THIS BEFORE ANYTHING ELSE. This job is worthless if it cannot report. Confirm you can (a) run a command on darwin and (b) comment on Asana.
  - If DARWIN is unreachable after one retry on a later turn: Asana is a CLOUD connector and sails through bridge rotation, so you almost certainly still have it. Open a card in Batter's Box titled "Flowers 24h dupe scan did not run — darwin unreachable", written as a paste-able prompt to Claude Desktop that repeats this whole job, AND say so loudly in chat. Do not quietly do nothing.
  - If ASANA is unreachable: say so loudly in chat and leave every card exactly as you found it.
  A verification that cannot fail out loud is decoration.

CONTEXT: On 2026-07-28 at 23:53:14 UTC an atomic duplicate guard went live on the flowers order-notification path (Asana card 1216968426926606). Before it, ~3 customers/day got "Your order has been delivered!" twice, because Shopify delivers orders/fulfilled twice and the previous guard read before it wrote, so both copies passed the check. Fix: an SmsSendClaim table with a UNIQUE index on (orderName, orderType) — the INSERT is the mutual exclusion. Full write-up: /var/www/flowers/OPUS-README.md section 16.

YOUR JOB — confirm it held for a full day of REAL traffic. The words "real traffic" are the whole job.

1. Run the scan on darwin. Note the --since flag; it is not optional:
     cd ~/repos/flowers-sms-relay
     git pull --ff-only
     set -a; . ~/.config/strike-zone/twilio.env; set +a
     python3 tools/dupe-scan.py --days 30 --since 2026-07-28T23:53:14Z
     echo "SCAN_EXIT=$?"
   Capture that exit code in its own command, on its own line. Do NOT pipe the scan into
   `tail`/`head` and then read `$?` — under zsh a pipeline's `$?` is the LAST element's,
   and you will read 0 (tail succeeded) no matter what the scan decided.

2. BRANCH ON THE EXIT CODE, not on your reading of a timestamp.
     exit 0 = PASS   -> comment on Asana 1216968426926606 quoting the whole verdict block
                       (post-fix outbound count, sample floor, 0-1s pairs) and COMPLETE the card.
     exit 1 = FAIL   -> the guard did not hold. Complete nothing. Open a card in Batter's Box,
                       written as a paste-able prompt to Claude Desktop, carrying the offending
                       SIDs the tool printed. Say so plainly in chat.
     exit 2 = INSUFFICIENT DATA -> not enough post-fix traffic for a clean scan to mean anything.
                       This is NOT a pass and NOT a failure. Comment on the card with the post-fix
                       count and the floor, leave the card OPEN, and set a fresh one-shot scheduled
                       task for the next business evening repeating this job.
   WHY THIS REPLACED "read the last line": until 2026-07-29 this step told you to eyeball
   `MOST RECENT 0-1s PAIR` and call it a pass if it predated the deploy. S21 found that reads
   PASS in two very different worlds — the bug being fixed, and nothing having been sent at all.
   The tool now derives its sample floor from the pre-fix duplicate rate (1 per 9 messages -> 29
   post-fix messages needed) and refuses to say PASS below it. A verification whose denominator
   is zero is decoration, exactly like a suite that cannot fail.
   NOTE THE ASYMMETRY, it is deliberate: a FAIL is trustworthy at any sample size (one real
   post-fix pair is proof), but a PASS needs the floor. Do not "balance" that.

3. Sanity-check the guard is still armed (a clean scan could still just be a quiet day):
     cd ~/repos/flowers-sms-relay && ./tools/flowers-verify.sh
   It runs all three suites on the box through tools/flowers-remote.sh, asserts the expected counts
   AND zero skips, and exits non-zero on any mismatch.
     PASS looks like: 12/0/0, 20/0, 18/0, "ALL GREEN".
   Proof the assertions are load-bearing:
     ./tools/flowers-verify.sh --self-test     (asserts a wrong count; must FAIL)
     ./tools/flowers-remote.sh --self-test     (runs the broken form; guard must fire)

3b. A CHEAP SECOND WITNESS — the Twilio scan and the app's own database should agree. Count
    SmsSendClaim rows created after the deploy boundary. Claim rows accruing = the guard is being
    exercised by real orders. Zero claims alongside a "clean" scan is the quiet-day signature and
    confirms exit 2 rather than contradicting it. (Strip any ?schema= from DATABASE_URL first.)

4. Success is SILENT unless something needs Jason — but a confirmed PASS IS worth one Asana comment
   and completing the card. An exit 2 is also worth one comment: silence would look like the job
   never ran.

WHAT EARLIER SESSIONS ALREADY DID:
 - Card 1216966300832952 (europeanflorist status-callback 502) is CLOSED. Twilio synthesises
   502/error-11200 for a response body with no Content-Type. Fixed 15:33 UTC 07-28. Do not reopen.
 - Card 1216968620841480 (second Shopify app identity): both prerequisites DONE. Our app is "blip"
   (blip-5 on ATX, blip-4 on SF). Needs Jason in Shopify admin; NOT yours.
 - Card 1216968508495305 (HMAC mismatch in monitor mode): DO NOT flip HMAC_MODE to enforce.
 - S21 (2026-07-29 ~10:40Z) proved the negative control by hand and shipped the --since verdict
   gate (flowers-sms-relay @ 10d9d85). S21 did NOT close the card: 2 post-fix messages vs a floor of 29.

Rollback if the guard ever needs undoing: git tag pre-dupe-guard-20260728 on jasoncbraatz/flowers,
then DROP TABLE "SmsSendClaim"; (also written literally at the bottom of
prisma/migrations/20260728233000_add_sms_send_claim/migration.sql).
