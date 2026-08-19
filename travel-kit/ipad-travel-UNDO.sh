#!/usr/bin/env bash
# Reverses ipad-travel-setup.sh completely. Run: sudo bash ipad-travel-UNDO.sh
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo"; exit 1; }
launchctl bootout system /Library/LaunchDaemons/io.braatz.wg-home-gateway.plist 2>/dev/null || true
rm -f /Library/LaunchDaemons/io.braatz.wg-home-gateway.plist /usr/local/sbin/wg-home-gateway.sh
pfctl -a io.braatz.wg-nat -F nat 2>/dev/null || true
rm -f /etc/pf.anchors/io.braatz.wg-nat
sysctl -w net.inet.ip.forwarding=0 >/dev/null
launchctl unload -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
echo "reverted: forwarding off, NAT anchor flushed, daemon removed, Screen Sharing off."
echo "(the WireGuard peer on n8n is untouched — remove it there if you also want that gone)"
