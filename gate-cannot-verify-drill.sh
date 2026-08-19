#!/bin/bash
# gate-cannot-verify-drill.sh — every instrument-gated gate step must SPEAK when its
# instrument is missing.  (born 2026-08-15, acmeLedger-22; subject inverted 2026-08-15,
# acmeLedger-24)
#
# THE CLASS THIS CLOSES
# Gate steps that delegate to an external instrument are written as:
#
#     INSTRUMENT="$HOME/Scripts/thing.sh"
#     if [ -x "$INSTRUMENT" ]; then
#       bold "=== G-XX · ... ==="
#       ...
#     fi
#
# With no else, a missing instrument makes the whole step VANISH: no ok, no WARN, no FAIL,
# no line at all — and the gate goes on to print its usual verdict having silently run one
# fewer check. Absence reads exactly like health.
#
# ── WHY THE SUBJECT WAS INVERTED (2026-08-15, acmeLedger-24) ────────────────────────────
# v1 defined a "gate step" as: something that prints `bold "=== G-XX"` within 3 lines after
# a guard. That is an ALLOWLIST OF THE FAMILIAR — the shape the steps happened to have in
# August — and it fails OPEN on every shape added later, while nothing about its output
# changes on the day it goes stale. It reported `10/10 instrument-gated steps speak` and
# was telling the truth about a set that did not contain the defect.
#
# MEASURED: the gate held FIVE else-less guards outside that subject. The sharpest was
# G-AA, the session-corroboration BLOCKER, gated on `[ -d "$SESSION_STATE" ]` with no else
# — and invisible to v1 precisely BECAUSE it obeys the house's "success is silent" rule: it
# prints its `bold` header only from inside a loop, when it has something to report. The
# control that exists to catch silently-vanishing steps could not see a step that was
# silent by design. Compliance with the doctrine was the camouflage.
#
# SO: the subject is now every `if [ -xfrd ... ]; then` guard in the gate file — the guard
# shape IS what makes a step vanishable, regardless of what it prints. Unknown counts as
# ours. A guard with no else is a FAIL unless it carries an EXPLICIT, REASONED
# ratification, which fails CLOSED: a new else-less guard written tomorrow goes red until
# somebody writes down why it is allowed to be quiet.
#
# THE RATIFICATION, and why it is inline rather than a side file:
#
#     # VANISH-OK: <at least 20 characters of reason>
#     if [ -f "$SOMETHING" ]; then
#
# A side allowlist is keyed on a line number or a guard's text; the first drifts on every
# edit and the second is not unique (`if [ -f "$CANON_GATE" ]; then` appears twice in this
# very file). The marker travels with the code it excuses and cannot fall out of sync with
# it. Same idiom as G-V#2's `# ASANA-READ-OK:` and G-E's `# why`.
#
# Structural on purpose: proving each step behaviourally costs a full gate run per step
# (minutes). Parsing costs ~30ms and catches the defect at authoring time. The drill
# carries positive AND negative controls — including controls for the ratification path
# itself — so a parser that can no longer go red refuses to go green.
#
# Exit: 0 = every instrument guard either speaks or is explicitly ratified (parser proved
#           it can still fail)
#       1 = at least one gate step would vanish silently
#       2 = CANNOT VERIFY (gate file unreadable, python3 missing, parser found too few
#           guards, or the parser failed one of its own controls)
set -u

GATE="${GATE_FILE:-$HOME/Scripts/gate-selfcheck.sh}"

command -v python3 >/dev/null 2>&1 || {
  echo "gate-cannot-verify-drill: CANNOT VERIFY — python3 is not on PATH"; exit 2; }
[ -r "$GATE" ] || {
  echo "gate-cannot-verify-drill: CANNOT VERIFY — cannot read $GATE"; exit 2; }

python3 - "$GATE" <<'PYDRILL'
import re, sys

GUARD  = re.compile(r'^\s*if \[ -[xfrd] .*\]; then\s*$')
HEADER = re.compile(r'^\s*bold "=== (G-[A-Z0-9#]+)')
# The ratification. A reason shorter than MIN_REASON is not a reason; it is a shrug.
VANISH_OK  = re.compile(r'#\s*VANISH-OK:\s*(.*)$')
MIN_REASON = 20


def analyse(lines):
    """Every instrument guard in the file is in the subject.

    -> list of dicts: guard line (1-based), has_else, ratified reason or None,
       and the nearest step label we can find for human-readable output.
    """
    out = []
    for i, ln in enumerate(lines):
        if not GUARD.match(ln):
            continue

        # walk the guard's own block to its matching `fi`, looking for an else at depth 1.
        #
        # COUNT PER LINE, NOT PER SHAPE. The first cut of this matched `^if`, `^else` and
        # `^fi` as whole lines, one classification each -- so a single-line
        # `if cond; then x; fi` (an extremely ordinary bash shape) incremented depth and
        # never decremented it. Every guard AFTER such a line then had its own `else`
        # measured at depth 2 and was reported as VANISHING when it plainly does not.
        # A control that cries wolf gets waved through, which costs more than the bug it
        # was watching for. Found 2026-08-19 when one new one-liner in G-AL turned this
        # drill red against a guard whose else sits 144 lines below it.
        depth, has_else, end = 0, False, i
        for k in range(i, len(lines)):
            s = lines[k].strip()
            if s.startswith('#'):
                continue
            opens = len(re.findall(r'(?:^|[;&|]\s*|\bthen\s+|\bdo\s+)if\b', s))
            closes = len(re.findall(r'(?:^|[;&|]\s*)fi\b', s))
            if re.match(r'^else\b', s) and depth == 1:
                has_else = True
            depth += opens
            if closes:
                depth -= closes
                if depth <= 0:
                    end = k
                    break

        # Ratification: on the guard line itself, or anywhere in the CONTIGUOUS comment
        # block directly above it. Probing only the single line above (v2's first cut)
        # silently ignored every marker whose reason needed a second sentence -- and a
        # reason worth 20+ characters usually does. Found immediately: the first real
        # ratification written in this file went unseen for exactly that reason.
        reason = None
        m = VANISH_OK.search(ln)
        if m:
            reason = m.group(1).strip()
        else:
            for j in range(i - 1, max(-1, i - 9), -1):
                if not lines[j].lstrip().startswith('#'):
                    break            # comment block ended; stop climbing
                m = VANISH_OK.search(lines[j])
                if m:
                    reason = m.group(1).strip()
                    break

        # a name for the human: the first G-step header inside the block, else the
        # nearest preceding `# --- G-XX` style comment, else the bare line number
        name = None
        for l in lines[i:end + 1]:
            m = HEADER.match(l)
            if m:
                name = m.group(1)
                break
        if name is None:
            for j in range(i, max(-1, i - 40), -1):
                m = re.search(r'#+\s*[-─— ]*(G-[A-Z0-9#]+)', lines[j])
                if m:
                    name = m.group(1) + '?'   # inferred from a comment, not printed by the step
                    break
        out.append({'line': i + 1, 'has_else': has_else, 'reason': reason,
                    'name': name or '(unnamed)'})
    return out


def fail_control(msg):
    print("gate-cannot-verify-drill: CANNOT VERIFY — " + msg)
    sys.exit(2)


# ---- the drill's own controls: prove the parser can go EVERY way it claims -------------
CTL = {
    # a step with an else: recognised as speaking
    'positive': (['INSTRUMENT="/x"', 'if [ -x "$INSTRUMENT" ]; then',
                  '  bold "=== G-ZZ · a fixture that speaks ==="', '  echo ok', 'else',
                  '  echo CANNOT VERIFY', 'fi'],
                 lambda r: r['has_else'] and r['reason'] is None),
    # a step with no else and no marker: flagged
    'negative': (['INSTRUMENT="/x"', 'if [ -x "$INSTRUMENT" ]; then',
                  '  bold "=== G-ZY · a fixture that vanishes ==="', '  echo ok', 'fi'],
                 lambda r: not r['has_else'] and r['reason'] is None),
    # THE SHAPE v1 COULD NOT SEE: an else-less guard whose step prints no header near it.
    # If this control ever stops being flagged, the inversion has been undone.
    'headerless': (['STATE="/x"', 'if [ -d "$STATE" ]; then',
                    '  for f in "$STATE"/*; do', '    echo found', '  done', 'fi'],
                   lambda r: not r['has_else'] and r['reason'] is None),
    # THE SHAPE THAT BROKE THE COUNTER (2026-08-19): a one-line `if ...; fi` inside the block.
    # The guard below DOES have an else; a per-shape counter loses a level on the one-liner
    # and reports it as vanishing.
    'oneliner': (['if [ -x "$TOOL" ]; then',
                  '  bold "=== G-ZZ · a step with a one-line if inside ==="',
                  '  if [ -n "$x" ]; then y=1; fi',
                  '  echo ok',
                  'else',
                  '  echo "CANNOT VERIFY"',
                  'fi'],
                 lambda r: r['has_else'] and r['reason'] is None),

    # a ratified else-less guard: NOT flagged
    'ratified': (['# VANISH-OK: reported downstream by the block above, deliberately quiet',
                  'if [ -f "$THING" ]; then', '  echo ok', 'fi'],
                 lambda r: not r['has_else'] and r['reason'] is not None
                           and len(r['reason']) >= MIN_REASON),
    # a ratification buried in a multi-line comment block: still found. This control
    # exists because v2's first cut probed ONLY the line above the guard and missed the
    # very first real ratification written into the gate.
    'ratified_block': (['# acmeLedger-NN: some context about why this step is the way it is',
                        '# VANISH-OK: the same condition FAILs loudly thirty lines above this one',
                        '# and is reported a second time at the triad.',
                        'if [ -f "$THING" ]; then', '  echo ok', 'fi'],
                       lambda r: not r['has_else'] and r['reason'] is not None
                                 and len(r['reason']) >= MIN_REASON),
    # a comment block that does NOT touch the guard must not ratify it
    'distant': (['# VANISH-OK: this reason belongs to something else entirely, far above',
                 'SOMEVAR="x"', 'if [ -f "$THING" ]; then', '  echo ok', 'fi'],
                lambda r: not r['has_else'] and r['reason'] is None),
    # a ratification with a shrug for a reason: the reason requirement must still bite
    'shrug': (['# VANISH-OK: fine',
               'if [ -f "$THING" ]; then', '  echo ok', 'fi'],
              lambda r: not r['has_else'] and r['reason'] is not None
                        and len(r['reason']) < MIN_REASON),
}
for label, (fixture, assertion) in CTL.items():
    rows = analyse(fixture)
    if len(rows) != 1 or not assertion(rows[0]):
        fail_control("the parser failed its %s control. Its verdict, green or red, would "
                     "mean nothing until that is fixed." % label.upper())

lines = open(sys.argv[1], errors='ignore').read().split('\n')
rows = analyse(lines)

# Non-vacuity: a parser that matches nothing would otherwise report a clean sweep.
# The gate has carried 15 instrument guards since acmeLedger-24 and has only ever grown.
if len(rows) < 8:
    fail_control("found only %d instrument guard(s) in %s. The gate has had a dozen-plus "
                 "for months, so the parser is broken, not the gate." % (len(rows), sys.argv[1]))

speaks    = [r for r in rows if r['has_else']]
ratified  = [r for r in rows if not r['has_else'] and r['reason']
             and len(r['reason']) >= MIN_REASON]
shrugged  = [r for r in rows if not r['has_else'] and r['reason']
             and len(r['reason']) < MIN_REASON]
vanishing = [r for r in rows if not r['has_else'] and not r['reason']]

for r in rows:
    if r['has_else']:
        verdict = 'ok'
    elif r in ratified:
        verdict = 'ok*'
    else:
        verdict = 'FAIL'
    print("  %-5s %-10s guard@%-5d %s"
          % (verdict, r['name'], r['line'],
             ('ratified: ' + r['reason']) if r in ratified else
             ('RATIFICATION TOO SHORT: ' + r['reason']) if r in shrugged else ''))

print("--- %d instrument guard(s): %d speak, %d ratified-quiet, %d would VANISH ---"
      % (len(rows), len(speaks), len(ratified), len(shrugged) + len(vanishing)))

if shrugged:
    print("FAIL: %d ratification(s) carry a reason under %d characters — a reason that "
          "short is a shrug, and a shrug is not a ratification:" % (len(shrugged), MIN_REASON))
    for r in shrugged:
        print("  %s guard@%d: '%s'" % (r['name'], r['line'], r['reason']))
if vanishing:
    print("FAIL: %d gate step(s) would VANISH SILENTLY if their instrument went missing:"
          % len(vanishing))
    for r in vanishing:
        print("  %s guard@%d — add an else printing CANNOT VERIFY (copy the shape from "
              "G-X or G-AF), or ratify it with a '# VANISH-OK: <reason>' comment on the "
              "line above the guard." % (r['name'], r['line']))
if shrugged or vanishing:
    sys.exit(1)

print("=== drill: %d/%d instrument guards speak when their instrument is missing "
      "(%d explicitly ratified-quiet) ===" % (len(speaks), len(rows), len(ratified)))
PYDRILL
