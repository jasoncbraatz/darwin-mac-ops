#!/bin/bash
# ratification-census.sh — does anything ever RE-EXAMINE a ratification?
#
# Born acmeLedger-25 (2026-08-15), as the next turn of the read-through:
#   -22 controls that print nothing when unplugged
#   -23 controls aimed at the wrong set
#   -24 a control whose SUBJECT was an allowlist of the familiar
#   -25 exceptions that no control ever re-reads
#
# THE PROBLEM. Every exception record in this estate was written to fail CLOSED at
# authoring time: # VANISH-OK: demands 20+ chars of reason, # ASANA-READ-OK: the same,
# gate-secret-sweep.allow reports ALLOW-NOREASON, bb-writers-allowlist.json wants a
# reason a human can audit. Not one of them has an expiry, a last-reviewed date, or a
# check that the excused condition still EXISTS. A ratchet whose exceptions are never
# re-read converges on a green light with a long footnote — and the footnote is where
# the real state of the estate quietly moves in.
#
# Two kinds of record, and only one of them can rot invisibly:
#
#   SELF-POLICING — the record is compared against reality on every run, so a stale
#     entry surfaces by construction. card-lint.baseline FAILS when a baselined site
#     stops offending; fda-canary's TSV is a hash that stops matching. For these the
#     census does NOT re-run the tool (that is G-V#3's and G-X's job, and re-running
#     costs wall clock a tired session will eventually skip). It asserts the
#     re-examination LOGIC IS STILL THERE — the regression to fear is somebody
#     flipping MUT_RATCHET_RETIRE off, not the ratchet failing to fire.
#
#   SUBTRACTIVE — the record only ever REMOVES findings. A stale entry is invisible by
#     construction: it suppresses nothing, so it prints nothing, so nobody learns it is
#     dead. Worse, it is fail-open in the FUTURE tense — a pattern ratifying a deleted
#     script pre-authorizes the next file that lands at that path, carrying somebody
#     else's reason from a year ago. These are the census's real subject: every entry
#     must still suppress something TODAY.
#
# THE SUBJECT IS DISCOVERED, NOT LISTED. -24's lesson was that a selector written as an
# allowlist of the familiar fails open on everything added later. So this script does not
# work from a list of records it knows about: it SWEEPS the estate for the two shapes an
# exception record can take (an inline <TOKEN>-OK: marker, a side file named like an
# allowlist or a baseline) and FAILS on any it does not know how to check. A new record
# invented tomorrow turns this red until somebody teaches the census to read it. Unknown
# counts as ours.
#
# (The author's own first selector required a leading '#' on the marker and therefore
# could not see CARD-LINT-OK:, which lives in HTML comments inside Asana cards. The
# subject was drawn around the shapes already in hand — on the session whose entire
# topic is that mistake. The regex below has no '#' in it for exactly that reason.)
#
# EXIT CODES (read them BARE — never through a pipe):
#   0  every ratification in the estate still describes something true
#   1  at least one entry excuses a subject that no longer exists, OR an exception
#      record was found that this census does not know how to check (fails CLOSED)
#   2  CANNOT VERIFY — a subject enumeration came back empty, so a clean report would
#      mean nothing. An empty world is not a clean world.
#
# ENV (the drill drives the census through these; production sets none of them):
#   RC_HOME, RC_BB_ALLOW, RC_FOREIGN, RC_DIVERGE, RC_GE_ALLOW, RC_ARL_BASELINE,
#   RC_GATE_FILE, RC_CARD_LINT, RC_ARL, RC_SCAN_ROOTS, RC_LAUNCHCTL, RC_NO_SWEEP
set -uo pipefail
exec /usr/bin/python3 - "$@" <<'PYEOF'
import os, sys, re, json, glob, fnmatch, subprocess, datetime, fnmatch as fm

HOME    = os.environ.get("RC_HOME", os.path.expanduser("~"))
def H(*p): return os.path.join(HOME, *p)
def rel(p): return "~/" + os.path.relpath(p, HOME) if p.startswith(HOME) else p

BB_ALLOW     = os.environ.get("RC_BB_ALLOW",     H("repos/claude-blackbook/scripts/bb-writers-allowlist.json"))
FOREIGN      = os.environ.get("RC_FOREIGN",      H("code/darwin-mac-ops/launchd-foreign-allowlist.txt"))
DIVERGE      = os.environ.get("RC_DIVERGE",      H("code/darwin-mac-ops/launchd-divergence-allowlist.txt"))
EPHEMERAL    = os.environ.get("RC_EPHEMERAL",    H("code/darwin-mac-ops/launchd-ephemeral-allowlist.txt"))  # G-AE 3rd category (smDrainGate4, SM 1218198174895655)
GE_ALLOW     = os.environ.get("RC_GE_ALLOW",     H("code/darwin-mac-ops/gate-secret-sweep.allow"))
ARL_BASELINE = os.environ.get("RC_ARL_BASELINE", H("Scripts/asana-read-lint.baseline"))
RD_ALLOW     = os.environ.get("RC_RD_ALLOW",     H("Scripts/repo-doctor.allow"))
CARD_BASE    = os.environ.get("RC_CARD_BASELINE",H("Scripts/card-lint.baseline"))
PG_ALLOW     = os.environ.get("RC_PG_ALLOW",     H("Scripts/portability-guard.allow"))   # feynmanSync-02
GATE_FILE    = os.environ.get("RC_GATE_FILE",    H("code/darwin-mac-ops/gate-selfcheck.sh"))
CARD_LINT    = os.environ.get("RC_CARD_LINT",    H("Scripts/card-lint.py"))
ARL          = os.environ.get("RC_ARL",          H("Scripts/asana-read-lint.py"))
FDA_CANARY   = os.environ.get("RC_FDA_CANARY",   H("Scripts/fda-canary.sh"))
LAUNCHCTL    = os.environ.get("RC_LAUNCHCTL",    "")     # a file of labels, for the drill
LAUNCHCTL_ABSENT = None                                  # set when the binary is not on this box
NO_SWEEP     = os.environ.get("RC_NO_SWEEP", "") == "1"  # skip the git-grep secret replay
SCAN_ROOTS   = [p for p in os.environ.get(
    "RC_SCAN_ROOTS", ":".join([H("Scripts"), H("code/darwin-mac-ops"),
                               H("repos/claude-blackbook/scripts")])).split(":") if p]

FAILS, NOTES, ROWS = [], [], []
REASONS = []   # (record, entry, UNTRUNCATED reason) — phase 4's subject
VERDICT_RC = [0]
def cannot(msg):
    print("  CANNOT VERIFY: %s" % msg); VERDICT_RC[0] = 2
def stale(msg):
    FAILS.append(msg)

VENDOR = re.compile(r"/(\.git|node_modules|__pycache__|venv|\.venv|site-packages|"
                    r"\.cdp-profile|\.shopify-profile|profile/Default|Extensions)/")

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — DISCOVERY. Sweep for the SHAPES an exception record takes. Anything
# discovered that is not in the registry below is a FAIL, not a shrug.
# ─────────────────────────────────────────────────────────────────────────────
KNOWN_MARKERS = {"VANISH-OK:", "ASANA-READ-OK:", "CARD-LINT-OK:"}
KNOWN_FILES   = {os.path.realpath(p) for p in
                 (BB_ALLOW, FOREIGN, DIVERGE, EPHEMERAL, GE_ALLOW, ARL_BASELINE, CARD_BASE, RD_ALLOW,
                  PG_ALLOW)}

# no leading '#' in this pattern, deliberately: see the header.
MARKER_RX = re.compile(r"\b[A-Z][A-Z0-9]+(?:-[A-Z0-9]+)*-OK:")
FILE_RX   = re.compile(r"(allowlist|allow|baseline|exempt|waiver|ratified)", re.I)
TEXT_EXT  = (".sh", ".py", ".md", ".txt", ".json", ".yaml", ".yml", ".allow", ".baseline")

def discover():
    markers, files = {}, {}
    for root in SCAN_ROOTS:
        if not os.path.isdir(root):
            continue
        for dp, dn, fn in os.walk(root):
            if VENDOR.search(dp + "/"):
                dn[:] = []; continue
            dn[:] = [d for d in dn if not VENDOR.search("/%s/" % d)]
            for f in fn:
                p = os.path.join(dp, f)
                if ".bak" in f or f.endswith((".png", ".pyc")):
                    continue
                # NOT gated on extension. The drill caught this: a record named
                # `*.allowlist` slipped straight through an extension allowlist, which is
                # the same bug this whole script exists to hunt, committed by the hunter.
                if FILE_RX.search(f):
                    files[os.path.realpath(p)] = p
                if not f.endswith(TEXT_EXT):
                    continue
                try:
                    txt = open(p, errors="ignore").read()
                except OSError:
                    continue
                for m in set(MARKER_RX.findall(txt)):
                    markers.setdefault(m, []).append(rel(p))
    return markers, files

print("=== ratification census · phase 1 · discovery (by shape, not by list) ===")
MARKERS, FILES = discover()
if not MARKERS and not FILES:
    cannot("the discovery sweep found ZERO exception records under %s — the estate has "
           "several, so this is a broken selector, not a clean estate"
           % ", ".join(rel(r) for r in SCAN_ROOTS))
print("  marker vocabularies found : %d  (%s)" % (len(MARKERS), ", ".join(sorted(MARKERS)) or "-"))
print("  record files found        : %d" % len(FILES))
for m in sorted(MARKERS):
    if m not in KNOWN_MARKERS:
        stale("UNKNOWN RATIFICATION MARKER '%s' (in %s) — the census does not know how to "
              "check whether it still describes something true. Teach it, or delete the marker."
              % (m, ", ".join(MARKERS[m][:3])))
for rp, p in sorted(FILES.items()):
    if rp not in KNOWN_FILES:
        stale("UNKNOWN EXCEPTION RECORD %s — a file shaped like an allowlist/baseline that no "
              "checker in this census reads. Teach it, or prove it is not a ratification."
              % rel(p))

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — the SUBTRACTIVE records. Every entry must still suppress something.
# ─────────────────────────────────────────────────────────────────────────────
print()
print("=== phase 2 · subtractive records (a stale entry here is invisible by construction) ===")

def entries_of(path):
    """<pattern>  # <reason>  — the estate's shared allowlist grammar.

    A reason may WRAP onto the following lines, indented and comment-led. All three launchd
    allowlists in this repo are written that way, because a one-line reason for a subtle
    ratification is a reason nobody writes. Those lines ARE the entry's reason and come back
    joined to it. Before feynmanSync-08 they were discarded as file comments, which made every
    RETIRE-WHEN:/REVIEWED: clause written past the first line invisible to phase 4 — the only
    check that reads them. Measured on darwin 2026-09-07: com.braatz.travel-mode-rearm carried
    BOTH clauses, exactly as its file's own documented bar demands, and phase 4 counted it as
    carrying neither. So the file's bar and the census's meter disagreed, silently, and the
    FLOOR that is "supposed to fall" charged an author for doing the work.

    Note the shape, because it is the point. `row()` already guards the SIBLING case — a clause
    pushed past print column 44 — and its docstring says why: "a control that cannot see its
    subject is not a control." Guarding truncation and not wrapping is the nearby-handled-case
    trap: the careful guard one line below reads as coverage and stops the search. Both are the
    same fact, that what phase 4 PARSES must be the whole reason its author actually wrote.

    A comment at column 0 is a file or section header, NOT a continuation — otherwise a header
    could inject a retirement clause into whatever entry happened to precede it.
    """
    out = []
    if not os.path.exists(path):
        return None
    for raw in open(path, errors="ignore"):
        s = raw.strip()
        if not s:
            continue
        if s.startswith("#"):
            if out and raw[:1] in (" ", "\t"):
                out[-1] = (out[-1][0], out[-1][1] + " " + s.lstrip("#").strip())
            continue
        pat = s.split("#")[0].strip()
        if pat:
            out.append((pat, s))
    return out

def row(record, entry, n, why, full=None, verdict=None):
    """`why` is what PRINTS (truncated to fit); `full` is what phase 4 PARSES. They must be
    separate: a RETIRE-WHEN: clause written past column 44 would otherwise be invisible to the
    only check that reads it, and a control that cannot see its subject is not a control.

    `verdict` overrides the default below. THE DEFAULT IS A DERIVATION AND DERIVATIONS GO BLIND:
    it reads `n` alone, so it cannot see a checker that decided, on grounds of its own, not to
    file a finding. That is exactly what the TRANSIENT suppression did — see the SELF-CHECK just
    above the summary, which is the guard that makes the two agree from now on."""
    v = verdict or ("live" if n else "STALE")
    ROWS.append((record, entry, n, why, v))
    REASONS.append((record, entry, full if full is not None else why))
    # %-7s, not %-6s: "dormant" is seven characters, and a verdict column that only fits
    # the verdicts that existed when it was written is the same species of thing this
    # census hunts — a shape that silently mis-renders whatever was added after it.
    print("      %-7s n=%-4d %-46s %s" % (v, n, entry[:46], why))


# ──────────────────────────────────────────────────────────────────────────────
# ABSENT vs STALE — the box is not the estate (feynmanSync-07, 2026-09-07)
#
# Every subtractive check below judges an entry by walking THIS BOX's filesystem.
# The estate has boxes with different repo sets: darwin clones ~64, feynman 15.
# So a pattern pointing into a repo that was never cloned here matches zero files,
# and the check printed STALE and told the session to DELETE the entry — a false
# accusation, with a destructive remedy, against a shared git-backed allowlist,
# produced by nothing but this box's own incompleteness. Measured on feynman
# 2026-09-07: 20 of 20 STALE findings were false, every one of them a subject
# living in a repo that is not cloned here.
#
# It is also exactly the shape -06 spent its day on: an enumeration that fails by
# returning EMPTY, read as a substantive finding rather than as "I could not look."
#
# The discriminator is the directory that WOULD contain the subject:
#   container present, subject missing  -> the subject really died. STALE (rc 1).
#   container absent                    -> this box cannot know.     CANNOT VERIFY (rc 2).
# rc 2 is not a new code invented for this; it is the one this census already
# defines as "a subject enumeration came back empty, so a clean report would mean
# nothing." That is precisely the situation. It was simply never wired to the
# PARTIAL case: the pre-existing guards fire only when a walk finds ZERO files
# estate-wide, and a box that is half-populated sails straight through them.
#
# There is deliberately NO env var to force this. An "absent" a session can assert
# is an off-switch, and which repos exist on a box is a fact to be measured, not a
# flag to be passed. The drill drives both directions through RC_HOME fixtures, so
# it executes this real function rather than grading a copy of it.
ABSENT = []
BOX = os.uname().nodename.split(".")[0]

def container_of(pat):
    """The directory that would hold `pat`, i.e. the dirname of its glob-free prefix."""
    p = pat.replace("~/", HOME + "/", 1) if pat.startswith("~/") else pat
    if not p.startswith(HOME + "/"):
        return None                      # not a path-shaped subject under HOME
    cut = [i for i, c in enumerate(p) if c in "*?["]
    lit = p[:cut[0]] if cut else p
    d = lit if lit.endswith("/") else os.path.dirname(lit)
    d = d.rstrip("/")
    return d or None

def absent_here(record, pat, where=None):
    """True if `pat` cannot be judged on this box. Records it; never accuses."""
    if where is None:
        d = container_of(pat)
        if d is None or os.path.isdir(d):
            return False
        where = "%s is not on %s" % (rel(d), BOX)
    ABSENT.append((record, pat, where))
    return True

# --- 2a. bb-writers-allowlist.json (consumer: bb-writers-audit.py, gate G-AD) ---
print("  --- %s ---" % rel(BB_ALLOW))
try:
    bb = json.load(open(BB_ALLOW))["entries"]
except Exception as e:
    cannot("could not read %s (%s)" % (rel(BB_ALLOW), e)); bb = []
BB_ROOTS = [H(p) for p in ("repos", "code", "Scripts")]
BB_SKIP = {".git", "node_modules", "__pycache__", ".venv", "venv"}
bbfiles = []
for r in BB_ROOTS:
    for dp, dn, fn in os.walk(r):
        dn[:] = [d for d in dn if d not in BB_SKIP]
        bbfiles += [rel(os.path.join(dp, f)) for f in fn]
if bb and not bbfiles:
    cannot("bb-writers roots walked ZERO files — every pattern would read as stale")
else:
    for e in bb:
        pat = e["pattern"]
        n = sum(1 for f in bbfiles if fnmatch.fnmatch(f, pat))
        ab = (not n) and absent_here("bb-writers", pat)
        row("bb-writers", pat, n, (e.get("reason", "") or "")[:44], full=e.get("reason", "") or "",
            verdict="absent" if ab else None)
        if not n and not ab:
            stale("bb-writers-allowlist.json: pattern '%s' matches NO file today. It ratifies "
                  "nothing — and pre-ratifies whatever lands at that path next, carrying a "
                  "reason written for something else. Delete it." % pat)

# --- 2b/c. the two launchd allowlists (consumer: launchd-census.sh) ---
if LAUNCHCTL:
    labels = {l.strip() for l in open(LAUNCHCTL) if l.strip()}
else:
    # NO launchctl ON LINUX. Before feynmanSync-07 this line raised an UNCAUGHT
    # FileNotFoundError: the census died mid-phase-2, python exited 1, and G-AK read
    # that 1 as its specific finding — "an exception record excuses a subject that no
    # longer exists". It was neither true nor a finding; phases 2b through 5 simply
    # never ran, on every wrap on this box. The author DID foresee an empty label set
    # (the `not labels` branch below, and drill control 6) — but an absent TOOL and an
    # empty RESULT are different failures, and only the second one had been imagined.
    try:
        out = subprocess.run(["launchctl", "list"], capture_output=True, text=True).stdout
    except (FileNotFoundError, NotADirectoryError, PermissionError) as _e:
        out = ""; LAUNCHCTL_ABSENT = _e
    labels = {p[2].strip() for p in (l.split("\t") for l in out.splitlines()[1:])
              if len(p) >= 3 and p[2].strip()}
print("  --- launchd allowlists (loaded labels: %d) ---" % len(labels))
if LAUNCHCTL_ABSENT is not None:
    cannot("launchctl is not installed on %s (%s), so NOT ONE of the three launchd "
           "allowlists was judged here. This is a routing fact, not a finding: the "
           "launchd records can only be re-read on the box that runs launchd (darwin)."
           % (BOX, LAUNCHCTL_ABSENT.__class__.__name__))
elif not labels:
    cannot("launchctl listed ZERO labels — every launchd allowlist entry would read as stale")
else:
    for path, name in ((FOREIGN, "launchd-foreign"), (DIVERGE, "launchd-divergence"), (EPHEMERAL, "launchd-ephemeral")):
        ents = entries_of(path)
        if ents is None and name == "launchd-ephemeral":
            # OPTIONAL by nature: no ephemeral list means "no deliberately transient jobs today",
            # which is the ordinary estate (and every drill fixture). Missing != cannot-check here.
            print("    %s (absent — no ephemeral jobs declared)" % rel(path)); continue
        if ents is None:
            cannot("%s is missing — launchd-census would treat every third-party job as ours, "
                   "which is a different verdict, not a quiet one" % rel(path)); continue
        print("    %s (%d entries)" % (rel(path), len(ents)))
        for pat, line in ents:
            n = sum(1 for L in labels if fnmatch.fnmatch(L, pat))
            why = line.split("#", 1)[-1].strip() if "#" in line else ""
            # TRANSIENT: — a vendor job that only registers a launchd label WHILE it is doing
            # something (Squirrel/ShipIt updaters, installers). It is legitimately absent on any
            # ordinary day, so zero matches is not evidence of rot. This suppresses ONLY the
            # staleness finding: the row still prints, and the marker still demands a real
            # reason, so a bogus TRANSIENT is as visible in review as a bogus glob would be.
            # Deliberately narrow — it is not an excuse for a job that simply died. (2026-08-24)
            m = re.match(r"TRANSIENT:\s*(.+)", why)
            transient = bool(m) and len(m.group(1).strip()) >= 25
            # DORMANT, not STALE. The suppression below (skip the stale() call) and the verdict
            # in row() are computed in two different places, and nothing joined them: the finding
            # was correctly silenced while the row still read STALE, so the summary printed
            # "stale: 2" directly above rc 0 and "every ratification still describes something
            # true." Both lines were produced by the same run. (feynmanSync-08, measured on
            # darwin — the launchd phase never runs on a Linux box, so this needed darwin to see.)
            row(name, pat, n, ("transient · " + m.group(1).strip())[:44] if transient else why[:44],
                full=why, verdict=("dormant" if (transient and not n) else None))
            if not n and not transient:
                stale("%s: '%s' matches NO loaded launchd label today — it excuses a job that is "
                      "no longer running. Delete it, or say in the file why it is kept "
                      "(a vendor job that only appears while updating: prefix the reason "
                      "'TRANSIENT: ' plus 25+ chars saying when it DOES appear)."
                      % (rel(path), pat))
            if m and not transient:
                stale("%s: '%s' is marked TRANSIENT but its reason is too thin to audit — say "
                      "in 25+ chars WHEN the label actually appears." % (rel(path), pat))

# --- 2d. gate-secret-sweep.allow (consumer: G-E, via ge_allowed) ---
print("  --- %s ---" % rel(GE_ALLOW))
ge = entries_of(GE_ALLOW)
if ge is None:
    cannot("%s missing — G-E would report its suppressed count as zero, which reads like "
           "'nothing was suppressed' rather than 'the allowlist is gone'" % rel(GE_ALLOW))
elif NO_SWEEP:
    print("      (sweep replay skipped: RC_NO_SWEEP=1)")
elif not ge:
    print("      (no entries)")
else:
    # Replay the real sweep and attribute every suppressed hit to the rule that ate it.
    # G-E only ever prints an AGGREGATE count, so a rule suppressing zero is invisible there.
    secret_lib = H("code/darwin-mac-ops/hooks/secret-re.sh")
    rx = ""
    if os.path.exists(secret_lib):
        m = re.search(r'^SECRET_RE=[\'"](.+)[\'"]\s*$',
                      open(secret_lib, errors="ignore").read(), re.M)
        rx = m.group(1) if m else ""
    if not rx:
        cannot("could not read SECRET_RE out of %s — cannot replay the sweep the allowlist "
               "subtracts from" % rel(secret_lib))
    else:
        repos = []
        for r in (H("repos"), H("code"), H("Desktop/downloads"), H("Scripts")):
            for g in glob.glob(os.path.join(r, "*", ".git")) + glob.glob(os.path.join(r, ".git")):
                repos.append(os.path.dirname(g))
        if not repos:
            cannot("found ZERO git repos to sweep — every allow rule would read as stale")
        else:
            keys = []
            for repo in repos:
                p = subprocess.run(["git", "grep", "-nIE", rx], cwd=repo,
                                   capture_output=True, text=True)
                for ln in p.stdout.splitlines():
                    keys.append("%s/%s" % (os.path.basename(repo), ln.split(":")[0]))
            print("      sweep hits before suppression: %d (across %d repos)" % (len(keys), len(repos)))
            repo_names = {os.path.basename(r) for r in repos}
            for pat, line in ge:
                n = sum(1 for k in keys if fnmatch.fnmatch(k, pat))
                reason = line.split("#", 1)[-1].strip()
                # Same discriminator as bb-writers, different namespace: these keys are
                # "<repo basename>/<path>", so the container is the repo itself.
                head = pat.split("/")[0]
                ab = (not n) and not any(c in head for c in "*?[") and head not in repo_names
                if ab:
                    absent_here("gate-secret-sweep", pat,
                                "repo '%s' is not cloned on %s" % (head, BOX))
                row("gate-secret-sweep", pat, n, reason[:44], full=reason,
                    verdict="absent" if ab else None)
                if not n and not ab:
                    stale("gate-secret-sweep.allow: '%s' suppresses NOTHING in today's sweep. "
                          "G-E prints one aggregate count, so a dead rule is invisible there — "
                          "it sits ready to silence a future match nobody chose to excuse." % pat)

# --- 2e. repo-doctor.allow (consumer: repo-doctor.sh) ---
# The one entry here writes its own retirement condition into its reason ("drop this line
# when the repo goes") — which is exactly the thing nothing was checking. Now something does.
print("  --- %s ---" % rel(RD_ALLOW))
rd = entries_of(RD_ALLOW)
if rd is None:
    cannot("%s missing — repo-doctor would re-flag its exempt repos, a different verdict" % rel(RD_ALLOW))
elif not rd:
    print("      (no entries — nothing to go stale)")
elif not any(os.access(os.path.join(d, "gh"), os.X_OK) for d in os.environ.get("PATH", "").split(":")):
    cannot("gh is not on PATH — cannot ask GitHub whether the exempted repo(s) still exist")
else:
    for nwo, line in rd:
        # A NONZERO gh EXIT IS NOT PROOF OF ABSENCE. A TLS handshake timeout, an expired
        # token, a rate limit and a 5xx all exit nonzero, and reading any of them as "the
        # repo is gone" turns a network blip into a confident FAIL telling a session to
        # delete a live exemption. Observed 2026-08-24 (opus-mcpMirror-04): api.github.com
        # timed out for ~two minutes, the gate reported the repo deleted, and the repo was
        # there the whole time. Only a 404 means gone; everything else is CANNOT VERIFY,
        # which this file already knows how to say.
        p = subprocess.run(["gh", "api", "repos/%s" % nwo, "--jq", ".full_name"],
                           capture_output=True, text=True)
        err = (p.stderr or "") + (p.stdout or "")
        if p.returncode == 0:
            gone = False
        elif "404" in err or "Not Found" in err:
            gone = True
        else:
            row("repo-doctor", nwo, 1, "UNVERIFIED — gh could not reach GitHub")
            cannot("repo-doctor.allow: could not ask GitHub about '%s' (gh: %s). NOT a"
                   " stale-exemption finding — retry when the network is back."
                   % (nwo, err.strip().splitlines()[0][:80] if err.strip() else
                      "exit %d, no output" % p.returncode))
            continue
        n = 0 if gone else 1
        rd_reason = line.split("#", 1)[-1].strip()
        row("repo-doctor", nwo, n, rd_reason[:44], full=rd_reason)
        if gone:
            stale("repo-doctor.allow: '%s' returns 404 on GitHub — the exemption outlived "
                  "its subject, and the reason line said to drop it when the repo went. Drop it."
                  % nwo)

# --- 2f. inline markers: each must still be attached to a live offence ---
print("  --- inline markers ---")
def marker_sites(token):
    """Dedupe by REALPATH: ~/Scripts is half symlink farm, and gate-selfcheck.sh is a
    symlink into darwin-mac-ops — counting a file twice because it has two names is the
    same class of bug as claiming a NAME when the write lands on an INODE."""
    sites, seen = [], set()
    for root in SCAN_ROOTS + [H("Desktop/downloads")]:
        if not os.path.isdir(root):
            continue
        for dp, dn, fn in os.walk(root):
            if VENDOR.search(dp + "/"):
                dn[:] = []; continue
            for f in fn:
                if not f.endswith(TEXT_EXT) or ".bak" in f:
                    continue
                p = os.path.join(dp, f)
                rp = os.path.realpath(p)
                if rp in seen:
                    continue
                try:
                    hits = [(rel(p), i, ln.strip())
                            for i, ln in enumerate(open(p, errors="ignore"), 1) if token in ln]
                except OSError:
                    continue
                if hits:
                    seen.add(rp); sites += hits
    return sites

# VANISH-OK: delegate to the drill that owns the idiom — it reports how many guards are
# ratified-quiet. A marker the drill does not count is a marker attached to nothing.
drill = H("code/darwin-mac-ops/gate-cannot-verify-drill.sh")
vsites = [s for s in marker_sites("VANISH-OK:") if s[0].endswith("gate-selfcheck.sh")]
print("    VANISH-OK:      %d live marker(s) in the gate" % len(vsites))
if vsites and not os.path.exists(drill):
    # A missing delegate must SPEAK. Skipping quietly here would make this check vanish
    # exactly the way G-AA vanished in -24 — the whole reason the VANISH-OK idiom exists.
    cannot("%s is missing, so the %d VANISH-OK marker(s) went unchecked" % (rel(drill), len(vsites)))
elif vsites:
    d = subprocess.run(["bash", drill], capture_output=True, text=True,
                       env={**os.environ, "GATE_FILE": GATE_FILE})
    m = re.search(r"(\d+)\s+ratified-quiet", d.stdout + d.stderr)
    counted = int(m.group(1)) if m else -1
    if counted < 0:
        cannot("the vanish drill did not report a 'ratified-quiet' count — cannot tell whether "
               "the %d VANISH-OK marker(s) are attached to anything" % len(vsites))
    elif counted != len(vsites):
        stale("VANISH-OK: %d marker(s) in the gate but the drill counts %d as ratified — at "
              "least one marker excuses a guard that is no longer there (or no longer quiet)."
              % (len(vsites), counted))
    else:
        print("      live  n=%-4d %-46s drill agrees" % (counted, "attached to a real quiet guard"))

# ASANA-READ-OK: a declaration is only true while the site it sits on is still a raw
# single-page read. asana-read-lint reports those as "DECLARED EXEMPT"; a declaration on
# a site since routed through asana_client.py is a note about a world that moved on.
# The count below is INFORMATIONAL, not the verdict: help text, the lint's own regex and
# its short-reason fixtures all contain the token. The lint is the authority on which
# declarations are live — asking my own grep to adjudicate would be measuring the observer.
asites = [s for s in marker_sites("ASANA-READ-OK:") if re.match(r"#\s*ASANA-READ-OK:", s[2])]
print("    ASANA-READ-OK:  %d marker line(s) found (the lint, not this grep, is the authority)"
      % len(asites))
if asites and not os.path.exists(ARL):
    cannot("%s is missing, so the %d ASANA-READ-OK declaration(s) went unchecked" % (rel(ARL), len(asites)))
elif asites:
    p = subprocess.run(["/usr/bin/python3", ARL], capture_output=True, text=True)
    m = re.search(r"declared exempt\s*:\s*(\d+)", p.stdout)
    if not m:
        cannot("asana-read-lint printed no 'declared exempt' tally — cannot tell whether the "
               "%d declaration(s) still sit on a raw read" % len(asites))
    else:
        n = int(m.group(1))
        # the lint's own fixtures carry short-reason markers it deliberately rejects
        if n == 0 and len(asites) > 0:
            stale("ASANA-READ-OK: %d declaration(s) present but the lint counts 0 as declared "
                  "exempt — the excused reads were fixed or moved; retire the markers." % len(asites))
        else:
            print("      live  n=%-4d %-46s lint agrees" % (n, "still sitting on a raw read"))

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — the SELF-POLICING records. Assert the re-examination LOGIC still exists.
# ─────────────────────────────────────────────────────────────────────────────

# --- 2f. portability-guard.allow (consumer: portability-guard.sh, pre-commit in darwin-scripts) ---
# Grammar here is `<glob> | <why this path is legitimately darwin-only>`, NOT the estate's usual
# `#` form, so the reason must be split off the pipe.
# The rightness test is bb-writers-allowlist's: a glob matching NO tracked file today ratifies
# NOTHING. Either the darwin-only path it excused is gone (retire the ruling) or the glob is a
# typo that has been silently excusing nothing while reading as a deliberate decision.
# Added feynmanSync-02 (2026-09-07). Before this, the file was shaped exactly like a ratification
# and no checker in this census read it -- which is the UNKNOWN EXCEPTION RECORD it kept failing
# on. Its own header calls a line here "a RULING, not a snooze"; a ruling nothing re-judges is a
# snooze with better manners.
print("  --- %s ---" % rel(PG_ALLOW))
pg = entries_of(PG_ALLOW)
if pg is None:
    cannot("%s missing -- portability-guard would re-flag every deliberately-darwin path" % rel(PG_ALLOW))
elif not pg:
    print("      (no entries -- nothing to go stale)")
else:
    import fnmatch
    _root = H("Scripts")
    _t = subprocess.run(["git", "ls-files"], cwd=_root, capture_output=True, text=True)
    if _t.returncode != 0:
        cannot("could not list tracked files in %s -- cannot tell whether a glob still ratifies anything" % rel(_root))
    else:
        _files = [f for f in _t.stdout.split("\n") if f]
        for _pat, _line in pg:
            _glob = _pat.split("|")[0].strip()
            if not _glob:
                continue
            _n = sum(1 for f in _files
                     if fnmatch.fnmatch(f, _glob) or fnmatch.fnmatch(os.path.basename(f), _glob))
            _why = _line.split("|", 1)[1].strip() if "|" in _line else "(no reason given)"
            row("portability-guard", _glob, _n, _why[:44], full=_line)
            if _n == 0:
                stale("portability-guard.allow: glob '%s' matches NO tracked file today. It "
                      "ratifies nothing -- retire the line, or fix the typo that has been "
                      "silently excusing nothing." % _glob)

print()
print("=== phase 3 · self-policing records (the regression to fear is the ratchet being turned OFF) ===")
def assert_logic(label, path, needle, why):
    if not os.path.exists(path):
        cannot("%s missing — cannot confirm %s still re-examines its own baseline" % (rel(path), label))
        return
    txt = open(path, errors="ignore").read()
    ok = re.search(needle, txt) is not None
    print("    %-16s %-7s %s" % (label, "ok" if ok else "GONE", why))
    if not ok:
        stale("%s no longer contains its stale-entry re-examination (%s). Its baseline can now "
              "rot silently: an entry that stopped being an offender stays, and the file that "
              "may only shrink starts to hold fiction." % (rel(path), needle))

assert_logic("card-lint G-V#3", CARD_LINT, r"MUT_RATCHET_RETIRE\s*=\s*True",
             "a baseline entry that no longer offends FAILS")
assert_logic("asana-read-lint",  ARL,       r"RATCHET DOWN",
             "prints baseline sites that no longer offend (speaks; does not bite)")
assert_logic("fda-canary G-X",   FDA_CANARY, r"--update-baseline",
             "hash baseline is compared to reality every run (self-invalidating)")

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4 — RIGHTNESS. A ratification can still MATCH and no longer be RIGHT.
#
# Phases 1-3 answer "does this entry still suppress something?". That is a MECHANICAL
# question and it is the only one a matcher can answer. The semantic question — "is the
# reason written beside it still TRUE?" — is not decidable from the pattern, ever: a glob
# can go on matching a live file for years after the fork got vendored, the fixture became
# production, or the guarantee the exception leaned on was quietly deleted.
#
# There is exactly ONE thing a machine can check here, and the estate already had one honest
# instance of it before this phase existed: repo-doctor.allow's entry writes its own
# retirement condition into its reason ("drop this line when the repo goes"). So the rule is
# not "let the census guess at rightness" — it is "make the AUTHOR write down, at authoring
# time, the observable fact that would END the exception", and then check that fact every run.
#
#   RETIRE-WHEN: <verb>:<arg>     in the reason text of any entry, in any record.
#
#     path-gone:<glob>            retire when nothing matches this path any more
#     path-here:<glob>            retire when something DOES land at this path
#     text-gone:<path>::<needle>  retire when <path> stops containing <needle> — the shape
#                                 for "this divergence is ratified ONLY because <guard>
#                                 still exists". The guard leaving is the retirement.
#     after:<YYYY-MM-DD>          a time-boxed exception; retire on that date
#
# An unknown verb is a FAIL, not a shrug — same doctrine as phase 1. A predicate whose
# SUBJECT cannot be read (the named file is missing) is CANNOT VERIFY, never a retirement:
# absence of evidence is not evidence of absence, which this file already learned the
# expensive way from gh in 2e.
#
#   REVIEWED: <YYYY-MM-DD>        the weak, cheap companion. Past RC_REVIEW_MAX_DAYS this
#                                 WARNS (rc unchanged) — it catches "nobody has looked at
#                                 this since S44", which no matching test can. A date in
#                                 the FUTURE is a FAIL: nobody reviewed anything on it.
#
# COVERAGE IS A FLOOR, NOT A VERDICT. On the day this shipped, 1 of ~55 entries carried a
# RETIRE-WHEN. Failing the other 54 would be tightening a ratchet with no rollout, and the
# estate has just watched a census floor (G-AP's 340 undeclared scripts) grow 35 in a day
# by being wallpaper. So the uncovered count PRINTS, every run, as a number that is supposed
# to fall — and the rollout is a card, not a silent red.
# ─────────────────────────────────────────────────────────────────────────────
print()
print("=== phase 4 · rightness (matching is mechanical; rightness must be WRITTEN DOWN) ===")

REVIEW_MAX_DAYS = int(os.environ.get("RC_REVIEW_MAX_DAYS", "180"))
TODAY = os.environ.get("RC_TODAY", "") or datetime.date.today().isoformat()

# The predicate may be double-quoted, because text-gone's needle is prose and prose has
# spaces. A bare \S+ form is kept for the short verbs (path-gone, after) where it reads better.
RETIRE_RX   = re.compile(r'RETIRE-WHEN:\s*(?:"([^"]+)"|(\S+))')
REVIEWED_RX = re.compile(r"REVIEWED:\s*(\S+)")
RETIRE_VERBS = ("path-gone", "path-here", "text-gone", "after")

def _p(path):
    path = path.strip()
    return H(path[2:]) if path.startswith("~/") else os.path.expanduser(path)

def retires(pred):
    """-> (True retire now | False still right | None cannot verify, one-line detail)."""
    verb, _, arg = pred.partition(":")
    if verb not in RETIRE_VERBS or not arg.strip():
        return "BAD", "unknown or empty verb"
    # A path predicate is evaluated against THIS BOX. If the directory that would hold
    # the subject is not here, no answer is available in either direction — and this is
    # the most destructive place to guess, because a satisfied path-gone tells the next
    # session to DELETE a live ratification. `text-gone` already got this right (missing
    # file -> None); the two path verbs did not. (feynmanSync-07)
    if verb in ("path-gone", "path-here"):
        hits = glob.glob(_p(arg))
        if not hits and container_of(_p(arg).replace(HOME + "/", "~/", 1)) \
           and not os.path.isdir(container_of(_p(arg).replace(HOME + "/", "~/", 1))):
            return None, "%s is not on %s — cannot tell whether the subject is gone or absent" % (
                arg, BOX)
        if verb == "path-gone":
            return (not hits), ("nothing at %s" % arg) if not hits else ("%d path(s) still there" % len(hits))
        return bool(hits), ("%d path(s) landed at %s" % (len(hits), arg)) if hits else ("still nothing at %s" % arg)
    if verb == "text-gone":
        f, _, needle = arg.partition("::")
        if not needle.strip():
            return "BAD", "text-gone needs <path>::<needle>"
        fp = _p(f)
        if not os.path.exists(fp):
            return None, "cannot read %s" % f
        try:
            txt = open(fp, errors="ignore").read()
        except OSError as e:
            return None, "cannot read %s (%s)" % (f, e)
        return (needle not in txt), ("%s no longer contains it" % f) if needle not in txt \
               else ("%s still contains it" % f)
    # after:
    try:
        datetime.date.fromisoformat(arg.strip())
    except ValueError:
        return "BAD", "after: needs YYYY-MM-DD"
    return (TODAY > arg.strip()), ("expired %s (today %s)" % (arg.strip(), TODAY))

covered = 0
for record, entry, reason in REASONS:
    reason = reason or ""
    m = RETIRE_RX.search(reason)
    r = REVIEWED_RX.search(reason)
    if m:
        covered += 1
        pred = m.group(1) or m.group(2)
        verdict, detail = retires(pred)
        if verdict == "BAD":
            print("    BAD   %-20s %-30s %s" % (record, entry[:30], pred))
            stale("%s: '%s' carries an unreadable RETIRE-WHEN (%s — %s). The census does not "
                  "know how to check it, so the entry is unaudited while LOOKING audited, which "
                  "is worse than carrying no clause at all. Verbs: %s."
                  % (record, entry, pred, detail, ", ".join(RETIRE_VERBS)))
        elif verdict is None:
            print("    ?     %-20s %-30s %s" % (record, entry[:30], detail))
            cannot("%s: '%s' has RETIRE-WHEN %s but its subject could not be read (%s). NOT a "
                   "retirement finding — an unreadable subject is not a satisfied condition."
                   % (record, entry, pred, detail))
        elif verdict:
            print("    RETIRE %-19s %-30s %s" % (record, entry[:30], detail))
            stale("%s: '%s' STILL MATCHES but its author's own retirement condition is now MET "
                  "(RETIRE-WHEN %s — %s). The pattern is live and the reason is dead: this is "
                  "the exact rot no matching test can see. Delete the entry, or write down what "
                  "makes it right TODAY." % (record, entry, pred, detail))
        else:
            print("    right %-20s %-30s %s" % (record, entry[:30], detail))
    if r:
        covered += 0 if m else 1
        try:
            d = datetime.date.fromisoformat(r.group(1).strip())
        except ValueError:
            stale("%s: '%s' has an unparseable REVIEWED: '%s' — use YYYY-MM-DD."
                  % (record, entry, r.group(1)))
            continue
        age = (datetime.date.fromisoformat(TODAY) - d).days
        if age < 0:
            stale("%s: '%s' is REVIEWED: %s, which is in the FUTURE (today %s). Nobody reviewed "
                  "anything on that date." % (record, entry, d.isoformat(), TODAY))
        elif age > REVIEW_MAX_DAYS:
            print("    WARN  %-20s %-30s last reviewed %s (%d d ago)" % (record, entry[:30], d, age))
            NOTES.append("%s: '%s' has not been re-read in %d days." % (record, entry, age))
        else:
            print("    fresh %-20s %-30s reviewed %s" % (record, entry[:30], d))

uncovered = len(REASONS) - covered
print("  FLOOR: %d of %d entr(ies) carry NO machine-checkable rightness clause "
      "(RETIRE-WHEN:/REVIEWED:). This number is supposed to fall." % (uncovered, len(REASONS)))
if REASONS and covered == 0:
    print("      note: zero entries are covered — phase 4 is proved only by its drill today.")


# ─────────────────────────────────────────────────────────────────────────────
print()
if ABSENT:
    print("=== phase 2z · entries this box CANNOT judge (%d) ===" % len(ABSENT))
    for _rec, _pat, _where in ABSENT:
        print("      absent %-46s %s" % (_pat[:46], _where))
    cannot("%d subtractive entr(ies) point into a container that does not exist on %s. "
           "Zero matches HERE is not evidence the subject died — it is evidence this box "
           "never had it, and the remedy those findings print is 'delete the entry'. "
           "The box of record is the one with the whole estate cloned; re-run there "
           "before retiring any of these." % (len(ABSENT), BOX))
    print()
live    = sum(1 for r in ROWS if r[2])
absent  = sum(1 for r in ROWS if len(r) > 4 and r[4] == "absent")
dormant = sum(1 for r in ROWS if len(r) > 4 and r[4] == "dormant")
dead    = sum(1 for r in ROWS if not r[2]) - absent - dormant

# ── SELF-CHECK · the summary may not contradict the findings ─────────────────────────────
# A row's verdict and a checker's decision to FILE are computed in two different places. The
# verdict is DERIVED from `n` alone; a suppression is expressed by not calling stale(). So a
# suppression is invisible to the derivation — and invisible reads as the default, which is
# STALE. That is how "stale: 2" came to print one line above "ok every ratification in the
# estate still describes something true", both true to their own mechanism, in the same run.
#
# This is feynmanSync-07's open question with the subject swapped: when a conclusion is derived
# from ONE mechanism, a fact expressed through a DIFFERENT one is invisible to that derivation.
# Patching the one path would leave the next suppression free to make the same mistake, so the
# guard asserts the JOIN instead: a row may be counted STALE only if some finding names it.
# Any future suppression that moves without its verdict trips this without anyone remembering
# it exists — and so does a finding phrased without naming its own entry, which is unactionable
# for the same reason. Both make the count and the findings say different things.
for _rec, _pat, _n, _why, _v in ROWS:
    if _v == "STALE" and not any(_pat in _f for _f in FAILS):
        stale("SELF-CHECK: %s: '%s' is counted STALE in the summary but NO finding names it. "
              "Either a suppression moved without its verdict, or a finding was filed that does "
              "not name its own entry. Either way the count and the findings disagree, and a "
              "session reading one of them is reading a different census." % (_rec, _pat))

print("=" * 78)
print("  entries checked: %d   still true: %d   dormant: %d   stale: %d   unjudgeable on %s: %d"
      % (len(ROWS), live, dormant, dead, BOX, absent))
if NOTES:
    print("  WARN — %d entr(ies) are matching but unreviewed (rc unaffected, deliberately):" % len(NOTES))
    for n in NOTES:
        print("    ~ %s" % n)
if FAILS:
    print("  FAIL — %d finding(s):" % len(FAILS))
    for f in FAILS:
        print("    • %s" % f)
    sys.exit(1)
if VERDICT_RC[0] == 2:
    print("  CANNOT VERIFY — see above. An empty subject is not a clean estate.")
    sys.exit(2)
print("  ok  every ratification in the estate still describes something true.")
sys.exit(0)
PYEOF
