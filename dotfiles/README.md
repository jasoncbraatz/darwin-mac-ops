# dotfiles — darwin global config (repo-backed so a reflatten can reinstate it)

## gitignore_global — git's global excludesfile (set up 2026-06-23)
Ignores universal junk (`.DS_Store`, editor swap files) and — importantly — BOTH `*.bak` AND the
timestamped backup form `*.bak.*` (e.g. `foo.py.bak.20260623-031053`), which slips a bare `*.bak` glob and
has bitten repos twice (a dirty repo tripping the HANDOFF-GATE; junk rsync'd to the runtime box).

**Install (on a fresh darwin):**
```bash
cp ~/Code/darwin-mac-ops/dotfiles/gitignore_global ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```
**Verify:** `cd /tmp && mkdir t && cd t && git init -q && touch x.py.bak.20260623 && git check-ignore -v x.py.bak.20260623` → should match `~/.gitignore_global:*.bak.*`.
**Undo:** `git config --global --unset core.excludesfile && rm ~/.gitignore_global` (it was unset before 2026-06-23).
