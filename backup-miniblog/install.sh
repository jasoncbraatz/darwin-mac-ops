#!/bin/bash
# install.sh — set up the miniblog backup pipeline on a fresh Mac.
#
# Idempotent. Re-running is safe; existing files get overwritten and the
# LaunchAgent is re-bootstrapped.
#
# Does NOT grant Full Disk Access — that's a one-time UI step you do
# in System Settings AFTER this finishes. The script prints what to do.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HOME/Scripts"
APPS="$HOME/Applications"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs"

APP_NAME="MiniblogBackup.app"
APP_PATH="$APPS/$APP_NAME"
SCRIPT_NAME="miniblog-backup-pull.sh"
SCRIPT_PATH="$SCRIPTS/$SCRIPT_NAME"
PLIST_LABEL="com.braatz.miniblog-backup-pull"
PLIST_PATH="$LAUNCH_AGENTS/$PLIST_LABEL.plist"
SSH_KEY="$HOME/.ssh/id_ed25519_n8n_backup"

mkdir -p "$SCRIPTS" "$APPS" "$LAUNCH_AGENTS" "$LOGS"

echo "==> Installing pull script"
cp "$HERE/scripts/$SCRIPT_NAME" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

echo "==> Building $APP_NAME (AppleScript wrapper)"
rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" -e "do shell script \"$SCRIPT_PATH\""

echo "==> Setting bundle identifier + LSUIElement"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.braatz.miniblog-backup" \
  "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.braatz.miniblog-backup" \
  "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSUIElement true" \
  "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" \
  "$APP_PATH/Contents/Info.plist"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_PATH"

echo "==> Registering with LaunchServices"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -f "$APP_PATH"

echo "==> Installing LaunchAgent plist"
cp "$HERE/launchagents/$PLIST_LABEL.plist" "$PLIST_PATH"
plutil -lint "$PLIST_PATH"

if [[ ! -f "$SSH_KEY" ]]; then
  echo "==> Generating dedicated SSH key for n8n backups"
  ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "darwin-backup-pull-$(date +%F)"
  echo
  echo "============================================================"
  echo "ADD THIS PUBLIC KEY TO n8n's claudeApp authorized_keys:"
  echo
  cat "${SSH_KEY}.pub"
  echo
  echo "Suggested authorized_keys line (restrict + pty so rsync still works):"
  echo "  restrict,pty $(cat ${SSH_KEY}.pub)"
  echo "============================================================"
fi

cat <<NEXT

==> Install complete.

NEXT STEPS:

1. Grant Full Disk Access to $APP_PATH:
   System Settings → Privacy & Security → Full Disk Access → +
   Navigate to $APP_PATH, Open. Authenticate when prompted.

2. From Terminal.app (not SSH):
   launchctl bootstrap gui/\$(id -u) $PLIST_PATH
   launchctl kickstart -k gui/\$(id -u)/$PLIST_LABEL
   sleep 5
   tail $LOGS/miniblog-backup-pull.log

   Expect: "pull complete, rsync exit=0".

NEXT
