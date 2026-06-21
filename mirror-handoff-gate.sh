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
ver() { grep -m1 -oE "^- v[0-9.]+" "$1" 2>/dev/null | sed 's/^- //' || echo "v?"; }  # reads changelog top (self-correcting; never hardcode)

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

cp "$CANON" "$MIRROR"
cd "$MIRROR_REPO"
git add HANDOFF-GATE.md
git commit -q -m "mirror HANDOFF-GATE.md from darwin-everything-meta ($(ver "$CANON"))"
git push -q
echo "[mirror-gate] synced + pushed -> claude-blackbook ($(ver "$CANON"))"
