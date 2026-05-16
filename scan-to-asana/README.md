# scan-to-asana

Watches `/Volumes/Jason2/SCANS` for new PDFs. For each new one: OCR locally with Apple Vision, classify with Claude Haiku, create a task in the Asana "Payments Calendar" project (Untitled section / uncategorized) with the PDF attached and a structured `Dough` (amount) + `Side` (Business/Personal) custom-field set. Archive the original to `processed/YYYY-MM/`.

## Flow

```
Brother ADS-3000N scanner
  → CIFS profile "voyager" → WD MyCloud NAS at /Volumes/Jason2/SCANS

[LaunchAgent on darwin every 10 min]
  ScanToAsana.app fires
    → /usr/bin/python3 ~/Scripts/scan_to_asana.py
      → state.json watermark: only process PDFs newer than last successful run
      → For each new PDF:
          PyMuPDF rasterize pages → ocrmac (Apple Vision OCR) → text
          POST text to Anthropic Haiku → {name, amount, side, due_on, summary}
          POST task to Asana → task GID
          POST attachment to Asana with the PDF
          Move PDF → /Volumes/Jason2/SCANS/processed/YYYY-MM/
      → Update state.json watermark
```

OCR is free (Apple Vision). Haiku is ~$0.001 per scan. End-to-end ~13 seconds per PDF including network.

## Install on a fresh Mac

Prereq: secrets in place (`~/.config/scan-pipeline/asana.token` and `anthropic.key`). See [`../secrets/README.md`](../secrets/README.md).

```bash
/usr/bin/python3 -m pip install --user -r requirements.txt
./install.sh
```

Then follow the printed FDA + bootstrap steps.

## Files

- `scripts/scan_to_asana.py` — the pipeline. State-based, idempotent, fails gracefully on NAS-down.
- `launchagents/com.braatz.scan-to-asana.plist` — fires every 600 seconds
- `requirements.txt` — PyMuPDF, ocrmac, requests
- `install.sh` — builds `ScanToAsana.app`, signs it, seeds the watermark, installs the LaunchAgent

## Asana project topology (as of 2026-05-16)

- Workspace: `699263919070451`
- Project: `1210461981452229` ("Payments Calendar")
- Default landing section: `1210461981452230` ("Untitled section" — uncategorized)
- Custom field `Side` (enum): `1212846039530033`
  - Business: `1212846039530034`
  - Personal: `1212846039530035`
- Custom field `Dough` (number): `1212806735213451`

If the project schema changes, edit the constants at the top of `scan_to_asana.py`.

## State file

`~/.local/state/scan-pipeline/state.json`:

```json
{
  "last_mtime": 1778907600.0,
  "last_run_iso": "2026-05-16T13:04:31.432755+00:00",
  "processed_count": 1
}
```

Watermark only advances on success. A failed PDF gets retried next run. The Mac being off (or NAS down) just delays processing.
