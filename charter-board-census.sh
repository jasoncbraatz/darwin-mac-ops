#!/bin/bash
# charter-board-census.sh — REGISTERED IS NOT MEASURED.
#
# Born smDrainHandoff-17 (2026-09-04), SM card 1217904193313336.
#
# THE HOLE. G-AL#board asks "is THIS session's project board stale?" It resolves its
# subject through project-charters.tsv — and a check that resolves its subject through a
# registry can only ever grade the row it landed on. Twenty projects are registered. On
# any given wrap exactly ONE of them is measured, and the other nineteen are green by
# omission: not passing, not failing, never asked. A project whose sessions have stopped
# happening is precisely the project whose board nobody will ever check again, which is
# the one whose board rots hardest. (Global lesson 2026-08-27-per-session-check-resolves-
# its-subject: whenever a gate step looks its subject up in a registry, something separate
# must ask the opposite question — what does the registry hold that nobody is grading?)
#
# MEASURED BEFORE IT WAS WRITTEN, and the measurement killed the cheap version. The first
# design compared git commit dates: board committed before its criteria file => stale. That
# proxy costs nothing and it reports ALL NINETEEN ROWS GREEN. Running the real
# `board.py --check` on the first three finds voiceBox, mcpMirror AND wealthTensor STALE.
# So the cheap axis is not a weaker version of the real one, it is indistinguishable from
# health — a board goes stale because a `cmd:` CRITERION changed status out in the world,
# and nothing in the repository's history moves when that happens. This census therefore
# RUNS the checks. That is the cost, and the cost is the point.
#
# WHICH IS WHY IT ROTATES. A full pass is ~19 board runs at 3-11 s each — minutes, at wrap,
# which is how a control gets switched off (smDrainHandoff-15 left G-E's PAN sweep unwired
# for exactly this reason and said so out loud). --rotate N checks the N rows measured
# longest ago and records the timestamp, so the gate pays one board run per wrap and the
# whole registry is covered over the next twenty. "Eventually measured" is a weaker promise
# than "measured every run" and a far stronger one than "never measured at all".
#
# EXIT CODES (read them BARE — never through a pipe):
#   0  every row checked THIS RUN has a fresh board
#   1  at least one checked row is STALE, or its criteria/board is missing
#   2  CANNOT VERIFY — the registry is unreadable or enumerates nothing. An empty
#      registry is not a clean estate, and a census of nothing must never read as a pass.
#
# A row whose board engine errors or times out is CANNOT VERIFY *for that row* and counts
# as a finding (rc 1), never as a pass. "I could not look" is not "it is fine" — the same
# rule ratification-census.sh phase 4 is built on.
#
# ENV (the drill drives the census through these; production sets none of them):
#   CBC_REG      registry path            (default: $HOME/code/darwin-mac-ops/project-charters.tsv)
#   CBC_STATE    rotation ledger          (default: $HOME/.local/state/charter-board-census.tsv)
#   CBC_TIMEOUT  per-row seconds          (default: 300 — the same BOARD_CHECK_TIMEOUT the
#                gate uses; a smaller one manufactures CANNOT VERIFY under load, wealthTensor-97)
# USAGE
#   charter-board-census.sh                 full pass, every registered row
#   charter-board-census.sh --rotate 1      the single least-recently-measured row
#   charter-board-census.sh --list          enumerate rows and last-measured, run nothing (rc 0/2)
set -uo pipefail
exec /usr/bin/python3 - "$@" <<'PYEOF'
import os, re, sys, time, subprocess

HOME = os.path.expanduser("~")
REG  = os.path.expanduser(os.environ.get("CBC_REG",
        os.path.join(HOME, "code/darwin-mac-ops/project-charters.tsv")))
STATE= os.path.expanduser(os.environ.get("CBC_STATE",
        os.path.join(HOME, ".local/state/charter-board-census.tsv")))
TMO  = int(os.environ.get("CBC_TIMEOUT", "300"))

argv = sys.argv[1:]
rotate = 0
listonly = "--list" in argv
if "--rotate" in argv:
    i = argv.index("--rotate")
    try: rotate = int(argv[i+1])
    except (IndexError, ValueError):
        print("charter-board-census: --rotate needs a count", file=sys.stderr); sys.exit(2)

def expand(p):
    return os.path.expanduser(os.path.expandvars(p))

# -- enumerate. The subject is DISCOVERED from the registry, never a list in this file:
# a census that names its own subjects fails open on every project registered tomorrow.
rows = []
try:
    with open(REG) as fh:
        for ln in fh:
            if ln.startswith("#") or not ln.strip(): continue
            f = ln.rstrip("\n").split("\t")
            if len(f) < 4 or not f[0].strip(): continue
            rows.append({"key": f[0].strip(), "repo": f[1].strip(),
                         "crit": expand(f[2].strip()), "brief": f[3].strip()})
except OSError as e:
    print("CANNOT VERIFY: registry %s unreadable (%s) -- so NO registered board on this "
          "machine was asked whether it still describes the world." % (REG, e))
    sys.exit(2)

if not rows:
    print("CANNOT VERIFY: %s enumerates no charter rows. An empty registry is not a clean "
          "estate; it is a census with no subject." % REG)
    sys.exit(2)

# -- rotation ledger: key <TAB> epoch-of-last-measurement. Missing = never measured, which
# sorts FIRST, so a newly registered project is the next thing the gate looks at.
last = {}
try:
    with open(STATE) as fh:
        for ln in fh:
            p = ln.rstrip("\n").split("\t")
            if len(p) == 2:
                try: last[p[0]] = int(p[1])
                except ValueError: pass
except OSError:
    pass

for r in rows:
    r["last"] = last.get(r["key"], 0)

if listonly:
    for r in sorted(rows, key=lambda r: (r["last"], r["key"])):
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(r["last"])) if r["last"] else "NEVER"
        print("%-24s last-measured %s" % (r["key"], when))
    print("CENSUS %d registered, %d never measured" %
          (len(rows), sum(1 for r in rows if not r["last"])))
    sys.exit(0)

todo = sorted(rows, key=lambda r: (r["last"], r["key"]))
if rotate > 0:
    todo = todo[:rotate]

findings = []
now = int(time.time())
for r in todo:
    key, crit, brief = r["key"], r["crit"], r["brief"]
    if not os.path.exists(crit):
        findings.append("%s: criteria file %s is MISSING, so this project's finish line has "
                        "vanished and no board can be generated from it" % (key, crit))
        print("  MISSING  %-22s %s" % (key, crit)); last[key] = now; continue
    # --check is --brief with the flag swapped: same invocation, same env, same timeout the
    # gate uses. Rebuilding the command by hand is how the two readers drift apart.
    if "--brief" not in brief:
        findings.append("%s: registry brief-command has no --brief flag, so the census cannot "
                        "derive its --check form. Fix the row in %s" % (key, REG))
        print("  NOCHECK  %-22s %s" % (key, brief)); last[key] = now; continue
    chk = brief.replace("--brief", "--check")
    env = dict(os.environ); env.setdefault("BOARD_CHECK_TIMEOUT", str(TMO))
    try:
        p = subprocess.run(["/bin/bash", "-c", chk], capture_output=True, text=True,
                           timeout=TMO + 30, env=env)
        rc, out = p.returncode, (p.stdout + p.stderr).strip()
    except subprocess.TimeoutExpired:
        rc, out = 124, "board engine exceeded %ds" % (TMO + 30)
    if rc == 0:
        print("  fresh    %-22s" % key)
    elif rc == 1:
        findings.append("%s: board is STALE -- a criterion changed status since it was "
                        "generated, and no session has been in a position to notice. "
                        "Regenerate and commit: BOARD_CHECK_TIMEOUT=%d %s"
                        % (key, TMO, brief.replace(" --brief", "")))
        print("  STALE    %-22s %s" % (key, out.splitlines()[0] if out else ""))
    else:
        # CANNOT VERIFY is a finding, never a pass. Reading "I could not look" as "it is
        # fine" is the failure that puts a confident green on an unmeasured board.
        findings.append("%s: CANNOT VERIFY -- the board engine exited %d (%s). An unreadable "
                        "board must never read as a fresh one." % (key, rc, out.splitlines()[0] if out else "no output"))
        print("  CANNOT   %-22s rc=%d" % (key, rc))
    last[key] = now

try:
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as fh:
        for k in sorted(last): fh.write("%s\t%d\n" % (k, last[k]))
except OSError as e:
    print("  (rotation ledger %s not writable: %s -- the next run will re-check the same "
          "rows, which is slow, not wrong)" % (STATE, e))

never = sum(1 for r in rows if not r["last"])
print("CENSUS %d registered · %d checked this run · %d never measured before this run · %d finding(s)"
      % (len(rows), len(todo), never, len(findings)))
for f in findings:
    print("  FINDING %s" % f)
sys.exit(1 if findings else 0)
PYEOF
