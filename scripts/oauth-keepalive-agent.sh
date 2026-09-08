#!/usr/bin/env bash
# oauth-keepalive-agent.sh -- install / remove / inspect the 30-minute OAuth keepalive on THIS box.
#   --install    launchd (darwin: launchagents/com.braatz.oauth-keepalive.plist) or
#                systemd --user (linux: systemd/oauth-keepalive.{service,timer}); idempotent.
#   --uninstall  disarm it (units stay in the repo).
#   --status     is it armed, and what the keepalive log last said.
# Mirrors pitching-machine/scripts/fuel-probe-agent.sh on purpose: same shape, same verbs, so
# ADD-A-BOX can say "run both --install" and be done. (smDrainDesk-14, 2026-09-08)
set -u
DMO="$HOME/code/darwin-mac-ops"
ST="$HOME/.local/state/pitching-machine"
mode="${1:---status}"
os="$(uname -s)"
mkdir -p "$ST"
case "$os" in
  Darwin)
    LA="$HOME/Library/LaunchAgents/com.braatz.oauth-keepalive.plist"
    case "$mode" in
      --install)
        cp "$DMO/launchagents/com.braatz.oauth-keepalive.plist" "$LA"
        launchctl bootout "gui/$(id -u)/com.braatz.oauth-keepalive" 2>/dev/null
        launchctl bootstrap "gui/$(id -u)" "$LA" && echo "oauth-keepalive: ARMED (launchd, 1800s)" ;;
      --uninstall)
        launchctl bootout "gui/$(id -u)/com.braatz.oauth-keepalive" 2>/dev/null; rm -f "$LA"; echo "oauth-keepalive: disarmed" ;;
      --status)
        if launchctl list com.braatz.oauth-keepalive >/dev/null 2>&1; then echo "oauth-keepalive: armed (launchd)"; else echo "oauth-keepalive: NOT ARMED"; fi
        tail -1 "$ST/oauth-keepalive.log" 2>/dev/null || true ;;
      *) echo "usage: $0 --install|--uninstall|--status" >&2; exit 2 ;;
    esac ;;
  Linux)
    U="$HOME/.config/systemd/user"
    case "$mode" in
      --install)
        mkdir -p "$U"
        cp "$DMO/systemd/oauth-keepalive.service" "$DMO/systemd/oauth-keepalive.timer" "$U/"
        systemctl --user daemon-reload
        systemctl --user enable --now oauth-keepalive.timer && echo "oauth-keepalive: ARMED (systemd --user, 30min)"
        if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null)" != "yes" ]; then
          echo "  ⚠ Linger=no: this timer dies at logout. Fix: loginctl enable-linger $USER"
        fi ;;
      --uninstall)
        systemctl --user disable --now oauth-keepalive.timer 2>/dev/null; rm -f "$U/oauth-keepalive.service" "$U/oauth-keepalive.timer"
        systemctl --user daemon-reload; echo "oauth-keepalive: disarmed" ;;
      --status)
        if systemctl --user is-active oauth-keepalive.timer >/dev/null 2>&1; then
          echo "oauth-keepalive: armed (systemd --user)"; systemctl --user list-timers oauth-keepalive.timer --no-pager 2>/dev/null | sed -n 2p
        else echo "oauth-keepalive: NOT ARMED"; fi
        tail -1 "$ST/oauth-keepalive.log" 2>/dev/null || true ;;
      *) echo "usage: $0 --install|--uninstall|--status" >&2; exit 2 ;;
    esac ;;
  *) echo "oauth-keepalive-agent: unsupported OS $os" >&2; exit 2 ;;
esac
