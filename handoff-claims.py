#!/usr/bin/env python3
# =============================================================================
# handoff-claims.py -- the MECHANICAL half of HANDOFF-GATE.md G-AR, globally.
# -----------------------------------------------------------------------------
# G-AR: "a handoff that ASSERTS an exit code must have it RE-RUN." Until now that
# was mechanical in `wealth-tensor` ONLY (scripts/handoff_gate.py, G-CLAIMS) and a
# hand-walked obligation on every other project. This is the port, and it is NOT a
# copy: two things about the global estate make a literal port wrong, and both were
# MEASURED before a line was written (feynmanSync-15, 2026-09-08).
#
# MEASUREMENT 1 -- THE PROSE AUDIT DOES NOT PORT.
#   wealth-tensor audits its one-line `phase:` field with /\bRC\s+(\d+)/ and
#   /\b(\d+) passed\b/. Those regexes over a WHOLE global handoff hit 46 of the 185
#   handoffs in ~/Desktop/downloads, and the hits in the six most recent are
#   NARRATIVE, not assertions: "CANNOT CHECK output / rc 127 -> CANNOT VERIFY",
#   "still rc 2 for a launchd subject Linux cannot have". A leg that reds on those
#   manufactures the false accusation G-AR's own spec forbids ("a gate that cries
#   liar is a gate somebody switches off"). So the anti-omission half is NOT a prose
#   sniff here. See MEASUREMENT 2 for what replaced it.
#
# MEASUREMENT 2 -- THE ESTATE'S `verify:` IDIOM IS THE -93 DEFECT, 13 TIMES OVER.
#   Every one of HANDOFF-feynmanSync-14.md's 13 command-shaped `verify:` lines is
#   PIPED: `| head -1`, `| tail -1`, `| wc -l`, `| grep ...`. `$?` after a pipe is
#   the PIPE's (G-AO) -- which is exactly how wealthTensor-93 handed over a red sweep
#   reported green. So the estate's established verification convention CANNOT verify
#   an exit code, systematically, and nothing said so. That is `G-AR#piped`, and it is
#   this leg's anti-omission half: it names every piped verify: line in the outbound
#   handoff. It is an ADVISORY, not a blocker, on the G-AQ#verify / G-AQ#selfcount
#   precedent -- 13 of 13 on day one is the G-AP-340 wallpaper trap, and a floor that
#   reds everybody on its first day gets switched off, not fixed.
#
# WHAT IS NEW HERE AND IS NOT IN wealth-tensor: THE REFUSAL LIST.
#   This leg EXECUTES COMMANDS READ OUT OF A DOCUMENT that a previous Claude session
#   wrote. wealth-tensor's leg forbids `|`, `;` and `&` -- for correctness of the exit
#   code, not for safety -- and would happily run `rm -rf ~`. A global leg pointed at
#   185 documents needs the safety half FIRST, so: every shell metacharacter that can
#   chain, substitute, redirect or background is refused, which reduces a claim to ONE
#   simple command; then that command's program is checked against a destructive
#   denylist, and its arguments against a dangerous-flag denylist. Nothing executes
#   until every declared claim has passed all three. REFUSAL IS STATIC: --static runs
#   the whole refusal path and executes nothing, so the refusal can be proven without
#   trusting it.
#
# DRILL-SCRATCH: read-only -- this file has NO selftest of its own; `--selftest` only prints
# a pointer to the separate red-proof (see @drill below), which is where the fixtures live and
# which sandboxes them under its own `mktemp -d`. This engine itself creates, edits and deletes
# nothing: it reads one handoff and re-runs the commands that handoff declares, and the refusal
# list above rejects every redirection, substitution and destructive program BEFORE anything is
# executed. Declared rather than sandboxed because there is no scratch for it to need.
#
# @verdict-contract
# @verdict 0  every declared claim was re-run and agreed (or there are none to run)
# @verdict 1  BLOCKER: a claim is false, unparseable, or refused as unsafe
# @verdict 2  CANNOT VERIFY: a claim was flaky, timed out, or was skipped as slow
# @drill ~/code/darwin-mac-ops/handoff-claims-drill.sh
# =============================================================================
import os
import re
import subprocess
import sys

CLAIMS_KEY = "claims"
CLAIM_ATTEMPTS = 3      # one run, then up to two MORE, and only when the first disagrees
# A wedged sweep must fail the leg, not hang the wrap. Overridable ONLY so the red-proof can
# fire the TIMEOUT verdict in a second instead of a quarter of an hour -- a verdict that can
# only be exercised by waiting is a verdict nobody ever proves.
CLAIM_TIMEOUT = int(os.environ.get("HANDOFF_CLAIM_TIMEOUT", "900"))
CMD_MAXLEN = 400

# Every tag this leg can emit, DECLARED rather than discovered. --selftest asserts that
# every key here was actually emitted by a probe, so a verdict added without a probe goes
# red BY CONSTRUCTION rather than by somebody remembering. (wealthTensor-95's 9-of-14.)
CLAIM_TAGS = {
    "OK":                 "re-run, and the observation agreed with the claim",
    "FALSE-CLAIM":        "disagreed on every attempt",
    "FLAKY":              "disagreed and then agreed -- a flaky check, NOT a caught liar",
    "SKIPPED-SLOW":       "declared slow and not run in this mode; un-run is not a pass",
    "PARSE-REFUSED":      "a line inside `claims:` does not match the declared shape",
    "MISSING-FIELD":      "a claim omits id, cmd or rc, or asserts a count it cannot observe",
    "UNKNOWN-FIELD":      "a claim carries a key this leg does not define",
    "DUPLICATE-ID":       "two claims share an id, so one of them is unreachable",
    "BAD-INT":            "rc or count is not an integer",
    "BAD-BOOL":           "slow is neither true nor false",
    "BAD-COUNT-RE":       "count_re does not compile, or does not capture exactly one group",
    "COUNT-NOT-FOUND":    "count_re matched nothing in the output, so the count is unverifiable",
    "TIMEOUT":            "the command did not finish inside CLAIM_TIMEOUT",
    "PIPED-CLAIM":        "the command chains, substitutes, redirects or backgrounds",
    "REFUSED-PROGRAM":    "the command's program is on the destructive denylist",
    "REFUSED-ARG":        "the command carries an argument on the dangerous-flag denylist",
    "TOO-LONG":           "the command is longer than CMD_MAXLEN, so it is a script, not a claim",
    "PIPED-VERIFY":       "ADVISORY: a verify: line in this handoff is piped and cannot assert rc",
    "UNREGISTERED-TAG":   "this leg emitted a tag that is not in CLAIM_TAGS",
}

CLAIM_REQUIRED = ("id", "cmd", "rc")
CLAIM_KNOWN = ("id", "cmd", "rc", "count", "count_re", "slow", "note")

# STAGE 1 -- shell metacharacters. `a | b` yields b's status, `a; b` yields b's, `a &`
# yields nothing at all; each is the -93 defect with a different operator. `$(`, a
# backtick and `<(` hide an ENTIRE second command inside a claim that looks simple, and
# `>` writes to the user's disk. Banning all of them is what reduces a claim to one
# simple command, which is the precondition for STAGE 2 being meaningful at all.
CLAIM_FORBIDDEN = (
    ("|",  "a pipe"),
    (";",  "a semicolon"),
    ("&",  "an ampersand"),
    ("$(", "a command substitution"),
    ("`",  "a backtick command substitution"),
    ("<(", "a process substitution"),
    (">",  "a redirection"),
    ("\n", "a newline"),
)

# STAGE 2 -- the program. A claim RE-RUNS a measurement; none of these measures anything.
DESTRUCTIVE_PROGRAMS = {
    "rm", "rmdir", "unlink", "shred", "srm", "trash",
    "mv", "dd", "mkfs", "newfs", "fdisk", "diskutil", "truncate", "tee",
    "chmod", "chown", "chflags", "chgrp", "install",
    "kill", "pkill", "killall", "shutdown", "reboot", "halt",
    "launchctl", "systemctl", "crontab", "at", "defaults", "csrutil",
    "sudo", "su", "doas", "eval", "exec", "source", "xargs",
    "apt", "apt-get", "yum", "dnf", "brew", "port", "npm", "yarn", "pnpm",
    "gem", "cargo", "go", "docker", "kubectl", "terraform", "ansible",
    "ssh", "scp", "rsync", "sftp", "nc", "ncat", "telnet",
}
# `pip`/`pip3` only mutate with a subcommand; see DANGEROUS_ARGS.
GIT_MUTATING = {
    "push", "reset", "checkout", "switch", "restore", "clean", "rebase", "merge",
    "commit", "am", "apply", "cherry-pick", "revert", "rm", "mv", "add", "stash",
    "gc", "prune", "filter-branch", "filter-repo", "update-ref", "reflog", "worktree",
    "remote", "config", "init", "clone", "fetch", "pull", "tag", "branch", "notes",
    "submodule", "sparse-checkout", "replace", "repack", "fsck", "bisect", "daemon",
}
# STAGE 3 -- arguments that make an otherwise-innocent program destructive. Per-program,
# because a blanket flag denylist produces FALSE REFUSALS and a false refusal blocks a wrap:
# `-i` is sed's in-place edit and grep's case-insensitive match, and refusing `grep -i` would
# teach sessions that this leg cries wolf. The general set below is dangerous whoever runs it.
DANGEROUS_ARGS_ANY = {
    "-delete", "-exec", "-execdir", "-ok", "-okdir",       # find, whatever invokes it
    "--force", "--hard", "--prune", "--purge",
    # NOT "-f": it is `file` to grep, awk, make, tar and docker-compose far more often than
    # it is `force` to anything a claim would legitimately run, and a denylist that refuses
    # `grep -f patterns.txt` teaches sessions that this leg cries wolf. Long form only.
}
DANGEROUS_ARGS_BY_PROG = {
    "sed":    {"-i", "--in-place"},
    "perl":   {"-i", "-i.bak"},
    "ruby":   {"-i"},
    "gsed":   {"-i", "--in-place"},
    "curl":   {"-o", "-O", "--output", "--remote-name"},
    "wget":   {"-O", "--output-document"},
    "pip":    {"install", "uninstall"},
    "pip3":   {"install", "uninstall"},
    "python":  {"-c"},   # -c is an inline program: the whole refusal list would be bypassed
    "python3": {"-c"},
    "bash":    {"-c"},
    "sh":      {"-c"},
    "zsh":     {"-c"},
}

VERIFY_LINE = re.compile(r"verify:\s*(.+)")
# A verify: line is only AUDITED as a command when it opens with a backticked span that
# looks like a program invocation. Measured: without this, "verify: the card is OPEN."
# and "verify: as above -- it no longer appears in the ratchet." are read as commands.
VERIFY_CMDISH = re.compile(r"^\s*`([^`\n]+)`")
VERIFY_PROGRAMISH = re.compile(r"^[A-Za-z_/~.][\w./~-]*\s")


def _tag(tag, message):
    """Every problem this leg reports goes through here, so an UNDECLARED tag cannot escape.

    A guard that can emit a verdict its own coverage check has never heard of IS the
    9-of-14 defect. Making the emission path the enforcement point means a successor who
    adds a verdict and forgets the registry finds out on the first run, not at review."""
    if tag not in CLAIM_TAGS:
        return ("UNREGISTERED-TAG: %r is not in CLAIM_TAGS -- add it, and add a probe for "
                "it in handoff-claims-drill.sh. Original message: %s" % (tag, message))
    return "%s: %s" % (tag, message)


# --------------------------------------------------------------------------- the registry
def registry_block(text):
    """The raw `claims:` region, from EITHER of the two shapes the estate actually has.

    wealth-tensor keeps it in YAML front matter. Measured on 2026-09-08: 12 of the 185
    handoffs in ~/Desktop/downloads have front matter at all, so demanding it would make
    this leg inapplicable to 93% of its own subject matter. A fenced ```claims block is
    therefore accepted too, and BOTH are parsed by the SAME parser below -- two shapes,
    one grammar, because two parsers is how the two halves of a rule drift apart."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if m and re.search(r"^claims:\s*$", m.group(1), re.M):
        return m.group(1), "front matter"
    m = re.search(r"^```claims[ \t]*\n(.*?)^```[ \t]*$", text, re.S | re.M)
    if m:
        # A fenced block IS the claims list, so give the parser the header it expects.
        return CLAIMS_KEY + ":\n" + m.group(1), "```claims fence"
    return "", ""


def parse_claims(fm_text):
    """(claims, problems) from the `claims:` block. REFUSES what it cannot parse.

    A LINE THIS PARSER DOES NOT UNDERSTAND IS A PROBLEM, NOT A SKIP. The tempting
    forgiving parser -- ignore what you cannot read and carry on -- would let one typo'd
    key quietly drop a sweep from the work list and still print a clean board. That is
    the entire family of defect this leg was built for."""
    claims, problems = [], []
    lines = fm_text.split("\n")
    try:
        start = next(i for i, ln in enumerate(lines) if ln.rstrip() == CLAIMS_KEY + ":")
    except StopIteration:
        return [], []
    cur = None
    for ln in lines[start + 1:]:
        if not ln.strip():
            continue
        if not ln.startswith(" "):          # the next top-level key ends the block
            break
        m = re.match(r"^  - (\w+): ?(.*)$", ln)
        if m:
            if cur is not None:
                claims.append(cur)
            cur = {}
        else:
            m = re.match(r"^    (\w+): ?(.*)$", ln)
            if m is None or cur is None:
                problems.append(_tag("PARSE-REFUSED",
                                     "%r is not `  - key: value` or `    key: value` "
                                     "inside `claims:`" % ln))
                continue
        key, val = m.group(1), m.group(2).strip()
        if len(val) >= 2 and val[0] == '"' and val[-1] == '"':
            val = val[1:-1]
        if key not in CLAIM_KNOWN:
            problems.append(_tag("UNKNOWN-FIELD",
                                 "%r (known: %s)" % (key, ", ".join(CLAIM_KNOWN))))
            continue
        if key in cur:
            problems.append(_tag("PARSE-REFUSED", "%r given twice in one claim" % key))
            continue
        cur[key] = val
    if cur is not None:
        claims.append(cur)

    seen = set()
    for c in claims:
        who = c.get("id") or c.get("cmd") or "(unnamed claim)"
        for f in CLAIM_REQUIRED:
            if f not in c:
                problems.append(_tag("MISSING-FIELD", "%s: no %s" % (who, f)))
        if c.get("id") in seen:
            problems.append(_tag("DUPLICATE-ID", "%r declared twice" % c.get("id")))
        seen.add(c.get("id"))
        for f in ("rc", "count"):
            if f in c:
                try:
                    c[f] = int(str(c[f]).strip())
                except ValueError:
                    problems.append(_tag("BAD-INT", "%s: %s=%r" % (who, f, c[f])))
                    c[f] = None
        if "slow" in c:
            if str(c["slow"]).strip().lower() not in ("true", "false"):
                problems.append(_tag("BAD-BOOL", "%s: slow=%r" % (who, c["slow"])))
                c["slow"] = False
            else:
                c["slow"] = str(c["slow"]).strip().lower() == "true"
        else:
            c["slow"] = False
        c["_rx"] = None
        if "count_re" in c:
            try:
                rx = re.compile(c["count_re"])
            except re.error as e:
                problems.append(_tag("BAD-COUNT-RE", "%s: %r (%s)" % (who, c["count_re"], e)))
                rx = None
            if rx is not None and rx.groups != 1:
                problems.append(_tag("BAD-COUNT-RE",
                                     "%s: %r captures %d group(s), needs exactly 1"
                                     % (who, c["count_re"], rx.groups)))
                rx = None
            c["_rx"] = rx
        if c.get("count") is not None and c["_rx"] is None:
            problems.append(_tag("MISSING-FIELD",
                                 "%s: a count with no usable count_re cannot be observed, so "
                                 "it would be asserted and never checked" % who))
        problems.extend(refuse(c.get("cmd", ""), who))
    return claims, problems


# --------------------------------------------------------------------------- the refusal
def refuse(cmd, who):
    """Everything that must be true BEFORE this leg is allowed to execute `cmd`.

    Called from parse_claims, so it runs in --static as well as in a real pass: the
    refusal is provable without executing anything, which is the only kind of safety
    check worth having in a leg whose whole job is to execute strings out of a document
    written by somebody else."""
    problems = []
    if not cmd:
        return problems
    if len(cmd) > CMD_MAXLEN:
        problems.append(_tag("TOO-LONG",
                             "%s: %d chars (max %d). A claim that long is a script; give it "
                             "a name and claim the script." % (who, len(cmd), CMD_MAXLEN)))
        return problems
    for bad, human in CLAIM_FORBIDDEN:
        if bad in cmd:
            problems.append(_tag("PIPED-CLAIM",
                                 "%s: %r contains %s. The exit code of a chained command is "
                                 "the LAST one's -- that is the defect this leg exists for -- "
                                 "and a substitution or redirection hides a second command "
                                 "inside a claim that looks simple. Give it a script with a "
                                 "name instead." % (who, cmd, human)))
    if problems:
        return problems      # the token walk below is only meaningful on ONE simple command
    try:
        import shlex
        toks = shlex.split(cmd)
    except ValueError as e:
        problems.append(_tag("PARSE-REFUSED", "%s: %r does not tokenise (%s)" % (who, cmd, e)))
        return problems
    if not toks:
        problems.append(_tag("MISSING-FIELD", "%s: cmd is empty" % who))
        return problems
    prog = os.path.basename(toks[0])
    if prog in DESTRUCTIVE_PROGRAMS:
        problems.append(_tag("REFUSED-PROGRAM",
                             "%s: %r. A claim RE-RUNS a measurement and %r does not measure, "
                             "it acts. This leg executes strings out of a document; the "
                             "denylist is what makes that safe." % (who, cmd, prog)))
        return problems
    if prog == "git" and len(toks) > 1:
        sub, skip = None, False
        for j, t in enumerate(toks[1:], start=1):      # enumerate, NOT toks.index(): index()
            if skip:                                    # returns the FIRST slot holding that
                skip = False                            # string, so a repeated token walks
                continue                                # the wrong argument.
            if t in ("-C", "-c", "--git-dir", "--work-tree"):
                skip = True
                continue
            if t.startswith("-"):
                continue
            sub = t
            break
        if sub in GIT_MUTATING:
            problems.append(_tag("REFUSED-PROGRAM",
                                 "%s: `git %s` mutates the repository. Claim a read-only git "
                                 "(status --porcelain, log, rev-parse, diff --stat)."
                                 % (who, sub)))
            return problems
    bad_for_prog = DANGEROUS_ARGS_BY_PROG.get(prog, set())
    for t in toks[1:]:
        if t in DANGEROUS_ARGS_ANY or t in bad_for_prog:
            problems.append(_tag("REFUSED-ARG",
                                 "%s: %r carries %r, which writes, deletes or smuggles an "
                                 "inline program past this refusal list. A claim observes."
                                 % (who, cmd, t)))
            return problems
    return problems


# --------------------------------------------------------------------------- the advisory
def piped_verifies(text):
    """G-AR#piped -- the anti-omission half, ANCHORED on a real convention.

    Reads the handoff's own `verify:` lines (G-AQ's convention, mechanically located) and
    names the ones that open with a backticked command containing a pipe. Those lines look
    like verification and cannot assert an exit code. ADVISORY on purpose: 13 of 13 in the
    handoff that motivated it means a blocker here would red every session on day one, and
    a floor that reds everybody gets switched off rather than paid down. G-AQ#verify and
    G-AQ#selfcount set the precedent -- make the finding visible, leave the exit code."""
    out = []
    for m in VERIFY_LINE.finditer(text):
        rest = m.group(1)
        cm = VERIFY_CMDISH.match(rest)
        if not cm:
            continue
        inner = cm.group(1).strip()
        if not VERIFY_PROGRAMISH.match(inner):
            continue
        if "|" in inner:
            out.append(inner if len(inner) <= 96 else inner[:93] + "...")
    return out


# --------------------------------------------------------------------------- running
def run_claim(c, cwd):
    """One attempt. (rc, output).

    `bash -c` with CAPTURED output is the UN-PIPED form: the returncode is the command's
    own, not a downstream reader's. This is the one line the whole leg exists to get
    right, so it is written once, here, and never re-derived at a call site."""
    try:
        r = subprocess.run(["bash", "-c", c["cmd"]], cwd=cwd, capture_output=True,
                           text=True, timeout=CLAIM_TIMEOUT)
    except subprocess.TimeoutExpired:
        return None, ""
    except OSError as e:
        return -1, str(e)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def observe(c, cwd):
    """(agrees, why) for ONE attempt, against everything the claim asserts."""
    rc, out = run_claim(c, cwd)
    if rc is None:
        return False, _tag("TIMEOUT", "no result after %ds" % CLAIM_TIMEOUT)
    if rc != c["rc"]:
        return False, "RC %d, claimed %d" % (rc, c["rc"])
    if c.get("count") is not None:
        m = c["_rx"].search(out)
        if not m:
            return False, _tag("COUNT-NOT-FOUND", "%r matched nothing" % c["count_re"])
        got = int(m.group(1))
        if got != c["count"]:
            return False, "RC %d ok, count %d, claimed %d" % (rc, got, c["count"])
        return True, "RC %d, count %d" % (rc, got)
    return True, "RC %d" % rc


def claims_leg(path, run_slow=False, static_only=False, cwd=None):
    """Re-run what the handoff claims. Returns 0 / 1 / 2 -- the gate's tri-state."""
    if not path or not os.path.isfile(path):
        print("G-AR CANNOT VERIFY: no handoff at %r" % path)
        return 2
    text = open(path, encoding="utf-8", errors="replace").read()
    cwd = cwd or os.path.dirname(os.path.abspath(path))

    block, shape = registry_block(text)
    claims, problems = parse_claims(block)

    advisory = piped_verifies(text)

    if problems:
        print("G-AR REFUSED before running anything (%s):" % (shape or "no registry"))
        for p in problems:
            print("  - %s" % p)
        _print_advisory(advisory)
        return 1

    if not claims:
        print("G-AR: %s declares no `claims:` registry, so there is nothing to re-run."
              % os.path.basename(path))
        print("      An asserted exit code is a measurement or it is a rumour: declare it in")
        print("      a ```claims fence and this leg re-runs it, un-piped, before you hand over.")
        _print_advisory(advisory)
        return 0

    print("G-AR: %d declared claim(s) from the %s; %s."
          % (len(claims), shape,
             "running all" if run_slow else "slow ones skipped -- use --claims-all"))
    if static_only:
        print("  --static: the registry parses and every claim passed the refusal list. "
              "Nothing was executed.")
        _print_advisory(advisory)
        return 0

    ok, flaky, false_claims, skipped, timed_out = [], [], [], [], []
    for c in claims:
        who = c["id"]
        if c["slow"] and not run_slow:
            skipped.append(c)
            print("  %-14s %s%s" % ("SKIPPED-SLOW", who,
                                    "   (%s)" % c["note"] if c.get("note") else ""), flush=True)
            continue
        agrees, why = observe(c, cwd)
        if agrees:
            ok.append(c)
            print("  %-14s %s   %s" % ("OK", who, why), flush=True)
            continue
        if why.startswith("TIMEOUT:"):
            # A wedged command is an UNVERIFIABLE claim, not a proven false one. Re-running a
            # command that already burned CLAIM_TIMEOUT twice more would turn one slow wrap
            # into three, and would still not tell you whether the claim was true.
            timed_out.append((c, why))
            print("  %-14s %s   %s" % ("TIMEOUT", who, why), flush=True)
            continue
        # THE RE-RUN RULE. A disagreement is a question, not yet an accusation.
        trail, agreed_later = [why], False
        print("  %-14s %s   %s   -- re-running before reporting it"
              % ("DISAGREED", who, why), flush=True)
        for _ in range(CLAIM_ATTEMPTS - 1):
            a2, w2 = observe(c, cwd)
            trail.append(w2)
            if a2:
                agreed_later = True
                break
        if agreed_later:
            flaky.append((c, trail))
            print("  %-14s %s   %s" % ("FLAKY", who, " | ".join(trail)), flush=True)
        else:
            false_claims.append((c, trail))
            print("  %-14s %s   %s" % ("FALSE-CLAIM", who, " | ".join(trail)), flush=True)

    print("\nG-AR: %d agreed, %d FLAKY, %d FALSE, %d timed out, %d skipped as slow."
          % (len(ok), len(flaky), len(false_claims), len(timed_out), len(skipped)))
    _print_advisory(advisory)
    if false_claims:
        print("BLOCKER: the handoff claims a result its own commands do not produce.")
        for c, trail in false_claims:
            print("  - %s" % _tag("FALSE-CLAIM", "%s: %d attempts, every one disagreed: %s"
                                  % (c["id"], CLAIM_ATTEMPTS, " | ".join(trail))))
        return 1
    if timed_out:
        print("CANNOT VERIFY (exit 2): %d claim(s) did not finish inside %ds. A wedged command"
              % (len(timed_out), CLAIM_TIMEOUT))
        print("  is an UNVERIFIABLE claim, not a proven false one -- it is not evidence that the")
        print("  session that wrote it was wrong. Run it by hand, or declare it slow.")
        for c, why in timed_out:
            print("  - %s" % why)
        return 2
    if flaky:
        print("CANNOT VERIFY (exit 2): a check disagreed and then agreed. THAT IS A FLAKY")
        print("  CHECK, NOT A CAUGHT LIAR -- do not report the predecessor as wrong.")
        for c, trail in flaky:
            print("  - %s" % _tag("FLAKY", "%s: %s" % (c["id"], " | ".join(trail))))
        return 2
    if skipped:
        print("CANNOT VERIFY (exit 2): %d slow claim(s) were not re-run, and an un-run claim"
              % len(skipped))
        print("  is not a verified one. Run --claims-all before you hand this over.")
        return 2
    return 0


def _print_advisory(advisory):
    if not advisory:
        return
    print("  ADVISORY (G-AR#piped): %d `verify:` line(s) in this handoff run a PIPED command."
          % len(advisory))
    print("      `$?` after a pipe is the PIPE's, so those lines cannot assert an exit code --")
    print("      they are eyeball instructions. To make one verify, declare it un-piped in the")
    print("      `claims:` registry. Advisory, not a blocker (G-AQ#verify precedent).")
    for a in advisory[:6]:
        print("      - %s" % _tag("PIPED-VERIFY", a))
    if len(advisory) > 6:
        print("      - ... and %d more" % (len(advisory) - 6))


def main(argv):
    path, run_slow, static_only = None, False, False
    i = 0
    # EVERY branch advances i ITSELF and there is NO increment at the bottom of the loop.
    # The first draft had both, so `--handoff PATH` consumed three slots and every flag
    # after it was skipped: the leg read as installed and could not be switched on. The
    # drill caught it (probes #6 and #26) before it shipped -- which is the whole argument
    # for writing the red-proof before trusting the tool.
    while i < len(argv):
        a = argv[i]
        if a == "--handoff":
            if i + 1 >= len(argv):
                print("--handoff needs a path", file=sys.stderr); return 2
            path = os.path.expanduser(argv[i + 1]); i += 2
        elif a in ("--claims-all", "--all"):
            run_slow = True; i += 1
        elif a == "--static":
            static_only = True; i += 1
        elif a == "--selftest":
            # The red-proof is a SEPARATE, declared drill (see @drill in the header) so that
            # the thing proving this leg can go red is not the same file that would have to
            # be trusted. Point at it rather than growing a second, weaker copy in here.
            print("handoff-claims.py has no in-file selftest ON PURPOSE. The red-proof is:")
            print("  bash ~/code/darwin-mac-ops/handoff-claims-drill.sh")
            return 2
        elif a in ("-h", "--help"):
            print("handoff-claims.py --handoff PATH [--claims-all] [--static]")
            return 0
        else:
            print("unknown arg: %s" % a, file=sys.stderr); return 2

    return claims_leg(path, run_slow=run_slow, static_only=static_only)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
