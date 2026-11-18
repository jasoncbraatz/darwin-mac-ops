#!/usr/bin/env bash
# ============================================================================
# mirror-handoff-gate.sh — keep the claude-blackbook SECONDARY MIRROR of
# HANDOFF-GATE.md in sync with the canonical copy.
#
#   Canonical : ~/Desktop/downloads/HANDOFF-GATE.md   (repo: darwin-everything-meta)
#   Mirror    : ~/repos/claude-blackbook/HANDOFF-GATE.md   (repo: claude-blackbook)
#
# WHY: Jason's doctrine keeps the gate repo-backed in darwin-everything-meta with a
# secondary mirror in claude-blackbook (belt + suspenders). A mirror that isn't synced
# automatically ROTS — it sat at v1.5 while canonical reached v1.9. Run this after ANY
# gate edit (it's the last step of updating the gate). Idempotent: a no-op when in sync.
#
#   bash ~/Scripts/mirror-handoff-gate.sh           # sync + commit + push if changed
#
# Lives in the darwin-mac-ops repo (alongside gate-selfcheck.sh), symlinked into ~/Scripts.
# ============================================================================
set -euo pipefail
CANON="$HOME/Desktop/downloads/HANDOFF-GATE.md"
MIRROR_REPO="$HOME/repos/claude-blackbook"
MIRROR="$MIRROR_REPO/HANDOFF-GATE.md"
ver() { grep -m1 -oE "Version [0-9]+\.[0-9]+" "$1" 2>/dev/null | sed 's/Version /v/' || echo "v?"; }  # reads the authoritative HEADER version line (self-correcting; never hardcode)

[ -f "$CANON" ] || { echo "[mirror-gate] ERR: canonical gate missing: $CANON" >&2; exit 1; }
if [ ! -d "$MIRROR_REPO/.git" ]; then
  echo "[mirror-gate] ERR: mirror repo not cloned: $MIRROR_REPO" >&2
  echo "[mirror-gate]      fix: cd ~/repos && gh repo clone jasoncbraatz/claude-blackbook" >&2
  exit 1
fi

if cmp -s "$CANON" "$MIRROR"; then
  echo "[mirror-gate] already in sync ($(ver "$CANON"))"
  exit 0
fi

# REFUSE TO REGRESS (fable-estateMow-01, 2026-11-18). The mirror is not read-only in practice:
# brief sessions edited it directly on 2026-11-15 (G-F.0) while the canonical sat at 2026-10-02,
# and on a box whose canonical clone was stale this script -- the gate's own suggested remedy for
# "mirror is STALE" -- would have pushed a six-week-old gate over the newer text. So: if the mirror
# has a NON-mirror commit to this file newer than the canonical's last commit to it, the mirror is
# AHEAD. Pull it home first (review, then: cat "$MIRROR" > "$CANON", commit in darwin-everything-meta).
# Override with MIRROR_GATE_FORCE=1 only after you have done exactly that.
_canon_dir=$(dirname "$CANON")
_canon_t=$(git -C "$_canon_dir" log -1 --format=%ct -- "$(basename "$CANON")" 2>/dev/null || echo 0)
_mirror_t=$(git -C "$MIRROR_REPO" log -1 --format=%ct --invert-grep --grep='^mirror HANDOFF-GATE.md' -- HANDOFF-GATE.md 2>/dev/null || echo 0)
if [ "${MIRROR_GATE_FORCE:-0}" != 1 ] && [ "${_mirror_t:-0}" -gt "${_canon_t:-0}" ]; then
  echo "[mirror-gate] REFUSED [mirror-ahead]: claude-blackbook has a direct edit to HANDOFF-GATE.md ($(git -C "$MIRROR_REPO" log -1 --format='%h %cd' --date=short --invert-grep --grep='^mirror HANDOFF-GATE.md' -- HANDOFF-GATE.md)) newer than the canonical's last commit -- copying would REGRESS it." >&2
  echo "[mirror-gate]   fix: git -C $_canon_dir pull --ff-only; if still refused, review the diff, then cat $MIRROR > $CANON and commit in darwin-everything-meta (MIRROR_GATE_FORCE=1 overrides)" >&2
  exit 3
fi
cp "$CANON" "$MIRROR"
cd "$MIRROR_REPO"
# `git add <path>` then a bare `git commit` is NOT path-scoped: commit takes the whole INDEX,
# so anything a CONCURRENT session staged between the two lines rides along. Measured
# 2026-08-15 (stateMachineRename-1): commit fe2aafa5 carried HANDOFF-GATE.md plus SIX in-flight
# lesson leaves belonging to acmeLedger-24, which had run `lessons.py add` (git add; git commit)
# milliseconds earlier -- its files were staged, mine committed them under my message. Nothing
# was lost, but it is a G-AC violation (another session's work is not yours to commit) that no
# amount of care in THIS script's `git add` line could prevent.
# `commit --only <path>` commits that path and nothing else, whatever else sits in the index.
git add HANDOFF-GATE.md
git commit -q --only HANDOFF-GATE.md -m "mirror HANDOFF-GATE.md from darwin-everything-meta ($(ver "$CANON"))"
git push -q
echo "[mirror-gate] synced + pushed -> claude-blackbook ($(ver "$CANON"))"
