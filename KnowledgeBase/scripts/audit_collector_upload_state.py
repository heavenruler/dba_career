#!/usr/bin/env python3
"""Audit collector PDFs against local upload state and Cloudflare R2 inventory."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
COLLECTOR_DIR = ROOT / "collector"
DEFAULT_STATE_FILE = COLLECTOR_DIR / "uploaded.tsv"
DEFAULT_INVENTORY_FILE = COLLECTOR_DIR / "r2_inventory.tsv"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def collect_pdfs(collector_dir: Path) -> dict[str, dict]:
    rows: dict[str, dict] = {}
    for path in sorted(collector_dir.glob("*.pdf")):
        if not re.fullmatch(r"[0-9a-f]{32}", path.stem):
            continue
        rows[path.stem] = {
            "doc_id": path.stem,
            "path": str(path),
            "size": path.stat().st_size,
            "sha256": sha256_file(path),
        }
    return rows


def read_state(state_file: Path) -> tuple[dict[str, list[dict]], list[dict]]:
    by_doc: dict[str, list[dict]] = {}
    bad_rows: list[dict] = []
    if not state_file.exists():
        return by_doc, bad_rows

    with state_file.open(newline="", encoding="utf-8") as fh:
        reader = csv.reader(fh, delimiter="\t")
        for row_no, row in enumerate(reader, start=1):
            if len(row) != 5:
                bad_rows.append({"row_no": row_no, "row": row, "reason": "expected_5_columns"})
                continue
            doc_id, sha256, size, uploaded_at, key = row
            if not re.fullmatch(r"[0-9a-f]{32}", doc_id):
                bad_rows.append({"row_no": row_no, "row": row, "reason": "bad_doc_id"})
                continue
            by_doc.setdefault(doc_id, []).append(
                {
                    "row_no": row_no,
                    "doc_id": doc_id,
                    "sha256": sha256,
                    "size": int(size) if size.isdigit() else None,
                    "uploaded_at": uploaded_at,
                    "key": key,
                }
            )
    return by_doc, bad_rows


def latest_state(rows: list[dict]) -> dict:
    return rows[-1]


def read_inventory(inventory_file: Path) -> tuple[dict[str, dict], list[dict]]:
    objects: dict[str, dict] = {}
    bad_rows: list[dict] = []
    if not inventory_file.exists():
        return objects, [{"reason": "inventory_missing", "path": str(inventory_file)}]
    with inventory_file.open(newline="", encoding="utf-8") as fh:
        for row_no, row in enumerate(csv.reader(fh, delimiter="\t"), start=1):
            if row and row[0].startswith("#"):
                continue
            if len(row) != 4 or not row[1].isdigit():
                bad_rows.append({"row_no": row_no, "row": row, "reason": "bad_inventory_row"})
                continue
            key, size, etag, last_modified = row
            objects[key] = {
                "key": key, "size": int(size), "etag": etag,
                "last_modified": last_modified,
            }
    return objects, bad_rows


def build_report(collector_dir: Path, state_file: Path, inventory_file: Path) -> dict:
    pdfs = collect_pdfs(collector_dir)
    state_by_doc, bad_state_rows = read_state(state_file)
    remote, bad_inventory_rows = read_inventory(inventory_file)

    missing = []
    stale = []
    duplicate_state_doc_ids = []
    orphan_state_doc_ids = []
    remote_missing = []
    remote_size_mismatch = []
    remote_present_untracked = []

    for doc_id, pdf in pdfs.items():
        state_rows = state_by_doc.get(doc_id, [])
        key = f"{doc_id}.pdf"
        remote_object = remote.get(key)
        if not remote_object:
            remote_missing.append(doc_id)
        elif remote_object["size"] != pdf["size"]:
            remote_size_mismatch.append({
                "doc_id": doc_id,
                "collector_size": pdf["size"],
                "remote_size": remote_object["size"],
            })
        if not state_rows:
            missing.append(doc_id)
            if remote_object and remote_object["size"] == pdf["size"]:
                remote_present_untracked.append(doc_id)
            continue
        if len(state_rows) > 1:
            duplicate_state_doc_ids.append(doc_id)
        state = latest_state(state_rows)
        if state["sha256"] != pdf["sha256"] or state["size"] != pdf["size"]:
            stale.append(
                {
                    "doc_id": doc_id,
                    "collector_sha256": pdf["sha256"],
                    "state_sha256": state["sha256"],
                    "collector_size": pdf["size"],
                    "state_size": state["size"],
                }
            )

    for doc_id in sorted(set(state_by_doc) - set(pdfs)):
        orphan_state_doc_ids.append(doc_id)

    return {
        "collector_dir": str(collector_dir),
        "state_file": str(state_file),
        "inventory_file": str(inventory_file),
        "collector_pdf_count": len(pdfs),
        "state_doc_count": len(state_by_doc),
        "ok_count": len(pdfs) - len(missing) - len(stale),
        "missing_upload_state_count": len(missing),
        "stale_upload_state_count": len(stale),
        "duplicate_state_doc_id_count": len(duplicate_state_doc_ids),
        "orphan_state_doc_id_count": len(orphan_state_doc_ids),
        "bad_state_row_count": len(bad_state_rows),
        "remote_object_count": len(remote),
        "remote_missing_count": len(remote_missing),
        "remote_size_mismatch_count": len(remote_size_mismatch),
        "remote_present_untracked_count": len(remote_present_untracked),
        "bad_inventory_row_count": len(bad_inventory_rows),
        "missing_upload_state": missing,
        "stale_upload_state": stale,
        "duplicate_state_doc_ids": duplicate_state_doc_ids,
        "orphan_state_doc_ids": orphan_state_doc_ids,
        "bad_state_rows": bad_state_rows,
        "remote_missing": remote_missing,
        "remote_size_mismatch": remote_size_mismatch,
        "remote_present_untracked": remote_present_untracked,
        "bad_inventory_rows": bad_inventory_rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--collector-dir", type=Path, default=COLLECTOR_DIR)
    parser.add_argument("--state-file", type=Path, default=DEFAULT_STATE_FILE)
    parser.add_argument("--inventory-file", type=Path, default=DEFAULT_INVENTORY_FILE)
    parser.add_argument("--json", action="store_true", help="Print full JSON report.")
    parser.add_argument("--strict", action="store_true", help="Exit nonzero when remote objects are missing or conflict.")
    args = parser.parse_args()

    report = build_report(args.collector_dir, args.state_file, args.inventory_file)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"collector_pdf_count={report['collector_pdf_count']}")
        print(f"state_doc_count={report['state_doc_count']}")
        print(f"ok_count={report['ok_count']}")
        print(f"missing_upload_state_count={report['missing_upload_state_count']}")
        print(f"stale_upload_state_count={report['stale_upload_state_count']}")
        print(f"duplicate_state_doc_id_count={report['duplicate_state_doc_id_count']}")
        print(f"orphan_state_doc_id_count={report['orphan_state_doc_id_count']}")
        print(f"bad_state_row_count={report['bad_state_row_count']}")
        print(f"remote_object_count={report['remote_object_count']}")
        print(f"remote_missing_count={report['remote_missing_count']}")
        print(f"remote_size_mismatch_count={report['remote_size_mismatch_count']}")
        print(f"remote_present_untracked_count={report['remote_present_untracked_count']}")
        print(f"bad_inventory_row_count={report['bad_inventory_row_count']}")

    complete = (
        report["remote_missing_count"] == 0
        and report["remote_size_mismatch_count"] == 0
        and report["bad_inventory_row_count"] == 0
    )
    return 1 if args.strict and not complete else 0


if __name__ == "__main__":
    raise SystemExit(main())
