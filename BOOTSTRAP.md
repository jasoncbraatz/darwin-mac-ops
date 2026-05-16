# BOOTSTRAP — rebuild on a fresh Mac

Start-to-finish recipe for getting both pipelines running on a clean macOS install. Target: under 60 minutes, including coffee.

Estimated phase times:
1. Prereqs — 10 min
2. Clone + Python deps — 5 min
3. Backup pipeline — 10 min (incl. FDA grant)
4. Scan-to-asana pipeline — 15 min (incl. FDA grant)
5. Verify both — 10 min

---

## 0. Prereqs (do these first)

1. **macOS 26 (Tahoe) or newer.** Older macOS doesn't need the AppleScript wrapper — it'll work with simpler tooling. These instructions target the strict TCC behavior on Tahoe.
2. **Xcode Command Line Tools:**
   ```bash
   xcode-select --install
   ```
3. **WireGuard client** installed and configured (so `10.10.10.1` reaches the Linode).
4. **NAS mounted at `/Volumes/Jason2`** via Finder → Go → Connect to Server → `smb://voyager.local/Jason2`. Tick "Connect on Login" so it remounts after reboots.
5. **SSH key on GitHub** for this account (use the existing `~/.ssh/id_ed25519`).
6. **System Python 3.9+** (`/usr/bin/python3`) — comes with the Command Line Tools.

## 1. Clone the repo

```bash
mkdir -p ~/Code && cd ~/Code
git clone git@github.com:jasoncbraatz/darwin-mac-ops.git
cd darwin-mac-ops
```

## 2. Install Python deps to the user site

```bash
/usr/bin/python3 -m pip install --user -r scan-to-asana/requirements.txt
```

This puts `PyMuPDF`, `ocrmac`, and `requests` into `~/Library/Python/3.9/`. No Homebrew needed; Apple's Vision framework handles all the OCR work.

## 3. Put the secrets in place

```bash
mkdir -p ~/.config/scan-pipeline
chmod 700 ~/.config/scan-pipeline

# Asana Personal Access Token (one line, no quotes, no trailing junk)
cat > ~/.config/scan-pipeline/asana.token   # paste, then Ctrl-D
chmod 600 ~/.config/scan-pipeline/asana.token

# Anthropic API key
cat > ~/.config/scan-pipeline/anthropic.key  # paste, then Ctrl-D
chmod 600 ~/.config/scan-pipeline/anthropic.key
```

**Verify** before continuing:
```bash
KEY=$(cat ~/.config/scan-pipeline/anthropic.key)
curl -s https://api.anthropic.com/v1/messages \
  -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" -H "content-type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","max_tokens":20,"messages":[{"role":"user","content":"PONG"}]}' \
  | python3 -c 'import sys,json; r=json.load(sys.stdin); print("✓" if r.get("content") else r)'
unset KEY
```

If the key was pasted with quotes or surrounding text, you'll get HTTP 401. Re-do step 3 cleanly.

## 4. Build the backup pipeline

```bash
cd backup-miniblog
./install.sh
```

`install.sh`:
- Copies `scripts/miniblog-backup-pull.sh` → `~/Scripts/`
- Builds `~/Applications/MiniblogBackup.app` (AppleScript wrapper)
- Ad-hoc-signs the `.app`
- Generates an SSH key pair at `~/.ssh/id_ed25519_n8n_backup` if missing, prints the pubkey for you to install on the Linode (one-time)
- Installs `~/Library/LaunchAgents/com.braatz.miniblog-backup-pull.plist`

**Grant Full Disk Access:**
1. Open `System Settings → Privacy & Security → Full Disk Access`
2. Click `+`, navigate to `~/Applications/MiniblogBackup.app`, Open
3. Touch ID to confirm

**Bootstrap the agent (from Terminal, not SSH):**
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.braatz.miniblog-backup-pull.plist
launchctl kickstart -k gui/$(id -u)/com.braatz.miniblog-backup-pull
sleep 5
tail ~/Library/Logs/miniblog-backup-pull.log
```

Expect: `pull complete, rsync exit=0`.

## 5. Build the scan-to-asana pipeline

```bash
cd ../scan-to-asana
./install.sh
```

`install.sh`:
- Copies `scripts/scan_to_asana.py` → `~/Scripts/`
- Builds `~/Applications/ScanToAsana.app` (AppleScript wrapper)
- Ad-hoc-signs the `.app`
- Installs `~/Library/LaunchAgents/com.braatz.scan-to-asana.plist`
- Seeds `~/.local/state/scan-pipeline/state.json` with today's midnight (skips historical backfill)

**Grant Full Disk Access** (same dance as step 4):
1. System Settings → Privacy & Security → Full Disk Access
2. `+`, navigate to `~/Applications/ScanToAsana.app`, Open, Touch ID

**Bootstrap + test:**
```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.braatz.scan-to-asana.plist
launchctl kickstart -k gui/$(id -u)/com.braatz.scan-to-asana
sleep 30
tail -30 ~/Library/Logs/scan-to-asana.log
```

Drop a test PDF into `/Volumes/Jason2/SCANS/`, kickstart again, and watch a task land in Asana with the PDF attached.

## 6. Verification checklist

- [ ] `launchctl print gui/$(id -u)/com.braatz.miniblog-backup-pull` shows the agent registered, next-fire time visible
- [ ] `launchctl print gui/$(id -u)/com.braatz.scan-to-asana` same
- [ ] `~/Library/Logs/miniblog-backup-pull.log` has `pull complete`
- [ ] `~/Library/Logs/scan-to-asana.log` has `no new scans` (after a clean kickstart with nothing new) or `processing ...` (if there's something today)
- [ ] `/Volumes/Jason2/BACKUPS/miniblog/$(date +%F)/miniblog.sql.gz` exists
- [ ] Asana shows the "Payments Calendar" project intact

## Troubleshooting

- **`launchctl bootstrap` returns "Input/output error":** old `launchctl load` syntax. Use `bootstrap gui/$(id -u) <plist>` instead.
- **Log shows `Operation not permitted` on `/Volumes/Jason2/...`:** the `.app` was bootstrapped from an SSH session, inheriting wrong TCC. Re-bootstrap from Terminal.app.
- **Log shows TCC error but Terminal can write to the volume:** the `.app` needs FDA. Add it in System Settings, then bootout + bootstrap.
- **OCR returns empty:** PyMuPDF didn't install correctly. Re-run `pip install --user PyMuPDF ocrmac`.
- **Anthropic returns 401:** the key file has trailing/leading junk. Inspect with `xxd ~/.config/scan-pipeline/anthropic.key` — should be 108 bytes plus optional newline.

For the longer narrative on why all this dancing exists, see [`shared/tcc-notes.md`](shared/tcc-notes.md).


## 7. GitHub PAT for future automation

A fine-grained Personal Access Token at `~/.config/github/pat` (0600 perms) lets future-Opus push to private repos and create new ones without SSH-agent complications. See [`OPS.md`](OPS.md#github-pat-for-future-opus-automation) for the format, the scopes required, and the rotation procedure.

If this file is missing on a fresh Mac, generate a new token at <https://github.com/settings/personal-access-tokens/new> with Contents R/W + Administration R/W on all repos, then stash it:

```bash
mkdir -p ~/.config/github && chmod 700 ~/.config/github
cat > ~/.config/github/pat   # paste, Enter, Ctrl-D
chmod 600 ~/.config/github/pat
```
