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
GATE_FILE    = os.environ.get("RC_GATE_FILE",    H("code/darwin-mac-ops/gate-selfcheck.sh"))
CARD_LINT    = os.environ.get("RC_CARD_LINT",    H("Scripts/card-lint.py"))
ARL          = os.environ.get("RC_ARL",          H("Scripts/asana-read-lint.py"))
FDA_CANARY   = os.environ.get("RC_FDA_CANARY",   H("Scripts/fda-canary.sh"))
LAUNCHCTL    = os.environ.get("RC_LAUNCHCTL",    "")     # a file of labels, for the drill
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
                 (BB_ALLOW, FOREIGN, DIVERGE, EPHEMERAL, GE_ALLOW, ARL_BASELINE, CARD_BASE, RD_ALLOW)}

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
    """<pattern>  # <reason>  — the estate's shared allowlist grammar."""
    out = []
    if not os.path.exists(path):
        return None
    for raw in open(path, errors="ignore"):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        pat = s.split("#")[0].strip()
        if pat:
            out.append((pat, s))
    return out

def row(record, entry, n, why, full=None):
    """`why` is what PRINTS (truncated to fit); `full` is what phase 4 PARSES. They must be
    separate: a RETIRE-WHEN: clause written past column 44 would otherwise be invisible to the
    only check that reads it, and a control that cannot see its subject is not a control."""
    ROWS.append((record, entry, n, why))
    REASONS.append((record, entry, full if full is not None else why))
    print("      %-5s n=%-4d %-46s %s" % ("live" if n else "STALE", n, entry[:46], why))

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
        row("bb-writers", pat, n, (e.get("reason", "") or "")[:44], full=e.get("reason", "") or "")
        if not n:
            stale("bb-writers-allowlist.json: pattern '%s' matches NO file today. It ratifies "
                  "nothing — and pre-ratifies whatever lands at that path next, carrying a "
                  "reason written for something else. Delete it." % pat)

# --- 2b/c. the two launchd allowlists (consumer: launchd-census.sh) ---
if LAUNCHCTL:
    labels = {l.strip() for l in open(LAUNCHCTL) if l.strip()}
else:
    out = subprocess.run(["launchctl", "list"], capture_output=True, text=True).stdout
    labels = {p[2].strip() for p in (l.split("\t") for l in out.splitlines()[1:])
              if len(p) >= 3 and p[2].strip()}
print("  --- launchd allowlists (loaded labels: %d) ---" % len(labels))
if not labels:
    cannot("launchctl listed ZERO labels — every launchd allowlist entry would read as stale")
else:
    for path, name in ((FOREIGN, "launchd-foreign"), (DIVERGE, "launchd-divergence"), (EPHEMERAL, "launchd-ephemeral")):
        ents = entries_of(path)
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
            row(name, pat, n, ("transient · " + m.group(1).strip())[:44] if transient else why[:44],
                full=why)
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
            for pat, line in ge:
                n = sum(1 for k in keys if fnmatch.fnmatch(k, pat))
                reason = line.split("#", 1)[-1].strip()
                row("gate-secret-sweep", pat, n, reason[:44], full=reason)
                if not n:
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
    if verb == "path-gone":
        hits = glob.glob(_p(arg))
        return (not hits), ("nothing at %s" % arg) if not hits else ("%d path(s) still there" % len(hits))
    if verb == "path-here":
        hits = glob.glob(_p(arg))
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
live  = sum(1 for r in ROWS if r[2])
dead  = sum(1 for r in ROWS if not r[2])
print("=" * 78)
print("  entries checked: %d   still true: %d   stale: %d" % (len(ROWS), live, dead))
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
