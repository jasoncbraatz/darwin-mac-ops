# OPS — day-to-day operations

## Where things live

| Thing | Path |
|---|---|
| Backup pull script | `~/Scripts/miniblog-backup-pull.sh` |
| Backup `.app` | `~/Applications/MiniblogBackup.app` |
| Backup LaunchAgent | `~/Library/LaunchAgents/com.braatz.miniblog-backup-pull.plist` |
| Backup log | `~/Library/Logs/miniblog-backup-pull.log` |
| Backup destination | `/Volumes/Jason2/BACKUPS/miniblog/YYYY-MM-DD/` |
| Scan pipeline script | `~/Scripts/scan_to_asana.py` |
| Scan `.app` | `~/Applications/ScanToAsana.app` |
| Scan LaunchAgent | `~/Library/LaunchAgents/com.braatz.scan-to-asana.plist` |
| Scan log | `~/Library/Logs/scan-to-asana.log` |
| Scan state | `~/.local/state/scan-pipeline/state.json` |
| Scan source | `/Volumes/Jason2/SCANS/*.pdf` |
| Scan archive | `/Volumes/Jason2/SCANS/processed/YYYY-MM/` |
| Secrets | `~/.config/scan-pipeline/{asana.token,anthropic.key}` |

## Kick a run manually

```bash
# Backup pull
launchctl kickstart -k gui/$(id -u)/com.braatz.miniblog-backup-pull

# Scan pipeline
launchctl kickstart -k gui/$(id -u)/com.braatz.scan-to-asana
```

## Watch logs

```bash
tail -f ~/Library/Logs/miniblog-backup-pull.log
tail -f ~/Library/Logs/scan-to-asana.log
```

## See agent state

```bash
launchctl print gui/$(id -u)/com.braatz.miniblog-backup-pull
launchctl print gui/$(id -u)/com.braatz.scan-to-asana
```

Look for `state = waiting` between runs, `state = running` while active.

## Reset the scan watermark

If you want the next run to re-process everything (rarely), or just today:

```bash
# Process everything (back to the beginning of time)
rm ~/.local/state/scan-pipeline/state.json

# Process from today midnight only
/usr/bin/python3 -c "
import json, os
from datetime import datetime
midnight = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
state = {'last_mtime': midnight.timestamp(),
         'last_run_iso': 'reset-' + datetime.now().isoformat(),
         'processed_count': 0}
path = os.path.expanduser('~/.local/state/scan-pipeline/state.json')
os.makedirs(os.path.dirname(path), exist_ok=True)
json.dump(state, open(path,'w'), indent=2)
print('reset to', midnight.isoformat())
"
```

## If a scan got processed wrong

The PDF was archived to `/Volumes/Jason2/SCANS/processed/YYYY-MM/`. To re-process:

```bash
# Move it back so it's newer than the watermark
mv /Volumes/Jason2/SCANS/processed/2026-05/THE_PDF.pdf /Volumes/Jason2/SCANS/
touch /Volumes/Jason2/SCANS/THE_PDF.pdf

# Also delete the bad Asana task in the UI
# Then kickstart
launchctl kickstart -k gui/$(id -u)/com.braatz.scan-to-asana
```

## Re-fetch the Asana token from n8n (if needed)

```bash
# On n8n:
sudo docker exec -e N8N_ENCRYPTION_KEY="6WestFrenchTemple!" n8n-n8n-1 \
  n8n export:credentials --all --decrypted --output=/tmp/creds.json
sudo docker cp n8n-n8n-1:/tmp/creds.json /tmp/creds.json
sudo python3 -c "
import json
d = json.load(open('/tmp/creds.json'))
for c in d:
    if c.get('type') == 'asanaApi':
        print(c['data']['accessToken'])
        break
"
sudo rm /tmp/creds.json
sudo docker exec n8n-n8n-1 rm /tmp/creds.json
```

Then on darwin, paste into `~/.config/scan-pipeline/asana.token` cleanly (see `secrets/README.md`).

## GitHub PAT (for future-Claude automation)

A fine-grained Personal Access Token lives at `~/.config/github/pat` (0600 perms). Future Claude can use it to:

- Push to private repos in this account (`Contents: Read and write`)
- Create new repos under jasoncbraatz (`Administration: Read and write`)
- Read repo metadata

**Usage example:**

```bash
TOKEN=$(cat ~/.config/github/pat)

# Push using HTTPS-auth (no SSH agent needed)
cd ~/Code/some-repo
git remote set-url origin "https://x-access-token:${TOKEN}@github.com/jasoncbraatz/some-repo.git"
git push origin main
git remote set-url origin "https://github.com/jasoncbraatz/some-repo.git"   # revert so PAT isn't in git config

# Create a new repo via API
curl -sS -X POST -H "Authorization: Bearer $TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/user/repos -d '{"name":"new-repo","private":true}'

unset TOKEN
```

**Token shape:** `github_pat_*`, ~93 bytes (fine-grained format).

**Rotation:** PATs expire (max 1 year). When you rotate at <https://github.com/settings/personal-access-tokens>, just overwrite the file:

```bash
cat > ~/.config/github/pat   # paste new token, Enter, Ctrl-D
chmod 600 ~/.config/github/pat
```

**Scopes the PAT needs:**
- Repository access: **All repositories** (or selected repos including any you want to push to / create)
- Repository permissions: **Contents (R/W)**, **Administration (R/W)**, Metadata (R, auto)

## Git hygiene (added 2026-06-15)
- **`gate-selfcheck.sh`** (this repo; symlinked to `~/Scripts/gate-selfcheck.sh`) sweeps all four clone roots — `~/repos`, `~/code`, `~/Desktop/downloads`, `~/Scripts` — for uncommitted/unpushed work (FAIL) and no-remote/no-tracking (WARN). `saturday-sanity-check` runs it weekly (check 8) so drift surfaces on tinker-day instead of rotting silently. It's the mechanical half of `~/Desktop/downloads/HANDOFF-GATE.md` (G-H#22 + G-I).
- **Gotcha — empty fetch refspec breaks `@{u}`:** a clone with no `remote.origin.fetch` (some de-opus-era clones, e.g. `domain-inventory-repo`) makes `git branch --set-upstream-to` fail with *"not stored as a remote-tracking branch"* even though `origin/main` resolves. Fix: `git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*' && git fetch && git branch --set-upstream-to=origin/main`.
- **Third-party tools:** we fork-and-own them (see claude-blackbook doctrine §12). Forked `google-ads-mcp-complete` from grantweston → jasoncbraatz on 2026-06-15; `origin`=our fork, `upstream`=grantweston (reference only).

## photo-sync (family photos → Dropbox cold backup)

| Thing | Path |
|---|---|
| Sync script | `~/bin/sync-photos-to-dropbox.sh` |
| Notify helper | `~/bin/photo-sync-notify.py` |
| Hourly LaunchAgent | `~/Library/LaunchAgents/com.braatz.photo-sync-dropbox.plist` |
| Weekly full-sweep | `~/Library/LaunchAgents/com.braatz.photo-sync-dropbox-fullsweep.plist` |
| Log | `~/Library/Logs/photo-sync-dropbox.log` |
| SSOT copy | `darwin-mac-ops/photo-sync/` |

Kick: `bash ~/bin/sync-photos-to-dropbox.sh` · Watch: `tail -f ~/Library/Logs/photo-sync-dropbox.log`
NAS addressed by `voyager.local` (mDNS), not a hardcoded IP — drift-proof. See `photo-sync/README.md`.
