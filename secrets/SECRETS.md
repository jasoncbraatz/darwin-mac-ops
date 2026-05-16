# Secrets inventory (the master where-do-my-keys-live document)

This document lists every credential file across all hosts. Each entry includes: where it lives, what it gates, and how to rotate.

## On darwin (the MacBook)

| Path | What it is | Used by | Rotation |
|---|---|---|---|
| `~/.config/cloudflare/token` (0600) | Cloudflare API token, scoped to "All zones, DNS:Edit" | The `cf-add-records.sh` helper, ad-hoc DNS edits, future-Opus | Generate new at <https://dash.cloudflare.com/profile/api-tokens>, overwrite file. |
| `~/.config/github/pat` (0600) | Fine-grained GitHub Personal Access Token, "All repositories", Contents R/W + Administration R/W | Pushing/pulling private repos, creating new repos via API | Edit existing at <https://github.com/settings/personal-access-tokens>, OR generate a new one and overwrite the file. |
| `~/.config/scan-pipeline/asana.token` (0600) | Asana Personal Access Token (originally minted in Asana, mirrored from n8n's encrypted credentials store) | `scan_to_asana.py` for creating tasks in the Payments Calendar | Asana → Profile → Settings → Apps → Developer Apps. Overwrite the file. |
| `~/.config/scan-pipeline/anthropic.key` (0600) | Anthropic API key, format `sk-ant-api03-...`, 108 chars | `scan_to_asana.py` for the Haiku classifier | console.anthropic.com → API Keys. Overwrite the file. |
| `~/.ssh/id_ed25519` (default macOS key) | The user's general SSH identity | Various git/SSH things | Standard `ssh-keygen` flow. |
| `~/.ssh/id_ed25519_n8n_backup` (no passphrase) | Dedicated key for: (a) the nightly backup-pull from n8n to NAS, and (b) rsyncing files from n8n to darwin. Public key is in `claudeApp@n8n:~/.ssh/authorized_keys` with `restrict,pty` options. | `MiniblogBackup.app` LaunchAgent, ad-hoc rsync | `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_n8n_backup -N ""`, update the `claudeApp@n8n` authorized_keys file. |

## On n8n (the n8n Linode, `72.14.189.89`)

| Path | What it is | Used by | Rotation |
|---|---|---|---|
| `/opt/n8n/docker-compose.yml` (root-owned) | Contains cleartext n8n encryption key, postgres passwords, JWT secret, umami secret — see `n8n-stack` repo `SECURITY.md` | The docker compose stack | See `n8n-stack/SECURITY.md` for the multi-step rotation procedure. |
| `/home/claudeApp/.ssh/authorized_keys` | Includes darwin's backup-key pubkey | SSH access | Replace the matching line if rotating darwin's key. |
| Inside the n8n container: encrypted credentials store | All connectors (Asana, etc.) decrypted by `N8N_ENCRYPTION_KEY` | n8n workflows | Rotation of N8N_ENCRYPTION_KEY = `n8n export:credentials --decrypted` → change key → `n8n import:credentials`. |

## On flowers (the mail Linode, `69.164.195.213`)

| Path | What it is | Used by | Rotation |
|---|---|---|---|
| `/root/secrets/stalwart-admin.txt` (0600) | Stalwart admin username/password + `jason@braatz.ai` mailbox password | Admin UI login, IMAP/SMTPS auth from mail clients | Admin UI → /admin → Manage → Account. Update file. |
| `/root/.secrets/cloudflare.ini` (0600) | CF API token for certbot DNS-01 challenges | `certbot renew` auto-triggered by certbot.timer | Rotate CF token, edit this file. Single line: `dns_cloudflare_api_token = <token>`. |
| `/etc/letsencrypt/live/mail.braatz.ai/privkey.pem` (root only) | Let's Encrypt private key | TLS for ports 465 (SMTPS) + 993 (IMAPS) | Auto-rotates every ~60 days via certbot.timer. Hook at `/etc/letsencrypt/renewal-hooks/deploy/stalwart-reload.sh` copies the new cert+key into Stalwart's path. |

## DKIM signing keys (in the Stalwart datastore)

Living inside `/opt/stalwart/data/` (RocksDB) — not files you'd rotate manually. The "View Zone File" admin UI is where you copy the public-key half into Cloudflare DNS records. Stalwart can be configured to auto-rotate DKIM keys; currently set to manual.

## How to find a secret in a hurry

```bash
# From darwin
ls -la ~/.config/cloudflare ~/.config/github ~/.config/scan-pipeline ~/.ssh/id_ed25519_n8n_backup 2>&1

# From flowers via SSH
ssh flowers 'sudo ls -la /root/secrets/ /root/.secrets/'

# On n8n, the n8n encryption key (also seen via docker inspect):
ssh n8n 'sudo grep N8N_ENCRYPTION_KEY /opt/n8n/docker-compose.yml'
```

## Rotation hygiene

If any of these secrets are suspected compromised:

1. **GitHub PAT:** revoke first at github.com/settings, then regenerate, then update `~/.config/github/pat` and `n8n:/root/.git-credentials`.
2. **CF token:** revoke at dash.cloudflare.com/profile/api-tokens, regenerate (Zone:DNS:Edit on All zones), update `~/.config/cloudflare/token` and `flowers:/root/.secrets/cloudflare.ini`.
3. **N8N_ENCRYPTION_KEY:** see `n8n-stack/SECURITY.md` for the dance.
4. **Asana PAT:** regenerate in Asana, update `~/.config/scan-pipeline/asana.token`, AND update the n8n credential (so the source-of-truth in n8n's credentials store also reflects it).
5. **Anthropic key:** revoke at console.anthropic.com, generate, update `~/.config/scan-pipeline/anthropic.key`.
6. **Mail account passwords:** Stalwart admin UI → Directory → Accounts → edit. Update all mail clients afterwards.
7. **SSH keys:** standard `ssh-keygen`, copy pubkey to remote `authorized_keys`, remove old key.
