# hooks/ — the estate's commit-time secret refusal

Every git repo under the gate's ROOTS points `core.hooksPath` here. One needle
(`secret-re.sh`), two readers: `gate-selfcheck.sh` **detects** at wrap (G-E), this
`pre-commit` **refuses** at commit (G-AF). They cannot drift apart.

| file | what it does |
|---|---|
| `secret-re.sh` | SSOT: `SECRET_RE`, allowlist loader, masker. Sourced, never executed. |
| `pre-commit` | Blocks credential shapes in the **staged index**. Fails closed. |
| `_chain.sh` | Runs whatever hook the repo had before. Every other hook name symlinks here. |
| `install-estate-hooks.sh` | Wire/unwire the estate. `--dry-run`, `--uninstall`, `--repo`. |
| `hooks-drill.sh` | 17 assertions on scratch repos. Run it before trusting a change. |

```sh
bash install-estate-hooks.sh --dry-run     # what would change
bash install-estate-hooks.sh               # wire it (idempotent)
bash install-estate-hooks.sh --uninstall   # put every repo back exactly as it was
bash hooks-drill.sh                        # prove it, offline
cd <repo> && ESTATE_HOOK_DRYRUN=1 ESTATE_HOOK_NAME=pre-push bash _chain.sh   # who chains here?
```

**Blocked?** Three legal answers, in order: scrub it **and rotate the credential** ·
name it with a written reason in `../gate-secret-sweep.allow` · `git commit --no-verify`
for that one commit. Deleting the hook is not one of them.

Full rationale: `~/Desktop/downloads/HANDOFF-GATE.md` § **G-AF** (added v2.46, 2026-08-08).
