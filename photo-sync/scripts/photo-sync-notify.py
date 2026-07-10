#!/usr/bin/env python3
"""
photo-sync-notify.py  —  post a task into the Asana "Batter's Box".

Three notification kinds, used by sync-photos-to-dropbox.sh:

  ok       A batch of new files was backed up. Friendly thumbs-up + summary.
           Variable-length per-folder summary is read from STDIN.
               photo-sync-notify.py ok <count>        (summary on stdin)

  error    Something broke that ISN'T just travel/network (e.g. token rot,
           an rclone failure, a path problem). Posts a copy-paste-ready prompt
           for a future Claude session so Jason can hand off debugging with zero
           thinking. Error detail is read from STDIN.
               photo-sync-notify.py error             (error detail on stdin)

  outage   The NAS has been unreachable for 14+ days. Jason never travels
           longer than two weeks, so this is almost certainly a local CIFS/SMB
           problem, not absence. Also posts a copy-paste Claude prompt.
               photo-sync-notify.py outage <days> <last_ok_date>

Dependency-free (urllib only). Reuses the scan-pipeline Asana token.
"""
import sys, json, urllib.request, pathlib

TOKEN_FILE = pathlib.Path.home() / ".config" / "scan-pipeline" / "asana.token"
PROJECT = "1213050213165325"   # Batter's Box
SECTION = "1213050213165326"   # top "Untitled section" (the inbox)
ASANA = "https://app.asana.com/api/1.0/tasks"

# Shared orientation block pasted into every "go ask Claude" prompt so a cold
# future session knows exactly where everything lives.
WHERE_IT_LIVES = """Here's where everything lives (you have an SSH MCP profile named "darwin" \
for this Mac — user jasoncbraatz on localhost):
  - Sync script:   ~/bin/sync-photos-to-dropbox.sh   (bash)
  - Notifier:      ~/bin/photo-sync-notify.py
  - LaunchAgent:   ~/Library/LaunchAgents/com.braatz.photo-sync-dropbox.plist  (runs hourly)
  - Log:           ~/Library/Logs/photo-sync-dropbox.log
  - State files:   ~/.local/state/photo-sync/  (last_nas_ok, outage_alerted, error_alerted)
  - rclone config: ~/.config/rclone/rclone.conf
  - rclone remotes: my_nas: (SMB to NAS "voyager" via voyager.local, share Jason2) and dropbox:
  - What it does: ONE-WAY, --ignore-existing backup of
        my_nas:Jason2/DROPBOX/Photos and Videos/personal photos/<year>
     -> dropbox:Photos and Videos/personal photos/<year>
     scoped to the current + previous year. The NAS is the read-only SSOT —
     NEVER modify the NAS side; we only ever write to Dropbox, never overwrite."""


def claude_error_prompt(detail: str) -> str:
    return (
        "Hi Claude! My hourly NAS→Dropbox family-photo backup threw an error and "
        "didn't fully complete. This isn't a travel/network thing — it's something "
        "else (token expiry, an rclone change, a path issue, etc.).\n\n"
        + WHERE_IT_LIVES
        + "\n\nThe tail of the error was:\n"
        "----------------------------------------\n"
        + (detail.strip() or "(no detail captured — check the log)")
        + "\n----------------------------------------\n\n"
        "Could you SSH to \"darwin\", read the log, work out what broke, and fix it? "
        "Then do a dry-run to confirm it's healthy again. Thanks!"
    )


def claude_outage_prompt(days: str, last_ok: str) -> str:
    return (
        f"Hi Claude! My NAS→Dropbox photo backup hasn't been able to reach the NAS "
        f"(voyager / voyager.local) for {days}+ days (last seen {last_ok}). I don't "
        "travel longer than two weeks, so this is probably a LOCAL CIFS/SMB problem "
        "rather than me being away.\n\n"
        + WHERE_IT_LIVES
        + "\n\nCould you SSH to \"darwin\" and investigate the NAS connection? Things to try: "
        "`ping 192.168.86.112`, `/opt/homebrew/bin/rclone lsd my_nas:`, check whether the "
        "\"Jason2\" SMB share still mounts, and confirm the my_nas: credentials in "
        "rclone.conf are still good. Figure out what's wrong and fix it (the NAS is the "
        "read-only SSOT — don't change anything on it). Thanks!"
    )


def post(title: str, notes: str) -> int:
    try:
        token = TOKEN_FILE.read_text().strip()
    except Exception as e:
        print(f"cannot read Asana token: {e}", file=sys.stderr)
        return 2
    payload = {"data": {
        "name": title[:120],
        "notes": notes,
        "projects": [PROJECT],
        "memberships": [{"project": PROJECT, "section": SECTION}],
    }}
    req = urllib.request.Request(
        ASANA, data=json.dumps(payload).encode("utf-8"), method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            print("asana task created:", json.load(r)["data"]["gid"])
            return 0
    except Exception as e:
        print(f"asana post failed: {e}", file=sys.stderr)
        return 1


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: photo-sync-notify.py <ok|error|outage> ...", file=sys.stderr)
        return 2
    kind = sys.argv[1]

    if kind == "ok":
        count = sys.argv[2] if len(sys.argv) > 2 else "?"
        summary = sys.stdin.read()
        title = f"\U0001F44D Photos backed up to Dropbox: {count} new file(s)"
        notes = (
            "Fresh family photos/videos were copied from the NAS up to Dropbox "
            "(cold-storage backup). Nothing existing was overwritten.\n\n"
            + summary
        )
        return post(title, notes)

    if kind == "error":
        detail = sys.stdin.read()
        title = "⚠️ Photo→Dropbox backup needs a look (copy into Claude)"
        return post(title, claude_error_prompt(detail))

    if kind == "outage":
        days = sys.argv[2] if len(sys.argv) > 2 else "14"
        last_ok = sys.argv[3] if len(sys.argv) > 3 else "unknown"
        title = f"⚠️ NAS unreachable {days}+ days — likely SMB issue (copy into Claude)"
        return post(title, claude_outage_prompt(days, last_ok))

    print(f"unknown kind: {kind}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
