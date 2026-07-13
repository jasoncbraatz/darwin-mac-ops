# opencode config — the INTERACTIVE cheap rail (DeepInfra)

**Live path:** `~/.config/opencode/opencode.jsonc` (NOT a git repo — this is the backup).
Restore: `cp dotfiles/opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc`

## What it's for
This is how an **interactive** Claude (Cowork / Claude Desktop) reaches the cheap rail —
the same DeepInfra lane Digital Jason uses, but driven from a live chat instead of the
Strike Zone tick. Jason says "let's use deepinfra" and the worker runs headless on darwin.

Two ways in, both verified live 2026-07-13:

| Path | Command | Notes |
|---|---|---|
| **di_worker shim** | `python3 ~/repos/strike-zone/tools/di-worker/di_worker.py '<prompt>'` | One-shot. **$5 budget cap**, writes a `di-cost/v1` row to `budget-ledger.jsonl`. The accounted path — prefer this. |
| **OpenCode headless** | `opencode run --model deepinfra/Qwen/Qwen3-Coder-480B-A35B-Instruct '<prompt>'` | Full agentic loop (tools, file edits). **No budget cap, not in the SZ ledger** — watch it. |

Both need `DEEPINFRA_API_KEY`: `set -a; source ~/.config/strike-zone/env; set +a`

## History — why this file exists
Until 2026-07-13 this config pointed at a provider named **`shellac`**
(`http://10.10.10.5:11434`, `qwen2.5-coder:32b`) — the RTX 3090 lab box. That box and
`toolbelt` were **powered down** on 2026-07-13 when the free rail was deprecated
(open-weight models only earn their keep when they're large enough; nothing that fits a
24GB consumer GPU is — renting a big open-weight model on DeepInfra beats hosting a small
one). OpenCode was still aimed at that dead endpoint and would have hung on first use.

**The trap for next time:** the free-rail deprecation sweep grepped `~/repos`, `~/code`,
`~/Scripts`, `~/Desktop/downloads` — but **not `~/.config`**, so this was missed on the
first pass. Config dirs outside the repo tree are a blind spot. Sweep them.

Old config preserved at `~/.config/opencode/opencode.jsonc.bak.20260713-shellac`.
