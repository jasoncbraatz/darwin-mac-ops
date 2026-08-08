# dotfiles — darwin global config (repo-backed so a reflatten can reinstate it)

**Install / verify / undo — one command each:**

```bash
bash dotfiles/install-dotfiles.sh --dry-run    # look first
bash dotfiles/install-dotfiles.sh              # install (idempotent)
bash dotfiles/dotfiles-drill.sh                # prove it, offline, on a scratch $HOME
bash dotfiles/install-dotfiles.sh --uninstall  # undo
```

`gate-selfcheck.sh` **G-AG** reports the truth either way, so you never have to remember whether
this Mac got them. `BOOTSTRAP.md` §1a is the rebuild step.

## Why an installer at all (S47)

Until 2026-08-08 this README said `cp`, by hand, and nothing pointed at this file — not
`BOOTSTRAP.md`, not a script, not a gate check. A fresh Mac that followed the rebuild runbook
perfectly came up **without any of these**, and neither absence announces itself.

## What's here

### `.zshenv` — load-bearing, not cosmetic
Sets `PATH` for **non-interactive** zsh (ssh, MCP, launchd), which is the only reason `gh`
resolves in automation; adds TeX Live + `~/bin`; and sets `no_nomatch` for those shells so an
unmatched glob passes through like bash instead of **aborting the line** (that one distilled four
blackbook zsh-glob leaves). Without it, scripts fail in ways that look like other bugs.

### `gitignore_global` — git's global excludesfile (set up 2026-06-23)
Ignores universal junk (`.DS_Store`, editor swap files) and — importantly — BOTH `*.bak` AND the
timestamped backup form `*.bak.*` (e.g. `foo.py.bak.20260623-031053`), which slips a bare `*.bak`
glob and has bitten repos twice (a dirty repo tripping the HANDOFF-GATE; junk rsync'd to the
runtime box).

**Verify:** `cd /tmp && mkdir -p t && cd t && git init -q && touch x.py.bak.20260623 && git check-ignore -v x.py.bak.20260623`
→ should match `~/.gitignore_global:*.bak.*`.

## Symlinks, not copies — on purpose

The installer links these into `$HOME`; it does not copy them. A copy is an **install-day
snapshot**: edit the repo version and the machine keeps using the frozen one, silently, forever.
That is the COPIED-not-DERIVED family this estate has now caught ten times. A symlink makes
`git pull` the deploy.

The obvious objection is availability — a dangling symlink if the repo moves. Measured, not
assumed (`dotfiles-drill.sh` #8/#8b): zsh treats an unreadable `~/.zshenv` exactly like an absent
one, and git treats a missing excludesfile the same way. And the estate already hard-depends on
this path existing, because `core.hooksPath` points into it — so the symlink adds no new failure
domain.

## Undo leaves you working, not bare

`--uninstall` replaces each symlink with the file that was there before (the
`.bak-predotfiles-*` stash the installer made *before* touching anything), or a plain copy of the
repo version if there wasn't one. It never leaves you with no `~/.zshenv`, because a Mac with no
`~/.zshenv` is a Mac where automation cannot find `gh`. Files it did not install, it does not
touch.

## Adding a dotfile

Add one `<repo-relative-source>|$HOME/<target>` line to `MANIFEST` in `install-dotfiles.sh`.
That is the whole registration: G-AG **extracts the manifest from the installer at run time**, so
the check learns about the new file automatically instead of quietly auditing a stale list.
