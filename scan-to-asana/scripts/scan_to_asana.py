#!/usr/bin/env python3
"""
scan_to_asana.py
================
Watch /Volumes/Jason2/SCANS for new PDFs, OCR them locally with the macOS Vision
framework, classify with Anthropic Haiku, create a task in the Asana
"Payments Calendar" project (in Untitled / uncategorized section) with the PDF
attached, then archive the PDF into a dated subfolder.

State-based, not time-window. The script tracks the newest successfully-processed
PDF mtime in ~/.local/state/scan-pipeline/state.json. Next run picks up where the
last left off, so a NAS-down day or a powered-off Mac simply delays processing.

Designed to be invoked by a LaunchAgent, which itself is wrapped by an
AppleScript .app so it inherits the .app's TCC identity (Full Disk Access).
That's why this script must NOT be the LaunchAgent's direct ProgramArguments —
on macOS 26+ the kernel re-execs the python3 interpreter and TCC checks the
interpreter, not the .app. The AppleScript .app's `do shell script` is what
keeps the .app identity attached to the spawned process tree.

Deps (pip install --user PyMuPDF ocrmac requests):
  - PyMuPDF (fitz)  — rasterize PDF pages to PNG
  - ocrmac           — Apple Vision OCR (free, native, no tokens)
  - requests         — HTTP for Anthropic + Asana
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import requests

# ─── Config ──────────────────────────────────────────────────────────────────

HOME = Path.home()
SCANS_DIR = Path("/Volumes/Jason2/SCANS")
ARCHIVE_DIR = SCANS_DIR / "processed"
STATE_DIR = HOME / ".local" / "state" / "scan-pipeline"
STATE_FILE = STATE_DIR / "state.json"
SECRETS_DIR = HOME / ".config" / "scan-pipeline"
ASANA_TOKEN_FILE = SECRETS_DIR / "asana.token"
ANTHROPIC_KEY_FILE = SECRETS_DIR / "anthropic.key"
LOG_DIR = HOME / "Library" / "Logs"
LOG_FILE = LOG_DIR / "scan-to-asana.log"

ASANA_API = "https://app.asana.com/api/1.0"
ASANA_WORKSPACE = "699263919070451"
ASANA_PROJECT = "1210461981452229"  # "Payments Calendar"
ASANA_SECTION_UNCATEGORIZED = "1210461981452230"  # "Untitled section"
ASANA_FIELD_SIDE = "1212846039530033"
ASANA_FIELD_SIDE_BUSINESS = "1212846039530034"
ASANA_FIELD_SIDE_PERSONAL = "1212846039530035"
ASANA_FIELD_DOUGH = "1212806735213451"

ANTHROPIC_API = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = "claude-haiku-4-5-20251001"
ANTHROPIC_VERSION = "2023-06-01"

# Limit per-run work so a single failing PDF can't stall everything
MAX_PER_RUN = 20

# ─── Logging ─────────────────────────────────────────────────────────────────

LOG_DIR.mkdir(parents=True, exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("scan-to-asana")


# ─── State ───────────────────────────────────────────────────────────────────


@dataclass
class State:
    last_mtime: float
    last_run_iso: str
    processed_count: int = 0

    @classmethod
    def load(cls) -> "State":
        if STATE_FILE.exists():
            try:
                data = json.loads(STATE_FILE.read_text())
                return cls(**data)
            except Exception as e:
                log.warning(f"state file unreadable ({e}); starting fresh")
        return cls(last_mtime=0.0, last_run_iso="never", processed_count=0)

    def save(self) -> None:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = STATE_FILE.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(
                {
                    "last_mtime": self.last_mtime,
                    "last_run_iso": self.last_run_iso,
                    "processed_count": self.processed_count,
                },
                indent=2,
            )
        )
        tmp.replace(STATE_FILE)


# ─── Secrets ─────────────────────────────────────────────────────────────────


def read_secret(path: Path, label: str) -> str:
    if not path.exists():
        log.error(f"missing {label} at {path}")
        sys.exit(2)
    text = path.read_text().strip()
    if not text:
        log.error(f"empty {label} at {path}")
        sys.exit(2)
    return text


# ─── PDF discovery ───────────────────────────────────────────────────────────


def find_new_scans(after_mtime: float) -> list[Path]:
    """PDFs in SCANS_DIR (not subdirs) with mtime strictly > after_mtime."""
    if not SCANS_DIR.exists():
        log.warning(f"{SCANS_DIR} not mounted; nothing to do")
        return []
    out: list[Path] = []
    for p in SCANS_DIR.iterdir():
        if not p.is_file() or p.suffix.lower() != ".pdf":
            continue
        if p.name.startswith("."):
            continue
        if p.stat().st_mtime > after_mtime:
            out.append(p)
    out.sort(key=lambda p: p.stat().st_mtime)
    return out


# ─── OCR ─────────────────────────────────────────────────────────────────────


def ocr_pdf(pdf_path: Path) -> str:
    """Rasterize each page with PyMuPDF, OCR with Apple Vision via ocrmac."""
    import fitz  # PyMuPDF
    from ocrmac import ocrmac

    doc = fitz.open(pdf_path)
    chunks: list[str] = []
    try:
        for page_num, page in enumerate(doc, start=1):
            with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
                tmp_path = Path(tmp.name)
            try:
                pix = page.get_pixmap(dpi=220)
                pix.save(tmp_path)
                results = ocrmac.OCR(str(tmp_path)).recognize()
                # results is List[Tuple[text, conf, bbox]]
                page_text = "\n".join(r[0] for r in results if r and r[0])
                chunks.append(f"--- page {page_num} ---\n{page_text}")
            finally:
                try:
                    tmp_path.unlink()
                except FileNotFoundError:
                    pass
    finally:
        doc.close()
    return "\n\n".join(chunks)


# ─── Classification ──────────────────────────────────────────────────────────

CLASSIFY_PROMPT = """You are extracting structured data from a piece of scanned mail.

Return STRICT JSON only (no prose, no markdown) with exactly these keys:

{
  "name": "<short task title, 60 chars max — usually 'Payee — what for'>",
  "amount": <number or null, the total amount due in USD>,
  "side": "Business" | "Personal" | null,
  "due_on": "YYYY-MM-DD" | null,
  "summary": "<1-2 sentence plain summary, 200 chars max>"
}

Rules:
- "name" should read like a calendar entry. Examples: "State of California — Tax Bill", "Pedernales Electric Coop — Aug Bill", "Verizon — Wireless".
- "amount" is the total payable. If there are multiple amounts, pick the most likely TOTAL DUE. Strip $ and commas. Return null if there's no clear amount.
- "side" — "Business" if it's addressed to a company / LLC / DBA or involves business expenses, "Personal" if addressed to Jason as an individual or for personal services (utilities at home, personal taxes, etc.). "null" if genuinely ambiguous.
- "due_on" — the payment due date. Null if no date is visible.
- No commentary, no apologies, no explanation. JSON only.

Document OCR text:
---
"""


def classify(text: str, api_key: str) -> dict:
    body = {
        "model": ANTHROPIC_MODEL,
        "max_tokens": 400,
        "messages": [
            {"role": "user", "content": CLASSIFY_PROMPT + text[:30_000]},
        ],
    }
    r = requests.post(
        ANTHROPIC_API,
        headers={
            "x-api-key": api_key,
            "anthropic-version": ANTHROPIC_VERSION,
            "content-type": "application/json",
        },
        json=body,
        timeout=60,
    )
    r.raise_for_status()
    raw = r.json()["content"][0]["text"].strip()
    # Sometimes models wrap in ```json blocks; defensively strip
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.lower().startswith("json"):
            raw = raw[4:]
        raw = raw.strip()
    return json.loads(raw)


# ─── Asana ───────────────────────────────────────────────────────────────────


def asana_create_task(token: str, classification: dict) -> str:
    name = (classification.get("name") or "Untitled scan")[:120]
    summary = classification.get("summary") or ""
    amount = classification.get("amount")
    side = classification.get("side")
    due_on = classification.get("due_on")

    custom_fields: dict[str, object] = {}
    if isinstance(amount, (int, float)):
        custom_fields[ASANA_FIELD_DOUGH] = float(amount)
    if side == "Business":
        custom_fields[ASANA_FIELD_SIDE] = ASANA_FIELD_SIDE_BUSINESS
    elif side == "Personal":
        custom_fields[ASANA_FIELD_SIDE] = ASANA_FIELD_SIDE_PERSONAL

    payload: dict = {
        "data": {
            "name": name,
            "notes": summary,
            "projects": [ASANA_PROJECT],
            "memberships": [
                {"project": ASANA_PROJECT, "section": ASANA_SECTION_UNCATEGORIZED}
            ],
        }
    }
    if due_on:
        payload["data"]["due_on"] = due_on
    if custom_fields:
        payload["data"]["custom_fields"] = custom_fields

    r = requests.post(
        f"{ASANA_API}/tasks",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=30,
    )
    if r.status_code >= 400:
        log.error(f"asana create failed: {r.status_code} {r.text}")
    r.raise_for_status()
    return r.json()["data"]["gid"]


def asana_attach_pdf(token: str, task_gid: str, pdf_path: Path) -> None:
    with pdf_path.open("rb") as fh:
        files = {"file": (pdf_path.name, fh, "application/pdf")}
        data = {"parent": task_gid}
        r = requests.post(
            f"{ASANA_API}/attachments",
            headers={"Authorization": f"Bearer {token}"},
            data=data,
            files=files,
            timeout=120,
        )
    if r.status_code >= 400:
        log.error(f"asana attach failed: {r.status_code} {r.text}")
    r.raise_for_status()


# ─── Archive ─────────────────────────────────────────────────────────────────


def archive(pdf_path: Path) -> Path:
    now = datetime.now(timezone.utc)
    dest_dir = ARCHIVE_DIR / now.strftime("%Y-%m")
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / pdf_path.name
    # If a same-named file already lives there, append a timestamp
    if dest.exists():
        stem, suffix = pdf_path.stem, pdf_path.suffix
        dest = dest_dir / f"{stem}-{now.strftime('%H%M%S')}{suffix}"
    shutil.move(str(pdf_path), str(dest))
    return dest


# ─── Process one PDF ─────────────────────────────────────────────────────────


def process_one(pdf: Path, asana_token: str, anthropic_key: str) -> bool:
    log.info(f"processing {pdf.name}  ({pdf.stat().st_size} bytes)")
    try:
        text = ocr_pdf(pdf)
        log.info(f"  ocr: {len(text)} chars")
        classification = classify(text, anthropic_key)
        log.info(f"  classified: name={classification.get('name')!r} amount={classification.get('amount')} side={classification.get('side')} due={classification.get('due_on')}")
        task_gid = asana_create_task(asana_token, classification)
        log.info(f"  asana task created: {task_gid}")
        asana_attach_pdf(asana_token, task_gid, pdf)
        log.info(f"  pdf attached")
        archived = archive(pdf)
        log.info(f"  archived → {archived}")
        return True
    except Exception as e:
        log.exception(f"  FAILED on {pdf.name}: {e}")
        return False


# ─── Main ────────────────────────────────────────────────────────────────────


def main() -> int:
    log.info("=" * 60)
    log.info(f"run starting (uid={os.getuid()})")

    asana_token = read_secret(ASANA_TOKEN_FILE, "Asana token")
    anthropic_key = read_secret(ANTHROPIC_KEY_FILE, "Anthropic key")

    if not SCANS_DIR.exists():
        log.error(f"{SCANS_DIR} not reachable — NAS not mounted? exiting 0 so we'll retry next run.")
        return 0

    state = State.load()
    log.info(f"state: last_mtime={state.last_mtime} last_run={state.last_run_iso}")

    scans = find_new_scans(state.last_mtime)
    if not scans:
        log.info("no new scans; nothing to do")
        state.last_run_iso = datetime.now(timezone.utc).isoformat()
        state.save()
        return 0

    log.info(f"{len(scans)} new PDF(s) found; processing up to {MAX_PER_RUN}")
    newest_processed_mtime = state.last_mtime
    successes = 0

    for pdf in scans[:MAX_PER_RUN]:
        mtime_before_processing = pdf.stat().st_mtime
        if process_one(pdf, asana_token, anthropic_key):
            successes += 1
            # Only advance the watermark on success
            if mtime_before_processing > newest_processed_mtime:
                newest_processed_mtime = mtime_before_processing
        else:
            # On failure, stop advancing so we'll retry this file next run.
            # But move on to other files to avoid one bad PDF blocking everything.
            continue

    state.last_mtime = newest_processed_mtime
    state.last_run_iso = datetime.now(timezone.utc).isoformat()
    state.processed_count += successes
    state.save()

    log.info(f"run complete: {successes}/{len(scans[:MAX_PER_RUN])} succeeded (lifetime={state.processed_count})")
    return 0 if successes == len(scans[:MAX_PER_RUN]) else 1


if __name__ == "__main__":
    sys.exit(main())
