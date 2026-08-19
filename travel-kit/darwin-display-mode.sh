#!/usr/bin/env bash
# darwin-display-mode.sh — flip darwin's desktop between the 32:9 Dell and an iPad-shaped 4:3 view.
#
#   darwin-display-mode ipad   # mirror everything onto the 4:3 virtual screen (for remote/VNC)
#   darwin-display-mode desk   # restore the ultrawide Dell layout (for sitting at the desk)
#   darwin-display-mode status # what am I in right now?
#   darwin-display-mode save   # snapshot the CURRENT layout as the new "desk" layout
#
# WHY MIRRORING, of all things:
#   macOS has no true multi-session remote desktop. Apple's Screen Sharing serves the desktop as
#   it is, so with a 6720x1890 (32:9) Dell attached you get a letterboxed sliver on an iPad.
#   Disabling the Dell outright needs BetterDisplay *Pro* (-connected=off). Mirroring does not:
#   when the Dell mirrors the 1600x1200 virtual screen, macOS collapses to ONE logical 4:3
#   framebuffer, which is exactly what any VNC client then receives. Free, and no Pro upsell.
#   Side effect: the physical Dell shows a 4:3 image letterboxed on its ultrawide panel. Nobody
#   is home to care, and 'desk' undoes it in one command.
set -uo pipefail

DELL="EB323A68-2390-4410-B8F0-E81612293306"
VIRT="B843A6B6-A419-4F8F-B72A-310C1F23C26E"
STATE="${HOME}/.config/darwin-display-mode"
DESK_FILE="${STATE}/desk-layout.cmd"
mkdir -p "$STATE"

command -v displayplacer >/dev/null || { echo "displayplacer missing: brew install displayplacer"; exit 1; }

# Seed the desk layout on first run so 'desk' always has something true to restore.
if [ ! -s "$DESK_FILE" ]; then
  cat > "$DESK_FILE" <<'SEED'
displayplacer "id:EB323A68-2390-4410-B8F0-E81612293306 res:3360x945 hz:60 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" "id:B843A6B6-A419-4F8F-B72A-310C1F23C26E res:1600x1200 hz:60 color_depth:4 enabled:true scaling:off origin:(-1600,0) degree:0"
SEED
fi

case "${1:-status}" in
  ipad)
    echo "-> iPad mode: mirroring everything onto the 4:3 virtual screen (1600x1200)"
    displayplacer "id:${VIRT}+${DELL} res:1600x1200 hz:60 color_depth:4 enabled:true scaling:off origin:(0,0) degree:0" 2>&1 | grep -v '^$' | head -5
    sleep 2
    ;;
  desk)
    echo "-> Desk mode: restoring the ultrawide layout"
    bash "$DESK_FILE" 2>&1 | grep -v '^$' | head -5
    sleep 2
    ;;
  save)
    displayplacer list 2>/dev/null | grep '^displayplacer ' | tail -1 > "$DESK_FILE"
    echo "-> saved current layout as 'desk':"; sed 's/^/     /' "$DESK_FILE"; exit 0
    ;;
  status) : ;;
  *) echo "usage: $(basename "$0") {ipad|desk|status|save}"; exit 1 ;;
esac

# --- report, always: what does macOS actually think right now? ---
echo
n=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c 'Mirror: On')
if [ "$n" -gt 0 ]; then echo "   MODE: iPad (mirrored)"; else echo "   MODE: desk (extended)"; fi
system_profiler SPDisplaysDataType 2>/dev/null \
  | grep -E '^ {8}[A-Za-z0-9].*:$|Resolution:|Main Display|Mirror:' | sed 's/^ */   /'
