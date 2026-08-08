# hooks/ — the estate's commit-time secret refusal

One needle (`secret-re.sh`), two readers: `gate-selfcheck.sh` **detects** at wrap (G-E),
this `pre-commit` **refuses** at commit (G-AF). They source the same file, so they
cannot drift apart.

## Two layers of coverage

1. **The global default** — `git config --global core.hooksPath <this dir>`, set by
   the installer. Covers every repo on this Mac that does not override it, *including
   every repo cloned or `git init`'d from now on*. This is the layer that makes a
   **fresh clone** protected; without it, protection lives only in `.git/config`,
   which is untracked and never cloned (the S45 hole, closed in S46).
2. **Per-repo wiring** — the loop in `install-estate-hooks.sh`. Git config is
   most-specific-wins, so a repo with its **own** `core.hooksPath` ignores the global
   default entirely. Those repos are the only ones that still need explicit wiring,
   and G-AF names any that lack it.

Not `init.templateDir`, which looks like the obvious answer. Measured in S46: a
template that **copies** the hooks freezes them at install-day forever; a template
that **symlinks** them makes `pre-commit` resolve `$0` inside `.git/hooks`, where
`secret-re.sh` and `_chain.sh` are not — so it fails closed on every commit in every
new clone. Both shapes were run end-to-end before the global default was chosen.

| file | what it does |
|---|---|
| `secret-re.sh` | SSOT: `SECRET_RE`, allowlist loader, masker. Sourced, never executed. |
| `pre-commit` | Blocks credential shapes in the **staged index**. Fails closed. |
| `_chain.sh` | Runs whatever hook the repo had before. Every other hook name symlinks here. |
| `install-estate-hooks.sh` | Wire/unwire both layers. `--dry-run`, `--uninstall`, `--repo`, `--no-global`. |
| `hooks-drill.sh` | The whole thing on scratch repos + a scratch `~/.gitconfig`. Run it before trusting a change. |
| `verify-freshclone.sh` | The other half: a **real** clone on **this** Mac, real `~/.gitconfig`. Answers "is this machine protected?", which a hermetic drill structurally cannot. |

```sh
bash install-estate-hooks.sh --dry-run     # what would change
bash install-estate-hooks.sh               # wire it (idempotent)
bash install-estate-hooks.sh --uninstall   # put the machine back exactly as it was
bash hooks-drill.sh                        # prove the mechanism, offline, hermetic
bash verify-freshclone.sh                  # prove THIS Mac: fresh clone, real config
cd <repo> && ESTATE_HOOK_DRYRUN=1 ESTATE_HOOK_NAME=pre-push bash _chain.sh   # who chains here?
```

The drill prints its own assertion count — it is not written down here, because a
number copied into prose rots (this estate has caught that family nine times).

**Blocked?** Three legal answers, in order: scrub it **and rotate the credential** ·
name it with a written reason in `../gate-secret-sweep.allow` · `git commit --no-verify`
for that one commit. Deleting the hook is not one of them.

**Undo, in one command:** `bash install-estate-hooks.sh --uninstall` — removes the
global default *and* restores every per-repo setting. That is why the installer owns
the global key instead of a hand-run `git config`: one documented undo has to stay true.

Full rationale: `~/Desktop/downloads/HANDOFF-GATE.md` § **G-AF** (v2.46, extended v2.47).
