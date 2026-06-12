# HANDOFF — paste this at the start of a session when you want to change something

> **Jason — copy everything below this line, paste it as your first message in a new chat, then say what you want to change.**

---

I'm working on `darwin-mac-ops`, a private repo of personal Mac automation. Two LaunchAgent-driven pipelines:

- **backup-miniblog** — nightly Postgres dump pull from a Linode (n8n + miniblog stack) to a NAS over WireGuard
- **scan-to-asana** — every 10 minutes, picks up new PDFs from `/Volumes/Jason2/SCANS/`, OCRs them locally with Apple Vision (free, no tokens), classifies with Claude Haiku, creates a task in the Asana "Payments Calendar" project with the PDF attached, archives to `processed/YYYY-MM/`

**SSH access:** the SSH MCP has a server named `darwin` (my MacBook over WireGuard, full tier) and `n8n` (the Linode, full tier, passwordless sudo as `claudeApp`). Use those rather than computer-use for almost everything — it's faster.

**Read first before touching anything:**

1. `~/Code/darwin-mac-ops/ARCHITECTURE.md` (doesn't exist yet — the repo's top-level `README.md` is the index)
2. `~/Code/darwin-mac-ops/OPS.md` — where everything lives on disk, how to kick a run, how to watch logs
3. `~/Code/darwin-mac-ops/shared/tcc-notes.md` — **this is critical**. macOS 26 (Tahoe) has strict TCC. The pipelines only work because they're wrapped in AppleScript `.app` bundles with ad-hoc code signatures and Full Disk Access. If you change anything about how an agent is invoked, re-read this doc.
4. The pipeline-specific READMEs in `backup-miniblog/` and `scan-to-asana/`

**Key paths (mirrors what's in OPS.md but here for convenience):**

| Thing | Where |
|---|---|
| Repo on darwin | `~/Code/darwin-mac-ops/` |
| Scan pipeline script | `~/Scripts/scan_to_asana.py` |
| Backup pipeline script | `~/Scripts/miniblog-backup-pull.sh` |
| AppleScript wrappers | `~/Applications/{ScanToAsana,MiniblogBackup}.app` |
| LaunchAgent plists | `~/Library/LaunchAgents/com.braatz.{scan-to-asana,miniblog-backup-pull}.plist` |
| Logs | `~/Library/Logs/{scan-to-asana,miniblog-backup-pull}.log` |
| Scan state watermark | `~/.local/state/scan-pipeline/state.json` |
| Secrets (file-based, 0600) | `~/.config/scan-pipeline/{asana.token,anthropic.key}` |
| GitHub PAT (fine-grained) | `~/.config/github/pat` |
| NAS source for scans | `/Volumes/Jason2/SCANS/` |
| NAS destination for backups | `/Volumes/Jason2/BACKUPS/miniblog/` |
| Asana project ("Payments Calendar") | `1210461981452229`, section `1210461981452230` ("Untitled section") |

**Critical gotchas, in priority order:**

1. **Never invoke a Python or shell script directly from a LaunchAgent's `ProgramArguments` if it needs to write to a network volume.** `#!/bin/bash` gets re-execed and TCC checks the SIP-protected interpreter, not the `.app`. Always go through the AppleScript `.app` wrapper.
2. **After changing or rebuilding a `.app`, you must re-do FDA in System Settings.** Old grant binds to the previous code signature; signed bundles get a new identity. Bootout the agent, edit the FDA entry, re-bootstrap.
3. **Bootstrap LaunchAgents from Terminal.app, not from SSH.** SSH-launched `launchctl bootstrap` inherits SSH's TCC context, which doesn't include network volumes. The repo's `install.sh` scripts print the bootstrap commands at the end and explicitly say to run them from Terminal.
4. **The scan pipeline's state watermark won't reprocess old PDFs.** If you want to re-process something, see "If a scan got processed wrong" in OPS.md.
5. **n8n cleanup was completed on 2026-05-16.** Don't try to "fix" n8n workflows for the scan pipeline — they were retired intentionally. The scan pipeline runs entirely on darwin now. n8n still hosts the miniblog Postgres + backup-source for the *backup* pipeline.

**For pushing changes to GitHub:**

```bash
TOKEN=$(cat ~/.config/github/pat)
cd ~/Code/darwin-mac-ops
git remote set-url origin "https://x-access-token:${TOKEN}@github.com/jasoncbraatz/darwin-mac-ops.git"
git push
git remote set-url origin "https://github.com/jasoncbraatz/darwin-mac-ops.git"
unset TOKEN
```

(The SSH agent on darwin isn't reachable from the SSH MCP session, so HTTPS-with-PAT is the working path.)

**Common changes and which files to touch:**

| Change | Files |
|---|---|
| New NAS mount path | `scan_to_asana.py` → `SCANS_DIR` and `ARCHIVE_DIR` constants; `miniblog-backup-pull.sh` → `DST` |
| Different SMB host | `/etc/auto_master` or Finder "Connect to Server" + tick "Connect on Login". No code changes — just remount at the same path. |
| New Asana project / section / custom fields | `scan_to_asana.py` → `ASANA_*` constants at top. Verify against current schema with `mcp__asana__get_project`. |
| Different cadence | `~/Library/LaunchAgents/com.braatz.scan-to-asana.plist` → `StartInterval` (seconds). Then `launchctl bootout` + `launchctl bootstrap`. |
| Different Haiku prompt or model | `scan_to_asana.py` → `CLASSIFY_PROMPT`, `ANTHROPIC_MODEL` |
| Add a new pipeline | Mirror the pattern: script in `~/Scripts/`, AppleScript `.app` in `~/Applications/`, LaunchAgent in `~/Library/LaunchAgents/`, `install.sh` and README in a new subdir of the repo. Follow `tcc-notes.md`. |

**Sanity test pattern:**

1. Make the change
2. Reinstall: `cd ~/Code/darwin-mac-ops/<pipeline> && ./install.sh`
3. (If the `.app` was rebuilt) remove from System Settings → FDA, add the new one, Touch ID
4. From Terminal: `launchctl bootout gui/$(id -u)/<label>; launchctl bootstrap gui/$(id -u) <plist>; launchctl kickstart -k gui/$(id -u)/<label>`
5. `tail -f ~/Library/Logs/<pipeline>.log`
6. Verify on the destination (Asana task / NAS file)

**Before you finish, check:**

- [ ] All `.app` builds and signings happened cleanly (`codesign --verify --verbose ~/Applications/<X>.app`)
- [ ] LaunchAgent plists pass `plutil -lint`
- [ ] Log shows successful run
- [ ] Destination (Asana / NAS) has the expected artifact
- [ ] `state.json` watermark advanced (for scan pipeline)
- [ ] Commit + push to `github.com/jasoncbraatz/darwin-mac-ops`
- [ ] Update CHANGELOG section in `OPS.md` if the change is structural

**Have fun. Don't replace anything load-bearing without reading `shared/tcc-notes.md` first. — past-Claude**
