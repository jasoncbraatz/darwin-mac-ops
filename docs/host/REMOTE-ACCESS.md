# darwin as a subject — its own remote access + credential model

Every other doc in this constellation treats darwin as the *substrate* the pipelines and the
[`darwin-remote-access`](https://github.com/jasoncbraatz/darwin-remote-access) map run on. This
file treats darwin as a **subject**: the box itself has its own remote-access surface and its own
credential model, and — per the 2026-10-09 estate audit (SM 1218729017558178,
`feynman-linux-ops/docs/AUDIT-floor-vs-subject-2026-10-09.md`) — three pieces of that surface
were undocumented anywhere: SSH/sshd's own config, `pmset`, and the Application Firewall. VNC and
ttyd are already well covered in `darwin-remote-access/README.md` and are cross-referenced below
rather than re-described.

**Read-only.** Everything below was gathered with read-only commands over SSH on 2026-10-09
(rail lane `ncCurie1009dm2`). Nothing on darwin was changed to produce this file. Any delta that
*should* change is called out as a finding, not applied here — see the property rule in
`docs/handoffs/ncCurie1009dm2.md`.

## The box's remote-access surface

| Service | Port | State (measured 2026-10-09) | Where re-asserted |
|---|---|---|---|
| SSH (Remote Login) | 22 | enabled — reachable, used to gather this file | **not re-asserted**: toggled once via System Settings/`systemsetup -setremotelogin`; no script in any repo re-applies it. If a rebuild forgets this step, `BOOTSTRAP.md` is silent on it too. |
| Screen Sharing (VNC) | 5900 | registered with launchd (`com.apple.screensharing.agent` et al. present in `launchctl list`), but on-demand/socket-activated — **listening state not independently verified this inning** (confirming requires root; non-root `lsof` cannot see it) | UI toggle only — see `darwin-remote-access/README.md` §5 gotcha ("must be enabled from the UI, never the CLI") |
| `ttyd` (browser terminal) | 7681 | running (confirmed: `ttyd -W -c <user>:<password> zsh`, pid live) | `~/Library/LaunchAgents/com.user.ttyd.plist`, repo-backed as a **template** at `launchagents/com.user.ttyd.plist.template` (the real credential is deliberately NOT in git; the live plist is a ratified divergence from the template per `launchd-divergence-allowlist.txt`) |
| WireGuard client (`wg0`) | n/a | up (`utun4`, 10.10.10.2), home-LAN gateway role | `io.braatz.wg-home-gateway.plist` (LaunchDaemon), re-asserted by `travel-kit/ipad-travel-setup.sh`, undone by `travel-kit/ipad-travel-UNDO.sh` — fully documented, see `travel-kit/README.md` |

## SSH / sshd — the credential model

- Config: `/etc/ssh/sshd_config` (stock, just an `Include`) + `/etc/ssh/sshd_config.d/100-macos.conf`
  (`UsePAM yes`, `AcceptEnv LANG LC_*`). Neither file is repo-tracked; both are Apple-shipped
  defaults plus the one override line macOS installs — there is nothing hand-written to re-assert.
- `AuthorizedKeysFile` is the default (`.ssh/authorized_keys` under the login user's home).
- `~jasoncbraatz/.ssh/authorized_keys` currently carries **14 key lines**. Reading comments only
  (never key material): entries tagged for `autoBridge3-livetest`, `estate-sync`,
  `mbp2024-rsync-to-n8n`, `curie`, and five `darlish-cloud` entries (rotations/replacements kept
  side by side rather than overwritten). Six timestamped `.bak-*` copies sit beside the live file
  — that *is* the undo trail, but it is a byproduct of hand-editing, not a script.
  **Not re-asserted**: nothing regenerates `authorized_keys` from a repo-tracked source list; it
  is hand-maintained via direct edits over existing SSH access.
- darwin's own **outbound** SSH client config (`~/.ssh/config` on darwin) names `n8n`, `flowers`,
  `shellac`, `toolbelt`, `feynman` (+ `-wg`), `curie` (+ `-wg`) — darwin's view of the rest of the
  estate. Also hand-maintained, with per-host `.bak-*` snapshots from past onboarding/offboarding
  sessions (`config.bak-curieOnboard`, `config.bak-darwin-20260914...`, etc.).

## `pmset` — why darwin stays reachable

Measured 2026-10-09:

```
SleepDisabled        1
hibernatemode        3
womp                 1      # Wake on Magic Packet — required for WireGuard to find it asleep
displaysleep         0
disksleep            0
ttyskeepawake        1
```

This is the config that makes darwin a plausible always-on gateway despite being a consumer Mac.
**Not re-asserted**: these are `pmset`/System Settings toggles with no installer script in any
repo. A clean rebuild (`BOOTSTRAP.md`) does not restore them — darwin would come back reachable
over LAN but **sleep** and drop off WireGuard until someone re-runs the equivalent of
`sudo pmset -a sleep 0 hibernatemode 3 womp 1 disksleep 0 displaysleep 0`. Carried here as a
finding, not fixed: this is a config change, and the lane's property rule is document-only.

## Application Firewall (`socketfilterfw`)

Measured 2026-10-09, non-root read: **`Firewall is disabled. (State = 0)`.**

Not re-asserted anywhere, and no script in any repo sets it either way. Given the estate's
stated security trade — this is a WireGuard/LAN-only surface, mirroring the
"enterprise/gateway shapes this estate does not have" reasoning in
`feynman-linux-ops/host/RDP.md` — an OS firewall layered on top of a locked-down sshd and an
on-demand Screen Sharing daemon may be an intentional no-op rather than a gap. **Carried as a
finding, not a fix**: if the firewall should be ON, that is a config decision for the estate desk,
not a "document only" rail lane — see the property rule.

## Cross-references (not re-described here)

- VNC/Screen Sharing enable procedure, the black-frame-from-CLI gotcha, ttyd usage, WireGuard
  topology, display-mode switching: [`darwin-remote-access/README.md`](https://github.com/jasoncbraatz/darwin-remote-access)
  (external repo — added to this repo's `README.md` "Related repos" table by this same commit).
- The iPad/travel path, the home-LAN gateway NAT, and its undo: [`../../travel-kit/README.md`](../../travel-kit/README.md).
