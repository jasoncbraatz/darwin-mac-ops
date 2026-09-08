#!/usr/bin/env python3
"""handoff-reference-integrity.py — G-R, made mechanical.

    "reference integrity -- every ID/path you cite must RESOLVE."
    gate-checks.manifest, judgment row G-R, third column.

WHY THIS ONE, AND WHY NOW
-------------------------
The manifest's third column is a to-do list: each judgment row names what a
witness for that step WOULD be. G-R's own row says it is "the most nearly-
mechanical of the nineteen -- the likeliest next one to promote to a reach
unit". This is that promotion. A handoff cites gids, paths and commit shas by
the dozen; a fresh session reads them as GOSPEL, because the one thing a
successor cannot cheaply do is doubt the document it is orienting from.

THE DISTINCTION THIS TOOL EXISTS TO MAKE
----------------------------------------
`card-lint.py` already resolves gids -- for a different question (is the card
CLOSED and the citing doc unreconciled?). Its resolver swallows every failure
into one bucket:

    try:    t = cl.get_one(f"/tasks/{gid}", ...)
    except: t = None
    ...
    if info is None: res["not_a_card"] += 1; return

Three different worlds arrive at that line and leave under one name:

    404  the gid does NOT EXIST      -> a broken reference. G-R's whole subject.
    403  we cannot SEE it            -> CANNOT VERIFY. Says nothing about the gid.
    timeout / DNS / no token         -> CANNOT VERIFY. Says nothing about anything.

`not_a_card` is a verdict; two of those three are the absence of one. That is
the fourth sighting of the class feynmanSync-11 and -12 named five times over
(roster-brake's mtime rung, bb-writers-audit's catalogue, G-H's six WHO rungs,
estate-sync's `skipped:dirty`): AN INSTRUMENT THAT GIVES TWO STATES ONE NAME.
So this tool keeps them apart by construction and never collapses them, and
its CANNOT VERIFY is loud rather than green.

WHAT IT CHECKS -- three reference kinds, each with a deliberate narrow scope
---------------------------------------------------------------------------
1. GIDS      a 15-18 digit run. Resolved through the Asana API across EVERY
             object type the estate cites, not just /tasks. A 404 from /tasks
             means "not a task" -- it does NOT mean "not a thing". Caught on this
             tool's first corpus sweep, where it called the Batter's Box itself
             (1213050213165325, a PROJECT) an unresolved reference. Only when
             every endpoint 404s is a gid genuinely unresolvable; a 403 anywhere
             is CANNOT VERIFY and outranks every 404 beside it.
2. PATHS     only backticked tokens beginning `~/`, `/Users/` or `/home/`.
             Classified by box FIRST: on darwin a `/home/jason/...` path is a
             ROUTING FACT, not rot (feynmanSync-09's G-AK lesson, one layer
             out) and is reported n/a, never red.
3. SHAS      only the high-signal `<repo-name> <7..40 hex>` shape the WHAT
             SHIPPED table uses. Resolved with `git cat-file -e <sha>^{commit}`
             against the repo of that name. A cited commit that no repo holds is
             a high-water mark that lies -- the single most expensive kind of
             broken reference, because the successor builds ON it. But a clone
             that has not fetched since the handoff was written cannot hold those
             commits at all, and that is CANNOT VERIFY, never a finding.
             And a sha the local object database HAS is still unresolved if no
             remote branch contains it: on the workshop box a rebase leaves the
             old commit lying there, and `cat-file -e` cannot tell it from a
             pushed one. The question a successor cares about is "can I fetch
             this", not "is it on your disk".

WHY THE SCOPE IS THIS NARROW
----------------------------
A guard that cries wolf gets muted, and a muted guard is indistinguishable from
a decoration. Every widening below is deliberate debt, declared here rather
than discovered:
  * bare (un-backticked) paths in prose are NOT scanned -- prose wraps them, and
    a wrapped path is a false positive machine.
  * only ~/, /Users/ and /home/ are path claims. /tmp is ephemeral by design and
    is simply not in that allowlist -- there is no skip branch for it, because a
    branch that can never be reached is a decoration that lies about coverage.
  * a backticked token containing WHITESPACE is a command fragment, not a path.
  * a token ending `...` or containing an ellipsis is a prose elision, not a claim.
  * a token carrying shell/regex metacharacters ($ | " ' < >) is not a path claim.
  * a glob is resolved by EXPANSION: if it matches anything, it resolves.
  * a trailing `:LINE` (or `:LINE:COL`) is a citation of a line, and is stripped
    before the file is stat-ed. The file underneath still has to exist.

THE OPT-OUT, AND ITS PRICE
--------------------------
`REF-OK: <token> -- <reason>` on any line of the handoff exempts one token, and
a reason under REASON_MIN chars is NOT a declaration. Same contract as
`portability-guard.allow` and `CARD-LINT-OK`: a record of intent, not a snooze
button. An exemption with no usable reason is itself a finding.

EXIT CODES
----------
    0  clean (or only n/a routing facts)
       stdout always carries a `REF-OK: <live> live, <dead> dead` tally, which is
       what ratification-census.sh reads to judge this marker vocabulary.
    1  findings: an unresolved gid, an unresolved sha, or a missing own-box path
    2  CANNOT VERIFY: the handoff could not be read at all
"""

import os
import re
import subprocess
import sys

REASON_MIN = 20
HOME = os.path.expanduser("~")

# Where a repo of a given name might live on this box.
REPO_ROOTS = [os.path.join(HOME, "code"), os.path.join(HOME, "repos"), HOME]
REPO_ALIASES = {
    "downloads": os.path.join(HOME, "Desktop", "downloads"),
    "Scripts": os.path.join(HOME, "Scripts"),
}

GID_RE = re.compile(r"(?<![0-9A-Za-z])(1[0-9]{14,17})(?![0-9A-Za-z])")
BACKTICK_RE = re.compile(r"`([^`\n]+)`")
SHA_PAIR_RE = re.compile(r"`([A-Za-z][A-Za-z0-9._-]{2,40})\s+([0-9a-f]{7,40})`")
REFOK_RE = re.compile(r"REF-OK:\s*(\S+)\s*(?:--|—|-)\s*(.+?)\s*$", re.MULTILINE)
META = set("$|\"'<>{}()!;&")


def box_kind():
    """Which box's absolute paths can this process resolve?"""
    return "darwin" if sys.platform == "darwin" else "linux"


def other_box_path(tok):
    """True when tok is an absolute path belonging to the OTHER box.

    A routing fact, not rot. Both spellings are checked against the running
    box rather than against a hardcoded username, so a fleet turnover
    (estate-box add/remove) cannot silently turn this into a lie.
    """
    if box_kind() == "darwin":
        return tok.startswith("/home/")
    return tok.startswith("/Users/")


def looks_like_path(tok):
    if any(c in META for c in tok):
        return False
    # A backticked token with a space in it is a command fragment (`~/Scripts/fx 'x'`,
    # `~/Scripts abc1234`), and stat-ing the whole string manufactures a missing path
    # out of a correct citation. Declared scope, held by control 7b below.
    if any(c.isspace() for c in tok):
        return False
    # `/Users/nobody/...` is a prose elision, not a path anyone cited.
    if tok.endswith("...") or "\u2026" in tok:
        return False
    if tok.startswith("~/"):
        return True
    return tok.startswith("/Users/") or tok.startswith("/home/")


LINE_SUFFIX_RE = re.compile(r"^(.*?):[0-9]+(?::[0-9]+)?$")


def strip_line_suffix(tok):
    """`path/to/file.sh:59` cites a LINE, not a file named `file.sh:59`.

    Found by running this tool against its first real subject: the only finding
    on a 331-line handoff citing 31 references was `mint-heartbeat.sh:59`, a
    file that exists. A guard's first true-looking finding deserves the same
    scepticism as its first green -- Hall of Fame 14.
    """
    m = LINE_SUFFIX_RE.match(tok)
    return m.group(1) if m else tok


def resolve_path(tok):
    """-> ('ok'|'missing'|'na', detail)"""
    if other_box_path(tok):
        return "na", "the other box's path -- a routing fact, not rot"
    tok = strip_line_suffix(tok)
    real = os.path.expanduser(tok)
    if any(ch in real for ch in "*?["):
        import glob as _g
        return ("ok", "glob expands") if _g.glob(real) else ("missing", "glob matches nothing")
    return ("ok", "") if os.path.exists(real) else ("missing", "no such file or directory")


def repo_dir(name):
    if name in REPO_ALIASES:
        d = REPO_ALIASES[name]
        return d if os.path.isdir(os.path.join(d, ".git")) else None
    for root in REPO_ROOTS:
        d = os.path.join(root, name)
        if os.path.isdir(os.path.join(d, ".git")):
            return d
    return None


def last_fetch(d):
    """When this clone last heard from its remote. None if it never has."""
    for name in ("FETCH_HEAD", "HEAD"):
        f = os.path.join(d, ".git", name)
        try:
            return os.path.getmtime(f)
        except OSError:
            continue
    return None


def resolve_sha(repo, sha, since=None):
    """-> ('ok'|'unresolved'|'cannotverify'|'na', detail)

    THE DISTINCTION THAT COSTS THE MOST TO GET WRONG. A commit this box does not
    have is not the same as a commit that does not exist, and on a two-box estate
    the second box is routinely minutes behind. Caught on feynman, where the very
    first real run reported `claude-blackbook 7bc465f2` -- a real, pushed commit --
    as an unresolved reference, purely because feynman had not pulled yet.

    The discriminator is the one card-lint.py is built on: compare two timestamps
    nobody was comparing. If this clone last fetched BEFORE the handoff was
    written, it cannot have the commits that handoff describes, and saying so is
    a blind spot, not a verdict. A clone that HAS fetched since and still lacks
    the object is naming a commit that is not on the remote either.
    """
    d = repo_dir(repo)
    if d is None:
        return "na", f"no repo named {repo} on this box"
    try:
        r = subprocess.run(["git", "-C", d, "cat-file", "-e", sha + "^{commit}"],
                           capture_output=True, timeout=20)
    except Exception as e:                       # transport, not a verdict
        return "na", f"git could not run: {type(e).__name__}"
    if r.returncode == 0:
        # EXISTS IS NOT REACHABLE. `cat-file -e` answers from the local object
        # database, which on the workshop box still holds everything a rebase
        # orphaned. feynmanSync-12's own handoff cites `claude-blackbook 7bc465f2`
        # -- a real object on darwin, on NO remote branch, superseded by daeea474
        # when the --autostash rebase that handoff documents rewrote it. darwin
        # called that reference fine and feynman called it broken, and feynman was
        # right. A high-water mark a successor cannot fetch is exactly the lie this
        # check exists to catch, so ask the question that matters: is it PUSHED?
        try:
            br = subprocess.run(["git", "-C", d, "branch", "-r", "--contains", sha],
                                capture_output=True, text=True, timeout=20)
        except Exception:
            return "ok", d                       # cannot ask -> do not accuse
        if br.returncode == 0 and not br.stdout.strip():
            fetched = last_fetch(d)
            if since is not None and fetched is not None and fetched < since:
                return ("cannotverify",
                        f"{repo} has the object but has not fetched since the handoff -- "
                        f"cannot tell a rebased-away commit from an unfetched branch")
            return ("unresolved",
                    f"exists in {d} but NO remote branch contains it -- rebased away or "
                    f"never pushed, so no other box and no successor can fetch it")
        return "ok", d
    fetched = last_fetch(d)
    if since is not None and fetched is not None and fetched < since:
        return ("cannotverify",
                f"{repo} on this box last fetched before the handoff was written -- "
                f"a clone that has not pulled yet cannot hold the commits it describes")
    return "unresolved", f"not a commit in {d}"


def classify_asana_error(msg):
    """The one judgement that keeps a broken reference apart from a blind spot.

    It lives out here, as a pure function of the error text, for one reason:
    inside make_resolver it could only ever be exercised by a live API, which
    means it could only ever be exercised by NOT being exercised -- the shape
    feynmanSync-12 named as "the subject exists by construction". Out here a
    control can feed it both worlds.
    """
    if "404" in msg or "Not a recognized ID" in msg:
        return "unresolved", "Asana 404 -- not a recognized ID"
    if "400" in msg:
        # We control the request shape, so a 400 means this gid is not a valid id
        # for THIS object type -- the same answer a 404 gives, by another door.
        # It must not read as a blind spot, or one fussy endpoint would mask a
        # genuine 404 from all the others via combine_gid_verdicts.
        return "unresolved", "Asana 400 -- not a valid id for this object type"
    # 401, 403, 429, 5xx, DNS, timeout: says nothing about the gid.
    return "cannotverify", msg.split("\n")[0][:140]


# Every Asana object type this estate actually cites by bare gid. /tasks first
# because it is the overwhelming majority and the loop stops on the first hit.
# `stories` is here because handoffs cite COMMENT gids constantly ("the 10:40Z
# comment"), and a story gid 404s on every other endpoint. The first sweep
# reported eleven of them in one handoff as broken references. Ordered by how
# often the estate cites each; the loop stops on the first hit, so the cost of
# the long tail is paid only by a gid that is genuinely nowhere.
GID_ENDPOINTS = ("tasks", "stories", "projects", "users", "tags", "sections",
                 "teams", "portfolios")


def combine_gid_verdicts(verdicts):
    """Fold one gid's per-endpoint verdicts into a single answer.

    Pure, so a control can drive it without a network. The precedence is the
    whole point and is asserted by controls 11/11t/11x:
        any ok            -> ok            (it is a real object of SOME type)
        else any 403/etc  -> cannotverify  (a blind spot outranks a 404 beside it)
        else              -> unresolved    (every endpoint agreed it is not there)
    """
    if any(v[0] == "ok" for v in verdicts):
        # The default matters: a bare `next(...)` over a zip against
        # GID_ENDPOINTS raises StopIteration whenever the verdict list is
        # longer than the endpoint tuple, which turns a naming detail into a
        # crash. Found by mutant M7b, whose whole finding was hidden behind
        # that traceback -- a control cannot report a red it never reached.
        kind = next((k for k, (st, _) in zip(GID_ENDPOINTS, verdicts)
                     if st == "ok"), "asana")
        return "ok", kind
    cvs = [v for v in verdicts if v[0] == "cannotverify"]
    if cvs:
        return "cannotverify", cvs[0][1]
    return "unresolved", "404 on every Asana object type (%s)" % ", ".join(GID_ENDPOINTS)


def make_resolver(offline=False):
    """-> (fn(gid) -> ('ok'|'unresolved'|'cannotverify', detail), reason_if_unavailable)

    The whole point of this function is that it NEVER returns a bare None. A
    404 and a 403 leave by different doors.
    """
    if offline:
        return None, "--offline"
    sys.path.insert(0, os.path.join(HOME, "Scripts"))
    try:
        from asana_client import AsanaClient
    except Exception as e:
        return None, f"asana_client unimportable ({type(e).__name__})"
    try:
        cl = AsanaClient()
        if not cl.ready():
            return None, "no Asana token on this box"
    except Exception as e:
        return None, f"AsanaClient failed to start ({type(e).__name__})"

    cache = {}

    def resolve(gid):
        if gid in cache:
            return cache[gid]
        verdicts = []
        for ep in GID_ENDPOINTS:
            try:
                cl.get_one(f"/{ep}/{gid}", {"opt_fields": "name"})
                verdicts.append(("ok", ep))
                break                      # a hit ends the question
            except Exception as e:
                verdicts.append(classify_asana_error(str(e)))
        out = combine_gid_verdicts(verdicts)
        cache[gid] = out
        return out

    return resolve, None


def scan(text):
    """Pure extraction -- no I/O, so a drill can drive it with fixtures."""
    exempt, bad_exempt = {}, []
    for tok, reason in REFOK_RE.findall(text):
        reason = reason.strip()
        if len(reason) >= REASON_MIN:
            exempt[tok] = reason
        else:
            bad_exempt.append((tok, reason))

    gids, paths, shas = [], [], []
    for m in SHA_PAIR_RE.finditer(text):
        shas.append((m.group(1), m.group(2)))
    for m in BACKTICK_RE.finditer(text):
        tok = m.group(1).strip()
        if looks_like_path(tok):
            paths.append(tok)
    for m in GID_RE.finditer(text):
        gids.append(m.group(1))

    def dedupe(seq):
        seen, out = set(), []
        for x in seq:
            if x not in seen:
                seen.add(x)
                out.append(x)
        return out

    return {"gids": dedupe(gids), "paths": dedupe(paths),
            "shas": dedupe(shas), "exempt": exempt, "bad_exempt": bad_exempt}


def report(found, resolver, resolver_why, since=None):
    findings, nas, cv = [], [], []

    for tok, reason in found["bad_exempt"]:
        findings.append(("EXEMPT-NOREASON", tok,
                         f"REF-OK declared with a reason under {REASON_MIN} chars "
                         f"({len(reason)}) -- a record of intent, not a snooze button"))

    used = set()

    for tok in found["paths"]:
        if tok in found["exempt"]:
            st, _d = resolve_path(tok)
            if st == "missing":
                used.add(tok)                 # the exemption is doing work
            continue
        state, detail = resolve_path(tok)
        if state == "missing":
            findings.append(("PATH-MISSING", tok, detail))
        elif state == "na":
            nas.append(("PATH", tok, detail))

    for repo, sha in found["shas"]:
        key = f"{repo} {sha}"
        if key in found["exempt"] or sha in found["exempt"]:
            st, _d = resolve_sha(repo, sha, since)
            if st == "unresolved":
                used.add(key if key in found["exempt"] else sha)
            continue
        state, detail = resolve_sha(repo, sha, since)
        if state == "unresolved":
            findings.append(("SHA-UNRESOLVED", key, detail))
        elif state == "cannotverify":
            cv.append(("SHA", key, detail))
        elif state == "na":
            nas.append(("SHA", key, detail))

    for gid in found["gids"]:
        if gid in found["exempt"]:
            if resolver is not None and resolver(gid)[0] == "unresolved":
                used.add(gid)
            continue
        if resolver is None:
            cv.append(("GID", gid, resolver_why))
            continue
        state, detail = resolver(gid)
        if state == "unresolved":
            findings.append(("GID-UNRESOLVED", gid, detail))
        elif state == "cannotverify":
            cv.append(("GID", gid, detail))

    # A REF-OK attached to a token that RESOLVES, or that the document no longer
    # cites at all, excuses nothing -- and it is indistinguishable from a live one
    # until something asks. That is the same shape as an exception record outliving
    # its subject, which is exactly what ratification-census.sh hunts. So it reports.
    all_tokens = (set(found["paths"]) | set(found["gids"])
                  | {f"{r} {sh}" for r, sh in found["shas"]}
                  | {sh for _r, sh in found["shas"]})
    for tok in found["exempt"]:
        if tok in used:
            continue
        why = ("the document no longer cites it" if tok not in all_tokens
               else "that reference resolves on its own now")
        findings.append(("EXEMPT-DEAD", tok,
                         f"REF-OK excuses nothing -- {why}. Retire the marker."))
    return findings, nas, cv, len(used), len(found["exempt"]) - len(used)


def derive_handoff():
    """Same tag -> filename derivation G-AQ uses, asked once."""
    tag = os.environ.get("CLAUDE_SESSION_TAG") or ""
    if not tag:
        st = os.path.join(HOME, ".local", "state", "claude-session", "current")
        try:
            with open(st) as fh:
                tag = fh.read().strip()
        except OSError:
            return None
    d = os.environ.get("HTC_DIR", os.path.join(HOME, "Desktop", "downloads"))
    for slug in (tag.split("-", 1)[-1], tag):
        m = re.match(r"^(.*)-([0-9]+)[a-z]?$", slug)
        if not m:
            continue
        cand = os.path.join(d, f"HANDOFF-{m.group(1)}-{m.group(2)}.md")
        if os.path.exists(cand):
            return cand
    return None


def main(argv):
    path, offline = None, False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--handoff":
            i += 1
            path = argv[i]
        elif a == "--offline":
            offline = True
        elif a == "--selftest":
            return selftest()
        i += 1

    if path is None:
        path = derive_handoff()
    if path is None:
        print("G-R CANNOT VERIFY: no handoff named (pass --handoff PATH)", file=sys.stderr)
        return 2
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError as e:
        print(f"G-R CANNOT VERIFY: cannot read {path}: {e}", file=sys.stderr)
        return 2

    found = scan(text)
    resolver, why = make_resolver(offline)
    try:
        since = os.path.getmtime(path)
    except OSError:
        since = None
    findings, nas, cv, ex_live, ex_dead = report(found, resolver, why, since)

    total = len(found["gids"]) + len(found["paths"]) + len(found["shas"])
    base = os.path.basename(path)
    for kind, tok, detail in findings:
        print(f"{kind}  {tok}  -- {detail}")
    for kind, tok, detail in cv:
        print(f"CANNOT-VERIFY  {kind} {tok}  -- {detail}")
    for kind, tok, detail in nas:
        print(f"n/a  {kind} {tok}  -- {detail}")
    print(f"REF-OK: {ex_live} live, {ex_dead} dead")
    print(f"-- {base}: {total} reference(s) "
          f"({len(found['gids'])} gid, {len(found['paths'])} path, {len(found['shas'])} sha) "
          f"| {len(findings)} finding(s), {len(cv)} unverifiable, {len(nas)} n/a")

    if findings:
        return 1
    if cv:
        # Loud, but not a red: an unreachable API is not a broken reference. The
        # count is printed above so a wrap cannot read this as "all clear".
        print("-- some references could not be verified; that is not the same as clean")
    return 0


# ------------------------------------------------------------------ selftest
def _r(table):
    return lambda gid: table.get(gid, ("ok", ""))


def selftest():
    """Every NEGATIVE control ships a POSITIVE TWIN on the SAME input.

    feynmanSync-12 found three controls in one session that were green because
    something OTHER than the thing they named satisfied them. The rule that came
    out of it: a negative control alone is an assertion; negative + positive twin
    + mutant is a measurement. So each pair below feeds ONE fixture to the same
    code path and asserts the verdict FLIPS -- which is a claim no accident about
    the fixture can satisfy.
    """
    fails = []

    def ok(n, msg="", why=""):
        print(f"  ok    {n} {msg}")

    def bad(n, msg="", why=""):
        print(f"  FAIL  {n} {msg}\n        {why}")
        fails.append(n)

    def kinds(findings):
        return sorted(k for k, _, _ in findings)

    # 1/1t -- a gid that 404s is a finding; the SAME gid resolving is not.
    txt = "the card 1218281330139051 covers it"
    f, _, _, _, _ = report(scan(txt), _r({"1218281330139051": ("unresolved", "404")}), None)
    f2, _, _, _, _ = report(scan(txt), _r({}), None)
    (ok if kinds(f) == ["GID-UNRESOLVED"] else bad)(
        "1  a 404 gid is a finding", "", f"got {kinds(f)}")
    (ok if not f2 else bad)(
        "1t POSITIVE TWIN: the same gid resolving is clean", "", f"got {kinds(f2)}")

    # 2/2t -- 403 is CANNOT VERIFY, never a finding. The twin proves the same
    #         input CAN produce a finding, so 2 is not passing by construction.
    f, _, cv, _, _ = report(scan(txt), _r({"1218281330139051": ("cannotverify", "403")}), None)
    (ok if (not f and len(cv) == 1) else bad)(
        "2  a 403 gid is CANNOT VERIFY, not a finding", "", f"findings={kinds(f)} cv={len(cv)}")
    f2, _, cv2, _, _ = report(scan(txt), _r({"1218281330139051": ("unresolved", "404")}), None)
    (ok if (kinds(f2) == ["GID-UNRESOLVED"] and not cv2) else bad)(
        "2t POSITIVE TWIN: same gid, 404 instead, flips to a finding", "",
        f"findings={kinds(f2)} cv={len(cv2)}")

    # 3/3t -- the other box's path is n/a; an OWN-box missing path is a finding.
    #         Both spellings are fed, so neither can pass by being unreachable.
    own = "/Users/nobody/x" if box_kind() == "darwin" else "/home/nobody/x"
    other = "/home/nobody/x" if box_kind() == "darwin" else "/Users/nobody/x"
    f, nas, _, _, _ = report(scan(f"see `{other}`"), _r({}), None)
    (ok if (not f and len(nas) == 1) else bad)(
        "3  the other box's absolute path is n/a, never red", "", f"findings={kinds(f)}")
    f2, _, _, _, _ = report(scan(f"see `{own}`"), _r({}), None)
    (ok if kinds(f2) == ["PATH-MISSING"] else bad)(
        "3t POSITIVE TWIN: the same shape on THIS box is a finding", "", f"got {kinds(f2)}")

    # 4/4t -- an ephemeral path is skipped; a non-ephemeral sibling is not.
    f, _, _, _, _ = report(scan("see `/tmp/gone-forever-xyz`"), _r({}), None)
    (ok if (not f and scan("see `/tmp/gone-forever-xyz`")["paths"] == []) else bad)(
        "4  a /tmp path is not a path claim -- it is outside the allowlist, not skipped by a branch",
        "", f"got {kinds(f)}")
    f2, _, _, _, _ = report(scan("see `~/definitely-not-here-xyz`"), _r({}), None)
    (ok if kinds(f2) == ["PATH-MISSING"] else bad)(
        "4t POSITIVE TWIN: the same missing file outside /tmp is a finding", "", f"got {kinds(f2)}")

    # 5/5t -- REF-OK with a real reason exempts; with a thin one it is itself a finding.
    #         feynmanSync-12's #3: a control that perturbs its own fixture. Both
    #         halves here use the SAME token, so only the reason can be the cause.
    good = ("see `~/definitely-not-here-xyz`\n"
            "REF-OK: ~/definitely-not-here-xyz -- deleted on purpose when the lane closed")
    thin = "see `~/definitely-not-here-xyz`\nREF-OK: ~/definitely-not-here-xyz -- meh"
    f, _, _, _, _ = report(scan(good), _r({}), None)
    (ok if not f else bad)("5  REF-OK with a usable reason exempts the token", "", f"got {kinds(f)}")
    f2, _, _, _, _ = report(scan(thin), _r({}), None)
    (ok if kinds(f2) == ["EXEMPT-NOREASON", "PATH-MISSING"] else bad)(
        "5t POSITIVE TWIN: the same token with a thin reason exempts NOTHING and is itself a finding",
        "", f"got {kinds(f2)}")

    # 6/6t -- a sha pair in a repo that does not exist is n/a; in a repo that
    #         DOES exist and lacks it, a finding. Uses this repo, so it is real.
    here = os.path.basename(os.path.dirname(os.path.abspath(__file__)))
    f, nas, _, _, _ = report(scan("`no-such-repo-xyz 0123abc`"), _r({}), None)
    (ok if (not f and len(nas) == 1) else bad)(
        "6  a sha in a repo this box does not have is n/a", "", f"findings={kinds(f)}")
    f2, _, _, _, _ = report(scan(f"`{here} 0000000000000000000000000000000000000000`"), _r({}), None)
    exp = ["SHA-UNRESOLVED"] if repo_dir(here) else []
    (ok if kinds(f2) == exp else bad)(
        "6t POSITIVE TWIN: an absent sha in a repo that IS here is a finding", "",
        f"got {kinds(f2)} expected {exp}")

    # 7 -- extraction must not read a sha pair as a path, nor a path as a gid.
    s = scan("`darwin-mac-ops 7e679dc` and `~/Scripts` and 1218281330139051")
    (ok if (s["shas"] == [("darwin-mac-ops", "7e679dc")] and s["paths"] == ["~/Scripts"]
            and s["gids"] == ["1218281330139051"]) else bad)(
        "7  the three reference kinds are extracted apart", "", repr(s)[:200])

    # 8 -- a bare path in prose is NOT scanned. Declared scope, held by a control
    #      so that widening it later must argue with this line.
    s2 = scan("the file ~/definitely-not-here-xyz is gone")
    (ok if s2["paths"] == [] else bad)(
        "8  an un-backticked path in prose is out of scope by design", "", repr(s2["paths"]))

    # 7b/7t -- a backticked command fragment beginning `~/` must not be stat-ed as a
    #          path. Its twin is the same prefix with the space removed, so only the
    #          whitespace rule can be what separates them.
    s3 = scan("run `~/Scripts abc1234` now")
    s3t = scan("run `~/Scripts` now")
    (ok if s3["paths"] == [] else bad)(
        "7b a backticked token containing whitespace is not a path claim", "", repr(s3["paths"]))
    (ok if s3t["paths"] == ["~/Scripts"] else bad)(
        "7t POSITIVE TWIN: the same prefix without the space IS a path claim", "", repr(s3t["paths"]))

    # 10/10t -- a `file:LINE` citation resolves to the FILE; the same suffix on a
    #           file that is genuinely absent still reports, naming the base path.
    _self = os.path.abspath(__file__)
    f, _, _, _, _ = report(scan(f"see `{_self}:59`"), _r({}), None)
    (ok if not f else bad)(
        "10  a trailing :LINE is a line citation, not part of the filename", "", f"got {kinds(f)}")
    f2, _, _, _, _ = report(scan("see `~/definitely-not-here-xyz.sh:59`"), _r({}), None)
    (ok if kinds(f2) == ["PATH-MISSING"] else bad)(
        "10t POSITIVE TWIN: the same suffix on an absent file still reports", "", f"got {kinds(f2)}")

    # 11/11t/11x -- the endpoint fold. A 404 from /tasks alone must never be the
    #               answer: the first corpus sweep had this tool calling the
    #               Batter's Box (a PROJECT) an unresolved reference. All three
    #               feed the SAME shape of input so only the fold can differ.
    _u = ("unresolved", "404"); _c = ("cannotverify", "403"); _o = ("ok", "")
    (ok if combine_gid_verdicts([_u, _o])[0] == "ok" else bad)(
        "11  a gid that 404s as a task but resolves as a project is RESOLVED", "",
        repr(combine_gid_verdicts([_u, _o])))
    (ok if combine_gid_verdicts([_u, _u, _u])[0] == "unresolved" else bad)(
        "11t POSITIVE TWIN: 404 on every endpoint is genuinely unresolved", "",
        repr(combine_gid_verdicts([_u, _u, _u])))
    # 11z -- COVERAGE, asserted by membership rather than by length. 11t used to
    #        size its fixture from GID_ENDPOINTS itself, so collapsing that tuple
    #        to ("tasks",) collapsed the control with it and stayed green. A list
    #        the control derives from the thing under test cannot measure it.
    _missing = [e for e in ("tasks", "stories", "projects", "users")
                if e not in GID_ENDPOINTS]
    (ok if (not _missing and GID_ENDPOINTS[0] == "tasks") else bad)(
        "11z the endpoint list still covers the types this estate cites (tasks first)",
        "", f"missing={_missing} first={GID_ENDPOINTS[0]}")
    _e400 = 'Asana HTTP 400 on GET /project_templates/1: {"errors":[{"message":"bad"}]}'
    (ok if classify_asana_error(_e400)[0] == "unresolved" else bad)(
        "11y a 400 from a fussy endpoint is 'not this type', not a blind spot -- "
        "otherwise it would mask every 404 beside it", "", repr(classify_asana_error(_e400)))
    (ok if combine_gid_verdicts([_u, _c])[0] == "cannotverify" else bad)(
        "11x a blind spot beside a 404 outranks it -- we cannot see, so we do not judge", "",
        repr(combine_gid_verdicts([_u, _c])))

    # 12 -- a prose elision is not a path claim
    (ok if scan("`/Users/nobody/...` and `~/x\u2026`")["paths"] == [] else bad)(
        "12  an ellipsis path is a prose elision, not a citation", "",
        repr(scan("`/Users/nobody/...`")["paths"]))

    # 13/13t -- a sha this clone does not have. The pair differs ONLY in whether
    #           the clone fetched before or after the handoff was written, so
    #           nothing but the timestamp comparison can separate them.
    _here = os.path.basename(os.path.dirname(os.path.abspath(__file__)))
    _d = repo_dir(_here)
    if _d is None:
        ok("13  (skipped: this file is not inside a git repo on this box)")
        ok("13t (skipped with 13)")
    else:
        _zero = "0" * 40
        _fetched = last_fetch(_d) or 0
        st_stale, _ = resolve_sha(_here, _zero, since=_fetched + 3600)
        st_fresh, _ = resolve_sha(_here, _zero, since=_fetched - 3600)
        (ok if st_stale == "cannotverify" else bad)(
            "13  a sha missing from a clone that has not fetched since the handoff is CANNOT VERIFY",
            "", st_stale)
        (ok if st_fresh == "unresolved" else bad)(
            "13t POSITIVE TWIN: the same absent sha in a clone that HAS fetched since is a finding",
            "", st_fresh)

    # 14/14t -- exists-but-unpushed. The twin is this repo's real HEAD, which IS
    #           on a remote branch, so only reachability separates the two.
    if _d is not None:
        _rc = subprocess.run(["git", "-C", _d, "rev-parse", "HEAD"],
                             capture_output=True, text=True)
        _head = _rc.stdout.strip()
        _orph = subprocess.run(["git", "-C", _d, "log", "--format=%H", "-1",
                                "--walk-reflogs", "--all"], capture_output=True, text=True)
        st_head, _det = resolve_sha(_here, _head, since=None)
        (ok if st_head == "ok" else bad)(
            "14  a pushed commit resolves", "", f"{st_head} {_det}")
        _fake = subprocess.run(
            ["git", "-C", _d, "commit-tree", "-p", _head, "-m", "hri drill orphan",
             _head + "^{tree}"], capture_output=True, text=True)
        if _fake.returncode == 0 and _fake.stdout.strip():
            st_orph, _det2 = resolve_sha(_here, _fake.stdout.strip(), since=None)
            (ok if st_orph == "unresolved" else bad)(
                "14t POSITIVE TWIN: an object that EXISTS but is on no remote branch "
                "is unresolved -- exists is not reachable", "", f"{st_orph} {_det2}")
        else:
            ok("14t (skipped: could not mint a throwaway object here)")
    else:
        ok("14  (skipped: not inside a git repo)")
        ok("14t (skipped with 14)")

    # 15/15t -- a REF-OK that excuses nothing. The pair uses the SAME marker text;
    #           only whether the token is still broken differs, so nothing about the
    #           fixture can satisfy 15 except the liveness test itself.
    _live = ("see `~/definitely-not-here-xyz`\n"
             "REF-OK: ~/definitely-not-here-xyz -- deleted on purpose when the lane closed")
    _dead = ("see `~/`\n"
             "REF-OK: ~/definitely-not-here-xyz -- deleted on purpose when the lane closed")
    f, _, _, lv, dd = report(scan(_live), _r({}), None)
    (ok if (not f and lv == 1 and dd == 0) else bad)(
        "15  a REF-OK still attached to a broken reference counts as LIVE", "",
        f"findings={kinds(f)} live={lv} dead={dd}")
    f2, _, _, lv2, dd2 = report(scan(_dead), _r({}), None)
    (ok if (kinds(f2) == ["EXEMPT-DEAD"] and lv2 == 0 and dd2 == 1) else bad)(
        "15t POSITIVE TWIN: the same marker, once the document stops citing it, is DEAD "
        "and says so -- an exemption excusing nothing is an exception record outliving its subject",
        "", f"findings={kinds(f2)} live={lv2} dead={dd2}")

    # 9/9t -- the classifier itself, fed both worlds. Controls 1 and 2 above
    #         inject a resolver, so until this pair existed the 404-vs-403
    #         judgement was exercised only by never being exercised.
    e404 = 'Asana HTTP 404 on GET /tasks/1: {"errors":[{"message":"Not a recognized ID"}]}'
    e403 = 'Asana HTTP 403 on GET /tasks/1: {"errors":[{"message":"Forbidden"}]}'
    (ok if classify_asana_error(e404)[0] == "unresolved" else bad)(
        "9  a 404 body classifies as UNRESOLVED", "", repr(classify_asana_error(e404)))
    (ok if classify_asana_error(e403)[0] == "cannotverify" else bad)(
        "9t POSITIVE TWIN: a 403 body -- same shape, same function -- classifies as CANNOT VERIFY",
        "", repr(classify_asana_error(e403)))
    for _noise in ("connection timed out", "Temporary failure in name resolution", ""):
        if classify_asana_error(_noise)[0] != "cannotverify":
            bad("9x transport noise must never read as a broken reference", "", _noise)
            break
    else:
        ok("9x transport noise (timeout, DNS, empty) never reads as a broken reference")

    print(f"=== selftest: {33 - len(fails)} passed, {len(fails)} failed ===")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
