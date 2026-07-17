#!/usr/bin/env python3
"""Fetch one Cloudflare R2 object inventory using Wrangler's Cloudflare login."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tomllib
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "collector" / "r2_inventory.tsv"


def wrangler_config_path() -> Path:
    candidates = [
        Path.home() / "Library/Preferences/.wrangler/config/default.toml",
        Path.home() / ".config/.wrangler/config/default.toml",
        Path.home() / ".wrangler/config/default.toml",
    ]
    for path in candidates:
        if path.is_file():
            return path
    raise RuntimeError("Wrangler OAuth config not found; run `wrangler login`")


def cloudflare_token() -> str:
    token = os.environ.get("CLOUDFLARE_API_TOKEN")
    if token:
        return token
    config = tomllib.loads(wrangler_config_path().read_text(encoding="utf-8"))
    token = config.get("oauth_token")
    if not token:
        raise RuntimeError("Wrangler OAuth token not found; run `wrangler login`")
    return token


def cloudflare_account_id(explicit: str | None) -> str:
    account_id = explicit or os.environ.get("CLOUDFLARE_ACCOUNT_ID")
    if account_id:
        return account_id
    result = subprocess.run(
        ["wrangler", "whoami"], check=True, text=True, capture_output=True
    )
    matches = re.findall(r"\b[0-9a-f]{32}\b", result.stdout)
    if len(set(matches)) != 1:
        raise RuntimeError("Set CLOUDFLARE_ACCOUNT_ID when Wrangler has multiple accounts")
    return matches[0]


def fetch_objects(account_id: str, bucket: str, prefix: str, token: str) -> list[dict]:
    query = urllib.parse.urlencode({"prefix": prefix, "limit": 1000})
    url = (
        f"https://api.cloudflare.com/client/v4/accounts/{account_id}"
        f"/r2/buckets/{urllib.parse.quote(bucket, safe='')}/objects?{query}"
    )
    result = subprocess.run(
        [
            "curl", "--silent", "--show-error", "--fail-with-body",
            "--max-time", "120", "-H", "@-", url,
        ],
        check=True,
        capture_output=True,
        text=True,
        input=f"Authorization: Bearer {token}\n",
    )
    payload = json.loads(result.stdout)
    if not payload.get("success") or not isinstance(payload.get("result"), list):
        raise RuntimeError(f"Cloudflare R2 list failed: {payload.get('errors', payload)}")
    objects = payload["result"]
    if len(objects) >= 1000:
        raise RuntimeError("R2 inventory reached the 1000-object limit; add cursor pagination")
    return objects


def write_inventory(path: Path, bucket: str, prefix: str, objects: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    fetched_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with temp.open("w", encoding="utf-8", newline="") as fh:
        fh.write(f"# bucket={bucket}\tprefix={prefix}\tfetched_at={fetched_at}\n")
        for item in sorted(objects, key=lambda row: row["key"]):
            values = (
                item["key"], str(item["size"]), item.get("etag", ""),
                item.get("last_modified", ""),
            )
            if any("\t" in value or "\n" in value for value in values):
                raise RuntimeError(f"Invalid R2 inventory value for {item['key']!r}")
            fh.write("\t".join(values) + "\n")
    temp.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--prefix", default="collector/")
    parser.add_argument("--account-id")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    try:
        account_id = cloudflare_account_id(args.account_id)
        objects = fetch_objects(account_id, args.bucket, args.prefix, cloudflare_token())
        write_inventory(args.output, args.bucket, args.prefix, objects)
    except (RuntimeError, subprocess.SubprocessError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(f"R2 inventory: bucket={args.bucket} prefix={args.prefix} objects={len(objects)} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
