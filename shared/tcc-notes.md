# macOS 26 (Tahoe) TCC Notes

The bit that took the longest to figure out. Capturing it here so future-Jason (or future-Claude rebuilding on a new Mac) doesn't waste an afternoon on it.

## The problem

You want a LaunchAgent to write to `/Volumes/Jason2/...` (an SMB-mounted NAS). You grant Full Disk Access to "Terminal" — and Terminal can write fine. You schedule a shell script via LaunchAgent or cron — it gets `Operation not permitted`.

## Why

macOS TCC ("Transparency, Consent, and Control") gates network volumes per-process. The grant follows the process's *code identity*, not the user who's logged in. Three relevant facts on macOS 26:

1. **TCC identity is determined at process spawn time**, by the kernel's evaluation of the executable being run.
2. **Shell scripts get re-execed by their interpreter.** When the kernel reads `#!/bin/bash`, it re-execs as `/bin/bash <script>`. The running process is `/bin/bash`. `/bin/bash` is SIP-protected; you cannot grant it Full Disk Access. The grant on your `.app` bundle does NOT transfer to the bash subprocess.
3. **Code signature stability matters.** Even when you point a LaunchAgent at a real Mach-O inside a `.app` bundle, an *unsigned* bundle has an unstable identity. macOS 26's TCC can't reliably bind grants to it. The grant might appear in System Settings but won't actually take effect.

## The pattern that works

Build an AppleScript-based `.app` whose MacOS executable is a real Mach-O binary (the AppleScript runner), and have *that* binary call your shell script.

```bash
# 1. Build the .app
osacompile -o ~/Applications/Whatever.app -e 'do shell script "/path/to/your-script.sh"'

# 2. Give it a stable bundle identifier
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.yourname.whatever" \
  ~/Applications/Whatever.app/Contents/Info.plist
/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" \
  ~/Applications/Whatever.app/Contents/Info.plist

# 3. Ad-hoc sign it (gives a stable code identity)
codesign --force --deep --sign - ~/Applications/Whatever.app

# 4. Register with LaunchServices
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -f ~/Applications/Whatever.app

# 5. Grant Full Disk Access via System Settings UI
#    (must be done from a real GUI session; Touch ID required)

# 6. Point your LaunchAgent at the .app's executable
#    <key>ProgramArguments</key>
#    <array>
#      <string>~/Applications/Whatever.app/Contents/MacOS/applet</string>
#    </array>

# 7. Bootstrap the LaunchAgent from Terminal.app (NOT from SSH)
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.yourname.whatever.plist
launchctl kickstart -k gui/$(id -u)/com.yourname.whatever
```

## Why "from Terminal.app, not from SSH"

When `launchctl bootstrap` registers an agent, the agent inherits TCC context from the *launchd domain* at registration time. SSH sessions get a different launchd domain than your interactive GUI session. If you bootstrap over SSH, the agent gets the SSH session's TCC context — which doesn't have access to network volumes even if the user's Terminal does.

Bootstrap once from Terminal.app (or just reboot — at next login launchd re-evaluates and uses the GUI session context).

## Diagnostic shortcuts

- **What's the TCC complaint?**
  ```bash
  log show --predicate 'subsystem == "com.apple.TCC"' --last 5m | tail -30
  ```
- **Is the agent registered, and in which domain?**
  ```bash
  launchctl print gui/$(id -u)/<label> 2>&1 | head -20
  ```
- **What's the running binary's signature?**
  ```bash
  codesign -dv ~/Applications/Whatever.app 2>&1
  ```
- **Sanity check: can Terminal write to the volume right now?**
  ```bash
  touch /Volumes/Jason2/BACKUPS/.tcc-test && rm /Volumes/Jason2/BACKUPS/.tcc-test
  ```

## What does NOT work (lessons learned the hard way)

- A `.app` bundle whose MacOS executable is itself a shell script with `#!/bin/bash`. Re-execed to bash, loses identity.
- Granting FDA to `/bin/bash` or `/usr/bin/python3`. SIP-protected, the grant silently does nothing.
- Granting FDA to your script file directly. Vision UI lets you do it; the grant doesn't apply.
- Skipping `codesign --sign -`. Unsigned bundles have unstable identity; grants don't bind.
- Skipping `lsregister -f`. The Vision UI won't find your `.app` for `+` → file picker until LaunchServices knows about it.
