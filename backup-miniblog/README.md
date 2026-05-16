# backup-miniblog

Nightly pull of the [jason.braatz.ai](https://jason.braatz.ai) Postgres dumps from the Linode (where n8n + miniblog live) to the NAS.

## Flow

```
[cron on n8n 03:15 UTC]
  pg_dumpall miniblog + umami → /opt/backups/miniblog/YYYY-MM-DD/

[LaunchAgent on darwin 03:45 local]
  ScanToAsana.app's sibling MiniblogBackup.app fires
    → /Users/jasoncbraatz/Scripts/miniblog-backup-pull.sh
      → rsync over SSH (WireGuard) using ~/.ssh/id_ed25519_n8n_backup
        → /Volumes/Jason2/BACKUPS/miniblog/
```

Retention: 14 days on n8n, indefinite on NAS.

## Install on a fresh Mac

```bash
cd backup-miniblog
./install.sh
```

Then follow the printed FDA + bootstrap steps. See [`../BOOTSTRAP.md`](../BOOTSTRAP.md) for the full sequence.

## Files

- `scripts/miniblog-backup-pull.sh` — the actual rsync script
- `launchagents/com.braatz.miniblog-backup-pull.plist` — schedules daily at 03:45 local time
- `install.sh` — builds `MiniblogBackup.app`, signs it, installs the LaunchAgent, generates an SSH key if missing

## The .app bundle

Not checked in (it's a build artifact). `install.sh` builds it from scratch via `osacompile`. See [`../shared/tcc-notes.md`](../shared/tcc-notes.md) for why the `.app` wrapper is required on macOS 26.
