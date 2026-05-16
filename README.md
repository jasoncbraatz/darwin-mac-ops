# darwin-mac-ops

Personal Mac automation — two LaunchAgent-driven pipelines that pull data from a NAS over WireGuard and write the world. Private repo, single-user.

## What's in here

| Pipeline | What it does | Cadence |
|---|---|---|
| [`backup-miniblog/`](backup-miniblog/) | Pulls nightly Postgres dumps of `jason.braatz.ai` from the Linode to `/Volumes/Jason2/BACKUPS/miniblog/` on the NAS | 03:45 local daily |
| [`scan-to-asana/`](scan-to-asana/) | Watches `/Volumes/Jason2/SCANS` for new PDFs, OCRs them locally with Apple Vision, classifies with Claude Haiku, creates a task in the Asana "Payments Calendar" project with the PDF attached | Every 10 min |

Both pipelines share the same macOS-26-friendly trick: an **AppleScript `.app`** wraps a shell or Python invocation, gets ad-hoc code-signed, gets **Full Disk Access** granted to its bundle identity, and is then driven by a **LaunchAgent**. Without this dance, scheduled work running over SSH or via raw launchd can't reach SMB-mounted network volumes.

## Why this repo exists

> macOS hardware fails, often the day after warranty expires. When that happens, this repo is the runbook to get back to a working state from a fresh Mac in roughly an hour. See [`BOOTSTRAP.md`](BOOTSTRAP.md).

Everything required to rebuild lives here EXCEPT the secrets — those land in `~/.config/scan-pipeline/` with 0600 perms and are listed in [`secrets/README.md`](secrets/README.md). The repo has placeholder files but never the real keys.

## Quick links

- **When you want to change something:** [`HANDOFF.md`](HANDOFF.md) — paste it into a fresh session as your first message
- **Fresh Mac install:** [`BOOTSTRAP.md`](BOOTSTRAP.md)
- **Daily ops (where logs live, how to kick a run, etc.):** [`OPS.md`](OPS.md)
- **The macOS 26 TCC dance, with footnotes:** [`shared/tcc-notes.md`](shared/tcc-notes.md)
- **Grant FDA recipe (UI screenshots-of-words):** [`shared/grant-fda.md`](shared/grant-fda.md)

## Related repos

These three private repos make up Jason's personal infrastructure constellation:

| Repo | What it covers |
|---|---|
| [**darwin-mac-ops**](https://github.com/jasoncbraatz/darwin-mac-ops) (here) | LaunchAgent-driven automation on Jason's Mac (NAS backups, scan-to-asana pipeline) |
| [**braatz-mail-server**](https://github.com/jasoncbraatz/braatz-mail-server) | Self-hosted Stalwart mail server on flowers Linode |
| [**miniblog**](https://github.com/jasoncbraatz/miniblog) | jason.braatz.ai personal site (Next.js + Postgres on n8n Linode) |

Each repo has its own `HANDOFF.md` you can paste into a fresh Opus session to pick up cold.
