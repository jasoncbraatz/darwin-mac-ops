# photo-sync — family photos/videos → Dropbox (one-way cold backup)

Hourly (+ weekly full-sweep) one-way backup of the family photo/video corpus from
voyager (the NAS SSOT) to Dropbox. Reads the NAS via rclone's own SMB client
(`my_nas:` remote) — **no `/Volumes` mount needed** (that path caused a beachball; see below).

## Where things live

| Thing | Path |
|---|---|
| Sync script | `~/bin/sync-photos-to-dropbox.sh` |
| Notify helper | `~/bin/photo-sync-notify.py` |
| Hourly LaunchAgent | `~/Library/LaunchAgents/com.braatz.photo-sync-dropbox.plist` |
| Weekly full-sweep LaunchAgent | `~/Library/LaunchAgents/com.braatz.photo-sync-dropbox-fullsweep.plist` |
| Log | `~/Library/Logs/photo-sync-dropbox.log` |
| State | `~/.local/state/photo-sync/{last_nas_ok,outage_alerted,error_alerted,home_alerted}` |
| Source (NAS) | `my_nas:Jason2/DROPBOX/Photos and Videos/personal photos/<YEAR>` |
| Dest (Dropbox) | `dropbox:Photos and Videos/personal photos/<YEAR>` |
| Asana token (reused) | `~/.config/scan-pipeline/asana.token` |

**⚠️ Deploy note:** the files in `scripts/` and `launchagents/` here are the SSOT
copy. The LIVE copies run from `~/bin` and `~/Library/LaunchAgents` (real files, not
symlinks) — so after editing here, redeploy with `install.sh` (TODO) or a manual `cp`.
Until a symlink-deploy exists, treat `~/bin` as a deploy target and keep it in sync.

## Kick a run manually
```bash
bash ~/bin/sync-photos-to-dropbox.sh                 # everyday (current+prev year)
PHOTO_SYNC_FULL=1 bash ~/bin/sync-photos-to-dropbox.sh   # full sweep (all years)
launchctl kickstart -k gui/$(id -u)/com.braatz.photo-sync-dropbox
```

## Watch
```bash
tail -f ~/Library/Logs/photo-sync-dropbox.log
```

## Design notes / hard-won history

- **Addressing (2026-07-10):** voyager is reached by **`voyager.local` (mDNS)**, NOT a
  hardcoded IP. Its DHCP address drifted `.112 → .200` and the old hardcoded `.112`
  silently killed this backup for 5 days (the script read "unreachable" as "traveling").
  The `my_nas` rclone remote also uses `voyager.local`. **Real fix pending:** a DHCP
  reservation / static IP for voyager (deferred to Jason's network redo). mDNS will NOT
  resolve while the NAS is fully asleep, so a reservation is still the durable answer.
- **Home-aware alerting (2026-07-10):** Jason is home ~51 wks/yr, so "NAS unreachable
  WHILE darwin is on the home LAN (`192.168.86.x`)" is treated as a real failure and
  alerts Batter's Box in ~2h, instead of assuming a 14-day trip. Update `HOME_NET_PREFIX`
  in the script after the network redo. The 14-day outage path remains as the away/travel fallback.
- **`copy` never `sync`** + `--size-only` + `--min-age 15m`: additive, self-healing,
  never deletes from Dropbox; one-way (NAS read-only).
- **Beachball caution:** do heavy NAS transfers via rclone's `my_nas:` SMB client, never
  by writing through the `/Volumes/Jason2` kernel mount (that dirties file-backed memory
  faster than the NAS ingests → I/O-bus stall / total UI freeze). If you must, throttle:
  `taskpolicy -b nice -n 10 rclone ... --transfers 2 --bwlimit 20M --use-mmap` (no `--fast-list`).
