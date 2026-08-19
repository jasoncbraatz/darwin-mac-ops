#!/usr/bin/env bash
# ipad-travel-setup.sh — darwin becomes the home-LAN gateway + remote-desktop host.
# Written 2026-08-19 (session ipadTravel-1) so Jason can reach darwin and the NAS from an iPad.
#
# RUN:   sudo bash ~/Desktop/downloads/ipad-travel-setup.sh
# UNDO:  sudo bash ~/Desktop/downloads/ipad-travel-UNDO.sh
#
# WHAT AND WHY
#   n8n (10.10.10.1) now routes 192.168.86.0/24 to darwin's WireGuard peer. For that route to
#   actually carry packets darwin must (a) forward IP and (b) NAT them onto the home LAN — the
#   NAS's gateway is the home router, which has never heard of 10.10.10.0/24, so without NAT the
#   replies would vanish. Both settings are volatile on macOS, hence the LaunchDaemon.
#
# INTERFACE DETECTION: deliberately dynamic. darwin's LAN is on en8 *today*, but macOS renumbers
# enN when dongles move, and this box reboots for every OS update. Hard-coding en8 would fail
# silently and look like a WireGuard problem. We resolve it at boot from the default route.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo"; exit 1; }

WG_NET="10.10.10.0/24"
HELPER="/usr/local/sbin/wg-home-gateway.sh"
PLIST="/Library/LaunchDaemons/io.braatz.wg-home-gateway.plist"
ANCHOR="/etc/pf.anchors/io.braatz.wg-nat"

echo "  [1/3] Screen Sharing ........."
launchctl enable system/com.apple.screensharing 2>/dev/null || true
launchctl load -w /System/Library/LaunchDaemons/com.apple.screensharing.plist 2>/dev/null || true
sleep 1
if nc -z -G 2 127.0.0.1 5900 2>/dev/null; then echo "        enabled (port 5900 listening)"
else echo "        !! port 5900 not listening — finish it by hand:"
     echo "           System Settings > General > Sharing > Screen Sharing ON"; fi

echo "  [2/3] Boot-time gateway helper"
mkdir -p /usr/local/sbin /etc/pf.anchors
cat > "$HELPER" <<'HELPEREOF'
#!/usr/bin/env bash
# Brings up darwin-as-home-gateway. Idempotent; safe to run repeatedly.
set -uo pipefail
WG_NET="10.10.10.0/24"
ANCHOR="/etc/pf.anchors/io.braatz.wg-nat"
# Resolve the LAN interface from the default route rather than trusting a remembered name.
LAN_IF="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')"
[ -z "$LAN_IF" ] && LAN_IF=en0
logger -t wg-home-gateway "LAN interface resolved to ${LAN_IF}"
sysctl -w net.inet.ip.forwarding=1 >/dev/null
printf 'nat on %s from %s to any -> (%s)\n' "$LAN_IF" "$WG_NET" "$LAN_IF" > "$ANCHOR"
pfctl -a io.braatz.wg-nat -f "$ANCHOR" 2>/dev/null
pfctl -e 2>/dev/null
logger -t wg-home-gateway "forwarding + NAT applied for ${WG_NET} via ${LAN_IF}"
HELPEREOF
chmod 755 "$HELPER"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>io.braatz.wg-home-gateway</string>
  <key>ProgramArguments</key><array><string>$HELPER</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><false/>
</dict></plist>
PLISTEOF
chmod 644 "$PLIST"
launchctl bootout system "$PLIST" 2>/dev/null || true
launchctl bootstrap system "$PLIST" 2>/dev/null || true
echo "        installed (survives reboot)"

echo "  [3/3] Applying now ..........."
bash "$HELPER"
FWD=$(sysctl -n net.inet.ip.forwarding)
echo "        ip.forwarding = $FWD"
echo "        NAT rule:"; pfctl -a io.braatz.wg-nat -s nat 2>/dev/null | sed 's/^/          /'
echo
echo "  done. verify from the iPad (WireGuard ON):"
echo "     ssh jasoncbraatz@10.10.10.2        # darwin"
echo "     smb://192.168.86.200               # voyager NAS, in Files.app"
