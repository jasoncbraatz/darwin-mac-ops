# Travel Kit — reaching darwin + the NAS from an iPad

Built 2026-08-19, session `ipadTravel-1`, for a family trip where the only client is a
lightly-configured iPad Pro. Written so a future Claude (or a future Jason on a hotel wifi)
can re-derive the whole thing without re-discovering anything.

**Definition of done:** from an iPad on a strange network, Jason can (a) get a shell on darwin,
(b) see darwin's desktop at a usable aspect ratio, and (c) pull a file off the NAS. All three
without paying LogMeIn or Splashtop a cent.

---

## 0. The map

```
        iPad (10.10.10.7)                    <- WireGuard peer, split tunnel
              |
              | UDP 51820 to 72.14.189.89
              v
        n8n Linode (10.10.10.1)              <- the hub. THE ROCK. always up.
              |                                 routes 192.168.86.0/24 -> darwin
              v
        darwin (10.10.10.2 / 192.168.86.126) <- home gateway + workstation
              |                                 forwards + NATs onto the home LAN
              v
        voyager NAS (192.168.86.200)         <- SMB, share "Jason2"
```

Trust order is unchanged: **GitHub > Linode > darwin.** darwin is infra-with-a-built-in-UPS,
but it is still a consumer OS that reboots whenever Cupertino ships a new shade of translucency.
The Linode is the rock.

### Live peers on wg0

| IP | Peer | Notes |
|---|---|---|
| 10.10.10.1 | n8n Linode | hub / router |
| 10.10.10.2 | darwin | **home gateway**, also routes `192.168.86.0/24` |
| 10.10.10.3 | Stephanie's laptop | travel spoke |
| 10.10.10.5 | shellac | powered down since 2026-07-13, kept for revival |
| 10.10.10.6 | workhorse | staged, never brought up |
| 10.10.10.7 | **iPad Pro** | added 2026-08-19, split tunnel |

`10.10.10.4` (toolbelt) is **free** — decommissioned 2026-08-19, see §5.

---

## 1. iPad setup (one time)

1. **WireGuard** (App Store) → `+` → *Create from QR code* → scan the QR from the session →
   name it `braatz`.
2. **Termius** (App Store, free tier) → new host → `10.10.10.2`, user `jasoncbraatz`.
   Password lives in `~/.ssh-mcp-servers.json` on darwin (mode 600, not repo-backed — see §6).

**Split tunnel, deliberately.** `AllowedIPs = 10.10.10.0/24, 192.168.86.0/24` only. Netflix and
Maps do *not* get routed through a Linode in Dallas; battery and latency both thank you. If you
ever want full-tunnel (hostile hotel wifi, say), edit the tunnel and set `AllowedIPs = 0.0.0.0/0`.

No `DNS =` line on purpose: with a split tunnel a DNS directive hijacks *all* name resolution,
which breaks the moment the tunnel drops. Use IPs, or add DNS only if you go full-tunnel.

---

## 2. Getting a shell

Three ways, most-to-least preferred:

| Path | How | Needs |
|---|---|---|
| **Claude app** | Just ask. The session drives darwin over the ssh MCP. | nothing |
| **Termius** | `ssh jasoncbraatz@10.10.10.2` | WireGuard on |
| **ttyd in Safari** | `http://10.10.10.2:7681` | WireGuard on |

`ttyd` is already running on darwin (`/opt/homebrew/bin/ttyd -W -c <user:pass> zsh`) — a full
terminal in a browser tab, no client to install. Credentials are in the running process args
(`pgrep -fl ttyd` on darwin). It is HTTP, not HTTPS — **only ever reach it over WireGuard**,
never expose 7681 to the internet.

---

## 3. Seeing the desktop — and the 32:9 problem

darwin drives a **Dell U4924DW at 6720×1890**. That is 32:9. An iPad is roughly 4:3. Mirroring
one onto the other gives you a letterboxed strip about a third of the screen tall, which is why
plain VNC feels useless here — it is *too literal*, exactly as suspected.

macOS has no true multi-session RDP; it cannot hand you a differently-shaped session the way
Windows can. The workaround is to change what "the screen" *is*:

**BetterDisplay** (free tier, installed 2026-08-19) creates a **virtual display** at any
resolution. Make one at 2732×2048 (iPad Pro 13" native), disable the Dell, and the Mac genuinely
believes it has one 4:3 monitor. VNC then streams a correctly-shaped desktop at full size — no
pinch-zooming, no scrolling a sliver.

```
Dell U4924DW  6720x1890  (32:9)  <- disabled while travelling
Virtual "ipad" 2732x2048  (4:3)  <- what you actually see
```

Client on the iPad: **RealVNC Viewer** (free) to `10.10.10.2:5900`, or **Jump Desktop**
(~one-time purchase, no subscription) if you want the noticeably better experience — its Fluid
protocol and display-picker beat raw VNC on a touchscreen.

### Rejected alternatives, and why

- **NoMachine** — free and RDP-like, but on a macOS *host* it cannot resize a physical display;
  the forums are full of this. Same wall, and it adds a daemon.
- **Parsec / Sunshine+Moonlight** — built for game streaming; macOS hosting is not a first-class
  target and virtual-display support is Windows-only.
- **Plain VNC alone** — the 32:9 letterbox. This is the thing we are working around.
- **Splashtop / LogMeIn** — works, but that is the subscription we are refusing to buy.

---

## 4. Reaching the NAS

`voyager.local` = `192.168.86.200`, SMB share **Jason2**, already mounted on darwin at
`/Volumes/Jason2`.

- **Files.app** → Connect to Server → `smb://192.168.86.200` (needs WireGuard on *and* the
  gateway script from §5 applied).
- **Or skip the network entirely:** ask the Claude app for the file. darwin already has the share
  mounted, so a session can read `/Volumes/Jason2/...` and hand you the file as a download. This
  path needs no WireGuard, no routing, and no NAT — it is the belt to the suspenders above.

---

## 5. What changed on 2026-08-19 (and how to undo it)

**toolbelt (Win11, 192.168.86.108) was decommissioned.** It had been dark for ~36 days and was
staying off — an always-on Win11 box is a poor joules-per-packet trade for occasional travel
routing. Removed from: the wg0 peer list on n8n, and `~/.ssh-mcp-servers.json`. Its `.108`
address and `10.10.10.4` are both free.

*Deliberately kept*: the annotated `Host toolbelt` block in `~/.ssh/config`, the DEPRECATED notes
in `models.json`, and the blackbook lessons. Those are the **revival recipe**, not rot. Records
should still name the dead; runtime configs should not.

**darwin took over the home-LAN route.** `AllowedIPs` for darwin's peer is now
`10.10.10.2/32, 192.168.86.0/24`. This required forwarding + NAT on darwin, installed by
`ipad-travel-setup.sh` as a LaunchDaemon (`io.braatz.wg-home-gateway`).

> ⚠️ **CAVEAT — the one thing that will bite you.** darwin is now load-bearing for the whole home
> LAN. If darwin ever *travels* again, `192.168.86.0/24` goes dark for every other peer until a
> box that stays home takes the route back. darwin is the gateway *because it stopped moving.*

**Undo everything:** `sudo bash travel-kit/ipad-travel-UNDO.sh` on darwin, then on n8n reset
darwin's peer to `wg set wg0 peer <darwin-pubkey> allowed-ips 10.10.10.2/32`. Config backups are
at `/etc/wireguard/wg0.conf.bak-*` on n8n.

---

## 6. Known debt (teed up, not swept under the rug)

- **`~/.ssh-mcp-servers.json` is not repo-backed and holds plaintext passwords.** It was mode
  `644` (world-readable) until 2026-08-19; now `600`. It dies with the SSD. It should not be
  committed as-is — the right fix is a sanitised template in `dotfiles/` plus the secrets in
  whatever vault we settle on. **Not done.**
- **toolbelt's dangling RDP shortcuts** live in `~/Desktop/downloads/HomeShares-away-nw/`. Left
  in place; harmless (they do not fire) and they are part of the revival path.
- **BetterDisplay needs GUI permission grants** that no script can perform — Screen Recording,
  plus the CLI-integration toggle. Any future automation must assume a human did that once.

---

## 7. Troubleshooting, in the order to try it

1. **Tunnel up?** WireGuard app should show a recent handshake. If not, the hotel wifi may block
   UDP 51820 — rare, but it happens on captive-portal networks.
2. **Tunnel up but nothing responds?** From darwin: `sudo wg show` on n8n and confirm the iPad
   peer has an endpoint and a handshake.
3. **darwin reachable but NAS is not?** The gateway daemon did not run. On darwin:
   `sudo bash /usr/local/sbin/wg-home-gateway.sh`, then check `sysctl net.inet.ip.forwarding`
   is `1` and `sudo pfctl -a io.braatz.wg-nat -s nat` shows a rule.
4. **Everything is dead and darwin rebooted for an OS update?** The LaunchDaemon should have
   re-applied at boot; check `log show --predicate 'process == "logger"' --last 1h | grep wg-home-gateway`.
5. **Still stuck?** Open the Claude app and ask. The ssh MCP path to darwin does not depend on
   WireGuard at all, so it keeps working when the tunnel does not — that is the whole point of
   having layers.
