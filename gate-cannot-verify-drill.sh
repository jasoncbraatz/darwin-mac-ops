#!/bin/bash
# gate-cannot-verify-drill.sh — every instrument-gated gate step must SPEAK when its
# instrument is missing.  (born 2026-08-15, acmeLedger-22)
#
# WHY THIS EXISTS
# ---------------
# Gate steps that delegate to an external instrument are written as:
#
#     INSTRUMENT="$HOME/Scripts/some-check.sh"
#     if [ -x "$INSTRUMENT" ]; then
#       bold "=== G-XX · <a sentence claiming something universal> ==="
#       ...run it, ok / WARN / FAIL...
#     fi                      <-- no else
#
# With no else, a missing instrument makes the whole step VANISH: no ok, no WARN, no FAIL,
# no line in the output at all — and the gate goes on to print its usual verdict having
# silently run one fewer check. Measured 2026-08-15: running gate-selfcheck.sh with
# ESTATE_HOOKS=/nonexistent/hooks produced no G-AF line whatsoever, on a step whose title
# claims "every repo refuses secrets at COMMIT" and whose own first leg calls a missing hook
# FILE a blocker. The strictly worse state — the whole directory gone — was the quiet one.
#
# G-X, G-Y and G-H#drill already got this right ("CANNOT VERIFY ... exit 2 is NOT a pass").
# Four steps did not. This drill is the thing that notices the FIFTH one, whenever it is added.
#
# It is deliberately STRUCTURAL, not behavioural: proving it by running the gate once per step
# with the instrument hidden costs a full gate run each time (minutes). Parsing costs 30ms and
# catches the defect at the moment it is written rather than the moment it matters.
#
# Exit: 0 = every instrument-gated step has an else branch (and the parser proved it can fail)
#       1 = at least one step would vanish silently
#       2 = CANNOT VERIFY (gate file unreadable, python3 missing, or the parser found no steps)
set -u

GATE="${GATE_FILE:-$HOME/Scripts/gate-selfcheck.sh}"

command -v python3 >/dev/null 2>&1 || {
  echo "gate-cannot-verify-drill: CANNOT VERIFY — python3 is not on PATH"; exit 2; }
[ -r "$GATE" ] || {
  echo "gate-cannot-verify-drill: CANNOT VERIFY — cannot read $GATE"; exit 2; }

python3 - "$GATE" <<'PYDRILL'
import re, sys, tempfile, os

GUARD = re.compile(r'^\s*if \[ -[xfrd] .*\]; then\s*$')
HEADER = re.compile(r'^\s*bold "=== (G-[A-Z0-9#]+)')

def analyse(lines):
    """-> list of (step_name, header_lineno, guard_lineno_or_None, has_else)"""
    out = []
    for i, ln in enumerate(lines):
        m = HEADER.match(ln)
        if not m:
            continue
        name = m.group(1)
        # look back a few lines for an instrument guard that opens this step
        guard = None
        for j in range(i - 1, max(-1, i - 4), -1):
            if GUARD.match(lines[j]):
                guard = j
                break
        if guard is None:
            out.append((name, i + 1, None, None))   # not instrument-gated; nothing to assert
            continue
        depth, has_else = 0, False
        for k in range(guard, len(lines)):
            s = lines[k].strip()
            if re.match(r'^if\b', s):
                depth += 1
            elif re.match(r'^else\b', s) and depth == 1:
                has_else = True
            elif re.match(r'^fi\b', s):
                depth -= 1
                if depth == 0:
                    break
        out.append((name, i + 1, guard + 1, has_else))
    return out

# ---- the drill's own controls: prove the parser can go BOTH ways ---------------------
POS = ['INSTRUMENT="/x"', 'if [ -x "$INSTRUMENT" ]; then',
       '  bold "=== G-ZZ · a fixture that speaks ==="', '  echo ok', 'else',
       '  echo CANNOT VERIFY', 'fi']
NEG = ['INSTRUMENT="/x"', 'if [ -x "$INSTRUMENT" ]; then',
       '  bold "=== G-ZY · a fixture that vanishes ==="', '  echo ok', 'fi']
ctl_ok = analyse(POS)
ctl_bad = analyse(NEG)
if not (ctl_ok and ctl_ok[0][3] is True):
    print("gate-cannot-verify-drill: CANNOT VERIFY — the parser failed its POSITIVE control "
          "(a step WITH an else was not recognised). Its green verdict would mean nothing.")
    sys.exit(2)
if not (ctl_bad and ctl_bad[0][3] is False):
    print("gate-cannot-verify-drill: CANNOT VERIFY — the parser failed its NEGATIVE control "
          "(a step WITHOUT an else was not flagged). It cannot go red, so it must not go green.")
    sys.exit(2)

lines = open(sys.argv[1], errors='ignore').read().split('\n')
rows = analyse(lines)
gated = [r for r in rows if r[2] is not None]

# Non-vacuity: a parser that matches nothing would otherwise report a clean sweep.
if len(gated) < 3:
    print("gate-cannot-verify-drill: CANNOT VERIFY — found only %d instrument-gated step(s) in %s. "
          "The gate has had several for months, so the parser is broken, not the gate."
          % (len(gated), sys.argv[1]))
    sys.exit(2)

bad = [r for r in gated if not r[3]]
for name, hdr, guard, has_else in gated:
    print("  %-4s %-10s guard@%-5d header@%-5d" % ("ok" if has_else else "FAIL", name, guard, hdr))
print("--- %d instrument-gated step(s); %d ungated step(s) also seen ---"
      % (len(gated), len(rows) - len(gated)))

if bad:
    print()
    print("FAIL: %d gate step(s) would VANISH SILENTLY if their instrument went missing:" % len(bad))
    for name, hdr, guard, _ in bad:
        print("   %s (guard at line %d) — add an else branch that prints CANNOT VERIFY and"
              " pushes a FAIL or WARN. Copy the shape from G-X or G-AF." % (name, guard))
    print()
    print("A step that does not run is not a pass.")
    sys.exit(1)

print()
print("=== drill: %d/%d instrument-gated steps speak when their instrument is missing ===" % (len(gated), len(gated)))
sys.exit(0)
PYDRILL
