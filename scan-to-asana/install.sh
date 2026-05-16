#!/bin/bash
# install.sh — set up the scan-to-asana pipeline on a fresh Mac.
#
# Idempotent. Will not clobber your state.json watermark if one exists.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HOME/Scripts"
APPS="$HOME/Applications"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
LOGS="$HOME/Library/Logs"
STATE_DIR="$HOME/.local/state/scan-pipeline"
CONFIG_DIR="$HOME/.config/scan-pipeline"

APP_NAME="ScanToAsana.app"
APP_PATH="$APPS/$APP_NAME"
SCRIPT_NAME="scan_to_asana.py"
SCRIPT_PATH="$SCRIPTS/$SCRIPT_NAME"
PLIST_LABEL="com.braatz.scan-to-asana"
PLIST_PATH="$LAUNCH_AGENTS/$PLIST_LABEL.plist"

mkdir -p "$SCRIPTS" "$APPS" "$LAUNCH_AGENTS" "$LOGS" "$STATE_DIR" "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR" "$STATE_DIR"

echo "==> Verifying secrets in $CONFIG_DIR"
for f in asana.token anthropic.key; do
  if [[ ! -s "$CONFIG_DIR/$f" ]]; then
    echo "  ✗ $CONFIG_DIR/$f is missing or empty"
    echo "    Populate it before running this installer. See secrets/README.md."
    exit 2
  fi
  chmod 600 "$CONFIG_DIR/$f"
done

echo "==> Verifying Python dependencies"
/usr/bin/python3 -c "import fitz, ocrmac, requests" 2>&1 || {
  echo "  ✗ Missing Python deps. Run:"
  echo "    /usr/bin/python3 -m pip install --user -r $HERE/requirements.txt"
  exit 2
}

echo "==> Installing pipeline script"
cp "$HERE/scripts/$SCRIPT_NAME" "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

echo "==> Building $APP_NAME (AppleScript wrapper)"
rm -rf "$APP_PATH"
osacompile -o "$APP_PATH" -e "do shell script \"/usr/bin/python3 $SCRIPT_PATH 2>&1\""

echo "==> Setting bundle identifier + LSUIElement"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.braatz.scan-to-asana" \
  "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.braatz.scan-to-asana" \
  "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName 'Scan To Asana'" \
  "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string 'Scan To Asana'" \
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

echo "==> Seeding state.json (today midnight watermark) if missing"
if [[ ! -f "$STATE_DIR/state.json" ]]; then
  /usr/bin/python3 - <<'PY'
import json, os
from datetime import datetime
midnight = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
state = {
    "last_mtime": midnight.timestamp(),
    "last_run_iso": "seeded-" + datetime.now().isoformat(),
    "processed_count": 0,
}
path = os.path.expanduser("~/.local/state/scan-pipeline/state.json")
with open(path, "w") as f:
    json.dump(state, f, indent=2)
print(f"  ✓ seeded watermark to {midnight.isoformat()}")
PY
else
  echo "  ✓ state.json already exists, leaving it alone"
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
   sleep 30
   tail -30 $LOGS/scan-to-asana.log

   Expect: "no new scans; nothing to do" if SCANS is empty, or
   "processing X.pdf" through to "asana task created".

NEXT
